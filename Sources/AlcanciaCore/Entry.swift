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
    public var category: ExpenseCategory?
    public var note: String?
    public var isBusiness: Bool
    public var recurringExpenseID: UUID?
    public var recurringPeriod: MonthKey?

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        currency: Currency,
        amountInMXN: Decimal,
        exchangeRateUsed: Double? = nil,
        date: Date = Date(),
        kind: EntryKind = .expense,
        category: ExpenseCategory? = nil,
        note: String? = nil,
        isBusiness: Bool = false,
        recurringExpenseID: UUID? = nil,
        recurringPeriod: MonthKey? = nil
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
        self.isBusiness = isBusiness
        self.recurringExpenseID = recurringExpenseID
        self.recurringPeriod = recurringPeriod
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
        category = try container.decodeIfPresent(ExpenseCategory.self, forKey: .category)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        isBusiness = try container.decodeIfPresent(Bool.self, forKey: .isBusiness) ?? false
        recurringExpenseID = try container.decodeIfPresent(UUID.self, forKey: .recurringExpenseID)
        recurringPeriod = try container.decodeIfPresent(MonthKey.self, forKey: .recurringPeriod)
    }
}
