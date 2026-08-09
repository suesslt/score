import Foundation

/// Configuration T — the same contract without a storage engine.
///
/// Not a test double bolted on beside the real thing: it runs the *same*
/// coalescence and the *same* ordering, and the contract test covers both
/// implementations.
public actor InMemoryMessageStore: MessageStore {

    private var messages: [UUID: QueuedMessage] = [:]

    public init(_ messages: [QueuedMessage] = []) {
        for message in messages { self.messages[message.id] = message }
    }

    public func enqueue(_ message: QueuedMessage) async throws {
        guard let open = messages.values.first(where: {
            $0.stream == message.stream && $0.subject == message.subject
        }) else {
            messages[message.id] = message
            return
        }
        switch open.coalescing(with: message) {
        case .keep(let merged): messages[open.id] = merged
        case .drop: messages[open.id] = nil
        }
    }

    public func due(at now: Date, limit: Int) async throws -> [QueuedMessage] {
        Array(messages.values
            .filter { $0.isDue(at: now) }
            .sorted { ($0.nextAttemptAt, $0.enqueuedAt, $0.id) < ($1.nextAttemptAt, $1.enqueuedAt, $1.id) }
            .prefix(limit))
    }

    public func failed() async throws -> [QueuedMessage] {
        messages.values
            .filter { $0.state == .failed }
            .sorted { ($0.updatedAt, $0.id) < ($1.updatedAt, $1.id) }
    }

    public func pendingCount() async throws -> Int {
        messages.values.count { $0.state == .pending }
    }

    public func update(_ message: QueuedMessage) async throws {
        guard messages[message.id] != nil else { throw QueueError.notFound(id: message.id) }
        messages[message.id] = message
    }

    public func remove(id: UUID) async throws {
        messages[id] = nil
    }

    public func clearFailure(id: UUID, at now: Date) async throws {
        guard var message = messages[id] else { throw QueueError.notFound(id: id) }
        message.state = .pending
        message.attempts = 0
        message.nextAttemptAt = now
        message.lastError = nil
        message.updatedAt = now
        messages[id] = message
    }

    /// Everything, in no particular order — diagnostics and tests.
    public func all() -> [QueuedMessage] { Array(messages.values) }
}
