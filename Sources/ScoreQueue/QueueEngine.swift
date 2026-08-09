import Foundation

/// What happened while draining. The queue itself logs nothing: it reports, and
/// the host decides what to write where (a library cannot know a project's
/// privacy rules, and ``QueuedMessage/label`` must never reach a log).
public enum QueueEvent: Sendable, Equatable {
    case drainStarted(due: Int)
    case delivered(id: UUID, stream: String)
    case discarded(id: UUID, stream: String, reason: String)
    case deferred(id: UUID, stream: String, until: Date)
    case parked(stream: String, reason: String)
    case retryScheduled(id: UUID, stream: String, attempt: Int, at: Date, error: String)
    case failed(id: UUID, stream: String, attempt: Int, error: String)
    case drainFinished(delivered: Int, remaining: Int)
    /// The store itself could not be reached — nothing is held against any
    /// message, the drain stops.
    case storeUnavailable(error: String)
}

/// Drains the queue: takes what is due, hands it to the handler of its stream,
/// and applies the retry policy to whatever comes back.
///
/// An `actor`, so exactly one drain runs at a time. A second caller does not
/// wait for a slot and does not start a competing pass — it marks that another
/// pass is needed, and the running loop repeats.
public actor QueueEngine {

    private let store: any MessageStore
    private let handlers: [String: any MessageHandler]
    private let policy: RetryPolicy
    private let clock: @Sendable () -> Date
    private let batchSize: Int
    private let observe: @Sendable (QueueEvent) -> Void

    private var isDraining = false
    private var needsAnotherPass = false

    public init(store: any MessageStore,
                handlers: [any MessageHandler],
                policy: RetryPolicy = .standard,
                batchSize: Int = 50,
                clock: @escaping @Sendable () -> Date = { Date() },
                observe: @escaping @Sendable (QueueEvent) -> Void = { _ in }) {
        self.store = store
        self.handlers = Dictionary(handlers.map { ($0.stream, $0) },
                                   uniquingKeysWith: { _, last in last })
        self.policy = policy
        self.batchSize = batchSize
        self.clock = clock
        self.observe = observe
    }

    // MARK: - Draining

    /// Delivers everything that is due. Never throws: a background loop that
    /// can fail its caller is a background loop nobody dares to start.
    public func drain() async {
        guard !isDraining else {
            needsAnotherPass = true
            return
        }
        isDraining = true
        defer { isDraining = false }

        repeat {
            needsAnotherPass = false
            await drainOnce()
        } while needsAnotherPass
    }

    private func drainOnce() async {
        var delivered = 0
        // A message is touched at most once per drain. Without this a handler
        // that defers into the past would spin the loop forever.
        var seen: Set<UUID> = []

        while true {
            let now = clock()
            let batch: [QueuedMessage]
            do {
                batch = try await store.due(at: now, limit: batchSize)
                    .filter { !seen.contains($0.id) }
            } catch {
                observe(.storeUnavailable(error: String(describing: error)))
                return
            }
            guard !batch.isEmpty else { break }
            if delivered == 0 { observe(.drainStarted(due: batch.count)) }

            for message in batch {
                seen.insert(message.id)
                let outcome = await deliver(message)
                switch outcome {
                case .delivered: delivered += 1
                case .stop:
                    observe(.drainFinished(delivered: delivered,
                                           remaining: (try? await store.pendingCount()) ?? 0))
                    return
                case .continued: break
                }
            }
        }

        if delivered > 0 || seen.count > 0 {
            observe(.drainFinished(delivered: delivered,
                                   remaining: (try? await store.pendingCount()) ?? 0))
        }
    }

    private enum Step { case delivered, continued, stop }

    private func deliver(_ message: QueuedMessage) async -> Step {
        guard let handler = handlers[message.stream] else {
            // A wiring mistake, not a transient failure — it rests at once and
            // is named in the failure list rather than retried three times.
            await park(message, error: String(describing: QueueError.noHandler(stream: message.stream)))
            return .continued
        }

        do {
            switch try await handler.handle(message) {
            case .done:
                try await store.remove(id: message.id)
                observe(.delivered(id: message.id, stream: message.stream))
                return .delivered

            case .discarded(let reason):
                try await store.remove(id: message.id)
                observe(.discarded(id: message.id, stream: message.stream, reason: reason))
                return .continued

            case .deferred(let until):
                var deferredMessage = message
                deferredMessage.nextAttemptAt = until
                deferredMessage.updatedAt = clock()
                try await store.update(deferredMessage)
                observe(.deferred(id: message.id, stream: message.stream, until: until))
                return .continued

            case .parked(let reason):
                observe(.parked(stream: message.stream, reason: reason))
                return .stop
            }
        } catch {
            await recordFailure(of: message, error: error)
            return .continued
        }
    }

    private func recordFailure(of message: QueuedMessage, error: any Error) async {
        let now = clock()
        let text = String(describing: error)
        var failing = message
        failing.attempts += 1
        failing.lastError = text
        failing.updatedAt = now

        switch policy.next(afterAttempt: failing.attempts, now: now) {
        case .retry(let at):
            failing.nextAttemptAt = at
            observe(.retryScheduled(id: message.id, stream: message.stream,
                                    attempt: failing.attempts, at: at, error: text))
        case .markFailed:
            failing.state = .failed
            observe(.failed(id: message.id, stream: message.stream,
                            attempt: failing.attempts, error: text))
        }
        try? await store.update(failing)
    }

    /// Comes to rest immediately, without using up the retries.
    private func park(_ message: QueuedMessage, error: String) async {
        var parked = message
        parked.state = .failed
        parked.lastError = error
        parked.updatedAt = clock()
        observe(.failed(id: message.id, stream: message.stream,
                        attempt: parked.attempts, error: error))
        try? await store.update(parked)
    }

    // MARK: - The failure list (settings)

    public func failedMessages() async throws -> [QueuedMessage] {
        try await store.failed()
    }

    /// «Try again»: back into processing, attempts reset, due now.
    public func retry(id: UUID) async throws {
        try await store.clearFailure(id: id, at: clock())
    }

    /// «Discard»: the intent is given up. The row keeps its local state — only
    /// the push is abandoned.
    public func discard(id: UUID) async throws {
        try await store.remove(id: id)
    }
}
