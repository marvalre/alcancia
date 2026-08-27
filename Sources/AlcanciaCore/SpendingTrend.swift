import Foundation

/// El gasto total de un mes, para dibujar una barra en la gráfica de
/// tendencia. Los meses sin gasto llevan `totalMXN == 0` a propósito: un
/// hueco en la gráfica es información, no algo que se deba omitir.
public struct MonthSpending: Identifiable, Equatable {
    /// El primer instante de ese mes.
    public let month: Date
    public let totalMXN: Decimal
    /// `true` para el mes en el que termina la serie (el mes en curso que se
    /// está viendo), para resaltarlo en la gráfica.
    public let isCurrent: Bool

    public var id: Date { month }

    public init(month: Date, totalMXN: Decimal, isCurrent: Bool) {
        self.month = month
        self.totalMXN = totalMXN
        self.isCurrent = isCurrent
    }
}

/// Serie de gasto mensual para la gráfica de barras de "Por categoría".
/// Reutiliza `MonthlySummary` para el total de cada mes en vez de reimplementar
/// el filtrado por mes — ese cálculo ya resuelve a propósito la comparación
/// por componentes de año/mes en vez de `DateInterval.contains`.
public struct SpendingTrend {
    /// Del más viejo al más reciente. Siempre `months` elementos.
    public let series: [MonthSpending]

    public init(
        entries: [Entry],
        endingAt month: Date,
        months: Int = 6,
        calendar: Calendar = .current
    ) {
        let comps = calendar.dateComponents([.year, .month], from: month)
        let firstOfEndingMonth = calendar.date(from: comps) ?? month

        var result: [MonthSpending] = []
        result.reserveCapacity(months)
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let monthStart = calendar.date(
                byAdding: .month,
                value: -offset,
                to: firstOfEndingMonth
            ) else { continue }
            let summary = MonthlySummary(entries: entries, month: monthStart, calendar: calendar)
            result.append(MonthSpending(
                month: monthStart,
                totalMXN: summary.totalSpentMXN,
                isCurrent: offset == 0
            ))
        }
        self.series = result
    }
}
