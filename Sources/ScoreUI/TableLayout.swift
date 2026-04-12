//
//  TableLayout.swift
//  ScoreUI
//
//  Table layout primitives for PDF generation.
//

import Foundation
import CoreGraphics

// MARK: - Line Style

/// Visual style for horizontal rules in PDF documents.
public enum PDFLineStyle: Sendable {
    /// A single solid line.
    case single
    /// Two parallel lines (used for totals).
    case double
    /// A dashed line.
    case dashed
}

// MARK: - Row Style

/// Visual style for a table row.
public enum PDFRowStyle: Sendable {
    /// Normal row (default font).
    case normal
    /// Bold row (section headers, subtotals).
    case bold
    /// Header row (column titles, drawn with bold + underline).
    case header
    /// Detail row (smaller font, indented).
    case detail
    /// Totals row with underline style.
    case totals(lineStyle: PDFLineStyle)
}

// MARK: - Table Column Definition

/// Defines a column in a PDF table.
public struct PDFTableColumn: Sendable {
    /// Column header label.
    public let label: String
    /// X position (absolute, from left edge of page).
    public let x: CGFloat
    /// Column width in points.
    public let width: CGFloat
    /// Whether values are right-aligned (default for numbers).
    public let rightAligned: Bool

    public init(label: String, x: CGFloat, width: CGFloat, rightAligned: Bool = false) {
        self.label = label
        self.x = x
        self.width = width
        self.rightAligned = rightAligned
    }
}

// MARK: - Table Layout

/// Describes a complete table layout with column definitions.
public struct PDFTableLayout: Sendable {
    public let columns: [PDFTableColumn]

    public init(columns: [PDFTableColumn]) {
        self.columns = columns
    }

    /// Creates a table layout with evenly spaced columns.
    public static func evenColumns(
        labels: [String],
        startX: CGFloat,
        totalWidth: CGFloat,
        rightAlignedIndices: Set<Int> = []
    ) -> PDFTableLayout {
        let colWidth = totalWidth / CGFloat(labels.count)
        let columns = labels.enumerated().map { index, label in
            PDFTableColumn(
                label: label,
                x: startX + CGFloat(index) * colWidth,
                width: colWidth,
                rightAligned: rightAlignedIndices.contains(index)
            )
        }
        return PDFTableLayout(columns: columns)
    }
}

// MARK: - Multi-Column Tracker

/// Tracks independent y-positions for multi-column layouts (e.g. balance sheet with left/right columns).
public struct PDFColumnTracker: Sendable {
    private var positions: [CGFloat]

    /// Creates a tracker with the given number of columns, all starting at the same y.
    public init(columnCount: Int, startY: CGFloat) {
        self.positions = Array(repeating: startY, count: columnCount)
    }

    /// Current y-position for the given column.
    public func y(for column: Int) -> CGFloat {
        positions[column]
    }

    /// Advances the y-position for a column by the given amount.
    public mutating func advance(column: Int, by amount: CGFloat) {
        positions[column] += amount
    }

    /// Sets the y-position for a column.
    public mutating func set(column: Int, y: CGFloat) {
        positions[column] = y
    }

    /// Returns the maximum y across all columns (useful for syncing after parallel sections).
    public var maxY: CGFloat {
        positions.max() ?? 0
    }

    /// Resets all columns to the same y-position.
    public mutating func resetAll(to y: CGFloat) {
        positions = positions.map { _ in y }
    }
}

// MARK: - PDFRenderer Table Extensions

extension PDFRenderer {

    // MARK: - Table Header

    /// Draws column headers with a horizontal rule below.
    ///
    /// - Returns: The y-position after the header (below the line).
    @discardableResult
    public func drawTableHeader(
        context: CGContext,
        layout: PDFTableLayout,
        y: CGFloat,
        fontType: FontType = .rowBold,
        color: CGColor = PDFRenderer.colorBlack,
        lineColor: CGColor = CGColor(gray: 0.6, alpha: 1.0)
    ) -> CGFloat {
        var maxLineHeight: CGFloat = 0

        for column in layout.columns {
            let lineHeight: CGFloat
            if column.rightAligned {
                lineHeight = drawTextRightAligned(
                    context: context,
                    text: column.label,
                    rightX: column.x + column.width,
                    y: y,
                    fontType: fontType,
                    color: color
                )
            } else {
                lineHeight = drawText(
                    context: context,
                    text: column.label,
                    x: column.x,
                    y: y,
                    fontType: fontType,
                    color: color
                )
            }
            maxLineHeight = max(maxLineHeight, lineHeight)
        }

        let lineY = y + maxLineHeight + 2
        let firstX = layout.columns.first?.x ?? marginLeft
        let lastCol = layout.columns.last
        let endX = (lastCol?.x ?? marginLeft) + (lastCol?.width ?? contentWidth)
        drawHRule(context: context, y: lineY, from: firstX, to: endX, color: lineColor)

        return lineY + 4
    }

