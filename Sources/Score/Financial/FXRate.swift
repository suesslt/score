import Foundation

/// FX rate between two currencies with bid/ask prices.
///
/// Convention:
/// - `baseCurrency` is the currency being quoted (e.g. EUR)
/// - `quoteCurrency` is the pricing currency (e.g. USD)
/// - Rate = how many units of quoteCurrency per 1 unit of baseCurrency
/// - `bid` = price at which the market buys baseCurrency (lower)
/// - `ask` = price at which the market sells baseCurrency (higher)
///
/// Example: EUR/USD bid 1.0800 / ask 1.0850
/// means 1 EUR costs 1.085 USD to buy, and can be sold for 1.08 USD.
public struct FXRate: Equatable, Hashable, Codable, Sendable {

    /// Base currency (the currency being quoted).
    public let baseCurrency: Currency

    /// Quote currency (the pricing currency).
    public let quoteCurrency: Currency

    /// Bid price (buy side — lower).
    public let bid: Decimal

    /// Ask price (sell side — higher).
    public let ask: Decimal

    // MARK: - Initializers

    public init(baseCurrency: Currency, quoteCurrency: Currency, bid: Decimal, ask: Decimal) {
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.bid = bid
        self.ask = ask
    }

    /// Creates an FXRate with a single mid rate (bid = ask = rate).
    public init(baseCurrency: Currency, quoteCurrency: Currency, rate: Decimal) {
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.bid = rate
        self.ask = rate
    }

    /// Identity rate (1:1) when both currencies are the same.
    public static func identity(_ currency: Currency) -> FXRate {
        FXRate(baseCurrency: currency, quoteCurrency: currency, rate: Decimal(1))
    }

    // MARK: - Conversion

    /// Convert an amount from base currency to quote currency at the mid rate.
    public func convert(_ money: Money) -> Money {
        precondition(money.currency == baseCurrency,
                     "Expected \(baseCurrency.rawValue), got \(money.currency.rawValue)")
        return Money(amount: money.amount * mid, currency: quoteCurrency)
    }

    /// Convert an amount from base currency to quote currency at the ask rate (buying base).
    public func convertAtAsk(_ money: Money) -> Money {
        precondition(money.currency == baseCurrency,
                     "Expected \(baseCurrency.rawValue), got \(money.currency.rawValue)")
        return Money(amount: money.amount * ask, currency: quoteCurrency)
    }

    /// Convert an amount from base currency to quote currency at the bid rate (selling base).
    public func convertAtBid(_ money: Money) -> Money {
        precondition(money.currency == baseCurrency,
                     "Expected \(baseCurrency.rawValue), got \(money.currency.rawValue)")
        return Money(amount: money.amount * bid, currency: quoteCurrency)
    }

    /// Convert an amount from quote currency back to base currency at the mid rate.
    public func convertInverse(_ money: Money) -> Money {
        precondition(money.currency == quoteCurrency,
                     "Expected \(quoteCurrency.rawValue), got \(money.currency.rawValue)")
        precondition(mid != .zero, "Cannot invert a zero rate")
        return Money(amount: money.amount / mid, currency: baseCurrency)
    }

    /// Returns the inverse rate (swap base and quote).
    public var inverted: FXRate {
        precondition(bid != .zero && ask != .zero, "Cannot invert a zero rate")
        return FXRate(
            baseCurrency: quoteCurrency,
            quoteCurrency: baseCurrency,
            bid: Decimal(1) / ask,    // inverse of ask becomes new bid
            ask: Decimal(1) / bid     // inverse of bid becomes new ask
        )
    }

    // MARK: - Computed Values

    /// Mid rate (average of bid and ask).
    public var mid: Decimal {
        (bid + ask) / 2
    }

    /// Spread between ask and bid.
    public var spread: Decimal {
        ask - bid
    }

    // MARK: - Formatting

    /// Formatted rate string (e.g. "EUR/USD 1.0800 / 1.0850").
    public var formatted: String {
        let bidStr = formatRate(bid)
        let askStr = formatRate(ask)
        return "\(baseCurrency.rawValue)/\(quoteCurrency.rawValue) \(bidStr) / \(askStr)"
    }

    public var bidFormatted: String { formatRate(bid) }
    public var askFormatted: String { formatRate(ask) }
    public var midFormatted: String { formatRate(mid) }

    private func formatRate(_ rate: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 6
        formatter.groupingSeparator = ""
        return formatter.string(from: rate as NSDecimalNumber) ?? "\(rate)"
    }
}
