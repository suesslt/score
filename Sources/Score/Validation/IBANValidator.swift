import Foundation

/// IBAN validation per ISO 13616 / ISO 7064 (Mod-97 check).
public enum IBANValidator {

    /// Checks whether an IBAN is syntactically valid (length + Mod-97 check digit).
    public static func isValid(_ iban: String) -> Bool {
        let clean = iban.replacingOccurrences(of: " ", with: "").uppercased()
        // ISO 13616: min length 5, max length 34
        guard clean.count >= 5, clean.count <= 34 else { return false }
        // Only letters and digits allowed
        guard clean.allSatisfy({ $0.isLetter || $0.isNumber }) else { return false }
        // First 2 characters must be letters (country code)
        guard clean.prefix(2).allSatisfy({ $0.isLetter }) else { return false }
        // Characters 3-4 must be digits (check digits)
        guard clean.dropFirst(2).prefix(2).allSatisfy({ $0.isNumber }) else { return false }
        // Mod-97 check (ISO 7064)
        let rearranged = String(clean.dropFirst(4)) + String(clean.prefix(4))
        let numeric = rearranged.map { char -> String in
            if let digit = char.wholeNumberValue {
                return String(digit)
            }
            // A=10, B=11, ..., Z=35
            return String(Int(char.asciiValue!) - 55)
        }.joined()
        return mod97(numeric) == 1
    }

    /// Validation message for UI. Returns `nil` if valid or empty.
    public static func validationMessage(_ iban: String) -> String? {
        let clean = iban.replacingOccurrences(of: " ", with: "")
        if clean.isEmpty { return nil }
        if !isValid(iban) { return "Invalid IBAN" }
        return nil
    }

    // MARK: - Private

    private static func mod97(_ numericString: String) -> Int {
        var remainder = 0
        for char in numericString {
            remainder = (remainder * 10 + Int(String(char))!) % 97
        }
        return remainder
    }
}
