import Foundation

/// Represents a year and month combination.
/// Immutable value type for monthly time steps.
public struct YearMonth: Hashable, Comparable, Codable, CustomStringConvertible, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        precondition(month >= 1 && month <= 12, "Month must be between 1 and 12, got \(month)")
        self.year = year
        self.month = month
    }

    /// Factory method: `YearMonth.of(2026, 3)`.
    public static func of(_ year: Int, _ month: Int) -> YearMonth {
        YearMonth(year: year, month: month)
    }

    /// Parse from ISO format "yyyy-MM" (e.g. "2020-01").
    public static func parse(_ string: String) -> YearMonth {
        let parts = string.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else {
            preconditionFailure("Cannot parse YearMonth from '\(string)', expected format 'yyyy-MM'")
        }
        return YearMonth(year: year, month: month)
    }

    /// Returns a new YearMonth with the given number of months added.
    public func plusMonths(_ months: Int) -> YearMonth {
        let totalMonths = year * 12 + (month - 1) + months
        let newYear = totalMonths / 12
        let newMonth = totalMonths % 12 + 1
        return YearMonth(year: newYear, month: newMonth)
    }

    /// Returns true if this YearMonth is before the other.
    public func isBefore(_ other: YearMonth) -> Bool {
        self < other
    }

    /// Returns true if this YearMonth is after the other.
    public func isAfter(_ other: YearMonth) -> Bool {
        self > other
    }

    /// Returns the number of days in this month.
    public var lengthOfMonth: Int {
        let calendar = Calendar(identifier: .gregorian)
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = calendar.date(from: dateComponents) else { return 30 }
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    /// Returns a specific day of this month as a Date.
    public func atDay(_ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Returns the last day of this month as a Date.
    public func atEndOfMonth() -> Date {
        atDay(lengthOfMonth)
    }

    /// Returns all dates in this month.
    public func daysInMonth() -> [Date] {
        (1...lengthOfMonth).map { atDay($0) }
    }

    /// Number of months since year 0 (for diff calculations).
    var monthsSince0000: Int {
        year * 12 + (month - 1)
    }

    /// Returns the number of months between two YearMonths.
    public static func monthDiff(end: YearMonth, start: YearMonth) -> Int {
        end.monthsSince0000 - start.monthsSince0000
    }

    // MARK: - Comparable

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        return lhs.month < rhs.month
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        String(format: "%04d-%02d", year, month)
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self = YearMonth.parse(string)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
