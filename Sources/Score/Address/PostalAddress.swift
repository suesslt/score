import Foundation

/// Unified postal-address value type shared by all Scoreware applications
/// (bookscore: person/employee/tenant/bank addresses; Moneypenny: address-book
/// mirror).
///
/// A pure value type: no persistence, no transport, no project error type.
/// Validation is split in two so the type stays error-type-free — projects
/// throw their own `DomainError` from the reported issues:
/// - `normalized()` returns a trimmed, canonicalized copy.
/// - `validationIssues` reports what is wrong as typed issues, never throws
///   and never carries user-facing text (localization is a presentation
///   concern of the consuming project).
public struct PostalAddress: Codable, Sendable, Equatable, Hashable {
    /// "z.Hd." / attention line, printed above the address lines.
    public var attention: String
    public var street: String
    public var houseNumber: String
    /// Free-form additional line printed before the street line.
    public var addressLine1: String
    public var addressLine2: String
    /// PO box ("Postfach"); an address is populated with either a street or a PO box.
    public var poBox: String
    public var postalCode: String
    public var city: String
    /// ISO 3166-1 alpha-2 country code.
    public var countryCode: String

    public init(attention: String = "", street: String = "", houseNumber: String = "",
                addressLine1: String = "", addressLine2: String = "", poBox: String = "",
                postalCode: String = "", city: String = "", countryCode: String = "CH") {
        self.attention = attention; self.street = street; self.houseNumber = houseNumber
        self.addressLine1 = addressLine1; self.addressLine2 = addressLine2; self.poBox = poBox
        self.postalCode = postalCode; self.city = city; self.countryCode = countryCode
    }

    /// Populated = at least a street or a PO box.
    public var isPopulated: Bool { !street.isEmpty || !poBox.isEmpty }

    /// One-line summary ("Musterstrasse 1 8000 Zürich").
    public var summary: String {
        [street, houseNumber, postalCode, city].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Multi-line formatted address (attention, extra lines, street, PO box, place).
    public var formatted: String {
        var lines: [String] = []
        if !attention.isEmpty { lines.append(attention) }
        if !addressLine1.isEmpty { lines.append(addressLine1) }
        if !addressLine2.isEmpty { lines.append(addressLine2) }
        let streetLine = [street, houseNumber].filter { !$0.isEmpty }.joined(separator: " ")
        if !streetLine.isEmpty { lines.append(streetLine) }
        if !poBox.isEmpty { lines.append(poBox) }
        let cityLine = [postalCode, city].filter { !$0.isEmpty }.joined(separator: " ")
        if !cityLine.isEmpty { lines.append(cityLine) }
        return lines.joined(separator: "\n")
    }

    /// Multi-line formatted address with the recipient name on top.
    public func formatted(withName name: String) -> String {
        let address = formatted
        return address.isEmpty ? name : "\(name)\n\(address)"
    }

    // MARK: - Normalization & validation

    /// Returns a copy with every field trimmed and the country code uppercased.
    public func normalized() -> PostalAddress {
        func trim(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
        var copy = self
        copy.attention = trim(attention)
        copy.street = trim(street)
        copy.houseNumber = trim(houseNumber)
        copy.addressLine1 = trim(addressLine1)
        copy.addressLine2 = trim(addressLine2)
        copy.poBox = trim(poBox)
        copy.postalCode = trim(postalCode)
        copy.city = trim(city)
        copy.countryCode = trim(countryCode).uppercased()
        return copy
    }

    /// Typed validation findings, evaluated over the `normalized()` form.
    ///
    /// An empty (unpopulated) address is valid. Once populated it needs a
    /// place (postal code + city); the country code, when given, is a
    /// two-letter ISO 3166-1 alpha-2 code. Empty when the address is valid.
    public var validationIssues: [PostalAddressIssue] {
        let n = normalized()
        var issues: [PostalAddressIssue] = []
        if n.isPopulated {
            if n.postalCode.isEmpty { issues.append(.missingPostalCode) }
            if n.city.isEmpty { issues.append(.missingCity) }
        }
        if !n.countryCode.isEmpty,
           n.countryCode.count != 2 || !n.countryCode.allSatisfy({ $0.isLetter }) {
            issues.append(.invalidCountryCode)
        }
        return issues
    }
}

/// A single validation finding on a `PostalAddress` — the WHAT, without text.
/// The consuming project maps it to its own error type and localized message.
public enum PostalAddressIssue: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    /// The address is populated but has no postal code.
    case missingPostalCode
    /// The address is populated but has no city.
    case missingCity
    /// The country code is set but is not a two-letter ISO 3166-1 alpha-2 code.
    case invalidCountryCode

    /// The offending field name, matching the `PostalAddress` property —
    /// ready-made for `validation(field:message:)`-style project errors.
    public var field: String {
        switch self {
        case .missingPostalCode: return "postalCode"
        case .missingCity: return "city"
        case .invalidCountryCode: return "countryCode"
        }
    }
}
