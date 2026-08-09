import Foundation

/// Durable storage for ``QueuedMessage``. One implementation per storage
/// technology; `ScoreQueueGRDB` ships the SQLite one, ``InMemoryMessageStore``
/// covers Configuration T.
///
/// **The one hard requirement.** ``enqueue(_:)`` must be able to run *inside*
/// the caller's transaction, so that a change to a row and the message about it
/// are committed together — or not at all. A store that opens its own
/// transaction breaks the whole construction: a rollback would leave a message
/// about a change that never happened.
public protocol MessageStore: Sendable {

    /// Stores the intent, merging it into an open message for the same
    /// `(stream, subject)` (see ``QueuedMessage/coalescing(with:)``).
    ///
    /// Merging may **remove** the open message and store nothing
    /// (create + delete): something never pushed needs no deletion.
    func enqueue(_ message: QueuedMessage) async throws

    /// Messages ready for delivery, oldest first. `failed` messages never are.
    func due(at now: Date, limit: Int) async throws -> [QueuedMessage]

    /// Everything that came to rest with a failure — the settings list.
    func failed() async throws -> [QueuedMessage]

    /// Number of messages that are not `failed` — «still to be delivered».
    func pendingCount() async throws -> Int

    func update(_ message: QueuedMessage) async throws

    func remove(id: UUID) async throws

    /// Puts a failed message back into processing: `pending`, no attempts, due
    /// now. The named way back from the failure list.
    func clearFailure(id: UUID, at now: Date) async throws
}

/// Errors the queue itself raises. Projects map them to their own
/// `DomainError` at the adapter boundary — the library ships no display texts.
public enum QueueError: Error, Sendable, Equatable {
    /// No handler is registered for that stream. A wiring mistake, and named
    /// rather than silently swallowed.
    case noHandler(stream: String)
    case notFound(id: UUID)
}
