// Sources/Alcancia/DesktopPanelView.swift
import SwiftUI
import AlcanciaCore

/// Lo que se ve en el panel flotante: el cerdito y lo que queda del mes.
struct DesktopPanelView: View {
    @ObservedObject var store: AlcanciaStore

    private var progress: BudgetProgress { store.budgetProgress(for: Date()) }
    private var summary: MonthlySummary { store.summary(for: Date()) }

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: PiggyBankIcon.image(
                progress: progress.fractionRemaining,
                accessibilityDescription: "",
                height: 34
            ))
            .renderingMode(.template)
            .foregroundStyle(progress.isOverBudget ? Color.red : Color.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.formattedAmount(summary.totalSpentMXN))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(progress.isOverBudget ? Color.red : Color.primary)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var caption: String {
        guard let budget = store.data.monthlyBudgetMXN, budget > 0 else {
            return "gastado este mes"
        }
        if progress.isOverBudget, let remaining = progress.remainingMXN {
            return "te pasaste por \(store.formattedAmount(-remaining))"
        }
        if let remaining = progress.remainingMXN {
            return "te quedan \(store.formattedAmount(remaining))"
        }
        return "gastado este mes"
    }
}
