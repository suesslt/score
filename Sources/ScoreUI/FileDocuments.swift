import SwiftUI
import UniformTypeIdentifiers

/// Generischer `FileDocument` für Text-Exporte (CSV, JSON, Markdown, …) über
/// `.fileExporter` — der geteilte Wrapper der Scoreware-Apps (vorher je eine
/// Kopie als `CSVDocument`, …). Der beim Schreiben verwendete Typ kommt vom
/// `contentType:`-Parameter des `fileExporter`; `readableContentTypes` deckt
/// die gängigen Text-Typen für `.fileImporter` ab.
public struct TextFileDocument: FileDocument {
    public static var readableContentTypes: [UTType] {
        [.plainText, .utf8PlainText, .commaSeparatedText, .json]
    }

    public var content: String

    public init(content: String = "") {
        self.content = content
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = string
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(content.utf8))
    }
}

/// Generischer `FileDocument` für Binär-Exporte (PDF, Bilder, ZIP, …) über
/// `.fileExporter` (vorher je eine Kopie als `PDFFile`, …).
public struct DataFileDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.data, .pdf] }

    public var data: Data

    public init(data: Data = Data()) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
