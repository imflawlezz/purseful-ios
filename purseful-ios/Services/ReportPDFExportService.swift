import Foundation
import UIKit

enum ReportPDFExportService {
    private static let pageWidth: CGFloat = 595
    private static let pageHeight: CGFloat = 842
    private static let margin: CGFloat = 40
    private static let footerHeight: CGFloat = 24
    private static let rowHeight: CGFloat = 14
    private static let sectionSpacing: CGFloat = 14

    private enum PDFColors {
        static let paper = UIColor.white
        static let textPrimary = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        static let textSecondary = UIColor(red: 0.39, green: 0.39, blue: 0.4, alpha: 1)
        static let rowStripe = UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
        static let cardFill = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
        static let separator = UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1)
        static let headerRule = UIColor(red: 0.68, green: 0.68, blue: 0.7, alpha: 1)
    }

    private struct PDFLayout {
        let printableRect: CGRect
        let rowHeight: CGFloat = 14
        var pageNumber: Int
        var y: CGFloat
        let context: UIGraphicsPDFRendererContext
        let generatedAt: Date

        mutating func fillPageBackground() {
            PDFColors.paper.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        }

        mutating func ensureSpace(_ height: CGFloat) -> Bool {
            let limit = printableRect.maxY - footerHeight
            guard y + height > limit else { return false }
            drawFooter()
            context.beginPage()
            pageNumber += 1
            fillPageBackground()
            y = printableRect.minY
            return true
        }

        func drawFooter() {
            let footerY = pageHeight - margin - 10
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: PDFColors.textSecondary
            ]
            let pageText = String(localized: "Page \(pageNumber)") as NSString
            pageText.draw(at: CGPoint(x: printableRect.minX, y: footerY), withAttributes: attrs)
            let generatedDate = DateFormatters.reportPDFDateTime.string(from: generatedAt)
            let generatedText = String(localized: "Generated \(generatedDate)") as NSString
            let generatedSize = generatedText.size(withAttributes: attrs)
            generatedText.draw(
                at: CGPoint(x: printableRect.maxX - generatedSize.width, y: footerY),
                withAttributes: attrs
            )
        }

        mutating func drawLine(
            _ text: String,
            font: UIFont,
            color: UIColor = PDFColors.textPrimary,
            x: CGFloat? = nil,
            width: CGFloat? = nil,
            alignment: NSTextAlignment = .left
        ) {
            let drawX = x ?? printableRect.minX
            let drawWidth = width ?? printableRect.width
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
            let attributed = NSAttributedString(string: text, attributes: attrs)
            let bounding = attributed.boundingRect(
                with: CGSize(width: drawWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let height = ceil(bounding.height)
            _ = ensureSpace(height)
            attributed.draw(
                with: CGRect(x: drawX, y: y, width: drawWidth, height: height),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            y += height
        }

        mutating func drawHorizontalRule(color: UIColor = PDFColors.separator) {
            _ = ensureSpace(1)
            color.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: printableRect.minX, y: y))
            path.addLine(to: CGPoint(x: printableRect.maxX, y: y))
            path.lineWidth = 0.5
            path.stroke()
            y += 5
        }

        mutating func drawReportHeader(title: String, version: String) {
            _ = ensureSpace(22)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: PDFColors.textPrimary
            ]
            let versionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: PDFColors.textSecondary
            ]
            (title as NSString).draw(at: CGPoint(x: printableRect.minX, y: y), withAttributes: titleAttrs)
            let versionText = version as NSString
            let versionSize = versionText.size(withAttributes: versionAttrs)
            versionText.draw(
                at: CGPoint(x: printableRect.maxX - versionSize.width, y: y + 5),
                withAttributes: versionAttrs
            )
            y += 22
        }

        mutating func drawSectionTitle(_ title: String) {
            _ = ensureSpace(sectionSpacing + 18)
            y += sectionSpacing
            drawLine(title, font: .boldSystemFont(ofSize: 11), color: PDFColors.textPrimary)
            y += 4
        }

        mutating func drawCategoryRow(
            name: String,
            amount: String,
            sharePercent: Double,
            fontSize: CGFloat = 9
        ) {
            _ = ensureSpace(rowHeight)
            let percentLabel = ReportPDFExportService.formatSharePercent(sharePercent)
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: PDFColors.textPrimary
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: PDFColors.textPrimary
            ]
            let percentAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize - 1, weight: .regular),
                .foregroundColor: PDFColors.textSecondary
            ]

            (name as NSString).draw(at: CGPoint(x: printableRect.minX, y: y), withAttributes: labelAttrs)

            let amountText = amount as NSString
            let amountSize = amountText.size(withAttributes: valueAttrs)
            let percentText = percentLabel as NSString
            let percentSize = percentText.size(withAttributes: percentAttrs)
            let rightEdge = printableRect.maxX
            percentText.draw(
                at: CGPoint(x: rightEdge - percentSize.width, y: y),
                withAttributes: percentAttrs
            )
            amountText.draw(
                at: CGPoint(x: rightEdge - percentSize.width - 8 - amountSize.width, y: y),
                withAttributes: valueAttrs
            )
            y += rowHeight
        }

        mutating func drawKeyValueRow(left: String, right: String, fontSize: CGFloat = 9) {
            _ = ensureSpace(rowHeight)
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: PDFColors.textPrimary
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: PDFColors.textPrimary
            ]
            (left as NSString).draw(at: CGPoint(x: printableRect.minX, y: y), withAttributes: labelAttrs)
            let rightNSString = right as NSString
            let rightSize = rightNSString.size(withAttributes: valueAttrs)
            rightNSString.draw(
                at: CGPoint(x: printableRect.maxX - rightSize.width, y: y),
                withAttributes: valueAttrs
            )
            y += rowHeight
        }

        mutating func drawStatCards(_ cards: [(label: String, value: String)]) {
            let gap: CGFloat = 8
            let columns = 2
            let cardWidth = (printableRect.width - gap) / CGFloat(columns)
            let cardHeight: CGFloat = 36
            let rows = (cards.count + columns - 1) / columns
            let gridHeight = CGFloat(rows) * cardHeight + CGFloat(max(0, rows - 1)) * gap

            _ = ensureSpace(gridHeight)

            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: PDFColors.textSecondary
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: PDFColors.textPrimary
            ]

            for (index, card) in cards.enumerated() {
                let column = index % columns
                let row = index / columns
                let originX = printableRect.minX + CGFloat(column) * (cardWidth + gap)
                let originY = y + CGFloat(row) * (cardHeight + gap)
                let rect = CGRect(x: originX, y: originY, width: cardWidth, height: cardHeight)

                PDFColors.cardFill.setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 5).fill()
                PDFColors.separator.setStroke()
                UIBezierPath(roundedRect: rect, cornerRadius: 5).lineWidth = 0.5
                UIBezierPath(roundedRect: rect, cornerRadius: 5).stroke()

                (card.label as NSString).draw(
                    at: CGPoint(x: rect.minX + 8, y: rect.minY + 6),
                    withAttributes: labelAttrs
                )
                (card.value as NSString).draw(
                    at: CGPoint(x: rect.minX + 8, y: rect.minY + 18),
                    withAttributes: valueAttrs
                )
            }

            y += gridHeight
        }
    }

    @MainActor
    static func export(summary: ReportSummary, lines: [ReportPDFLine]) throws -> URL {
        let paperRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let printableRect = paperRect.insetBy(dx: margin, dy: margin)
        let renderer = UIGraphicsPDFRenderer(bounds: paperRect)

        let data = renderer.pdfData { context in
            context.beginPage()
            var layout = PDFLayout(
                printableRect: printableRect,
                pageNumber: 1,
                y: printableRect.minY,
                context: context,
                generatedAt: summary.generatedAt
            )
            layout.fillPageBackground()

            layout.drawReportHeader(title: String(localized: "Purseful report"), version: appVersionLabel())
            let periodLabel = summary.periodLabel
            layout.drawLine(String(localized: "Period: \(periodLabel)"), font: .systemFont(ofSize: 10), color: PDFColors.textSecondary)
            let currency = summary.baseCurrency
            layout.drawLine(String(localized: "Currency: \(currency)"), font: .systemFont(ofSize: 9), color: PDFColors.textSecondary)
            layout.y += 6

            layout.drawStatCards([
                (String(localized: "Total income"), CurrencyFormatter.format(summary.totalIncome, currencyCode: summary.baseCurrency)),
                (String(localized: "Total expenses"), CurrencyFormatter.format(summary.totalExpenses, currencyCode: summary.baseCurrency)),
                (String(localized: "Net cash flow"), CurrencyFormatter.format(summary.netCashFlow, currencyCode: summary.baseCurrency)),
                (String(localized: "Transactions"), "\(summary.transactionCount)")
            ])
            layout.y += 4

            drawLedger(lines: lines, layout: &layout)

            layout.drawSectionTitle(String(localized: "Spending by category"))
            if summary.categories.isEmpty {
                layout.drawLine(String(localized: "No spending yet"), font: .systemFont(ofSize: 9), color: PDFColors.textSecondary)
            } else {
                for category in summary.categories {
                    layout.drawCategoryRow(
                        name: category.name,
                        amount: CurrencyFormatter.format(category.amount, currencyCode: summary.baseCurrency),
                        sharePercent: category.sharePercent
                    )
                }
            }

            layout.drawFooter()
        }

        let fileName = pdfFileName(for: summary.periodLabel)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func appVersionLabel() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return String(localized: "Purseful \(version) (Build \(build))")
    }

    private static func formatSharePercent(_ value: Double) -> String {
        if value > 0, value < 1 {
            return String(format: "%.1f%%", value)
        }
        return String(format: "%.0f%%", value)
    }

    private static func pdfFileName(for periodLabel: String) -> String {
        let range = periodLabel
            .replacingOccurrences(of: " – ", with: "-")
            .replacingOccurrences(of: " ", with: "")
        return "purseful_report_\(range).pdf"
    }

    private static func drawLedger(lines: [ReportPDFLine], layout: inout PDFLayout) {
        let tableWidth = layout.printableRect.width
        let dateWidth: CGFloat = 108
        let titleWidth: CGFloat = 138
        let accountWidth: CGFloat = 90
        let categoryWidth: CGFloat = 62
        let amountWidth = tableWidth - dateWidth - titleWidth - accountWidth - categoryWidth

        let columns: [(title: String, width: CGFloat, alignment: NSTextAlignment)] = [
            (String(localized: "Date & time"), dateWidth, .left),
            (String(localized: "Title"), titleWidth, .left),
            (String(localized: "Account"), accountWidth, .left),
            (String(localized: "Category"), categoryWidth, .left),
            (String(localized: "Amount"), amountWidth, .right)
        ]

        func drawHeader() {
            _ = layout.ensureSpace(layout.rowHeight + 8)
            var x = layout.printableRect.minX
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 8),
                .foregroundColor: PDFColors.textSecondary
            ]
            for column in columns {
                let title = column.title as NSString
                if column.alignment == .right {
                    let size = title.size(withAttributes: headerAttrs)
                    title.draw(
                        at: CGPoint(x: x + column.width - size.width, y: layout.y),
                        withAttributes: headerAttrs
                    )
                } else {
                    title.draw(at: CGPoint(x: x, y: layout.y), withAttributes: headerAttrs)
                }
                x += column.width
            }
            layout.y += layout.rowHeight + 2
            layout.drawHorizontalRule(color: PDFColors.headerRule)
        }

        let transactionCount = lines.count
        layout.drawSectionTitle(String(localized: "Transactions (\(transactionCount))"))

        if lines.isEmpty {
            layout.drawLine(String(localized: "No transactions in this period"), font: .systemFont(ofSize: 9), color: PDFColors.textSecondary)
            return
        }

        drawHeader()

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: PDFColors.textPrimary
        ]
        let amountAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: PDFColors.textPrimary
        ]

        for (index, line) in lines.enumerated() {
            if layout.ensureSpace(layout.rowHeight + 3) {
                drawHeader()
            }

            if index.isMultiple(of: 2) {
                PDFColors.rowStripe.setFill()
                UIRectFill(
                    CGRect(
                        x: layout.printableRect.minX,
                        y: layout.y - 1,
                        width: layout.printableRect.width,
                        height: layout.rowHeight + 2
                    )
                )
            }

            var x = layout.printableRect.minX
            let values = [
                line.dateTimeLabel,
                line.title,
                line.accountLabel,
                line.categoryName,
                line.amountLabel
            ]
            for (columnIndex, value) in values.enumerated() {
                let column = columns[columnIndex]
                let attrs = columnIndex == values.count - 1 ? amountAttrs : bodyAttrs
                let displayText: String
                if columnIndex == 0 {
                    displayText = value
                } else {
                    displayText = truncate(value, toWidth: column.width - 4, attributes: attrs)
                }
                let text = displayText as NSString
                let size = text.size(withAttributes: attrs)
                let drawX: CGFloat
                switch column.alignment {
                case .right:
                    drawX = x + column.width - size.width
                default:
                    drawX = x
                }
                text.draw(at: CGPoint(x: drawX, y: layout.y), withAttributes: attrs)
                x += column.width
            }
            layout.y += layout.rowHeight + 2
        }
    }

    private static func truncate(
        _ text: String,
        toWidth width: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) -> String {
        if (text as NSString).size(withAttributes: attributes).width <= width { return text }
        var result = text
        while result.count > 1 {
            result = String(result.dropLast())
            let candidate = result + "…"
            if (candidate as NSString).size(withAttributes: attributes).width <= width {
                return candidate
            }
        }
        return "…"
    }
}
