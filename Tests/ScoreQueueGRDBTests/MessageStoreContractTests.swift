import Foundation
import GRDB
import ScoreQueue
import Testing

@testable import ScoreQueueGRDB

/// One contract, both implementations — the SQLite store and the in-memory one
/// answer the same questions the same way. Written once and parametrised, so a
/// rule cannot hold in one adapter and quietly not in the other.
@Suite("MessageStore contract")
struct MessageStoreContractTests {

    private static let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    enum Adapter: String, CaseIterable, Sendable {
        case sqlite, inMemory
    }

    /// A store plus, for SQLite, the queue that keeps it alive.
    private struct Fixture {
        let store: any MessageStore
        let queue: DatabaseQueue?
    }

    private func makeStore(_ adapter: Adapter) throws -> Fixture {
        switch adapter {
        case .inMemory:
            return Fixture(store: InMemoryMessageStore(), queue: nil)
        case .sqlite:
            let queue = try DatabaseQueue()
            var migrator = DatabaseMigrator()
            QueueMigration.register(in: &migrator)
            try migrator.migrate(queue)
            return Fixture(store: GRDBMessageStore(writer: queue), queue: queue)
        }
    }

    private func message(_ kind: QueuedMessage.Kind = .update,
                         stream: String = "contact",
                         subject: String = "s-1",
                         label: String? = nil,
                         at offset: TimeInterval = 0) -> QueuedMessage {
        QueuedMessage(stream: stream, subject: subject, kind: kind, label: label,
                      at: Self.epoch.addingTimeInterval(offset))
    }

    // MARK: - Enqueue and coalescence

    @Test("Only one open message per subject", arguments: Adapter.allCases)
    func oneOpenMessagePerSubject(_ adapter: Adapter) async throws {
        let store = try makeStore(adapter).store
        try await store.enqueue(message(.create, subject: "s-1", label: "A"))
        try await store.enqueue(message(.update, subject: "s-1", label: "B", at: 10))
        try await store.enqueue(message(.update, subject: "s-2", at: 20))

        let due = try await store.due(at: Self.epoch.addingTimeInterval(60), limit: 10)

        #expect(due.count == 2)
        let merged = try #require(due.first { $0.subject == "s-1" })
        #expect(merged.kind == .create)     // the creation carries the change along
        #expect(merged.label == "B")
    }

    @Test("The same subject in another stream is another message",
          arguments: Adapter.allCases)
    func streamsAreSeparate(_ adapter: Adapter) async throws {
        let store = try makeStore(adapter).store
        try await store.enqueue(message(.update, stream: "contact", subject: "x"))
        try await store.enqueue(message(.update, stream: "group", subject: "x"))

        #expect(try await store.due(at: Self.epoch, limit: 10).count == 2)
    }

    @Test("Created and deleted again leaves nothing", arguments: Adapter.allCases)
    func createThenDeleteLeavesNothing(_ adapter: Adapter) async throws {
        let store = try makeStore(adapter).store
        try await store.enqueue(message(.create))
        try await store.enqueue(message(.delete, at: 10))

        #expect(try await store.due(at: Self.epoch.addingTimeInterval(60), limit: 10).isEmpty)
        #expect(try await store.pendingCount() == 0)
    }

    // MARK: - Due, failed, counting

    @Test("Only what is due, oldest first", arguments: Adapter.allCases)
    func dueIsOrderedAndBounded(_ adapter: Adapter) async throws {
        let store = try makeStore(adapter).store
        for index in 0..<3 {
            try await store.enqueue(message(subject: "s-\(index)",
                                            at: TimeInterval(index)))
        }
        var later = message(subject: "s-later")
        later.nextAttemptAt = Self.epoch.addingTimeInterval(300)
        try await store.enqueue(later)

        let due = try await store.due(at: Self.epoch.addingTimeInterval(10), limit: 10)

        #expect(due.map(\.subject) == ["s-0", "s-1", "s-2"])
        #expect(try await store.due(at: Self.epoch.addingTimeInterval(10), limit: 2).count == 2)
    }

    @Test("A resting message is never due, but it is listed",
          arguments: Adapter.allCases)
    func failedIsNeverDue(_ adapter: Adapter) async throws {
        let store = try makeStore(adapter).store
        var failing = message(subject: "s-1", label: "Anna Muster")
        try await store.enqueue(failing)
        failing.state = .failed
        failing.attempts = 4
        failing.lastError = "CNErrorDomain 1"
        try await store.update(failing)

        #expect(try await store.due(at: Self.epoch.addingTimeInterval(600), limit: 10).isEmpty)
        #expect(try await store.pendingCount() == 0)
        let listed = try #require(try await store.failed().first)
        #expect(listed.label == "Anna Muster")       // the list can name the subject
        #expect(listed.lastError == "CNErrorDomain 1")
        #expect(listed.attempts == 4)
    }

    @Test("Clearing the failure makes it due again with a clean slate",
          arguments: Adapter.allCases)
    func clearFailureResets(_ adapter: Adapter) async throws {
        let store = try makeStore(adapter).store
        var failing = message()
        try await store.enqueue(failing)
        failing.state = .failed
        failing.attempts = 4
        failing.lastError = "boom"
        failing.nextAttemptAt = Self.epoch.addingTimeInterval(9_999)
        try await store.update(failing)

        let now = Self.epoch.addingTimeInterval(600)
        try await store.clearFailure(id: failing.id, at: now)

        let revived = try #require(try await store.due(at: now, limit: 10).first)
        #expect(revived.state == .pending)
        #expect(revived.attempts == 0)
        #expect(revived.lastError == nil)
        #expect(try await store.failed().isEmpty)
    }

