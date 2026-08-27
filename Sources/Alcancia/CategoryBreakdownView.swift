// Sources/Alcancia/CategoryBreakdownView.swift
import SwiftUI
import AlcanciaCore

/// En qué se fue el dinero del mes, de mayor a menor, con la tendencia de los
/// últimos 6 meses debajo — "en qué" y "cómo ha ido" en la misma pestaña.
struct CategoryBreakdownView: View {
    @ObservedObject var store: AlcanciaStore
    let summary: MonthlySummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if summary.byCategory.isEmpty {
                    Text("Sin gastos este mes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(summary.byCategory.enumerated()), id: \.element.id) { index, total in
                            CategoryBarRow(
                                total: total,
                                index: index,
                                formattedAmount: store.formattedAmount(total.amountMXN)
                            )
                        }
                    }
                }

                Divider()

                SpendingTrendView(trend: store.spendingTrend(endingAt: summary.month))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

/// Una fila del desglose: emoji, categoría, monto y una barra que crece con
/// resorte al aparecer. El `index` escalona el arranque de cada fila para que
/// la lista se sienta como una cascada corta, no como un golpe simultáneo.
private struct CategoryBarRow: View {
    let total: CategoryTotal
    let index: Int
    let formattedAmount: String

    /// Controla el ancho de la barra: arranca en 0 y crece al aparecer.
    @State private var grown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(total.category.emoji)
                Text(total.category.label)
                    .font(.caption)
                Spacer()
                Text(formattedAmount)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 1), value: formattedAmount)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor)
                        .frame(width: grown ? max(2, geometry.size.width * total.fractionOfTotal) : 0)
                }
            }
            .frame(height: 6)
        }
        .onAppear {
            // Resorte sin rebote (dampingFraction 1): el dinero se toma en
            // serio incluso cuando se mueve. El escalonamiento por índice
            // mantiene la cascada completa por debajo de ~400ms.
            withAnimation(
                .spring(response: 0.32, dampingFraction: 1)
                    .delay(Double(index) * 0.035)
            ) {
                grown = true
            }
        }
    }
}
