import Foundation

public struct CategoryTotal: Identifiable, Equatable {
    public let category: Category
    public let amountMXN: Decimal
    /// Parte del gasto total del mes, de 0 a 1, para dibujar la barra.
    public let fractionOfTotal: Double

    public var id: String { category.rawValue }

    public init(category: Category, amountMXN: Decimal, fractionOfTotal: Double) {
        self.category = category
        self.amountMXN = amountMXN
        self.fractionOfTotal = fractionOfTotal
    }
}

/// Todo lo que la interfaz necesita saber de un mes, calculado de una pasada.
public struct MonthlySummary {
    public let month: Date
    /// Del más reciente al más viejo.
    public let entriesInMonth: [Entry]
    public let totalSpentMXN: Decimal
    public let totalIncomeMXN: Decimal
    /// Sólo categorías con gasto, de mayor a menor.
    public let byCategory: [CategoryTotal]

    public init(entries: [Entry], month: Date, calendar: Calendar = .current) {
        self.month = month

        let monthComps = calendar.dateComponents([.year, .month], from: month)

        let inMonth = entries
            .filter { entry in
                let entryComps = calendar.dateComponents([.year, .month], from: entry.date)
                return entryComps.year == monthComps.year && entryComps.month == monthComps.month
            }
            .sorted { $0.date > $1.date }
        self.entriesInMonth = inMonth

        let expenses = inMonth.filter { $0.kind == .expense }
        let spent = expenses.reduce(Decimal(0)) { $0 + $1.amountInMXN }
        self.totalSpentMXN = spent
        self.totalIncomeMXN = inMonth
            .filter { $0.kind == .income }
            .reduce(Decimal(0)) { $0 + $1.amountInMXN }

        var totals: [Category: Decimal] = [:]
        for expense in expenses {
            // Un gasto sin categoría cuenta como "Otro" en vez de desaparecer
            // del desglose.
            let category = expense.category ?? .otro
            totals[category, default: 0] += expense.amountInMXN
        }

        let spentDouble = NSDecimalNumber(decimal: spent).doubleValue
        self.byCategory = totals
            .map { category, amount in
                let share = spentDouble > 0
                    ? NSDecimalNumber(decimal: amount).doubleValue / spentDouble
                    : 0
                return CategoryTotal(
                    category: category,
                    amountMXN: amount,
                    fractionOfTotal: share
                )
            }
            .sorted { left, right in
                // Empate resuelto por el orden fijo del enum, para que la lista
                // no baile entre renders.
                if left.amountMXN == right.amountMXN {
                    return categoryOrder(left.category) < categoryOrder(right.category)
                }
                return left.amountMXN > right.amountMXN
            }
    }
}

private func categoryOrder(_ category: Category) -> Int {
    Category.allCases.firstIndex(of: category) ?? Category.allCases.count
}