    // MARK: - Round trip and identity

    @Test("Everything survives the round trip, to the second",
          arguments: Adapter.allCases)
    func roundTripKeepsEveryField(_ adapter: Adapter) async throws {
        let store = try makeStore(adapter).store
        let original = QueuedMessage(
            id: UUID(), stream: "group", subject: "g-1", kind: .delete,
            label: "Vorstand", attempts: 2,
            nextAttemptAt: Self.epoch.addingTimeInterval(30),
            state: .pending, lastError: "earlier",
            enqueuedAt: Self.epoch, updatedAt: Self.epoch.addingTimeInterval(5))
        try await store.enqueue(original)

        let read = try #require(try await store.due(at: Self.epoch.addingTimeInterval(60),
                                                    limit: 10).first)
        #expect(read.id == original.id)
        #expect(read.stream == original.stream)
        #expect(read.subject == original.subject)
        #expect(read.kind == .delete)
        #expect(read.label == "Vorstand")
        #expect(read.attempts == 2)
        #expect(read.lastError == "earlier")
        #expect(abs(read.nextAttemptAt.timeIntervalSince(original.nextAttemptAt)) < 0.001)
        #expect(abs(read.enqueuedAt.timeIntervalSince(original.enqueuedAt)) < 0.001)
        #expect(abs(read.updatedAt.timeIntervalSince(original.updatedAt)) < 0.001)
    }

    @Test("Merging keeps the row: same id, same waiting-since",
          arguments: Adapter.allCases)
    func mergeKeepsRowIdentity(_ adapter: Adapter) async throws {
        let store = try makeStore(adapter).store
        let first = message(.update, at: 0)
        try await store.enqueue(first)
        try await store.enqueue(message(.update, at: 60))

        let merged = try #require(try await store.due(at: Self.epoch.addingTimeInterval(120),
                                                      limit: 10).first)
        #expect(merged.id == first.id)
        #expect(abs(merged.enqueuedAt.timeIntervalSince(Self.epoch)) < 0.001)
    }

    @Test("update and clearFailure name an unknown message instead of doing nothing",
          arguments: Adapter.allCases)
    func unknownIdIsNamed(_ adapter: Adapter) async throws {
        let store = try makeStore(adapter).store
        let stranger = message()

        await #expect(throws: QueueError.notFound(id: stranger.id)) {
            try await store.update(stranger)
        }
        await #expect(throws: QueueError.notFound(id: stranger.id)) {
            try await store.clearFailure(id: stranger.id, at: Self.epoch)
        }
        // Removing something that is gone is success — the crash window of the
        // engine (remote write done, message not yet removed) must not become
        // an error on the next pass.
        try await store.remove(id: stranger.id)
    }
}

/// The property the whole construction rests on: a change and the message about
/// it are committed together, or not at all.
@Suite("Transactional enqueue")
struct TransactionalEnqueueTests {

    private static let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    /// A host bracket that runs everything inside one transaction — the shape
    /// Moneypenny's `SQLiteWriter` has.
    private struct TransactionAccess: DatabaseAccess {
        let db: any DatabaseWriter

        func read<T: Sendable>(
            _ body: @escaping @Sendable (Database) throws -> T
        ) async throws -> T {
            try await db.read(body)
        }

        func write<T: Sendable>(
            _ body: @escaping @Sendable (Database) throws -> T
        ) async throws -> T {
            try await db.writeWithoutTransaction { db in
                var result: T!
                try db.inSavepoint {
                    result = try body(db)
                    return .commit
                }
                return result
            }
        }
    }

    private struct Rollback: Error {}

    @Test("A rolled-back change leaves no message behind")
    func rollbackLeavesNoMessage() async throws {
        let queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("subject") { db in
            try db.create(table: "subject") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
            }
        }
        QueueMigration.register(in: &migrator)
        try migrator.migrate(queue)
        let store = GRDBMessageStore(access: TransactionAccess(db: queue))

        // The row and its message in ONE transaction — which then fails.
        try? await queue.writeWithoutTransaction { db in
            try db.inTransaction {
                try db.execute(sql: "INSERT INTO subject (id, name) VALUES ('s-1', 'Anna')")
                try db.execute(sql: """
                    INSERT INTO \(QueueMigration.tableName)
                        (id, stream, subject, kind, attempts, nextAttemptAt, state,
                         enqueuedAt, updatedAt)
                    VALUES (?, 'contact', 's-1', 'update', 0, ?, 'pending', ?, ?)
                    """, arguments: [UUID().uuidString, Self.epoch, Self.epoch, Self.epoch])
                throw Rollback()
            }
        }

        #expect(try await store.pendingCount() == 0)
        let rows = try await queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM subject") ?? 0
        }
        #expect(rows == 0)
    }

    @Test("A committed change carries its message with it")
    func commitCarriesTheMessage() async throws {
        let queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        QueueMigration.register(in: &migrator)
        try migrator.migrate(queue)
        let store = GRDBMessageStore(access: TransactionAccess(db: queue))

        try await store.enqueue(QueuedMessage(stream: "contact", subject: "s-1",
                                              kind: .create, at: Self.epoch))

        #expect(try await store.pendingCount() == 1)
    }
}
