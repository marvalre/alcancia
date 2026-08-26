import Foundation

public enum Currency: String, Codable, CaseIterable {
    case mxn
    case usd
}

public enum EntryKind: String, Codable, CaseIterable, Sendable {
    case expense
    case income
}

public struct Entry: Identifiable, Codable, Equatable {
    public let id: UUID
    public var amount: Decimal
    public var currency: Currency
    public var amountInMXN: Decimal
    public var exchangeRateUsed: Double?
    public var date: Date
    public var kind: EntryKind
    public var category: Category?
    public var note: String?

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        currency: Currency,
        amountInMXN: Decimal,
        exchangeRateUsed: Double? = nil,
        date: Date = Date(),
        kind: EntryKind = .expense,
        category: Category? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.amountInMXN = amountInMXN
        self.exchangeRateUsed = exchangeRateUsed
        self.date = date
        self.kind = kind
        self.category = category
        self.note = note
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        amount = try container.decode(Decimal.self, forKey: .amount)
        currency = try container.decode(Currency.self, forKey: .currency)
        amountInMXN = try container.decode(Decimal.self, forKey: .amountInMXN)
        exchangeRateUsed = try container.decodeIfPresent(Double.self, forKey: .exchangeRateUsed)
        date = try container.decode(Date.self, forKey: .date)
        // Campos agregados después de la primera versión. Un movimiento sin
        // `kind` viene de la versión que sólo registraba dinero ganado, así que
        // se lee como ingreso — nunca como gasto, que falsearía los totales.
        kind = try container.decodeIfPresent(EntryKind.self, forKey: .kind) ?? .income
        category = try container.decodeIfPresent(Category.self, forKey: .category)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}
