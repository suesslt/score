import Foundation
import CoreGraphics
import CoreText

// MARK: - Font Configuration

public enum FontType: String, CaseIterable, Sendable {
    case title = "Title"
    case standard = "Standard"
    case standardFixed = "Standard fixed"
    case standardSmall = "Standard small"
    case subject = "Subject"
    case titleInvoiceLines = "Title Invoice Lines"
    case standardBold = "Standard bold"
    case standardFixedBold = "Standard fixed bold"
    case titleReceiver = "Title Receiver"
    case headerReceiver = "Header Receiver"
    case textReceiver = "Text Receiver"
    case titlePayment = "Title Payment"
    case headerPayment = "Header Payment"
    case textPayment = "Text Payment"
    case amountPayment = "Amount Payment"
    case amountReceiver = "Amount Receiver"
    // Neue Cases für Faktenblatt-Renderer
    case row = "Row"
    case rowBold = "Row Bold"
    case footnote = "Footnote"

    public var fontSize: CGFloat? {
        switch self {
        case .title: return 14
        case .standardFixed, .standardFixedBold, .titleReceiver, .titlePayment: return 11
        case .standard, .textPayment, .amountPayment: return 10
        case .standardSmall, .titleInvoiceLines, .textReceiver, .headerPayment, .amountReceiver: return 8
        case .headerReceiver: return 6
        case .row, .rowBold: return 9
        case .footnote: return 7
        case .subject: return nil
        case .standardBold: return nil
        }
    }

    public var isBold: Bool {
        switch self {
        case .standard, .standardFixed, .standardSmall, .textReceiver, .textPayment,
             .amountPayment, .amountReceiver, .row, .footnote:
            return false
        default:
            return true
        }
    }

    public var isLight: Bool {
        switch self {
        case .footnote: return true
        default: return false
        }
    }

    public var isMonospaced: Bool {
        switch self {
        case .amountPayment, .amountReceiver:
            return true
        default:
            return false
        }
    }

    public var fontName: String? {
        switch self {
        case .titleReceiver, .headerReceiver, .textReceiver, .titlePayment, .headerPayment, .textPayment,
            .amountPayment, .amountReceiver:
            return "Helvetica"
        default:
            return nil
        }
    }

    public var lineSpacing: CGFloat {
        switch self {
        case .textReceiver, .headerReceiver, .textPayment, .headerPayment:
            return 1.1
        default:
            return 1.2
        }
    }
}

// MARK: - PDF Renderer Base Class

/// Base class providing reusable PDF drawing primitives for text, lines, and separators.
/// Uses CoreGraphics/CoreText for cross-platform support (iOS + macOS).
/// All y-coordinates are "distance from top" — internally converted to CoreGraphics bottom-left origin.
/// Subclass this to build domain-specific PDF renderers.
open class PDFRenderer {
    public let fontName: String
    public let fontSize: CGFloat

    // MARK: - A4 Dimensionen (72 dpi)

    public let pageWidth: CGFloat
    public let pageHeight: CGFloat
    public let marginLeft: CGFloat
    public let marginRight: CGFloat
    public let marginTop: CGFloat
    public let marginBottom: CGFloat

    public var contentWidth: CGFloat {
        pageWidth - marginLeft - marginRight
    }

    // MARK: - Farb-Konstanten

    public static let colorBlack = CGColor(gray: 0.0, alpha: 1.0)
    public static let colorDarkGray = CGColor(gray: 0.35, alpha: 1.0)
    public static let colorMediumGray = CGColor(gray: 0.5, alpha: 1.0)
    public static let colorLightGrayBg = CGColor(gray: 0.92, alpha: 1.0)

    // MARK: - Init

    public init(
        fontName: String? = nil,
        fontSize: CGFloat? = nil,
        pageWidth: CGFloat = 595.28,
        pageHeight: CGFloat = 841.89,
        marginLeft: CGFloat = 50,
        marginRight: CGFloat = 50,
        marginTop: CGFloat = 50,
        marginBottom: CGFloat = 50
    ) {
        self.fontName = fontName ?? "Helvetica"
        self.fontSize = fontSize ?? 10
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.marginLeft = marginLeft
        self.marginRight = marginRight
        self.marginTop = marginTop
        self.marginBottom = marginBottom
    }

    // MARK: - PDF Lifecycle

