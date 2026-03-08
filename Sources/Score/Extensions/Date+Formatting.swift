import Foundation

extension Date {
    /// Short formatted date (e.g. "Feb 24, 2026" or "24.02.2026" depending on locale).
    public func shortFormatted(locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = locale
        return formatter.string(from: self)
    }

    /// ISO date string (e.g. "2026-02-24").
    public var isoFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }

    /// Date and time formatted (e.g. "Feb 24, 2026 at 3:45 PM").
    public func dateTimeFormatted(locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = locale
        return formatter.string(from: self)
    }

    /// Start of day (midnight).
    public var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Number of business days between two dates (excludes weekends).
    public func businessDays(to other: Date) -> Int {
        let calendar = Calendar.current
        var count = 0
        var current = self < other ? self : other
        let end = self < other ? other : self
        while current < end {
            let weekday = calendar.component(.weekday, from: current)
            if weekday != 1 && weekday != 7 { // not Sunday or Saturday
                count += 1
            }
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return self < other ? count : -count
    }
}
