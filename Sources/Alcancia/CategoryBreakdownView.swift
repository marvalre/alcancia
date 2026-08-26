// Sources/Alcancia/CategoryBreakdownView.swift
import SwiftUI
import AlcanciaCore

/// En qué se fue el dinero del mes, de mayor a menor.
struct CategoryBreakdownView: View {
    @ObservedObject var store: AlcanciaStore
    let summary: MonthlySummary

    var body: some View {
        if summary.byCategory.isEmpty {
            VStack {
                Spacer()
                Text("Sin gastos este mes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(summary.byCategory) { total in
                        row(for: total)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    private func row(for total: CategoryTotal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(total.category.emoji)
                Text(total.category.label)
                    .font(.caption)
                Spacer()
                Text(store.formattedAmount(total.amountMXN))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor)
                        .frame(width: max(2, geometry.size.width * total.fractionOfTotal))
                }
            }
            .frame(height: 6)
        }
    }
}
