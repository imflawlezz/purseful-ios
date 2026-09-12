import SwiftData
import SwiftUI

struct DatedTransactionQuery<Content: View>: View {
    let start: Date
    @Query private var transactions: [Transaction]
    @ViewBuilder var content: ([Transaction]) -> Content

    init(start: Date, @ViewBuilder content: @escaping ([Transaction]) -> Content) {
        self.start = start
        let capturedStart = start
        _transactions = Query(
            filter: #Predicate<Transaction> { $0.date >= capturedStart },
            sort: \Transaction.date,
            order: .reverse
        )
        self.content = content
    }

    var body: some View {
        content(transactions)
    }
}
