import Foundation

/// A durable, ordered **intent** to push a local change to an external system.
///
/// The message deliberately carries **no payload**. Its body is read fresh from
/// the owning row when the message is delivered — a payload would deliver a
/// state that no longer exists, and it would defeat the late comparisons that
/// make delivery correct (a member diff computed at push time, a field mask
/// against the *current* remote record).
///
/// The one exception is ``label``: a display text kept purely so the failure
/// list can name *what* is affected, even after the row itself is gone.
public struct QueuedMessage: Identifiable, Codable, Sendable, Equatable {

    /// What the delivery is meant to achieve. See ``coalesced(existing:incoming:)``.
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case create, update, delete
    }

    /// Where a message stands. A `failed` message rests: it is never delivered
    /// again until someone clears the failure (`MessageStore.clearFailure`).
    public enum State: String, Codable, Sendable, CaseIterable {
        case pending, failed
    }

    public let id: UUID
    /// The kind of subject — one handler per stream (`"contact"`, `"group"`, …).
    public let stream: String
    /// Identifies the subject within its stream. Together with ``stream`` it is
    /// unique across all open messages, which is what makes coalescence possible.
    public let subject: String
    public var kind: Kind
    /// Display text for the failure list only. Never logged (it names a person).
    public var label: String?
    /// How often delivery has been attempted and failed.
    public var attempts: Int
    /// Not due before this instant — backoff after a failure, or a handler that
    /// asked to be called later (`HandlerOutcome.deferred`).
    public var nextAttemptAt: Date
    public var state: State
    /// Why the last attempt failed. Kept for the failure list.
    public var lastError: String?
    public let enqueuedAt: Date
    public var updatedAt: Date

    public init(id: UUID,
                stream: String,
                subject: String,
                kind: Kind,
                label: String? = nil,
                attempts: Int = 0,
                nextAttemptAt: Date,
                state: State = .pending,
                lastError: String? = nil,
                enqueuedAt: Date,
                updatedAt: Date) {
        self.id = id
        self.stream = stream
        self.subject = subject
        self.kind = kind
        self.label = label
        self.attempts = attempts
        self.nextAttemptAt = nextAttemptAt
        self.state = state
        self.lastError = lastError
        self.enqueuedAt = enqueuedAt
        self.updatedAt = updatedAt
    }

    /// A fresh, immediately due message.
    public init(id: UUID = UUID(),
                stream: String,
                subject: String,
                kind: Kind,
                label: String? = nil,
                at now: Date) {
        self.init(id: id, stream: stream, subject: subject, kind: kind,
                  label: label, attempts: 0, nextAttemptAt: now,
                  state: .pending, lastError: nil,
                  enqueuedAt: now, updatedAt: now)
    }

    /// Due for delivery at `now`? A failed message never is.
    public func isDue(at now: Date) -> Bool {
        state == .pending && nextAttemptAt <= now
    }
}

// MARK: - Coalescence

extension QueuedMessage.Kind {

    /// What a stored intent and a newer one add up to. A pure function, because
    /// this table is the whole of the merge rule and deserves to be read and
    /// tested as one.
    ///
    /// | stored | incoming | result |
    /// |--------|----------|--------|
    /// | create | update   | create — the creation carries the change along |
    /// | create | delete   | **nothing** — something never pushed needs no deletion |
    /// | update | delete   | delete |
    /// | delete | update   | update — a revival |
    ///
    /// `nil` means the stored message is dropped and no new one takes its place.
    public static func coalesced(existing: Self, incoming: Self) -> Self? {
        switch (existing, incoming) {
        case (.create, .update): .create
        case (.create, .delete): nil
        case (.create, .create): .create
        case (.update, _): incoming
        case (.delete, .delete): .delete
        case (.delete, _): incoming
        }
    }
}

extension QueuedMessage {

    /// The result of merging a newer intent into this message.
    public enum Coalescence: Sendable, Equatable {
        /// Store this message in place of the old one.
        case keep(QueuedMessage)
        /// Drop the stored message; nothing is delivered.
        case drop
    }

    /// Merges a newer intent into a stored message.
    ///
    /// **A failed message stays failed.** The newer intent is merged so that a
    /// later retry delivers the *current* state — but the message does not
    /// silently re-enter processing. Otherwise a row that keeps failing would
    /// churn through the backoff on every edit, and the named way back (the
    /// failure list) would never be reached.
    public func coalescing(with incoming: QueuedMessage) -> Coalescence {
        guard let kind = Kind.coalesced(existing: self.kind, incoming: incoming.kind) else {
            return .drop
        }
        var merged = self
        merged.kind = kind
        merged.label = incoming.label ?? self.label
        merged.updatedAt = incoming.updatedAt
        // A pending message becomes due again right away: the state it carries
        // has just changed, so any backoff from an earlier attempt is moot.
        if merged.state == .pending {
            merged.nextAttemptAt = min(merged.nextAttemptAt, incoming.nextAttemptAt)
        }
        return .keep(merged)
    }
}
