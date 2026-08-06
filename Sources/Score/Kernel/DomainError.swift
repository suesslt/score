import Foundation

/// The single serializable error type thrown by services in every configuration (ARCH §5.2).
///
/// Local configurations throw it directly; server configurations map it to an HTTP status and the
/// client stub re-throws the same value. The presentation layer maps it to user-facing text
/// (UI_GUIDELINES §12.2) — never this layer.
///
/// `notFound` carries the identity as `String` so that entities keyed by `UUID`, `Int`, or a
/// composite value type can all report it; the typed convenience factories below keep call sites
/// with `UUID`/`Int` identities unchanged.
public enum DomainError: Error, Codable, Sendable, Equatable {
    /// An entity of the given type with the given identity was not found.
    case notFound(entity: String, id: String)
    /// A field failed validation.
    case validation(field: String, message: String)
    /// The change conflicts with the current state (e.g. an optimistic-concurrency conflict).
    case conflict(message: String)
    /// A business rule refused the operation, identified by a stable, machine-matchable code
    /// (e.g. `"freemium.bookingLimit"`) so the presentation layer can react specifically
    /// (UI-31/WEB-8). `message` may carry a service-provided reason; it may be empty when the
    /// presentation layer resolves the code itself. Maps to HTTP 409 (like `.conflict`).
    case businessRule(code: String, message: String)
    /// The caller is not authenticated/authorized.
    case unauthorized
    /// A persistence failure (wraps a storage-layer error message).
    case storage(message: String)
    /// A transport failure (client stub only).
    case transport(message: String)
}

public extension DomainError {
    static func notFound(entity: String, id: UUID) -> DomainError {
        .notFound(entity: entity, id: id.uuidString)
    }

    static func notFound(entity: String, id: Int) -> DomainError {
        .notFound(entity: entity, id: String(id))
    }

    /// Code-only business rule; the presentation layer owns the user-facing reason.
    static func businessRule(_ code: String) -> DomainError {
        .businessRule(code: code, message: "")
    }
}
