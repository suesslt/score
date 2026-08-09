import Foundation

/// What a delivery attempt achieved.
///
/// Note what is **not** an error here: a subject that is not ready yet
/// (`deferred`) and a missing permission (`parked`). Neither says the message
/// is bad, so neither counts as a failed attempt — otherwise a locked-out queue
/// would mark everything failed while nothing was ever wrong with it.
public enum HandlerOutcome: Sendable, Equatable {
    /// Delivered. The message is removed.
    case done
    /// Deliberately not delivered — the remote state is newer, so the local
    /// intent is dropped. The reason is reported, never swallowed.
    case discarded(reason: String)
    /// Not yet: try again at that instant. Attempts are unchanged.
    case deferred(until: Date)
    /// The whole queue must rest (no permission, storage unavailable). The
    /// drain stops; nothing is counted against any message.
    case parked(reason: String)
}

/// Delivers the messages of exactly one stream.
///
/// The handler reads the body **fresh** from the owning row — the message
/// carries an intent, not a payload. Delivery has to be idempotent: a crash
/// between the remote write and the removal of the message means the same
/// message arrives twice.
public protocol MessageHandler: Sendable {
    var stream: String { get }
    func handle(_ message: QueuedMessage) async throws -> HandlerOutcome
}
