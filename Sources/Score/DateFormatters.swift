import Foundation

/// Zentral gecachte DateFormatter-Instanzen.
/// `static let` ist in Swift thread-safe (dispatch_once).
public enum DateFormatters {

    // MARK: - Feste Formate (locale-unabhängig)

    /// "yyyy-MM-dd" — ISO-Datum für Dateinamen, APIs, XML
    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// "yyyyMMdd" — Kompakt für Dateinamen, Rechnungsnummern
    static let isoCompact: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// "yyyy-MM" — Jahr-Monat für Dateinamen
    static let isoYearMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Schweizer Formate (de_CH)

    /// "dd.MM.yyyy" — Schweizer Standarddatum
    static let swissDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "de_CH")
        return f
    }()

    /// "dd.MM.yyyy HH:mm" — Schweizer Datum mit Uhrzeit
    static let swissDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm"
        f.locale = Locale(identifier: "de_CH")
        return f
    }()

    /// "dd.MM" — Kurzformat (Tag.Monat)
    static let swissShortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM"
        f.locale = Locale(identifier: "de_CH")
        return f
    }()

    /// "MMMM yyyy" — Monatsname mit Jahr (z.B. "März 2026")
    static let swissMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "de_CH")
        return f
    }()

    /// "MM.yyyy" — Monat.Jahr numerisch
    static let swissNumericMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM.yyyy"
        f.locale = Locale(identifier: "de_CH")
        return f
    }()

    /// "dd. MMM. yyyy" — Kurzer Monatsname (z.B. "28. Mär. 2026")
    static let swissDateMedium: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd. MMM. yyyy"
        f.locale = Locale(identifier: "de_CH")
        return f
    }()
}
