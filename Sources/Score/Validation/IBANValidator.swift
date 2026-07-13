import Foundation

/// IBAN validation per ISO 13616 / ISO 7064 (Mod-97 check).
/// Thin facade around `IbanNumber` for callers that only need a yes/no answer.
public enum IBANValidator {

    public static func isValid(_ iban: String) -> Bool {
        IbanNumber.isValid(iban)
    }

    public static func validationMessage(_ iban: String) -> String? {
        let clean = iban.replacingOccurrences(of: " ", with: "")
        if clean.isEmpty { return nil }
        return isValid(iban) ? nil : "Invalid IBAN"
    }
}
