import Foundation

/// Currency-safe monetary amount with `Decimal` precision.
/// Arithmetic operators enforce currency matching via precondition.
public struct Money: Equatable, Hashable, Codable, Sendable, Comparable, Identifiable {
    public let amount: Decimal
    public let currency: Currency

    public var id: String { "\(currency.rawValue)-\(amount)" }

    public init(amount: Decimal, currency: Currency) {
        self.amount = amount
        self.currency = currency
    }

    /// Zero amount in the given currency.
    public static func zero(_ currency: Currency) -> Money {
        Money(amount: .zero, currency: currency)
    }

    // MARK: - Error Handling

    public enum MoneyError: Error, LocalizedError, Sendable {
        case currencyMismatch(Currency, Currency)

        public var errorDescription: String? {
            switch self {
            case .currencyMismatch(let a, let b):
                return "Currency mismatch: \(a.rawValue) and \(b.rawValue) cannot be combined."
            }
        }
    }

    // MARK: - Arithmetic (precondition — same currency guaranteed within a context)

    public static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Currencies must match: \(lhs.currency.rawValue) vs \(rhs.currency.rawValue)")
        return Money(amount: lhs.amount + rhs.amount, currency: lhs.currency)
    }

    public static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Currencies must match: \(lhs.currency.rawValue) vs \(rhs.currency.rawValue)")
        return Money(amount: lhs.amount - rhs.amount, currency: lhs.currency)
    }

    public static func += (lhs: inout Money, rhs: Money) {
        lhs = lhs + rhs
    }

    public static func -= (lhs: inout Money, rhs: Money) {
        lhs = lhs - rhs
    }

    /// Scale by a factor (e.g. percentage).
    public static func * (lhs: Money, rhs: Decimal) -> Money {
        Money(amount: lhs.amount * rhs, currency: lhs.currency)
    }

    /// Scale by a factor (e.g. percentage).
    public static func * (lhs: Decimal, rhs: Money) -> Money {
        Money(amount: lhs * rhs.amount, currency: rhs.currency)
    }

    /// Divide by a factor.
    public static func / (lhs: Money, rhs: Decimal) -> Money {
        precondition(rhs != .zero, "Division by zero")
        return Money(amount: lhs.amount / rhs, currency: lhs.currency)
    }

    /// Negation.
    public static prefix func - (value: Money) -> Money {
        Money(amount: -value.amount, currency: value.currency)
    }

    // MARK: - Throwing Variants (for multi-currency contexts)

    public func adding(_ other: Money) throws -> Money {
        guard currency == other.currency else {
            throw MoneyError.currencyMismatch(currency, other.currency)
        }
        return Money(amount: amount + other.amount, currency: currency)
    }

    public func subtracting(_ other: Money) throws -> Money {
        guard currency == other.currency else {
            throw MoneyError.currencyMismatch(currency, other.currency)
        }
        return Money(amount: amount - other.amount, currency: currency)
    }

    // MARK: - Null-safe Static Operations

    public static func add(_ m1: Money?, _ m2: Money?) -> Money? {
        if let m1, let m2 { return m1 + m2 }
        return m1 ?? m2
    }

    // MARK: - Formatting

    /// Formatted amount with currency code (e.g. "1,234.56 CHF").
    public func formatted(locale: Locale = Locale(identifier: "en_US")) -> String {
        "\(formattedAmount(locale: locale)) \(currency.rawValue)"
    }

    /// Compact formatted amount without currency code (e.g. "1,234.56").
    public func formattedAmount(locale: Locale = Locale(identifier: "en_US")) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minimumFractionDigits = currency.decimalPlaces
        formatter.maximumFractionDigits = currency.decimalPlaces
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }

    // MARK: - Swiss 5-Rappen Rounding

    /// Rounds to the nearest 5 centimes (0.05).
    public func roundedTo5Centimes() -> Money {
        guard amount != .zero else { return self }
        let step = Decimal(string: "0.05")!
        var divided = amount / step
        var result = Decimal()
        NSDecimalRound(&result, &divided, 0, .plain)
        return Money(amount: result * step, currency: currency)
    }

    // MARK: - Comparable

    public static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency, "Currencies must match")
        return lhs.amount < rhs.amount
    }

    // MARK: - Convenience

    public var isZero: Bool { amount == .zero }
    public var isPositive: Bool { amount > .zero }
    public var isNegative: Bool { amount < .zero }
    public var absoluteValue: Money { Money(amount: abs(amount), currency: currency) }

    private func abs(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}
