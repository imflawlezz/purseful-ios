import CoreSpotlight
import Foundation
import SwiftData
import MobileCoreServices

enum SpotlightService {
    static func indexAll(
        transactions: [Transaction],
        accounts: [Account],
        categories: [Category]
    ) {
        var items: [CSSearchableItem] = []

        for transaction in transactions.prefix(200) {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = transaction.title
            attributeSet.contentDescription = CurrencyFormatter.format(
                transaction.amount,
                currencyCode: transaction.account?.currency ?? AppSettings.shared.baseCurrency
            )
            attributeSet.keywords = [transaction.category?.name, transaction.note].compactMap { $0 }
            let item = CSSearchableItem(
                uniqueIdentifier: "transaction-\(transaction.id.uuidString)",
                domainIdentifier: "transactions",
                attributeSet: attributeSet
            )
            items.append(item)
        }

        for account in accounts {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = account.name
            attributeSet.contentDescription = account.type.displayName
            let item = CSSearchableItem(
                uniqueIdentifier: "account-\(account.id.uuidString)",
                domainIdentifier: "accounts",
                attributeSet: attributeSet
            )
            items.append(item)
        }

        for category in categories where !category.isHidden {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = category.name
            let item = CSSearchableItem(
                uniqueIdentifier: "category-\(category.id.uuidString)",
                domainIdentifier: "categories",
                attributeSet: attributeSet
            )
            items.append(item)
        }

        CSSearchableIndex.default().indexSearchableItems(items)
    }
}
