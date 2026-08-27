import SwiftUI
import AlcanciaCore

struct OnboardingView: View {
    @ObservedObject var store: AlcanciaStore
    let onFinish: () -> Void
    let onDefer: () -> Void

    @State private var balanceText = ""
    @State private var budgetText = ""
    @State private var errorMessage: String?

    private var parsedBalance: Decimal? { MoneyParser.parseBalance(balanceText) }
    private var parsedBudget: Decimal? { budgetText.isEmpty ? nil : MoneyParser.parse(budgetText) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()

            Image(systemName: "banknote.fill")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("¿Con cuánto empiezas hoy?")
                .font(.title2.bold())

            Text("Este saldo será la base. Los cierres de cada mes pasan automáticamente al siguiente y podrás corregir el total cuando lo necesites.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Saldo actual (MXN)").font(.subheadline.weight(.medium))
                TextField("ej. 1500", text: $balanceText)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.monospacedDigit())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Presupuesto de este mes (opcional)").font(.subheadline.weight(.medium))
                TextField("ej. 8000", text: $budgetText)
                    .textFieldStyle(.roundedBorder)
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            Button("Empezar", action: save)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(parsedBalance == nil || (!budgetText.isEmpty && parsedBudget == nil))

            Button("Configurar después", action: onDefer)
                .buttonStyle(.link)
                .foregroundStyle(.secondary)

            Text("Atajo de captura: \(HotKeyShortcut.saved.label)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
    }

    private func save() {
        guard let balance = parsedBalance else { return }
        switch store.completeOnboarding(balance: balance, budget: parsedBudget) {
        case .failure:
            errorMessage = "No se pudo guardar la configuración. Tus datos anteriores no se modificaron."
        case .success:
            onFinish()
        }
    }
}
