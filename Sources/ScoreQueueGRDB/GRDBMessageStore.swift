import Foundation
import GRDB
import ScoreQueue

/// ``MessageStore`` over SQLite (GRDB).
///
/// **Deliberately raw SQL with explicit `Date` arguments.** A Codable record
/// would encode dates through GRDB's Codable strategy (a number) while a bound
/// parameter in a comparison goes through `DatabaseValueConvertible` (text) —
/// the two would not compare, and `due(at:)` would quietly return the wrong
/// rows. Text throughout sorts chronologically and leaves nothing to interpret.
public struct GRDBMessageStore: MessageStore {

    private let access: any DatabaseAccess
    private let table = QueueMigration.tableName

    public init(access: any DatabaseAccess) {
        self.access = access
    }

    public init(writer: any DatabaseWriter) {
        self.init(access: DatabaseWriterAccess(writer))
    }

    // MARK: - Writing

    public func enqueue(_ message: QueuedMessage) async throws {
        let table = self.table
        try await access.write { db in
            let open = try Self.row(
                db, table: table,
                sql: "SELECT * FROM \(table) WHERE stream = ? AND subject = ?",
                arguments: [message.stream, message.subject])

            guard let open else {
                try Self.insert(message, into: db, table: table)
                return
            }
            switch open.coalescing(with: message) {
            case .keep(let merged): try Self.write(merged, into: db, table: table)
            case .drop: try db.execute(sql: "DELETE FROM \(table) WHERE id = ?",
                                       arguments: [open.id.uuidString])
            }
        }
    }

    public func update(_ message: QueuedMessage) async throws {
        let table = self.table
        try await access.write { db in
            try Self.write(message, into: db, table: table)
            guard db.changesCount > 0 else { throw QueueError.notFound(id: message.id) }
        }
    }

    public func remove(id: UUID) async throws {
        let table = self.table
        try await access.write { db in
            try db.execute(sql: "DELETE FROM \(table) WHERE id = ?", arguments: [id.uuidString])
        }
    }

    public func clearFailure(id: UUID, at now: Date) async throws {
        let table = self.table
        try await access.write { db in
            try db.execute(sql: """
                UPDATE \(table)
                   SET state = 'pending', attempts = 0, lastError = NULL,
                       nextAttemptAt = ?, updatedAt = ?
                 WHERE id = ?
                """, arguments: [now, now, id.uuidString])
            guard db.changesCount > 0 else { throw QueueError.notFound(id: id) }
        }
    }

    // MARK: - Reading

    public func due(at now: Date, limit: Int) async throws -> [QueuedMessage] {
        let table = self.table
        return try await access.read { db in
            try Self.rows(db, table: table, sql: """
                SELECT * FROM \(table)
                 WHERE state = 'pending' AND nextAttemptAt <= ?
                 ORDER BY nextAttemptAt, enqueuedAt, id
                 LIMIT ?
                """, arguments: [now, limit])
        }
    }

    public func failed() async throws -> [QueuedMessage] {
        let table = self.table
        return try await access.read { db in
            try Self.rows(db, table: table, sql: """
                SELECT * FROM \(table) WHERE state = 'failed' ORDER BY updatedAt, id
                """, arguments: [])
        }
    }

    public func pendingCount() async throws -> Int {
        let table = self.table
        return try await access.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table) WHERE state = 'pending'") ?? 0
        }
    }

    /// Everything, oldest first — diagnostics and tests.
    public func all() async throws -> [QueuedMessage] {
        let table = self.table
        return try await access.read { db in
            try Self.rows(db, table: table,
                          sql: "SELECT * FROM \(table) ORDER BY enqueuedAt, id",
                          arguments: [])
        }
    }

    // MARK: - Mapping

    private static func insert(_ message: QueuedMessage, into db: Database,
                               table: String) throws {
        try db.execute(sql: """
            INSERT INTO \(table)
                (id, stream, subject, kind, label, attempts, nextAttemptAt,
                 state, lastError, enqueuedAt, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                message.id.uuidString, message.stream, message.subject,
                message.kind.rawValue, message.label, message.attempts,
                message.nextAttemptAt, message.state.rawValue, message.lastError,
                message.enqueuedAt, message.updatedAt,
            ])
    }

    /// Updates everything that may change; `id`, `stream`, `subject` and
    /// `enqueuedAt` are identity and origin and stay put.
    private static func write(_ message: QueuedMessage, into db: Database,
                              table: String) throws {
        try db.execute(sql: """
            UPDATE \(table)
               SET kind = ?, label = ?, attempts = ?, nextAttemptAt = ?,
                   state = ?, lastError = ?, updatedAt = ?
             WHERE id = ?
            """, arguments: [
                message.kind.rawValue, message.label, message.attempts,
                message.nextAttemptAt, message.state.rawValue, message.lastError,
                message.updatedAt, message.id.uuidString,
            ])
    }

    private static func row(_ db: Database, table: String, sql: String,
                            arguments: StatementArguments) throws -> QueuedMessage? {
        try Row.fetchOne(db, sql: sql, arguments: arguments).flatMap(message(from:))
    }

    private static func rows(_ db: Database, table: String, sql: String,
                             arguments: StatementArguments) throws -> [QueuedMessage] {
        try Row.fetchAll(db, sql: sql, arguments: arguments).compactMap(message(from:))
    }

    /// A row whose `id`, `kind` or `state` cannot be read is skipped rather
    /// than crashing the drain — but it is not silently lost either: it stays
    /// in the table and shows up in ``all()``.
    private static func message(from row: Row) -> QueuedMessage? {
        guard let id = UUID(uuidString: row["id"]),
              let kind = QueuedMessage.Kind(rawValue: row["kind"]),
              let state = QueuedMessage.State(rawValue: row["state"]) else { return nil }
        return QueuedMessage(
            id: id,
            stream: row["stream"],
            subject: row["subject"],
            kind: kind,
            label: row["label"],
            attempts: row["attempts"],
            nextAttemptAt: row["nextAttemptAt"],
            state: state,
            lastError: row["lastError"],
            enqueuedAt: row["enqueuedAt"],
            updatedAt: row["updatedAt"])
    }
}
