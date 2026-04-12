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

        return try parse(from: content)
    }

    /// Parses a CSV string and returns an array of dictionaries (column name → value).
    /// Header names are lowercased for case-insensitive matching.
    /// Supports RFC 4180 multiline quoted fields.
    public static func parse(from text: String, separator: Character? = nil) throws -> [[String: String]] {
        let records = parseRecords(from: text, separator: separator)

        guard records.count >= 2 else {
            throw CSVImportError.emptyFile
        }

        let headers = records[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        var results: [[String: String]] = []
        for i in 1..<records.count {
            let values = records[i]
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

    /// Parses a CSV string with row-level error tracking.
    ///
    /// Unlike `parse(from:)`, this method continues parsing after row-level errors
    /// and returns both successfully parsed rows and errors per line.
    ///
    /// - Parameters:
    ///   - text: The CSV string to parse.
    ///   - separator: The field separator. Auto-detected from header if `nil`.
    ///   - required: Required column names (lowercased). Validation is performed before row parsing.
    ///   - transform: Transforms a row dictionary into the target type. Throw to record a row error.
    /// - Returns: A `CSVImportResult` with valid items and per-row errors.
    public static func parseWithErrors<T>(
        from text: String,
        separator: Character? = nil,
        required: [String] = [],
        transform: ([String: String]) throws -> T
    ) throws -> CSVImportResult<T> {
        let records = parseRecords(from: text, separator: separator)

        guard records.count >= 2 else {
            throw CSVImportError.emptyFile
        }

        let headers = records[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        // Validate required columns
        if !required.isEmpty {
            let available = Set(headers)
            let missing = required.filter { !available.contains($0) }
            if !missing.isEmpty {
                throw CSVImportError.missingColumns(missing)
            }
        }

        var valid: [T] = []
        var errors: [CSVImportRowError] = []

        for i in 1..<records.count {
            let values = records[i]
            var row: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                if index < values.count {
                    row[header] = values[index].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            do {
                let item = try transform(row)
                valid.append(item)
            } catch {
                errors.append(CSVImportRowError(lineNumber: i + 1, error: error))
            }
        }

        return CSVImportResult(valid: valid, errors: errors)
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

    /// Parses CSV text into records (array of field arrays), handling RFC 4180
    /// multiline quoted fields correctly.
    private static func parseRecords(from text: String, separator: Character?) -> [[String]] {
        // Strip BOM if present
        let cleanText = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text

        // Find first line to detect separator
        let firstNewline = cleanText.firstIndex(where: { $0 == "\n" || $0 == "\r" })
        let firstLine = firstNewline.map { String(cleanText[cleanText.startIndex..<$0]) } ?? cleanText
        let sep = separator ?? detectSeparator(firstLine)

        var records: [[String]] = []
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = cleanText.startIndex

        while i < cleanText.endIndex {
            let char = cleanText[i]

            if inQuotes {
                if char == "\"" {
                    let next = cleanText.index(after: i)
                    if next < cleanText.endIndex && cleanText[next] == "\"" {
                        // Escaped quote ""
                        current.append("\"")
                        i = cleanText.index(after: next)
                        continue
                    } else {
                        // End of quoted field
                        inQuotes = false
                    }
                } else {
                    current.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == sep {
                    fields.append(current)
                    current = ""
                } else if char == "\r" {
                    // Handle \r\n or bare \r
                    fields.append(current)
                    current = ""
                    let next = cleanText.index(after: i)
                    if next < cleanText.endIndex && cleanText[next] == "\n" {
                        i = cleanText.index(after: next)
                    } else {
                        i = next
                    }
                    if !fields.allSatisfy({ $0.isEmpty }) || fields.count > 1 {
                        records.append(fields)
                    }
                    fields = []
                    continue
                } else if char == "\n" {
                    fields.append(current)
                    current = ""
                    if !fields.allSatisfy({ $0.isEmpty }) || fields.count > 1 {
                        records.append(fields)
                    }
                    fields = []
                    i = cleanText.index(after: i)
                    continue
                } else {
                    current.append(char)
                }
            }

            i = cleanText.index(after: i)
        }

        // Final record
        fields.append(current)
        if !fields.allSatisfy({ $0.isEmpty }) || fields.count > 1 {
            records.append(fields)
        }

        return records
    }
}

// MARK: - Import Result Types

/// Result of a CSV import with row-level error tracking.
public struct CSVImportResult<T>: Sendable where T: Sendable {
    /// Successfully parsed items.
    public let valid: [T]
    /// Errors encountered during parsing, with line numbers.
    public let errors: [CSVImportRowError]

    public var totalCount: Int { valid.count + errors.count }
    public var hasErrors: Bool { !errors.isEmpty }
}

/// An error encountered while parsing a specific CSV row.
public struct CSVImportRowError: Sendable {
    /// The 1-based line number in the CSV file.
    public let lineNumber: Int
    /// The error that occurred.
    public let error: any Error

    public init(lineNumber: Int, error: any Error) {
        self.lineNumber = lineNumber
        self.error = error
    }
}
