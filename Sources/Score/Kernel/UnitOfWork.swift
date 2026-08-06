/// Groups multiple DAO writes into one transaction (ARCH §5.3).
///
/// A service wraps a multi-write operation in `perform { … }`; each storage technology provides
/// its own implementation. Single-write operations may call a DAO directly — each DAO call is
/// itself atomic. The closure is `@escaping` because transactional backends (e.g. Fluent's
/// `db.transaction { … }`) forward it into their own escaping closures.
public protocol UnitOfWork: Sendable {
    func perform<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T
}

/// Executes the closure directly, without a transaction — Configuration T and previews.
public struct NoopUnitOfWork: UnitOfWork {
    public init() {}

    public func perform<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await work()
    }
}
