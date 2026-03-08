import Foundation

/// Typed errors for all services.
/// Every service throws exclusively ServiceError instances.
public enum ServiceError: LocalizedError, Sendable {
    /// Entity was not found.
    case notFound(String)

    /// Input validation failed.
    case validation(String)

    /// Business rule violated.
    case businessRule(String)

    /// Persistence failed.
    case persistence(Error)

    /// No permission for this operation.
    case authorization(String)

    /// Data conflict (e.g. overlapping periods, duplicate keys).
    case conflict(String)

    /// Calculation error (e.g. missing FX rate, insufficient data).
    case calculation(String)

    /// Import error (e.g. malformed CSV, missing columns).
    case importError(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let detail):
            return "Not found: \(detail)"
        case .validation(let detail):
            return "Validation error: \(detail)"
        case .businessRule(let detail):
            return detail
        case .persistence(let error):
            return "Persistence error: \(error.localizedDescription)"
        case .authorization(let detail):
            return "Not authorized: \(detail)"
        case .conflict(let detail):
            return "Conflict: \(detail)"
        case .calculation(let detail):
            return "Calculation error: \(detail)"
        case .importError(let detail):
            return "Import error: \(detail)"
        }
    }
}
