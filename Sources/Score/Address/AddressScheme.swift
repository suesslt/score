import Foundation

/// Purpose of an address attached to a party (correspondence, legal domicile,
/// invoicing). Shared by the Scoreware applications so address records mean
/// the same thing everywhere; the priority rule "invoice > correspondence >
/// domicile" for picking an invoice address lives with the consuming domain.
public enum AddressScheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case correspondence, domicile, invoice
    public var id: String { rawValue }
}
