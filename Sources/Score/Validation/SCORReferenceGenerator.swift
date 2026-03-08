import Foundation

/// Generates and formats SCOR references per ISO 11649 (Creditor Reference).
/// Format: RF + 2 check digits + up to 21 alphanumeric characters.
public enum SCORReferenceGenerator {

    /// Formats a numeric reference as a complete SCOR reference.
    /// - Parameter reference: Numeric reference (e.g. "000000042")
    /// - Returns: SCOR reference (e.g. "RF47000000042") or nil for invalid input
    public static func format(_ reference: String) -> String? {
        let trimmed = reference.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.allSatisfy(\.isNumber) else { return nil }

        // ISO 11649: reference + "RF00" → replace letters with numbers → Mod 97
        let rearranged = trimmed + "RF00"
        let digits = rearranged.map { char -> String in
            if char.isNumber {
                return String(char)
            }
            guard let ascii = char.asciiValue else { return "" }
            return String(Int(ascii) - 55) // A=10, B=11, ..., Z=35
        }.joined()

        guard let remainder = modulo97(digits) else { return nil }
        let checkDigits = 98 - remainder
        return String(format: "RF%02d%@", checkDigits, trimmed)
    }

    /// Calculates Modulo 97 for an arbitrarily long digit string (chunk-wise, no overflow).
    private static func modulo97(_ digits: String) -> Int? {
        var remainder = 0
        for char in digits {
            guard let digit = char.wholeNumberValue else { return nil }
            remainder = (remainder * 10 + digit) % 97
        }
        return remainder
    }
}
