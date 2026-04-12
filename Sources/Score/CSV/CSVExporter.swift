import Foundation

/// Generic CSV export service (RFC 4180 compliant, Excel-compatible with BOM).
public enum CSVExporter {

    /// Where to write the exported CSV file.
    public enum ExportLocation: Sendable {
        /// System temporary directory.
        case temp
        /// User's Documents directory.
        case documents
        /// A custom directory URL.
        case custom(URL)

        var directoryURL: URL {
            switch self {
            case .temp:
                return FileManager.default.temporaryDirectory
            case .documents:
                return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                    ?? FileManager.default.temporaryDirectory
            case .custom(let url):
                return url
            }
        }
    }

    /// Generates a CSV string from exportable data (no file I/O).
    public static func exportCSVString<T: CSVExportable>(
        data: [T],
        separator: Character = ";"
    ) -> String {
        let columns = T.exportColumns
        let sep = String(separator)

        var csv = columns.map { escapeCSV($0.title, separator: separator) }.joined(separator: sep) + "\n"

        for item in data {
            let row = item.exportValues.map { escapeCSV($0, separator: separator) }.joined(separator: sep)
            csv += row + "\n"
        }

        return csv
    }

    /// Exports data as a CSV file and returns the file URL.
    public static func exportCSV<T: CSVExportable>(
        data: [T],
        filename: String,
        separator: Character = ";",
        location: ExportLocation = .temp
    ) -> URL? {
        let csv = exportCSVString(data: data, separator: separator)

        // BOM for Excel compatibility with umlauts
        let bom = "\u{FEFF}"
        let csvWithBom = bom + csv

        let fileURL = location.directoryURL
            .appendingPathComponent(filename)
            .appendingPathExtension("csv")

        do {
            try csvWithBom.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
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
