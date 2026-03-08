import Foundation

extension Decimal {
    /// Formats an FX rate (4-6 decimal places, no grouping separator).
    public func formattedRate(locale: Locale = Locale(identifier: "en_US")) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 6
        formatter.groupingSeparator = ""
        return formatter.string(from: self as NSDecimalNumber) ?? ""
    }

    /// Formats a percentage with 1 decimal place (e.g. "23.5%").
    public func formattedPercent() -> String {
        String(format: "%.1f%%", NSDecimalNumber(decimal: self).doubleValue)
    }

    /// Formats with 2 decimal places and grouping (e.g. "1,234.56").
    public func formattedAmount(locale: Locale = Locale(identifier: "en_US")) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? ""
    }
}
