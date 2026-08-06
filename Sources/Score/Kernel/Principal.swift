import Foundation

/// What the business layer may know about the caller (ARCH §13.1, Rule AUTH-1).
/// Resolved by the transport boundary (JWT middleware / session), never by services.
public struct Principal: Codable, Sendable, Equatable {
    public let userID: UUID
    public let roles: Set<String>

    public init(userID: UUID, roles: Set<String>) {
        self.userID = userID
        self.roles = roles
    }

    public var isAdmin: Bool { roles.contains("admin") }
}
