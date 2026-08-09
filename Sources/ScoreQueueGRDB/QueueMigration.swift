import Foundation
import GRDB

/// The table behind ``GRDBMessageStore``.
///
/// Registered by the host into its own migrator, so the queue takes part in the
/// project's migration order instead of running a second, competing one. The
/// migration name is a parameter because it is recorded in
/// `grdb_migrations` — a host that already shipped one keeps its name.
public enum QueueMigration {

    public static let tableName = "scoreQueueMessage"

    public static func register(in migrator: inout DatabaseMigrator,
                                name: String = "scoreQueueMessage") {
        migrator.registerMigration(name) { db in
            try db.create(table: tableName) { t in
                t.primaryKey("id", .text)
                t.column("stream", .text).notNull()
                t.column("subject", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("label", .text)
                t.column("attempts", .integer).notNull().defaults(to: 0)
                t.column("nextAttemptAt", .datetime).notNull()
                t.column("state", .text).notNull().defaults(to: "pending")
                t.column("lastError", .text)
                t.column("enqueuedAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            // At most one open message per subject — this index *is* the
            // coalescence rule, enforced by the database rather than by care.
            try db.create(index: "scoreQueueMessage_subject", on: tableName,
                          columns: ["stream", "subject"], unique: true)
            // The drain reads exactly along this: what is due, oldest first.
            try db.create(index: "scoreQueueMessage_due", on: tableName,
                          columns: ["state", "nextAttemptAt"])
        }
    }
}
