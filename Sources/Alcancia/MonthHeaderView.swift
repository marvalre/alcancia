// Sources/Alcancia/MonthHeaderView.swift
import SwiftUI
import AlcanciaCore

/// Navegación entre meses y el estado del presupuesto: el primer vistazo al
/// abrir la app.
struct MonthHeaderView: View {
    @ObservedObject var store: AlcanciaStore
    @Binding var month: Date
    /// Cierre, no un binding a la bandera cruda: el encabezado no necesita
    /// saber cómo se representa "mostrando Ajustes" en `MenuBarView`, sólo
    /// pedir que se abra.
    let onOpenSettings: () -> Void

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

            Text(headlineAmount)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(headlineColor)
                .contentTransition(.numericText())
                .animation(.default, value: store.data.showsBalance)
                .animation(.default, value: summary.totalSpentMXN)
                .animation(.default, value: store.balanceMXN)

            if store.data.showsBalance {
                Text("tu saldo · gastado este mes: \(store.formattedAmount(summary.totalSpentMXN))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let budget = store.data.monthlyBudgetMXN, budget > 0 {
                ProgressView(value: 1 - (progress.fractionRemaining ?? 0))
                    .tint(progress.isOverBudget ? .red : .accentColor)
                Text(budgetCaption(budget: budget))
                    .font(.caption)
                    .foregroundStyle(progress.isOverBudget ? Color.red : Color.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Define tu presupuesto mensual para que el cerdito funcione")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Definir", action: onOpenSettings)
                        .buttonStyle(.link)
                        .controlSize(.small)
                }
            }

            if summary.totalIncomeMXN > 0 {
                Text("Ingresos del mes: \(store.formattedAmount(summary.totalIncomeMXN))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if summary.totalBusinessMXN > 0 {
                Text("de negocio: \(store.formattedAmount(summary.totalBusinessMXN))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// El número grande: lo gastado este mes, o — con el saldo activado en
    /// Ajustes — el dinero real del usuario, ingresos menos gastos de todo
    /// el tiempo. Sigue siendo una lectura alterna opcional, no un
    /// reemplazo: por defecto muestra lo gastado, como siempre.
    private var headlineAmount: String {
        store.data.showsBalance
            ? store.formattedAmount(store.balanceMXN)
            : store.formattedAmount(summary.totalSpentMXN)
    }

    private var headlineColor: Color {
        if store.data.showsBalance {
            return store.balanceMXN < 0 ? .red : .primary
        }
        return progress.isOverBudget ? .red : .primary
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