    /// Erstellt einen PDF-Kontext und gibt (context, pdfData) zurueck.
    open func beginPDF() -> (CGContext, NSMutableData)? {
        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }
        context.beginPage(mediaBox: &mediaBox)
        return (context, pdfData)
    }

    /// Schliesst den PDF-Kontext und gibt die Daten zurueck.
    open func endPDF(context: CGContext, pdfData: NSMutableData) -> Data {
        context.endPage()
        context.closePDF()
        return pdfData as Data
    }

    /// Beginnt eine neue Seite.
    open func newPage(context: CGContext) {
        context.endPage()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        context.beginPage(mediaBox: &mediaBox)
    }

    /// Prueft ob noch genug Platz auf der aktuellen Seite ist.
    /// Falls nicht, wird eine neue Seite begonnen.
    /// Gibt die (ggf. zurueckgesetzte) Y-Position zurueck.
    open func checkPageBreak(
        context: CGContext,
        y: CGFloat,
        requiredSpace: CGFloat = 60
    ) -> CGFloat {
        if y + requiredSpace > pageHeight - marginBottom {
            newPage(context: context)
            return marginTop + 10
        }
        return y
    }

    // MARK: - Text Drawing (CoreText)

    /// Zeichnet Text linksbuendig. y = Abstand von oben.
    @discardableResult
    open func drawText(
        context: CGContext,
        text: String,
        x: CGFloat,
        y: CGFloat,
        fontType: FontType,
        color: CGColor = PDFRenderer.colorBlack
    ) -> CGFloat {
        let ctFont = createCTFont(fontType: fontType)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: ctFont,
            .foregroundColor: color
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let fs = fontType.fontSize ?? self.fontSize
        context.textPosition = CGPoint(x: x, y: pageHeight - y - fs)
        CTLineDraw(line, context)
        return fs * fontType.lineSpacing
    }

    /// Zeichnet Text rechtsbuendig. rightX = rechter Rand.
    @discardableResult
    open func drawTextRightAligned(
        context: CGContext,
        text: String,
        rightX: CGFloat,
        y: CGFloat,
        fontType: FontType,
        color: CGColor = PDFRenderer.colorBlack
    ) -> CGFloat {
        let ctFont = createCTFont(fontType: fontType)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: ctFont,
            .foregroundColor: color
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        let fs = fontType.fontSize ?? self.fontSize
        context.textPosition = CGPoint(x: rightX - CGFloat(textWidth), y: pageHeight - y - fs)
        CTLineDraw(line, context)
        return fs * fontType.lineSpacing
    }

    /// Gibt die Zeilenhoehe fuer einen FontType zurueck, ohne etwas zu zeichnen.
    open func drawEmptyLine(fontType: FontType) -> CGFloat {
        return (fontType.fontSize ?? self.fontSize) * fontType.lineSpacing
    }

    // MARK: - Line Drawing

    /// Zeichnet eine horizontale Linie. y = Abstand von oben.
    open func drawHRule(
        context: CGContext,
        y: CGFloat,
        from startX: CGFloat,
        to endX: CGFloat,
        lineWidth: CGFloat = 0.5,
        dashed: Bool = false,
        color: CGColor = CGColor(gray: 0.6, alpha: 1.0)
    ) {
        context.saveGState()
        context.setStrokeColor(color)
        context.setLineWidth(lineWidth)
        if dashed {
            context.setLineDash(phase: 0, lengths: [4, 3])
        } else {
            context.setLineDash(phase: 0, lengths: [])
        }
        let cgY = pageHeight - y
        context.move(to: CGPoint(x: startX, y: cgY))
        context.addLine(to: CGPoint(x: endX, y: cgY))
        context.strokePath()
        context.restoreGState()
    }

    /// Zeichnet eine vertikale Linie. fromY/toY = Abstand von oben.
    open func drawVerticalLine(
        context: CGContext,
        x: CGFloat,
        fromY: CGFloat,
        toY: CGFloat,
        dashed: Bool = true,
        color: CGColor = PDFRenderer.colorBlack,
        lineWidth: CGFloat = 0.5
    ) {
        context.saveGState()
        context.setStrokeColor(color)
        context.setLineWidth(lineWidth)
        if dashed {
            context.setLineDash(phase: 0, lengths: [3, 3])
        } else {
            context.setLineDash(phase: 0, lengths: [])
        }
        context.move(to: CGPoint(x: x, y: pageHeight - fromY))
        context.addLine(to: CGPoint(x: x, y: pageHeight - toY))
        context.strokePath()
        context.restoreGState()
    }

    // MARK: - Shapes

    /// Zeichnet ein gefuelltes Rechteck. rect.origin.y = Abstand von oben.
    open func fillRect(
        context: CGContext,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        color: CGColor
    ) {
        context.saveGState()
        let cgRect = CGRect(x: x, y: pageHeight - y - height, width: width, height: height)
        context.setFillColor(color)
        context.fill(cgRect)
        context.restoreGState()
    }

    /// Zeichnet ein CGImage an der gegebenen Position mit maximaler Groesse (Aspektverhaltnis beibehaltend).
    open func drawImage(
        context: CGContext,
        image: CGImage,
        x: CGFloat,
        y: CGFloat,
        maxWidth: CGFloat,
        maxHeight: CGFloat
    ) {
        let imgW = CGFloat(image.width)
        let imgH = CGFloat(image.height)
        let scale = min(maxWidth / imgW, maxHeight / imgH, 1.0)
        let drawW = imgW * scale
        let drawH = imgH * scale
        let logoRect = CGRect(
            x: x,
            y: pageHeight - y - drawH,
            width: drawW,
            height: drawH
        )
        context.draw(image, in: logoRect)
    }

    // MARK: - Utility

    /// Speichert PDF-Daten als temporaere Datei und gibt die URL zurueck.
    public static func saveTempPDF(data: Data, filename: String) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - Font Helpers

    /// Erstellt einen CTFont fuer den gegebenen FontType.
    open func createCTFont(fontType: FontType) -> CTFont {
        let fs = fontType.fontSize ?? self.fontSize
        let name: String
        if fontType.isMonospaced {
            name = fontType.isBold ? "Menlo-Bold" : "Menlo"
        } else if fontType.isLight {
            name = (fontType.fontName ?? self.fontName) + "-Light"
        } else if fontType.isBold {
            name = (fontType.fontName ?? self.fontName) + "-Bold"
        } else {
            name = fontType.fontName ?? self.fontName
        }
        return CTFontCreateWithName(name as CFString, fs, nil)
    }
}
