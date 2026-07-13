import Foundation

/// Swiss QR reference (QRR) per the SIX QR-bill implementation guidelines:
/// 27 digits, the last being a recursive Mod-10 check digit.
/// Counterpart to `SCORReferenceGenerator` (ISO 11649).
public enum QRRReferenceGenerator {

    private static let carry: [Int] = [0, 9, 4, 6, 8, 2, 7, 1, 3, 5]

    /// Recursive Mod-10 check digit over the given digit string.
    public static func checkDigit(_ digits: String) -> Int {
        var state = 0
        for char in digits {
            guard let digit = char.wholeNumberValue else { continue }
            state = carry[(state + digit) % 10]
        }
        return (10 - state) % 10
    }

    /// Random 27-digit QRR reference (26 digits + check digit).
    public static func generate() -> String {
        let digits = (0..<26).map { _ in String(Int.random(in: 0...9)) }.joined()
        return digits + String(checkDigit(digits))
    }

    /// Groups a 27-digit reference as "XX XXXXX XXXXX XXXXX XXXXX XXXXX" for display;
    /// other lengths are returned unchanged.
    public static func format(_ raw: String) -> String {
        guard raw.count == 27 else { return raw }
        let chars = Array(raw)
        var parts: [String] = [String(chars[0..<2])]
        for index in stride(from: 2, to: 27, by: 5) {
            parts.append(String(chars[index..<min(index + 5, 27)]))
        }
        return parts.joined(separator: " ")
    }

    /// `true` for a syntactically valid QRR reference (27 digits, correct check digit).
    public static func isValid(_ raw: String) -> Bool {
        guard raw.count == 27, raw.allSatisfy(\.isWholeNumber) else { return false }
        return raw.last?.wholeNumberValue == checkDigit(String(raw.prefix(26)))
    }
}
