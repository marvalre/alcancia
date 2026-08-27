import Foundation

/// Cuánto del presupuesto del mes queda. El cerdito de la barra de menú se
/// rellena con `fractionRemaining`: lleno al empezar el mes, vacío cuando se
/// acabó.
public struct BudgetProgress {
    public let spentMXN: Decimal
    public let budgetMXN: Decimal?

    public init(spentMXN: Decimal, budgetMXN: Decimal?) {
        self.spentMXN = spentMXN
        self.budgetMXN = budgetMXN
    }

    /// Un presupuesto de cero o menos cuenta como "sin presupuesto".
    private var activeBudget: Decimal? {
        guard let budgetMXN, budgetMXN > 0 else { return nil }
        return budgetMXN
    }

    /// Negativo cuando te pasaste.
    public var remainingMXN: Decimal? {
        guard let activeBudget else { return nil }
        return activeBudget - spentMXN
    }

    /// Acotada a 0...1 por ambos extremos, lista para `ProgressView` y para el
    /// relleno del cerdito.
    public var fractionRemaining: Double? {
        guard let activeBudget, let remainingMXN else { return nil }
        let ratio = remainingMXN / activeBudget
        let value = NSDecimalNumber(decimal: ratio).doubleValue
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    public var isOverBudget: Bool {
        guard let remainingMXN else { return false }
        return remainingMXN < 0
    }

    /// Sin acotar por arriba: puede pasar de 100% cuando te pasaste. Se acota
    /// antes de convertir a Int para que un presupuesto minúsculo no desborde.
    public var percentSpentText: String? {
        guard let activeBudget else { return nil }
        let ratio = spentMXN / activeBudget
        let value = NSDecimalNumber(decimal: ratio).doubleValue
        guard value.isFinite else { return nil }
        let scaled = min((value * 100).rounded(), 999_999_999_999)
        return "\(Int(max(scaled, 0)))%"
    }

    /// Cuánto puedes gastar por día con lo que queda, incluyendo hoy.
    /// `nil` sin presupuesto, o si ya te pasaste.
    public func dailyAllowance(remainingDays: Int) -> Decimal? {
        guard !isOverBudget, remainingDays > 0, let remainingMXN else { return nil }
        return remainingMXN / Decimal(remainingDays)
    }
}
