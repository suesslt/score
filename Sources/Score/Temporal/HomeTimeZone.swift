import Foundation

// Heimatzeitzone der Scoreware-Apps (extrahiert 2026-08-06 aus Auftritte).
//
// Fachliche Ereignisse (Auftritte, Termine, Abrechnungsperioden) werden als
// absolute Zeitpunkte gespeichert, aber immer in dieser Zeitzone angezeigt,
// eingegeben und formatiert — unabhängig davon, in welcher Zeitzone das Gerät
// gerade steht. Ohne diese Verankerung würde ein Termin um 17:30 auf Reisen
// (z.B. GMT+4) als 19:30 erscheinen und ein Mitternachts-Datum auf den
// Folgetag rutschen.

extension TimeZone {
    /// Heimatzeitzone der fachlichen Ereignisse: Europe/Zurich.
    public static let home = TimeZone(identifier: "Europe/Zurich")!
}

extension Calendar {
    /// Gregorianischer Kalender in der Heimatzeitzone — für alle Tages-,
    /// Monats- und Jahresberechnungen über fachliche Daten.
    public static let home: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .home
        return calendar
    }()
}

extension Date {
    /// Wie `formatted(date:time:)`, aber fix in der Heimatzeitzone statt der
    /// Gerätezeitzone.
    public func homeFormatted(date: Date.FormatStyle.DateStyle,
                              time: Date.FormatStyle.TimeStyle) -> String {
        formatted(Date.FormatStyle(date: date, time: time, timeZone: .home))
    }
}
