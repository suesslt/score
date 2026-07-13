import Foundation

public extension String {
    /// Escapes the five XML special characters (`& < > " '`) for use in element
    /// content and attribute values (e.g. ISO-20022 pain.001, eCH-0217, Swissdec ELM).
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
