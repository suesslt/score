import Foundation
import GRDB

/// How ``GRDBMessageStore`` reaches the database.
///
/// Deliberately **not** a `DatabaseWriter`: the store must be able to write
/// inside the caller's open transaction, and GRDB's own `write { … }` would
/// start a second one. A host that brackets its transactions by hand (a queue
/// held exclusively across `await` boundaries, savepoints for the inner writes)
/// conforms this protocol to that bracket, and the store inherits it.
///
/// ``DatabaseWriterAccess`` is the plain implementation for hosts without such
/// a bracket.
public protocol DatabaseAccess: Sendable {
    func read<T: Sendable>(_ body: @escaping @Sendable (Database) throws -> T) async throws -> T
    func write<T: Sendable>(_ body: @escaping @Sendable (Database) throws -> T) async throws -> T
}

/// Straight through to a GRDB writer — each call is its own transaction.
///
/// Good enough where the queue is the only writer. A host that must commit a
/// row change and its message together conforms ``DatabaseAccess`` to its own
/// transaction bracket instead.
public struct DatabaseWriterAccess: DatabaseAccess {
    private let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func read<T: Sendable>(
        _ body: @escaping @Sendable (Database) throws -> T
    ) async throws -> T {
        try await writer.read(body)
    }

    public func write<T: Sendable>(
        _ body: @escaping @Sendable (Database) throws -> T
    ) async throws -> T {
        try await writer.write(body)
    }
}
