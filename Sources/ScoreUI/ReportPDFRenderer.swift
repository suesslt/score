#if canImport(UIKit)
import CoreGraphics
import Foundation
import UIKit

/// Basis für seitenweise Report-PDFs (extrahiert 2026-08-06 aus den Auftritte-
/// Generatoren): ergänzt den CoreText-basierten `PDFRenderer` um UIKit-Rect-Text
/// mit Truncation/Ausrichtung, Formen (RoundedRect, Ellipse) und den geteilten
/// Report-Rahmen (Titel+Untertitel-Kopf mit Trennlinie, «Seite X von Y»-Fuss).
///
/// Koordinaten wie im `PDFRenderer`: y = Abstand von OBEN; die Klasse spiegelt
/// intern in das CoreGraphics-Koordinatensystem.
open class ReportPDFRenderer: PDFRenderer {

    public let headerHeight: CGFloat
    public let footerHeight: CGFloat

    /// Oberkante des Inhaltsbereichs (unterhalb des Report-Kopfs).
    public var contentTop: CGFloat { marginTop + headerHeight }
    /// Unterkante des Inhaltsbereichs (oberhalb des Fusses).
    public var contentBottom: CGFloat { pageHeight - marginBottom - footerHeight }

    /// Vorgabe: A4 quer (842×595), 30pt Rand, 50pt Kopf, 20pt Fuss —
    /// das Format der Scoreware-Reports.
    public init(
        pageWidth: CGFloat = 842,
        pageHeight: CGFloat = 595,
        margin: CGFloat = 30,
        headerHeight: CGFloat = 50,
        footerHeight: CGFloat = 20
    ) {
        self.headerHeight = headerHeight
        self.footerHeight = footerHeight
        super.init(
            pageWidth: pageWidth, pageHeight: pageHeight,
            marginLeft: margin, marginRight: margin,
            marginTop: margin, marginBottom: margin
        )
    }

    // MARK: - Koordinaten

    /// Spiegelt ein Rechteck aus Oben-Koordinaten ins CG-Koordinatensystem.
    public func flipped(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.origin.x, y: pageHeight - rect.origin.y - rect.height,
               width: rect.width, height: rect.height)
    }

    // MARK: - Text (UIKit, Rect-basiert)

    /// Standard-Attribut-Satz für Report-Text.
    public func attributes(
        size: CGFloat,
        weight: UIFont.Weight = .regular,
        color: UIColor = .black
    ) -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
    }

    /// Zeichnet Text in ein Rechteck (Oben-Koordinaten) mit Umbruch-/
    /// Truncation-Verhalten und Ausrichtung — im Gegensatz zum einzeiligen
    /// CoreText-`drawText(context:text:x:y:...)` der Basisklasse.
    open func drawText(
        context: CGContext,
        _ text: String,
        in rect: CGRect,
        attributes: [NSAttributedString.Key: Any],
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        alignment: NSTextAlignment = .left
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = lineBreakMode
        paragraphStyle.alignment = alignment
        var attrs = attributes
        attrs[.paragraphStyle] = paragraphStyle

        let nsString = text as NSString
        context.saveGState()
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        nsString.draw(in: rect, withAttributes: attrs)
        UIGraphicsPopContext()
        context.restoreGState()
    }

    // MARK: - Formen

    /// Gefülltes (und optional umrandetes) abgerundetes Rechteck, Oben-Koordinaten.
    open func fillRoundedRect(
        context: CGContext,
        rect: CGRect,
        cornerRadius: CGFloat,
        fillColor: CGColor,
        strokeColor: CGColor? = nil,
        lineWidth: CGFloat = 0.5
    ) {
        context.saveGState()
        context.setFillColor(fillColor)
        let path = CGPath(roundedRect: flipped(rect), cornerWidth: cornerRadius,
                          cornerHeight: cornerRadius, transform: nil)
        context.addPath(path)
        if let strokeColor {
            context.setStrokeColor(strokeColor)
            context.setLineWidth(lineWidth)
            context.drawPath(using: .fillStroke)
        } else {
            context.drawPath(using: .fill)
        }
        context.restoreGState()
    }

    /// Gefüllte Ellipse (z.B. Status-Punkt), Oben-Koordinaten.
    open func fillEllipse(context: CGContext, rect: CGRect, color: CGColor) {
        context.saveGState()
        context.setFillColor(color)
        context.fillEllipse(in: flipped(rect))
        context.restoreGState()
    }

    // MARK: - Report-Rahmen

    /// Report-Kopf: Titel (20pt fett), Untertitel (11pt grau), Trennlinie.
    open func drawReportHeader(context: CGContext, title: String, subtitle: String) {
        drawText(context: context, title,
                 in: CGRect(x: marginLeft, y: marginTop, width: contentWidth, height: 26),
                 attributes: attributes(size: 20, weight: .bold))
        drawText(context: context, subtitle,
                 in: CGRect(x: marginLeft, y: marginTop + 28, width: contentWidth, height: 16),
                 attributes: attributes(size: 11, color: .darkGray))
        drawHRule(context: context, y: marginTop + headerHeight - 4,
                  from: marginLeft, to: marginLeft + contentWidth,
                  lineWidth: 0.5, color: UIColor.lightGray.cgColor)
    }

    /// Zentrierter Seiten-Fuss «Seite X von Y».
    open func drawReportFooter(context: CGContext, pageNumber: Int, totalPages: Int) {
        let text = "Seite \(pageNumber) von \(totalPages)"
        drawText(context: context, text,
                 in: CGRect(x: 0, y: pageHeight - marginBottom / 2 - 6,
                            width: pageWidth, height: 12),
                 attributes: attributes(size: 10, color: .darkGray),
                 alignment: .center)
    }
}
#endif
