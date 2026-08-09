import Foundation
import Testing

@testable import ScoreQueue

/// The merge rule is the heart of the queue: it decides what a burst of edits
/// finally delivers. A pure function, so it is tested as one.
@Suite("Coalescence")
struct CoalescenceTests {

    private static let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    private func message(_ kind: QueuedMessage.Kind,
                         subject: String = "s-1",
                         label: String? = nil,
                         at offset: TimeInterval = 0) -> QueuedMessage {
        QueuedMessage(stream: "contact", subject: subject, kind: kind, label: label,
                      at: Self.epoch.addingTimeInterval(offset))
    }

    @Test("The whole table, including the row that leaves nothing behind")
    func table() {
        typealias Kind = QueuedMessage.Kind
        #expect(Kind.coalesced(existing: .create, incoming: .update) == .create)
        #expect(Kind.coalesced(existing: .create, incoming: .delete) == nil)
        #expect(Kind.coalesced(existing: .create, incoming: .create) == .create)
        #expect(Kind.coalesced(existing: .update, incoming: .update) == .update)
        #expect(Kind.coalesced(existing: .update, incoming: .delete) == .delete)
        #expect(Kind.coalesced(existing: .update, incoming: .create) == .create)
        #expect(Kind.coalesced(existing: .delete, incoming: .update) == .update)
        #expect(Kind.coalesced(existing: .delete, incoming: .delete) == .delete)
    }

    @Test("Created and deleted again leaves no message at all")
    func createThenDeleteDropsTheMessage() {
        let open = message(.create)
        #expect(open.coalescing(with: message(.delete, at: 60)) == .drop)
    }

    @Test("Merging keeps identity and origin, takes over the newer label")
    func mergeKeepsIdentity() throws {
        let open = message(.create, label: "old")
        let incoming = message(.update, label: "new", at: 60)

        guard case .keep(let merged) = open.coalescing(with: incoming) else {
            Issue.record("expected a merge")
            return
        }
        #expect(merged.id == open.id)                   // same row
        #expect(merged.enqueuedAt == open.enqueuedAt)   // waiting since when
        #expect(merged.kind == .create)
        #expect(merged.label == "new")                  // the failure list names the newest state
        #expect(merged.updatedAt == incoming.updatedAt)
    }

    @Test("A resting message stays at rest — the way back is the failure list")
    func failedStaysFailed() throws {
        var open = message(.update)
        open.state = .failed
        open.attempts = 4
        open.lastError = "CNErrorDomain 1"

        guard case .keep(let merged) = open.coalescing(with: message(.update, at: 60)) else {
            Issue.record("expected a merge")
            return
        }
        // The newer intent is merged …
        #expect(merged.updatedAt == Self.epoch.addingTimeInterval(60))
        // … but it does not start running again by itself.
        #expect(merged.state == .failed)
        #expect(merged.nextAttemptAt == open.nextAttemptAt)
    }

    @Test("A pending message becomes due at once when a newer state arrives")
    func pendingBecomesDueAgain() throws {
        var open = message(.update)
        open.attempts = 1
        open.nextAttemptAt = Self.epoch.addingTimeInterval(30)   // inside the backoff

        guard case .keep(let merged) = open.coalescing(with: message(.update, at: 5)) else {
            Issue.record("expected a merge")
            return
        }
        #expect(merged.nextAttemptAt == Self.epoch.addingTimeInterval(5))
        // Attempts are kept: otherwise a row that keeps failing would never
        // come to rest as long as anyone touches it.
        #expect(merged.attempts == 1)
    }
}

@Suite("RetryPolicy")
struct RetryPolicyTests {

    private static let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Three quiet retries, then rest")
    func threeQuietRetries() {
        let policy = RetryPolicy.standard
        #expect(policy.next(afterAttempt: 1, now: Self.epoch)
                    == .retry(at: Self.epoch.addingTimeInterval(5)))
        #expect(policy.next(afterAttempt: 2, now: Self.epoch)
                    == .retry(at: Self.epoch.addingTimeInterval(30)))
        #expect(policy.next(afterAttempt: 3, now: Self.epoch)
                    == .retry(at: Self.epoch.addingTimeInterval(120)))
        #expect(policy.next(afterAttempt: 4, now: Self.epoch) == .markFailed)
    }

    @Test("Without delays a message rests after the first failure")
    func emptyPolicyFailsAtOnce() {
        #expect(RetryPolicy(delays: []).next(afterAttempt: 1, now: Self.epoch) == .markFailed)
    }
}
