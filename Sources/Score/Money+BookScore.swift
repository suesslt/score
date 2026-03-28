import Foundation
import Score

/// Konten-spezifische Money-Extensions (de_CH Locale).
extension Money {
    /// Formatiert den Betrag mit Währungscode im Schweizer Format (z.B. "1'234.56 CHF").
    public var formatted: String {
        formatted(locale: Locale(identifier: "de_CH"))
    }
}
