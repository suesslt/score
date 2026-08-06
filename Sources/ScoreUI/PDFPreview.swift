#if canImport(UIKit) && canImport(PDFKit) && !os(watchOS)
import PDFKit
import SwiftUI

/// PDFKit-`PDFView` als SwiftUI-View — die geteilte Inline-PDF-Vorschau der
/// Scoreware-Apps (vorher je eine Kopie in Stromabrechnungen, KWYK, …).
///
/// Bewusst schlicht: synchrones Laden aus `PDFDocument`, `Data` oder `URL`.
/// Wer grosse Dateien asynchron nachladen oder Seiten-Paging steuern muss,
/// baut weiterhin einen eigenen Wrapper (Beispiel: KWYKs `PDFKitView`).
public struct PDFPreview: UIViewRepresentable {
    /// SwiftUI vergleicht bei `updateUIView` über diese Quelle, nicht über
    /// teure `dataRepresentation()`-Abzüge.
    public enum Source: Equatable {
        case document(PDFDocument)
        case data(Data)
        case url(URL)

        var pdfDocument: PDFDocument? {
            switch self {
            case .document(let document): document
            case .data(let data): PDFDocument(data: data)
            case .url(let url): PDFDocument(url: url)
            }
        }
    }

    private let source: Source
    private let displayMode: PDFDisplayMode

    public init(_ source: Source, displayMode: PDFDisplayMode = .singlePageContinuous) {
        self.source = source
        self.displayMode = displayMode
    }

    public init(document: PDFDocument, displayMode: PDFDisplayMode = .singlePageContinuous) {
        self.init(.document(document), displayMode: displayMode)
    }

    public init(data: Data, displayMode: PDFDisplayMode = .singlePageContinuous) {
        self.init(.data(data), displayMode: displayMode)
    }

    public init(url: URL, displayMode: PDFDisplayMode = .singlePageContinuous) {
        self.init(.url(url), displayMode: displayMode)
    }

    public func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = displayMode
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        view.document = source.pdfDocument
        context.coordinator.source = source
        return view
    }

    public func updateUIView(_ view: PDFView, context: Context) {
        view.displayMode = displayMode
        guard context.coordinator.source != source else { return }
        context.coordinator.source = source
        view.document = source.pdfDocument
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator {
        var source: Source?
    }
}
#endif