    // MARK: - Table Row

    /// Draws a single table row with values aligned to column definitions.
    ///
    /// - Returns: The y-position after the row.
    @discardableResult
    public func drawTableRow(
        context: CGContext,
        layout: PDFTableLayout,
        values: [String],
        y: CGFloat,
        style: PDFRowStyle = .normal,
        color: CGColor = PDFRenderer.colorBlack
    ) -> CGFloat {
        let fontType: FontType
        switch style {
        case .normal: fontType = .row
        case .bold, .header: fontType = .rowBold
        case .detail: fontType = .footnote
        case .totals: fontType = .rowBold
        }

        var maxLineHeight: CGFloat = 0

        for (index, column) in layout.columns.enumerated() {
            let value = index < values.count ? values[index] : ""
            let lineHeight: CGFloat
            if column.rightAligned {
                lineHeight = drawTextRightAligned(
                    context: context,
                    text: value,
                    rightX: column.x + column.width,
                    y: y,
                    fontType: fontType,
                    color: color
                )
            } else {
                lineHeight = drawText(
                    context: context,
                    text: value,
                    x: column.x,
                    y: y,
                    fontType: fontType,
                    color: color
                )
            }
            maxLineHeight = max(maxLineHeight, lineHeight)
        }

        let afterTextY = y + maxLineHeight

        // Draw line for totals style
        if case .totals(let lineStyle) = style {
            let firstX = layout.columns.first?.x ?? marginLeft
            let lastCol = layout.columns.last
            let endX = (lastCol?.x ?? marginLeft) + (lastCol?.width ?? contentWidth)

            switch lineStyle {
            case .single:
                drawHRule(context: context, y: afterTextY, from: firstX, to: endX)
                return afterTextY + 4
            case .double:
                drawHRule(context: context, y: afterTextY, from: firstX, to: endX)
                drawHRule(context: context, y: afterTextY + 3, from: firstX, to: endX)
                return afterTextY + 7
            case .dashed:
                drawHRule(context: context, y: afterTextY, from: firstX, to: endX, dashed: true)
                return afterTextY + 4
            }
        }

        return afterTextY
    }

    // MARK: - Alternating Row Background

    /// Fills a row background with an alternating color pattern.
    public func drawAlternatingRowBackground(
        context: CGContext,
        rowIndex: Int,
        y: CGFloat,
        height: CGFloat,
        startX: CGFloat? = nil,
        width: CGFloat? = nil,
        evenColor: CGColor = PDFRenderer.colorLightGrayBg
    ) {
        guard rowIndex % 2 == 0 else { return }
        fillRect(
            context: context,
            x: startX ?? marginLeft,
            y: y,
            width: width ?? contentWidth,
            height: height,
            color: evenColor
        )
    }

    // MARK: - Enhanced Line Drawing

    /// Draws a horizontal rule with a specific line style.
    public func drawStyledHRule(
        context: CGContext,
        y: CGFloat,
        from startX: CGFloat? = nil,
        to endX: CGFloat? = nil,
        style: PDFLineStyle = .single,
        lineWidth: CGFloat = 0.5,
        color: CGColor = CGColor(gray: 0.6, alpha: 1.0)
    ) -> CGFloat {
        let fromX = startX ?? marginLeft
        let toX = endX ?? (pageWidth - marginRight)

        switch style {
        case .single:
            drawHRule(context: context, y: y, from: fromX, to: toX, lineWidth: lineWidth, color: color)
            return y + 4
        case .double:
            drawHRule(context: context, y: y, from: fromX, to: toX, lineWidth: lineWidth, color: color)
            drawHRule(context: context, y: y + 3, from: fromX, to: toX, lineWidth: lineWidth, color: color)
            return y + 7
        case .dashed:
            drawHRule(context: context, y: y, from: fromX, to: toX, lineWidth: lineWidth, dashed: true, color: color)
            return y + 4
        }
    }
}
