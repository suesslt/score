import Foundation

/// Defines an exportable column with title and width hint.
public struct ExportColumn: Sendable {
    public let title: String
    public let width: Int

    public init(_ title: String, width: Int = 15) {
        self.title = title
        self.width = width
    }
}

/// Protocol for types that can be exported as CSV rows.
public protocol CSVExportable {
    static var exportColumns: [ExportColumn] { get }
    var exportValues: [String] { get }
}
