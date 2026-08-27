import Foundation

/// Una sangría mensual predecible (Adobe, Midjourney, ChatGPT, Figma...) que
/// el usuario administra una vez desde Ajustes en vez de teclearla cada mes.
/// No se registra sola: `AlcanciaStore.logRecurring` crea el movimiento del
/// mes cuando el usuario lo pide explícitamente.
public struct RecurringExpense: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var amountMXN: Decimal
    public var category: ExpenseCategory
    public var isBusiness: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        amountMXN: Decimal,
        category: ExpenseCategory,
        isBusiness: Bool = false
    ) {
        self.id = id
        self.name = name
        self.amountMXN = amountMXN
        self.category = category
        self.isBusiness = isBusiness
    }
}
