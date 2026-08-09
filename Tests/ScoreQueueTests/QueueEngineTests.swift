import Foundation
import Testing

@testable import ScoreQueue

/// The engine against the in-memory store, with a settable clock — backoff
/// windows are wound forward instead of waited out.
@Suite("QueueEngine")
struct QueueEngineTests {

    private static let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    private final class MutableClock: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Date
        init(_ value: Date) { self.value = value }
        var now: Date {
            lock.lock(); defer { lock.unlock() }
            return value
        }
        func advance(by interval: TimeInterval) {
            lock.lock(); defer { lock.unlock() }
            value = value.addingTimeInterval(interval)
        }
    }

    /// A handler with a script: it answers as told and records what it saw.
    private actor ScriptedHandler: MessageHandler {
        nonisolated let stream: String
        private var outcomes: [Result<HandlerOutcome, any Error>]
        private var fallback: Result<HandlerOutcome, any Error>
        private(set) var seen: [QueuedMessage] = []

        init(stream: String = "contact",
             outcomes: [Result<HandlerOutcome, any Error>] = [],
             fallback: Result<HandlerOutcome, any Error> = .success(.done)) {
            self.stream = stream
            self.outcomes = outcomes
            self.fallback = fallback
        }

        func handle(_ message: QueuedMessage) async throws -> HandlerOutcome {
            seen.append(message)
            let next = outcomes.isEmpty ? fallback : outcomes.removeFirst()
            return try next.get()
        }
    }

    private struct TestError: Error, CustomStringConvertible {
        let description: String
    }

    private final class EventLog: @unchecked Sendable {
        private let lock = NSLock()
        private var events: [QueueEvent] = []
        func record(_ event: QueueEvent) {
            lock.lock(); defer { lock.unlock() }
            events.append(event)
        }
        var all: [QueueEvent] {
            lock.lock(); defer { lock.unlock() }
            return events
        }
    }

    private func makeEngine(store: InMemoryMessageStore,
                            handler: any MessageHandler,
                            clock: MutableClock,
                            log: EventLog) -> QueueEngine {
        QueueEngine(store: store, handlers: [handler], policy: .standard,
                    clock: { clock.now }, observe: { log.record($0) })
    }

    /// `at` shifts the enqueue instant. Where a test cares which message is
    /// taken first it must say so: equal instants leave the order to the id.
    private func message(_ kind: QueuedMessage.Kind = .update,
                         subject: String = "s-1",
                         stream: String = "contact",
                         at offset: TimeInterval = 0) -> QueuedMessage {
        QueuedMessage(stream: stream, subject: subject, kind: kind,
                      at: Self.epoch.addingTimeInterval(offset))
    }

    @Test("Delivered messages are gone")
    func deliveredMessagesAreRemoved() async throws {
        let store = InMemoryMessageStore()
        let clock = MutableClock(Self.epoch)
        let log = EventLog()
        let handler = ScriptedHandler()
        try await store.enqueue(message())

        await makeEngine(store: store, handler: handler, clock: clock, log: log).drain()

        #expect(await store.all().isEmpty)
        #expect(await handler.seen.count == 1)
    }

    @Test("A failure waits, and comes to rest after the third retry")
    func failuresBackOffThenRest() async throws {
        let store = InMemoryMessageStore()
        let clock = MutableClock(Self.epoch)
        let log = EventLog()
        let handler = ScriptedHandler(
            outcomes: [], fallback: .failure(TestError(description: "boom")))
        let engine = makeEngine(store: store, handler: handler, clock: clock, log: log)
        try await store.enqueue(message())

        // Attempt 1 → 5 s, attempt 2 → 30 s, attempt 3 → 120 s, attempt 4 → rest.
        for wait in [5.0, 30.0, 120.0] {
            await engine.drain()
            let waiting = try #require(await store.all().first)
            #expect(waiting.state == .pending)
            #expect(waiting.nextAttemptAt == clock.now.addingTimeInterval(wait))
            // Not due yet: a drain right now must not touch it.
            await engine.drain()
            #expect(await handler.seen.count == Int(waiting.attempts))
            clock.advance(by: wait)
        }
        await engine.drain()

        let resting = try #require(await store.all().first)
        #expect(resting.state == .failed)
        #expect(resting.attempts == 4)
        #expect(resting.lastError?.contains("boom") == true)
        // And it stays at rest, however often the queue is drained.
        clock.advance(by: 3600)
        await engine.drain()
        #expect(await handler.seen.count == 4)
    }

    @Test("Clearing the failure puts it back into processing")
    func clearingFailureResumes() async throws {
        let store = InMemoryMessageStore()
        let clock = MutableClock(Self.epoch)
        let log = EventLog()
        let handler = ScriptedHandler(outcomes: [
            .failure(TestError(description: "boom")), .failure(TestError(description: "boom")),
            .failure(TestError(description: "boom")), .failure(TestError(description: "boom")),
        ], fallback: .success(.done))
        let engine = makeEngine(store: store, handler: handler, clock: clock, log: log)
        try await store.enqueue(message())
        for _ in 0..<4 {
            await engine.drain()
            clock.advance(by: 200)
        }
        let resting = try #require(await engine.failedMessages().first)

        try await engine.retry(id: resting.id)
        await engine.drain()

        #expect(await store.all().isEmpty)      // delivered on the fifth attempt
        #expect(try await engine.failedMessages().isEmpty)
    }

    @Test("deferred and parked are not failures")
    func deferredAndParkedDoNotCount() async throws {
        let store = InMemoryMessageStore()
        let clock = MutableClock(Self.epoch)
        let log = EventLog()
        let later = Self.epoch.addingTimeInterval(600)
        let handler = ScriptedHandler(outcomes: [
            .success(.deferred(until: later)),
        ], fallback: .success(.parked(reason: "noPermission")))
        let engine = makeEngine(store: store, handler: handler, clock: clock, log: log)
        try await store.enqueue(message(subject: "s-1", at: -10))   // taken first
        try await store.enqueue(message(subject: "s-2"))

        await engine.drain()

        let messages = await store.all()
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.attempts == 0 && $0.state == .pending })
        #expect(messages.first { $0.subject == "s-1" }?.nextAttemptAt == later)
        #expect(log.all.contains(.parked(stream: "contact", reason: "noPermission")))
    }

    @Test("Parking stops the drain — nothing behind it is attempted")
    func parkingStopsTheDrain() async throws {
        let store = InMemoryMessageStore()
        let clock = MutableClock(Self.epoch)
        let log = EventLog()
        let handler = ScriptedHandler(fallback: .success(.parked(reason: "noPermission")))
        let engine = makeEngine(store: store, handler: handler, clock: clock, log: log)
        for index in 0..<5 { try await store.enqueue(message(subject: "s-\(index)")) }

        await engine.drain()

        #expect(await handler.seen.count == 1)
        #expect(await store.all().count == 5)
    }

    @Test("A discarded message is removed and its reason reported")
    func discardedIsNamed() async throws {
        let store = InMemoryMessageStore()
        let clock = MutableClock(Self.epoch)
        let log = EventLog()
        let handler = ScriptedHandler(fallback: .success(.discarded(reason: "remoteIsNewer")))
        try await store.enqueue(message())

        await makeEngine(store: store, handler: handler, clock: clock, log: log).drain()

        #expect(await store.all().isEmpty)
        #expect(log.all.contains { event in
            if case .discarded(_, "contact", "remoteIsNewer") = event { return true }
            return false
        })
    }

    @Test("A stream without a handler rests at once and is named")
    func unknownStreamRestsImmediately() async throws {
        let store = InMemoryMessageStore()
        let clock = MutableClock(Self.epoch)
        let log = EventLog()
        let handler = ScriptedHandler(stream: "contact")
        try await store.enqueue(message(stream: "reminder"))

        await makeEngine(store: store, handler: handler, clock: clock, log: log).drain()

        let resting = try #require(await store.all().first)
        #expect(resting.state == .failed)
        #expect(resting.attempts == 0)               // no retries used up
        #expect(resting.lastError?.contains("noHandler") == true)
    }

    @Test("A handler that defers into the past does not spin the drain")
    func deferringIntoThePastTerminates() async throws {
        let store = InMemoryMessageStore()
        let clock = MutableClock(Self.epoch)
        let log = EventLog()
        let handler = ScriptedHandler(
            fallback: .success(.deferred(until: Self.epoch.addingTimeInterval(-60))))
        try await store.enqueue(message())

        await makeEngine(store: store, handler: handler, clock: clock, log: log).drain()

        #expect(await handler.seen.count == 1)
    }

    @Test("Delivery is idempotent: the same message may arrive twice")
    func deliveryIsIdempotent() async throws {
        // The crash window between the remote write and the removal of the
        // message: the message survives, so it is delivered again.
        let store = InMemoryMessageStore()
        let clock = MutableClock(Self.epoch)
        let log = EventLog()
        let handler = ScriptedHandler()
        let engine = makeEngine(store: store, handler: handler, clock: clock, log: log)
        let pending = message()
        try await store.enqueue(pending)

        await engine.drain()
        try await store.enqueue(pending)    // as if the removal had been lost
        await engine.drain()

        #expect(await handler.seen.count == 2)
        #expect(await store.all().isEmpty)
    }
}
