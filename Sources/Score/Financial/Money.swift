import Foundation

/// Currency-safe monetary amount with `Decimal` precision.
///
/// **Semantics (v3):** arithmetic (`+ - * /`) is EXACT, so intermediate results
/// (quantity × unit price, FX conversion, interest) lose nothing. Equality, ordering,
/// hashing and the sign predicates work at the currency's precision
/// (`currency.decimalPlaces`, rounded half-up): `4000.000…0004 CHF == 4000.00 CHF`.
/// The exact amount stays available via `amount`; `rounded()` materializes the
/// currency-precision value. Arithmetic operators enforce currency matching via
/// precondition.
public struct Money: Hashable, Codable, Sendable, Comparable, Identifiable {
    public let amount: Decimal
    public let currency: Currency

    public var id: String { "\(currency.rawValue)-\(roundedAmount)" }

    public init(amount: Decimal, currency: Currency) {
        self.amount = amount
        self.currency = currency
    }

    /// Zero amount in the given currency.
    public static func zero(_ currency: Currency) -> Money {
        Money(amount: .zero, currency: currency)
    }

    // MARK: - Factory Methods

    public static func of(_ currency: Currency, _ amount: Decimal) -> Money {
        Money(amount: amount, currency: currency)
    }

    public static func of(_ currency: Currency, _ amount: Int) -> Money {
        Money(amount: Decimal(amount), currency: currency)
    }

    public static func of(_ currency: Currency, _ amount: Double) -> Money {
        Money(amount: Decimal(amount), currency: currency)
    }

    /// Factory with an ISO-4217 code string; `nil` for unknown codes.
    public static func of(code: String, _ amount: Decimal) -> Money? {
        Currency(rawValue: code.uppercased()).map { Money(amount: amount, currency: $0) }
    }

    // MARK: - Parsing

    /// Parses `"CHF 1234.56"` or `"1234.56 CHF"` (code prefix or suffix, `.` decimal separator).
    public static func parse(_ string: String) -> Money? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 3 else { return nil }

        if let currency = Currency(rawValue: String(trimmed.prefix(3)).uppercased()),
           let amount = Decimal(string: trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)) {
            return Money(amount: amount, currency: currency)
        }
        if let currency = Currency(rawValue: String(trimmed.suffix(3)).uppercased()),
           let amount = Decimal(string: trimmed.dropLast(3).trimmingCharacters(in: .whitespaces)) {
            return Money(amount: amount, currency: currency)
        }
        return nil
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

    /// Betrag mit Währungscode im Schweizer Format (z.B. "1'234.56 CHF").
    public var formatted: String {
        formatted(locale: Locale(identifier: "de_CH"))
    }

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

    // MARK: - Rounding

    /// Amount rounded to the currency's decimal places (half-up by default —
    /// commercial rounding as used in Swiss bookkeeping and VAT).
    public func rounded(_ mode: NSDecimalNumber.RoundingMode = .plain) -> Money {
        Money(amount: Self.round(amount, scale: currency.decimalPlaces, mode: mode), currency: currency)
    }

    /// Amount rounded half-up to the currency's decimal places.
    public var roundedAmount: Decimal {
        Self.round(amount, scale: currency.decimalPlaces, mode: .plain)
    }

    static func round(_ value: Decimal, scale: Int, mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, mode)
        return result
    }

    // MARK: - VAT

    /// Splits this amount into net and VAT. The VAT is rounded half-up to the
    /// currency's precision; net/gross are derived so that `net + vat == gross` holds
    /// EXACTLY (no residue from non-terminating divisions such as `x × 8.1 / 108.1`).
    /// - Parameters:
    ///   - ratePercent: VAT rate in percent (e.g. `8.1`).
    ///   - inclusive: `true` if this amount already contains the VAT (gross),
    ///     `false` if it is the net amount.
    public func vatSplit(ratePercent: Decimal, inclusive: Bool) -> VATSplit {
        guard ratePercent != .zero else {
            return VATSplit(net: self, vat: .zero(currency), gross: self)
        }
        if inclusive {
            let vat = Money(amount: amount * ratePercent / (100 + ratePercent), currency: currency).rounded()
            return VATSplit(net: self - vat, vat: vat, gross: self)
        }
        let vat = Money(amount: amount * ratePercent / 100, currency: currency).rounded()
        return VATSplit(net: self, vat: vat, gross: self + vat)
    }

    /// Result of `Money.vatSplit(ratePercent:inclusive:)`.
    public struct VATSplit: Hashable, Sendable {
        public let net: Money
        public let vat: Money
        public let gross: Money
    }

    // MARK: - Equality, Ordering, Hashing (currency precision)

    public static func == (lhs: Money, rhs: Money) -> Bool {
        lhs.currency == rhs.currency && lhs.roundedAmount == rhs.roundedAmount
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(currency)
        hasher.combine(roundedAmount)
    }

    public static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency, "Currencies must match")
        return lhs.roundedAmount < rhs.roundedAmount
    }

    // MARK: - Convenience

    public var isZero: Bool { roundedAmount == .zero }
    public var isPositive: Bool { roundedAmount > .zero }
    public var isNegative: Bool { roundedAmount < .zero }
    public var absoluteValue: Money { Money(amount: abs(amount), currency: currency) }

    /// Sum of `values` in `currency` (zero for an empty sequence). Every element must
    /// be in `currency`.
    public static func sum<S: Sequence>(_ values: S, currency: Currency) -> Money where S.Element == Money {
        values.reduce(.zero(currency), +)
    }

    private func abs(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}

extension Money: CustomStringConvertible {
    /// Locale-unabhängige Darstellung "CHF 1234.56" (Code, Punkt-Dezimaltrennung, keine Gruppierung).
    public var description: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = currency.decimalPlaces
        formatter.maximumFractionDigits = currency.decimalPlaces
        formatter.groupingSeparator = ""
        formatter.decimalSeparator = "."
        let text = formatter.string(from: roundedAmount as NSDecimalNumber) ?? "\(roundedAmount)"
        return "\(currency.rawValue) \(text)"
    }
}
