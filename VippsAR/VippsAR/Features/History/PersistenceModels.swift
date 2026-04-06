import SwiftData
import Foundation

/// Lightweight record of a completed split session saved to SwiftData.
@Model
final class BillSession {
    var total: Decimal
    var currencyCode: String
    var date: Date
    var dinerCount: Int

    @Relationship(deleteRule: .cascade, inverse: \BillItem.session)
    var items: [BillItem] = []

    @Relationship(deleteRule: .cascade, inverse: \Diner.session)
    var diners: [Diner] = []

    init(total: Decimal, currencyCode: String, date: Date, dinerCount: Int) {
        self.total = total
        self.currencyCode = currencyCode
        self.date = date
        self.dinerCount = dinerCount
    }

    var formattedTotal: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: total as NSDecimalNumber) ?? "\(total)"
    }
}

@Model
final class BillItem {
    var label: String
    var price: Decimal
    var session: BillSession?

    init(label: String, price: Decimal) {
        self.label = label
        self.price = price
    }
}

@Model
final class Diner {
    var name: String
    var share: Decimal
    var session: BillSession?

    init(name: String, share: Decimal) {
        self.name = name
        self.share = share
    }
}
