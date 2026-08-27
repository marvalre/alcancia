import Foundation

/// Un saldo total declarado en una fecha concreta; no es una diferencia.
public struct BalanceAdjustment: Identifiable, Codable, Equatable {
    public let id: UUID
    public var amountMXN: Decimal
    public var date: Date
    public var note: String?

    public init(id: UUID = UUID(), amountMXN: Decimal, date: Date = Date(), note: String? = nil) {
        self.id = id
        self.amountMXN = amountMXN
        self.date = date
        self.note = note
    }
}
