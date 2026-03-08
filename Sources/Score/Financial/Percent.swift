import Foundation

/// Represents a percentage value.
///
/// Internally stored as a factor (e.g. 10% = 0.1, 100% = 1.0).
/// Created via `Percent.of("10%")` or `Percent.of(0.1)`.
public struct Percent: Hashable, Comparable, Codable, CustomStringConvertible, Sendable {
    public static let hundred = Percent(factorRate: Decimal(1))
    public static let zero = Percent(factorRate: Decimal(0))

    /// The internal factor representation (e.g. 0.1 for 10%).
    public let factorAmount: Decimal

    private init(factorRate: Decimal) {
        self.factorAmount = factorRate
    }

    // MARK: - Factory Methods

    /// Creates Percent from a Decimal factor (e.g. 0.1 for 10%).
    public static func of(_ factorRate: Decimal) -> Percent {
        Percent(factorRate: factorRate)
    }

    /// Creates Percent from a Double factor (e.g. 0.1 for 10%).
    public static func of(_ factorRate: Double) -> Percent {
        Percent(factorRate: Decimal(factorRate))
    }

    /// Parses a percentage string like "10%", "5%", "80%".
    /// "10%" is parsed as factor 0.1.
    public static func of(_ percentString: String) -> Percent {
        let trimmed = percentString.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("%") {
            let numberPart = trimmed.dropLast().trimmingCharacters(in: .whitespaces)
            guard let value = Decimal(string: numberPart) else {
                preconditionFailure("Cannot parse Percent from '\(percentString)'")
            }
            return Percent(factorRate: value / Decimal(100))
        }
        guard let value = Decimal(string: trimmed) else {
            preconditionFailure("Cannot parse Percent from '\(percentString)'")
        }
        return Percent(factorRate: value)
    }

    // MARK: - Null-safe Static Operations

    public static func add(_ p1: Percent?, _ p2: Percent?) -> Percent? {
        if let p1, let p2 { return p1.add(p2) }
        return p1 ?? p2
    }

    // MARK: - Arithmetic

    public func add(_ other: Percent) -> Percent {
        Percent(factorRate: factorAmount + other.factorAmount)
    }

    public func subtract(_ other: Percent) -> Percent {
        Percent(factorRate: factorAmount - other.factorAmount)
    }

    public func multiply(_ factor: Decimal) -> Percent {
        Percent(factorRate: factorAmount * factor)
    }

    public func multiply(_ factor: Double) -> Percent {
        Percent(factorRate: factorAmount * Decimal(factor))
    }

    public func multiply(_ other: Percent) -> Percent {
        Percent(factorRate: factorAmount * other.factorAmount)
    }

    public func divide(_ divisor: Double) -> Percent {
        Percent(factorRate: Decimal(factorAmount.doubleValue / divisor))
    }

    public func divide(_ other: Percent) -> Percent {
        Percent(factorRate: Decimal(factorAmount.doubleValue / other.factorAmount.doubleValue))
    }

    public func negate() -> Percent {
        Percent(factorRate: -factorAmount)
    }

    /// Applies this percent to an integer base value.
    public func applyTo(_ base: Int) -> Int {
        Int((factorAmount.doubleValue * Double(base)).rounded())
    }

    /// Returns the discounted value (base * (1 - rate)).
    public func discount(_ base: Int) -> Int {
        Int((Double(base) * (1.0 - factorAmount.doubleValue)).rounded())
    }

    /// The double value of the factor.
    public var doubleValue: Double {
        factorAmount.doubleValue
    }

    /// The percentage as a display value (e.g. 10.0 for 10%).
    public var displayValue: Decimal {
        factorAmount * Decimal(100)
    }

    // MARK: - Comparable

    public static func < (lhs: Percent, rhs: Percent) -> Bool {
        lhs.factorAmount < rhs.factorAmount
    }

    public static func == (lhs: Percent, rhs: Percent) -> Bool {
        lhs.factorAmount == rhs.factorAmount
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(factorAmount)
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        let percentage = factorAmount.doubleValue * 100.0
        if percentage == percentage.rounded() {
            return "\(Int(percentage))%"
        }
        return "\(percentage)%"
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = Percent.of(str)
        } else {
            let value = try container.decode(Decimal.self)
            self.factorAmount = value
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
