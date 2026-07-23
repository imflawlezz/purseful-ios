import Foundation
import UIKit

enum ReceiptScanSupport {
    static func jpegAttachment(from image: UIImage) -> Data? {
        image.jpegData(compressionQuality: 0.82)
    }

    static func matchCategory(named name: String, in categories: [Category]) -> Category? {
        categories.first { $0.name == name }
    }

    static func apply(
        result: ReceiptParseResult,
        categories: [Category],
        attachmentData: Data?
    ) -> (amountText: String?, title: String?, date: Date?, category: Category?, attachmentData: Data?) {
        let category = result.suggestedCategory.flatMap { matchCategory(named: $0, in: categories) }
        let amountText = result.total.map { NSDecimalNumber(decimal: $0).stringValue }
        return (
            amountText: amountText,
            title: result.merchant,
            date: result.date,
            category: category,
            attachmentData: attachmentData
        )
    }
}
