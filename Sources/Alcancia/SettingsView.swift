// Sources/Alcancia/SettingsView.swift
import SwiftUI
import AlcanciaCore

struct SettingsView: View {
    @ObservedObject var store: AlcanciaStore
    @Environment(\.dismiss) private var dismiss

    @State private var budgetText: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var showsDesktopPanel: Bool = false
    @State private var loginItemError: String?
    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ajustes").font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Presupuesto mensual (MXN)").font(.subheadline)
                HStack {
                    TextField("ej. 8000", text: $budgetText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(saveBudget)
                    Button("Guardar", action: saveBudget)
                    if store.data.monthlyBudgetMXN != nil {
                        Button("Quitar") {
                            store.setMonthlyBudget(nil)
                            budgetText = ""
                        }
                        .foregroundStyle(.red)
                    }
                }
                Text("El cerdito de la barra arranca lleno cada mes y se vacía conforme gastas.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let rate = store.data.lastKnownUSDMXNRate {
                Text(exchangeRateText(rate: rate, date: store.data.lastKnownRateDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Mostrar panel en el escritorio", isOn: $showsDesktopPanel)
                .onChange(of: showsDesktopPanel) { _, newValue in
                    store.setShowsDesktopPanel(newValue)
                }

            Toggle("Iniciar con el sistema", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    let succeeded = LoginItemManager.setEnabled(newValue)
                    if succeeded {
                        store.setLaunchAtLogin(newValue)
                        loginItemError = nil
                    } else {
                        loginItemError = "No se pudo cambiar el inicio automático. Revisa Ajustes del Sistema > Elementos de inicio."
                        syncLaunchAtLoginFromSystem()
                    }
                }

            if let loginItemError {
                Text(loginItemError).font(.caption).foregroundStyle(.red)
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
        .frame(width: 320, height: 430)
        .onAppear {
            if let budget = store.data.monthlyBudgetMXN {
                budgetText = "\(budget)"
            }
            showsDesktopPanel = store.data.showsDesktopPanel
            syncLaunchAtLoginFromSystem()
        }
    }

    /// El interruptor refleja el estado real del sistema, no la preferencia
    /// guardada, para que no pueda mentir si el registro falló.
    private func syncLaunchAtLoginFromSystem() {
        let actual = LoginItemManager.isEnabled
        if launchAtLogin != actual {
            launchAtLogin = actual
        }
        if store.data.launchAtLogin != actual {
            store.setLaunchAtLogin(actual)
        }
    }

    private func saveBudget() {
        guard let value = Decimal(string: budgetText.replacingOccurrences(of: ",", with: "")),
              value > 0 else { return }
        store.setMonthlyBudget(value)
    }

    private func exchangeRateText(rate: Double, date: Date?) -> String {
        let text = String(format: "Tipo de cambio guardado: %.2f MXN por USD", rate)
        guard let date else { return text }
        return text + " (\(Self.dateFormatter.string(from: date)))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
}
