import SwiftUI
import AlcanciaCore

struct SettingsView: View {
    @ObservedObject var store: AlcanciaStore
    @Environment(\.dismiss) private var dismiss

    @State private var goalText: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var showingResetConfirmation = false
    @State private var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ajustes")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Meta (MXN)")
                    .font(.subheadline)
                HStack {
                    TextField("ej. 10000", text: $goalText)
                        .textFieldStyle(.roundedBorder)
                    Button("Guardar") {
                        saveGoal()
                    }
                    if store.data.goalMXN != nil {
                        Button("Quitar meta") {
                            store.setGoal(nil)
                            goalText = ""
                        }
                        .foregroundStyle(.red)
                    }
                }
            }

            if let rate = store.data.lastKnownUSDMXNRate {
                Text(exchangeRateText(rate: rate, date: store.data.lastKnownRateDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Iniciar con el sistema", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    let succeeded = LoginItemManager.setEnabled(newValue)
                    if succeeded {
                        store.setLaunchAtLogin(newValue)
                        loginItemError = nil
                    } else {
                        launchAtLogin = LoginItemManager.isEnabled
                        store.setLaunchAtLogin(launchAtLogin)
                        loginItemError = "No se pudo cambiar el inicio automático. Revisa Ajustes del Sistema > Elementos de inicio."
                    }
                }

            if let loginItemError {
                Text(loginItemError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Button("Borrar todo el historial", role: .destructive) {
                showingResetConfirmation = true
            }
            .confirmationDialog(
                "¿Borrar todo el historial? Esta acción no se puede deshacer.",
                isPresented: $showingResetConfirmation
            ) {
                Button("Borrar todo", role: .destructive) {
                    store.resetAllEntries()
                }
                Button("Cancelar", role: .cancel) {}
            }

            Spacer()

            Button("Cerrar") { dismiss() }
        }
        .padding(20)
        .frame(width: 300, height: 380)
        .onAppear {
            if let goal = store.data.goalMXN {
                goalText = "\(goal)"
            }
            launchAtLogin = LoginItemManager.isEnabled
            if launchAtLogin != store.data.launchAtLogin {
                store.setLaunchAtLogin(launchAtLogin)
            }
        }
    }

    private func saveGoal() {
        guard let value = Decimal(string: goalText.replacingOccurrences(of: ",", with: "")),
              value > 0 else { return }
        store.setGoal(value)
    }

    private func exchangeRateText(rate: Double, date: Date?) -> String {
        let rateText = String(format: "Tipo de cambio guardado: %.2f MXN por USD", rate)
        guard let date else { return rateText }
        return rateText + " (\(Self.dateFormatter.string(from: date)))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
}
