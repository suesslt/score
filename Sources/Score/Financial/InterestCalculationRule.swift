import Foundation

/// Interest calculation rules for collateral interest.
public enum InterestCalculationRule: String, Codable, CaseIterable, Identifiable, Sendable {
    case simple = "Simple"
    case compound = "Compound"
    case dailyCompound = "Daily Compound"

    public var id: String { rawValue }
}
