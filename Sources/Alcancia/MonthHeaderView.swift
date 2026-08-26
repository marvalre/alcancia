// Sources/Alcancia/MonthHeaderView.swift
import SwiftUI
import AlcanciaCore

/// Navegación entre meses y el estado del presupuesto: el primer vistazo al
/// abrir la app.
struct MonthHeaderView: View {
    @ObservedObject var store: AlcanciaStore
    @Binding var month: Date

    private var summary: MonthlySummary { store.summary(for: month) }
    private var progress: BudgetProgress { store.budgetProgress(for: month) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(Self.monthFormatter.string(from: month).capitalized)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(isShowingCurrentMonth)
            }

            Text(store.formattedAmount(summary.totalSpentMXN))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(progress.isOverBudget ? Color.red : Color.primary)

            if let budget = store.data.monthlyBudgetMXN, budget > 0 {
                ProgressView(value: 1 - (progress.fractionRemaining ?? 0))
                    .tint(progress.isOverBudget ? .red : .accentColor)
                Text(budgetCaption(budget: budget))
                    .font(.caption)
                    .foregroundStyle(progress.isOverBudget ? Color.red : Color.secondary)
            } else {
                Text("Gastado este mes · sin presupuesto definido")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if summary.totalIncomeMXN > 0 {
                Text("Ingresos del mes: \(store.formattedAmount(summary.totalIncomeMXN))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func budgetCaption(budget: Decimal) -> String {
        if progress.isOverBudget, let remaining = progress.remainingMXN {
            return "Te pasaste por \(store.formattedAmount(-remaining))"
        }
        if let remaining = progress.remainingMXN {
            return "de \(store.formattedAmount(budget)) · te quedan \(store.formattedAmount(remaining))"
        }
        return "de \(store.formattedAmount(budget))"
    }

    private var isShowingCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private func shiftMonth(by delta: Int) {
        if let shifted = Calendar.current.date(byAdding: .month, value: delta, to: month) {
            month = shifted
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}
