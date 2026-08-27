// Sources/Alcancia/SettingsView.swift
import SwiftUI
import AlcanciaCore

struct SettingsView: View {
    @ObservedObject var store: AlcanciaStore
    @ObservedObject private var hotKeyManager = HotKeyManager.shared
    let month: Date
    /// Se cierra volviendo a la vista principal dentro del mismo panel, no
    /// descartando una hoja: en la barra de menú no puede haber otra ventana.
    let onClose: () -> Void

    @State private var budgetText: String = ""
    @State private var balanceText: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var showsDesktopPanel: Bool = false
    @State private var showsBalance: Bool = false
    @State private var loginItemError: String?
    @State private var hotKeyShortcut: HotKeyShortcut = .saved
    @State private var dataMessage: String?
    @State private var confirmingReset = false

    @State private var newRecurringName: String = ""
    @State private var newRecurringAmountText: String = ""
    @State private var newRecurringCategory: ExpenseCategory = .otro
    @State private var newRecurringIsBusiness = false
    @State private var pendingDeleteRecurringID: UUID?

    var body: some View {
        // Con las suscripciones el contenido ya no cabe en 360×560; sin el
        // `ScrollView` la parte de abajo (borrar historial, Cerrar) se corta.
        ScrollView {
            settingsContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: seedState)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ajustes").font(.headline)

            if store.status != .healthy {
                recoverySection
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Saldo total actual (MXN)").font(.subheadline)
                HStack {
                    TextField("ej. 1500", text: $balanceText)
                        .textFieldStyle(.roundedBorder)
                    Button("Ajustar", action: saveBalance)
                }
                Text("Crea un ajuste fechado hoy; no reescribe los meses anteriores.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Presupuesto mensual (MXN)").font(.subheadline)
                HStack {
                    TextField("ej. 8000", text: $budgetText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(saveBudget)
                    Button("Guardar", action: saveBudget)
                    if store.budget(for: month) != nil {
                        Button("Quitar") {
                            _ = store.setBudget(nil, for: month)
                            budgetText = ""
                        }
                        .foregroundStyle(.red)
                    }
                }
                Text("El cerdito de la barra arranca lleno cada mes y se vacía conforme gastas.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Mostrar mi saldo en vez de lo gastado", isOn: $showsBalance)
                    .onChange(of: showsBalance) { _, newValue in
                        store.setShowsBalance(newValue)
                    }
                Text("El número grande pasa a ser tu dinero real: todos tus ingresos menos todos tus gastos.")
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

            Toggle("Iniciar con el sistema", isOn: launchAtLoginBinding)

            if let loginItemError {
                Text(loginItemError).font(.caption).foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 6) {
                Picker("Atajo de captura", selection: $hotKeyShortcut) {
                    ForEach(HotKeyShortcut.allCases) { shortcut in
                        Text(shortcut.label).tag(shortcut)
                    }
                }
                .onChange(of: hotKeyShortcut) { _, shortcut in
                    _ = hotKeyManager.register(shortcut: shortcut)
                }

                if let error = hotKeyManager.registrationError {
                    Text(error).font(.caption).foregroundStyle(.red)
                } else {
                    Text("Abre la captura rápida desde cualquier app.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            exportSection

            Divider()

            recurringSection

            Divider()

            if confirmingReset {
                VStack(alignment: .leading, spacing: 8) {
                    Text("¿Borrar todo el historial? Esta acción no se puede deshacer.")
                        .font(.caption)
                        .foregroundStyle(.red)
                    HStack {
                        Button("Cancelar") {
                            confirmingReset = false
                        }
                        .buttonStyle(.bordered)

                        Button("Borrar todo") {
                            switch store.resetAllEntries() {
                            case .success:
                                confirmingReset = false
                                dataMessage = "Historial borrado."
                            case .failure:
                                dataMessage = "No se pudo borrar el historial. Tus datos no se modificaron."
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            } else {
                Button("Borrar todo el historial", role: .destructive) {
                    confirmingReset = true
                }
            }

            Button("Cerrar") { onClose() }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func seedState() {
        if let budget = store.budget(for: month) { budgetText = "\(budget)" }
        balanceText = "\(store.balanceMXN)"
        showsDesktopPanel = store.data.showsDesktopPanel
        showsBalance = store.data.showsBalance
        hotKeyShortcut = .saved
        // Sembramos el interruptor con el estado real del sistema, no la
        // preferencia guardada, para que no pueda mentir si el registro
        // había fallado en una sesión anterior.
        let actual = LoginItemManager.isEnabled
        launchAtLogin = actual
        if store.data.launchAtLogin != actual {
            store.setLaunchAtLogin(actual)
        }
    }

    // MARK: - Suscripciones

    /// Se configuran rara vez: sección compacta, sin animaciones de más.
    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suscripciones").font(.subheadline)

            if store.data.recurringExpenses.isEmpty {
                Text("Sin recurrentes configuradas todavía.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.data.recurringExpenses) { recurring in
                    recurringRow(for: recurring)
                }
            }

            addRecurringRow
        }
    }

    /// Mismo patrón que `HistoryView.deleteConfirmation`: la confirmación
    /// reemplaza la fila en el sitio, nunca un diálogo aparte.
    private func recurringRow(for recurring: RecurringExpense) -> some View {
        Group {
            if pendingDeleteRecurringID == recurring.id {
                HStack(spacing: 8) {
                    Text("¿Borrar \(recurring.name)?")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    Button("Cancelar") {
                        pendingDeleteRecurringID = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Borrar") {
                        store.deleteRecurringExpense(id: recurring.id)
                        pendingDeleteRecurringID = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.red)
                }
            } else {
                HStack(spacing: 8) {
                    Text(recurring.category.emoji)
                    Text(recurring.name)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(store.formattedAmount(recurring.amountMXN))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button {
                        pendingDeleteRecurringID = recurring.id
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var addRecurringRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Nombre (ej. Adobe CC)", text: $newRecurringName)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                TextField("Monto", text: $newRecurringAmountText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(width: 70)
            }

            CategoryRowView(selection: $newRecurringCategory)

            HStack {
                Toggle(isOn: $newRecurringIsBusiness) {
                    Text("Negocio").font(.caption2)
                }
                .toggleStyle(.button)
                .controlSize(.small)

                Spacer()

                Button("Agregar", action: addRecurring)
                    .disabled(!canAddRecurring)
            }
        }
    }

    private var canAddRecurring: Bool {
        guard !newRecurringName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard MoneyParser.parse(newRecurringAmountText) != nil else { return false }
        return true
    }

    private func addRecurring() {
        guard canAddRecurring,
              let amount = MoneyParser.parse(newRecurringAmountText) else { return }
        let result = store.addRecurringExpense(
            name: newRecurringName.trimmingCharacters(in: .whitespacesAndNewlines),
            amountMXN: amount,
            category: newRecurringCategory,
            isBusiness: newRecurringIsBusiness
        )
        switch result {
        case .success:
            newRecurringName = ""
            newRecurringAmountText = ""
            newRecurringCategory = .otro
            newRecurringIsBusiness = false
            dataMessage = "Suscripción agregada."
        case .failure:
            dataMessage = "No se pudo guardar la suscripción. Tus datos no se modificaron."
        }
    }

    /// El interruptor se maneja con un Binding en vez de @State + .onChange: el
    /// setter no puede reentrar a sí mismo, así que el mensaje de error sobrevive
    /// a la corrección del valor. Con .onChange, reasignar el valor volvía a
    /// disparar el manejador y la segunda pasada borraba el error.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { requested in
                if LoginItemManager.setEnabled(requested) {
                    launchAtLogin = requested
                    store.setLaunchAtLogin(requested)
                    loginItemError = nil
                } else {
                    // No escribimos lo que pidió el usuario: el interruptor se
                    // queda donde de verdad está el sistema.
                    let actual = LoginItemManager.isEnabled
                    launchAtLogin = actual
                    store.setLaunchAtLogin(actual)
                    loginItemError = "No se pudo cambiar el inicio automático. Revisa Ajustes del Sistema > Elementos de inicio."
                }
            }
        )
    }

    private func saveBudget() {
        guard let value = MoneyParser.parse(budgetText) else { return }
        if case .failure = store.setBudget(value, for: month) {
            dataMessage = "No se pudo guardar el presupuesto."
        } else {
            dataMessage = "Presupuesto guardado para este mes."
        }
    }

    private func saveBalance() {
        guard let value = MoneyParser.parseBalance(balanceText) else { return }
        if case .failure = store.setBalance(value, note: "Ajuste manual") {
            dataMessage = "No se pudo ajustar el saldo."
        } else {
            balanceText = "\(store.balanceMXN)"
            dataMessage = "Saldo ajustado desde hoy."
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exportar").font(.subheadline)
            HStack {
                exportButton("CSV", format: .csv)
                exportButton("JSON", format: .json)
                exportButton("Excel", format: .xlsx)
            }
            if let dataMessage {
                Text(dataMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func exportButton(_ title: String, format: DataExportFormat) -> some View {
        Button(title) {
            switch ExportController.export(data: store.data, format: format) {
            case .success(let url): dataMessage = "Exportado: \(url.lastPathComponent)"
            case .failure(let error) where error is CancellationError: break
            case .failure: dataMessage = "No se pudo exportar el archivo."
            }
        }
        .buttonStyle(.bordered)
    }

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.status == .recoveredFromBackup
                 ? "Se cargó un respaldo porque el archivo principal no era legible."
                 : "El archivo de datos no se pudo leer. Alcancía evitó reemplazarlo.")
                .font(.caption)
                .foregroundStyle(.orange)
            Button("Recuperar último respaldo") {
                if case .success = store.restoreLatestBackup() {
                    dataMessage = "Respaldo recuperado."
                } else {
                    dataMessage = "No hay un respaldo recuperable."
                }
            }
            .disabled(store.status == .recoveredFromBackup)
        }
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
