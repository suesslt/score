import Foundation

/// Day count conventions for interest calculations.
public enum DayCountRule: String, Codable, CaseIterable, Identifiable, Sendable {
    case act360 = "ACT/360"
    case act365 = "ACT/365"
    case actAct = "ACT/ACT"
    case thirty360 = "30/360"
    case thirtyE360 = "30E/360"

    public var id: String { rawValue }

    public var displayName: String { rawValue }

    /// Calculates the year fraction between two dates using this day count rule.
    public func yearFraction(from start: Date, to end: Date) -> Decimal {
        let calendar = Calendar.current
        let startComps = calendar.dateComponents([.year, .month, .day], from: start)
        let endComps = calendar.dateComponents([.year, .month, .day], from: end)

        switch self {
        case .act360:
            let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            return Decimal(days) / Decimal(360)

        case .act365:
            let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            return Decimal(days) / Decimal(365)

        case .actAct:
            let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            let daysInYear = calendar.range(of: .day, in: .year, for: start)?.count ?? 365
            return Decimal(days) / Decimal(daysInYear == 366 ? 366 : 365)

        case .thirty360:
            var d1 = startComps.day ?? 1
            var d2 = endComps.day ?? 1
            let m1 = startComps.month ?? 1
            let m2 = endComps.month ?? 1
            let y1 = startComps.year ?? 2026
            let y2 = endComps.year ?? 2026
            if d1 == 31 { d1 = 30 }
            if d2 == 31 && d1 >= 30 { d2 = 30 }
            let days = (y2 - y1) * 360 + (m2 - m1) * 30 + (d2 - d1)
            return Decimal(days) / Decimal(360)

        case .thirtyE360:
            var d1 = startComps.day ?? 1
            var d2 = endComps.day ?? 1
            let m1 = startComps.month ?? 1
            let m2 = endComps.month ?? 1
            let y1 = startComps.year ?? 2026
            let y2 = endComps.year ?? 2026
            if d1 == 31 { d1 = 30 }
            if d2 == 31 { d2 = 30 }
            let days = (y2 - y1) * 360 + (m2 - m1) * 30 + (d2 - d1)
            return Decimal(days) / Decimal(360)
        }
    }
}
