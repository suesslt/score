import Foundation

/// Generic CSV parser with multi-encoding support and auto-separator detection.
public enum CSVImporter {

    public enum CSVImportError: LocalizedError, Sendable {
        case invalidEncoding
        case emptyFile
        case missingColumns([String])

        public var errorDescription: String? {
            switch self {
            case .invalidEncoding:
                return "The file could not be read. Supported encodings: UTF-8, ISO-8859-1."
            case .emptyFile:
                return "The CSV file contains no data."
            case .missingColumns(let columns):
                return "Missing required columns: \(columns.joined(separator: ", "))"
            }
        }
    }

    /// Parses a CSV file and returns an array of dictionaries (column name → value).
    /// Header names are lowercased for case-insensitive matching.
    public static func parse(from url: URL) throws -> [[String: String]] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Read file: UTF-8, then fallback ISO-8859-1
        let rawData = try Data(contentsOf: url)
        let content: String
        if let utf8 = String(data: rawData, encoding: .utf8) {
            content = utf8
        } else if let latin1 = String(data: rawData, encoding: .isoLatin1) {
            content = latin1
        } else {
            throw CSVImportError.invalidEncoding
        }

        // Split lines (CR+LF, LF, CR)
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else {
            throw CSVImportError.emptyFile
        }

        // Detect separator (semicolon vs comma)
        let headerLine = lines[0]
        let separator = detectSeparator(headerLine)

        // Parse header line (case-insensitive)
        let headers = parseLine(headerLine, separator: separator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        // Parse data lines
        var results: [[String: String]] = []
        for i in 1..<lines.count {
            let values = parseLine(lines[i], separator: separator)
            var row: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                if index < values.count {
                    row[header] = values[index].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            results.append(row)
        }

        return results
    }

    /// Validates that required columns are present.
    public static func validateColumns(_ rows: [[String: String]], required: [String]) throws {
        guard let firstRow = rows.first else {
            throw CSVImportError.emptyFile
        }
        let available = Set(firstRow.keys)
        let missing = required.filter { !available.contains($0) }
        if !missing.isEmpty {
            throw CSVImportError.missingColumns(missing)
        }
    }

    // MARK: - Parsing Helpers

    /// Parses a date from a string (dd.MM.yyyy or yyyy-MM-dd).
    public static func parseDate(_ string: String, locale: Locale = Locale(identifier: "en_US_POSIX")) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }

        let formatter1 = DateFormatter()
        formatter1.locale = Locale(identifier: "de_CH")
        formatter1.dateFormat = "dd.MM.yyyy"
        if let date = formatter1.date(from: trimmed) { return date }

        let formatter2 = DateFormatter()
        formatter2.locale = Locale(identifier: "en_US_POSIX")
        formatter2.dateFormat = "yyyy-MM-dd"
        if let date = formatter2.date(from: trimmed) { return date }

        return nil
    }

    /// Parses a decimal from a string (normalizes comma/dot and removes grouping separators).
    public static func parseDecimal(_ string: String) -> Decimal? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        let cleaned = trimmed
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
        let normalized = cleaned.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    // MARK: - Private

    /// Detects the separator based on the header line.
    private static func detectSeparator(_ headerLine: String) -> Character {
        let semicolonCount = headerLine.filter { $0 == ";" }.count
        let commaCount = headerLine.filter { $0 == "," }.count
        return semicolonCount >= commaCount ? ";" : ","
    }

    /// Parses a CSV line with support for quoted fields.
    private static func parseLine(_ line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == separator && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}
