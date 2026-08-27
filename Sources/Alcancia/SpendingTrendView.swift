// Sources/Alcancia/SpendingTrendView.swift
import SwiftUI
import Charts
import AlcanciaCore

/// Barras de gasto de los últimos 6 meses, con el mes en curso resaltado.
/// Vive debajo del desglose por categoría, dentro de un popover de 360×560 —
/// compacta a propósito: es para ver la forma del gasto, no para leer cifras
/// exactas encima de cada barra.
struct SpendingTrendView: View {
    let trend: SpendingTrend

    private static let chartHeight: CGFloat = 90

    /// Formato de mes independiente ("stand-alone"), no el que usaría una
    /// oración ("de agosto"). En es_MX eso da "ago", "sep" en vez de
    /// capitalizaciones o preposiciones inesperadas.
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.setLocalizedDateFormatFromTemplate("LLL")
        return formatter
    }()

    private var hasAnySpending: Bool {
        trend.series.contains { $0.totalMXN > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Últimos 6 meses")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if hasAnySpending {
                chart
            } else {
                Text("Aún no hay suficiente historial")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: Self.chartHeight, alignment: .center)
            }
        }
    }

    private var chart: some View {
        Chart(trend.series) { monthSpending in
            BarMark(
                x: .value("Mes", monthSpending.month, unit: .month),
                y: .value("Gasto", doubleValue(monthSpending.totalMXN))
            )
            .foregroundStyle(
                monthSpending.isCurrent
                    ? Color.accentColor
                    : Color.secondary.opacity(0.35)
            )
            .cornerRadius(3)
        }
        .frame(height: Self.chartHeight)
        .chartXAxis {
            AxisMarks(values: trend.series.map(\.month)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel(Self.monthFormatter.string(from: date))
                        .font(.caption2)
                }
            }
        }
        .chartYAxis(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gasto de los últimos seis meses")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        trend.series.map { month in
            let name = Self.monthFormatter.string(from: month.month)
            let amount = NumberFormatter.localizedString(
                from: month.totalMXN as NSDecimalNumber,
                number: .currency
            )
            return "\(name): \(amount)"
        }.joined(separator: ", ")
    }

    private func doubleValue(_ decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }
}
