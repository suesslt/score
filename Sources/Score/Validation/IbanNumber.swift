import Foundation

/// Wertobjekt fuer IBANs gemaess ISO 13616 mit Schweizer QR-IBAN-Erkennung.
///
/// Selbstvalidierend (Mod-97 / ISO 7064). QR-IBAN: CH/LI-IBAN mit '3' an
/// Position 5 (1-basiert) — d.h. erstes Zeichen der 5-stelligen Bank-
/// Clearing-Nummer liegt im QR-IID-Range 30000–31999 (SIX QR-Bill IG).
public struct IbanNumber: Hashable, Sendable, CustomStringConvertible {

    /// Normalisierte IBAN (whitespace-frei, uppercase).
    public let normalized: String

    /// Liefert `nil` nur fuer leere/whitespace-Inputs. Ungueltige IBANs
    /// werden trotzdem akzeptiert, damit Caller per `kind`/`isValid`
    /// unterscheiden koennen.
    public init?(_ raw: String) {
        let cleaned = raw
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .uppercased()
        guard !cleaned.isEmpty else { return nil }
        self.normalized = cleaned
    }

    public var description: String { normalized }

    // MARK: - Validation (ISO 13616 / ISO 7064 Mod-97)

    /// `true`, wenn die IBAN syntaktisch gueltig ist UND die Mod-97-Pruefziffer stimmt.
    public var isValid: Bool {
        guard normalized.count >= 5, normalized.count <= 34 else { return false }
        guard normalized.allSatisfy({ $0.isLetter || $0.isNumber }) else { return false }
        guard normalized.prefix(2).allSatisfy({ $0.isLetter }) else { return false }
        guard normalized.dropFirst(2).prefix(2).allSatisfy({ $0.isNumber }) else { return false }
        let rearranged = String(normalized.dropFirst(4)) + String(normalized.prefix(4))
        let numeric = rearranged.map { char -> String in
            if let digit = char.wholeNumberValue { return String(digit) }
            return String(Int(char.asciiValue!) - 55)
        }.joined()
        return Self.mod97(numeric) == 1
    }

    /// `true`, wenn QR-IBAN: CH/LI + '3' an Position 5 (Index 4).
    public var isQRIBAN: Bool {
        guard normalized.count >= 5 else { return false }
        let country = normalized.prefix(2)
        guard country == "CH" || country == "LI" else { return false }
        return normalized[normalized.index(normalized.startIndex, offsetBy: 4)] == "3"
    }

    /// Typsichere Klassifikation.
    public var kind: Kind {
        guard isValid else { return .invalid }
        return isQRIBAN ? .qrIban : .regular
    }

    public enum Kind: Sendable, Equatable { case qrIban, regular, invalid }

    // MARK: - Display formatting

    /// Gruppiert die IBAN in 4er-Bloecke fuer die Anzeige (z.B. "CH44 3199 9123 …").
    public var formatted: String {
        stride(from: 0, to: normalized.count, by: 4).map { i in
            let start = normalized.index(normalized.startIndex, offsetBy: i)
            let end = normalized.index(start, offsetBy: min(4, normalized.count - i))
            return String(normalized[start..<end])
        }.joined(separator: " ")
    }

    // MARK: - Static convenience

    public static func isValid(_ raw: String) -> Bool {
        IbanNumber(raw)?.isValid ?? false
    }

    public static func isQRIBAN(_ raw: String) -> Bool {
        guard let iban = IbanNumber(raw), iban.isValid else { return false }
        return iban.isQRIBAN
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
