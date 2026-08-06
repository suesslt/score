import Foundation

// Shared querying & pagination building blocks (ARCH §12.1).

public enum SortDirection: String, Codable, Sendable {
    case asc, desc
}

/// A single sort clause over an entity's typed sort field.
public struct Sort<Field: RawRepresentable & Codable & Sendable>: Codable, Sendable
    where Field.RawValue == String {
    public let field: Field
    public let direction: SortDirection

    public init(field: Field, direction: SortDirection = .asc) {
        self.field = field
        self.direction = direction
    }
}

extension Sort: Equatable where Field: Equatable {}

/// Bounds on page size (guardrail — Rule QRY-1).
public enum PageLimits {
    public static let maxSize = 100
}

/// Offset/limit pagination request (1-based page). Size is clamped to `PageLimits`.
public struct Pagination: Codable, Sendable, Equatable {
    public let page: Int
    public let size: Int

    public init(page: Int = 1, size: Int = 20) {
        self.page = max(1, page)
        self.size = min(max(1, size), PageLimits.maxSize)
    }

    /// Zero-based offset for the requested page.
    public var offset: Int { (page - 1) * size }
}

/// A page of results: the requested slice plus the total count under the same filter.
///
/// Works for both business objects (DAO layer) and DTOs (service layer). It is `Codable` only when
/// the element is (i.e. `Page<XDTO>` serializes for a REST boundary; `Page<X>` need not).
public struct Page<Item: Sendable>: Sendable {
    public let items: [Item]
    public let totalCount: Int
    public let page: Int
    public let size: Int

    public init(items: [Item], totalCount: Int, page: Int, size: Int) {
        self.items = items
        self.totalCount = totalCount
        self.page = page
        self.size = size
    }

    public var pageCount: Int {
        guard size > 0 else { return 1 }
        return max(1, Int(ceil(Double(totalCount) / Double(size))))
    }

    /// Maps the items while preserving the pagination envelope (BO page → DTO page).
    public func map<T: Sendable>(_ transform: (Item) throws -> T) rethrows -> Page<T> {
        Page<T>(items: try items.map(transform), totalCount: totalCount, page: page, size: size)
    }

    /// Asynchronous variant of `map` for transforms that resolve values (e.g. name lookups).
    public func asyncMap<T: Sendable>(_ transform: (Item) async throws -> T) async rethrows -> Page<T> {
        var mapped: [T] = []
        mapped.reserveCapacity(items.count)
        for item in items { mapped.append(try await transform(item)) }
        return Page<T>(items: mapped, totalCount: totalCount, page: page, size: size)
    }

    /// An empty first page (e.g. as an initial view-model state).
    public static func empty(size: Int = 20) -> Page<Item> {
        Page(items: [], totalCount: 0, page: 1, size: size)
    }
}

extension Page: Codable where Item: Codable {}
extension Page: Equatable where Item: Equatable {}
