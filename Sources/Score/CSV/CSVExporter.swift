import Foundation

/// Generic CSV export service (RFC 4180 compliant, Excel-compatible with BOM).
public enum CSVExporter {

    /// Exports data as a CSV file and returns the temporary URL.
    public static func exportCSV<T: CSVExportable>(
        data: [T],
        filename: String,
        separator: Character = ";"
    ) -> URL? {
        let columns = T.exportColumns
        let sep = String(separator)

        var csv = columns.map { escapeCSV($0.title, separator: separator) }.joined(separator: sep) + "\n"

        for item in data {
            let row = item.exportValues.map { escapeCSV($0, separator: separator) }.joined(separator: sep)
            csv += row + "\n"
        }

        // BOM for Excel compatibility with umlauts
        let bom = "\u{FEFF}"
        let csvWithBom = bom + csv

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("csv")

        do {
            try csvWithBom.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }

    /// Escapes a CSV field per RFC 4180.
    public static func escapeCSV(_ value: String, separator: Character = ";") -> String {
        let sep = String(separator)
        if value.contains(sep) || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
