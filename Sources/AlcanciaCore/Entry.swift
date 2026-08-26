import Foundation

public enum Currency: String, Codable, CaseIterable {
    case mxn
    case usd
}

public struct Entry: Identifiable, Codable, Equatable {
    public let id: UUID
    public var amount: Decimal
    public var currency: Currency
    public var amountInMXN: Decimal
    public var exchangeRateUsed: Double?
    public var date: Date

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        currency: Currency,
        amountInMXN: Decimal,
        exchangeRateUsed: Double? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.amountInMXN = amountInMXN
        self.exchangeRateUsed = exchangeRateUsed
        self.date = date
    }
}
