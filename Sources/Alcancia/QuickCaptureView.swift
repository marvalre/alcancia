// Sources/Alcancia/QuickCaptureView.swift
import SwiftUI
import AlcanciaCore

/// Captura mínima para el atajo global. No es una copia de `QuickAddView`:
/// es la versión pelada. Sólo MXN, sólo gasto — el atajo es para el caso
/// común; cualquier otra cosa (USD, ingresos) pasa por el panel completo de
/// la barra de menú.
struct QuickCaptureView: View {
    @ObservedObject var store: AlcanciaStore
    var onFinished: () -> Void

    @FocusState private var amountFocused: Bool

    @State private var amountText: String = ""
    @State private var noteText: String = ""
    @State private var category: ExpenseCategory = .otro
    @State private var errorMessage: String?

    private var parsedAmount: Decimal? {
        MoneyParser.parse(amountText)
    }

    private var canSubmit: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        return true
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                TextField("¿Cuánto?", text: $amountText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .focused($amountFocused)
                    .onSubmit(submit)

                CategoryRowView(selection: $category)

                TextField("Concepto (opcional)", text: $noteText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit(submit)

                if let errorMessage {
                    Text(errorMessage).font(.caption2).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(width: 360, height: 150, alignment: .topLeading)

            // Botón invisible: Escape cierra sin guardar, sin robarle el
            // primer responder al campo de monto.
            Button("", action: onFinished)
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .frame(width: 360, height: 150)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onAppear {
            category = store.data.lastUsedCategory ?? .otro
            // El foco es lo que hace que esto tome tres segundos.
            amountFocused = true
        }
    }

    private func submit() {
        guard canSubmit, let amount = parsedAmount else { return }
        switch store.addEntryResult(amount: amount, currency: .mxn, category: category, note: noteText) {
        case .success: onFinished()
        case .failure: errorMessage = "No se pudo guardar. Abre Ajustes para recuperar tus datos."
        }
    }
}
