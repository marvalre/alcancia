// Sources/Alcancia/DesktopPanelView.swift
import AppKit
import SwiftUI
import AlcanciaCore

/// Lo que se ve en el panel flotante. Es la alternativa viable a un widget de
/// WidgetKit real (que necesitaría un App Group y por lo tanto una cuenta de
/// desarrollador de Apple), así que tiene que sentirse como uno: de un
/// vistazo, sin ruido, y con lo más accionable — cuánto queda por gastar —
/// por delante de lo histórico.
///
/// Todo el panel es un botón: un clic abre la captura rápida, para que viva
/// en el escritorio como un acceso directo permanente a "agregar gasto".
struct DesktopPanelView: View {
    @ObservedObject var store: AlcanciaStore
    var onActivate: () -> Void = {}

    private var progress: BudgetProgress { store.budgetProgress(for: Date()) }
    private var summary: MonthlySummary { store.summary(for: Date()) }

    private var hasBudget: Bool {
        guard let budget = store.data.monthlyBudgetMXN else { return false }
        return budget > 0
    }

    /// Días que quedan del mes en curso, contando hoy.
    private var remainingDays: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard
            let range = calendar.range(of: .day, in: .month, for: today),
            let lastDayOfMonth = calendar.date(bySetting: .day, value: range.count, of: today)
        else {
            return 1
        }
        let days = calendar.dateComponents([.day], from: today, to: lastDayOfMonth).day ?? 0
        return days + 1
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(nsImage: PiggyBankIcon.image(
                progress: progress.fractionRemaining,
                accessibilityDescription: "",
                height: 40
            ))
            .renderingMode(.template)
            .foregroundStyle(progress.isOverBudget ? Color.red : Color.primary)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(headline)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(headlineColor)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subcaption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if hasBudget {
                    ProgressView(value: progress.fractionRemaining ?? 0)
                        .progressViewStyle(.linear)
                        .tint(progress.isOverBudget ? .red : .accentColor)

                    if let allowanceLine {
                        Text(allowanceLine)
                            .font(.caption2)
                            .foregroundStyle(progress.isOverBudget ? Color.red : .secondary)
                            .contentTransition(.numericText())
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 240, height: 110, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: onActivate)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(.default, value: summary.totalSpentMXN)
        .animation(.default, value: store.balanceMXN)
    }

    /// El número grande: lo que queda, no lo que ya se gastó. Sin
    /// presupuesto no hay nada accionable que liderar, así que cae al total
    /// gastado. Con el saldo activado, esto se reemplaza por el dinero real
    /// del usuario — ingresos menos gastos, de todo el tiempo.
    private var headline: String {
        if store.data.showsBalance { return store.formattedAmount(store.balanceMXN) }
        guard hasBudget else { return store.formattedAmount(summary.totalSpentMXN) }
        if progress.isOverBudget, let remaining = progress.remainingMXN {
            return store.formattedAmount(-remaining)
        }
        if let remaining = progress.remainingMXN {
            return store.formattedAmount(remaining)
        }
        return store.formattedAmount(summary.totalSpentMXN)
    }

    private var headlineColor: Color {
        if store.data.showsBalance { return store.balanceMXN < 0 ? .red : .primary }
        guard hasBudget else { return .primary }
        return progress.isOverBudget ? .red : .primary
    }

    /// El gasto queda relegado a subtítulo: es historia, no la decisión de
    /// hoy. Con el saldo activado, el subtítulo aclara qué es el número
    /// grande y qué se gastó este mes en concreto.
    private var subcaption: String {
        if store.data.showsBalance {
            return "tu saldo · gastado este mes: \(store.formattedAmount(summary.totalSpentMXN))"
        }
        guard hasBudget else { return "sin presupuesto este mes" }
        if progress.isOverBudget {
            return "te pasaste · gastaste \(store.formattedAmount(summary.totalSpentMXN))"
        }
        return "quedan de \(store.formattedAmount(summary.totalSpentMXN)) gastados"
    }

    /// "$145 al día · quedan 22 días". `nil` cuando no hay presupuesto o
    /// cuando ya no quedan días del mes — en over budget cae al texto del
    /// exceso en vez de desaparecer sin más.
    private var allowanceLine: String? {
        if let allowance = progress.dailyAllowance(remainingDays: remainingDays) {
            let days = remainingDays == 1 ? "1 día" : "\(remainingDays) días"
            return "\(store.formattedAmount(allowance)) al día · quedan \(days)"
        }
        if progress.isOverBudget, let remaining = progress.remainingMXN {
            return "te pasaste por \(store.formattedAmount(-remaining))"
        }
        return nil
    }
}
