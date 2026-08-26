// Sources/Alcancia/QuickAddView.swift
import SwiftUI
import AlcanciaCore

/// Captura rápida. La regla que manda: escribir el monto y dar Enter tiene que
/// bastar. Todo lo demás (categoría, concepto, moneda, tipo de movimiento) son
/// ajustes opcionales que arrancan en el valor más probable.
struct QuickAddView: View {
    @ObservedObject var store: AlcanciaStore

    @FocusState private var amountFocused: Bool

    @State private var amountText: String = ""
    @State private var noteText: String = ""
    @State private var kind: EntryKind = .expense
    @State private var currency: Currency = .mxn
    @State private var category: ExpenseCategory = .otro
    @State private var isResolvingRate = false
    @State private var needsManualRate = false
    @State private var manualRateText: String = ""
    @State private var errorMessage: String?
    @State private var noticeMessage: String?

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }

    private var parsedManualRate: Double? {
        Double(manualRateText.replacingOccurrences(of: ",", with: ""))
    }

    private var canSubmit: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        if isResolvingRate { return false }
        if needsManualRate {
            guard let rate = parsedManualRate, rate > 0 else { return false }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("¿Cuánto?", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .focused($amountFocused)
                    .onSubmit(submit)

                Picker("Moneda", selection: $currency) {
                    Text("MXN").tag(Currency.mxn)
                    Text("USD").tag(Currency.usd)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 96)
                .onChange(of: currency) { _, _ in
                    needsManualRate = false
                    errorMessage = nil
                    noticeMessage = nil
                }

                Button(action: submit) {
                    if isResolvingRate {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "return")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .help("Agregar")
            }

            HStack(spacing: 8) {
                TextField("Concepto (opcional)", text: $noteText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit(submit)

                Picker("Tipo", selection: $kind) {
                    Text("Gasto").tag(EntryKind.expense)
                    Text("Ingreso").tag(EntryKind.income)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 130)
            }

            if kind == .expense {
                CategoryRowView(selection: $category)
            }

            if needsManualRate {
                HStack(spacing: 8) {
                    Text("Tipo de cambio USD→MXN:").font(.caption)
                    TextField("ej. 18.50", text: $manualRateText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onSubmit(submit)
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            if let noticeMessage {
                Text(noticeMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onAppear {
            category = store.data.lastUsedCategory ?? .otro
            // El foco es la pieza que hace que capturar tome tres segundos.
            amountFocused = true
        }
    }

    private func submit() {
        guard canSubmit else { return }
        Task { await addEntry() }
    }

    @MainActor
    private func addEntry() async {
        guard let amount = parsedAmount, amount > 0 else { return }
        errorMessage = nil
        noticeMessage = nil

        if currency == .mxn {
            commit(amount: amount, rate: nil)
            return
        }

        if needsManualRate {
            guard let rate = parsedManualRate, rate > 0 else { return }
            store.recordExchangeRate(rate)
            commit(amount: amount, rate: rate)
            manualRateText = ""
            needsManualRate = false
            return
        }

        isResolvingRate = true
        let service = ExchangeRateService()
        let result = await service.resolveRate(
            cachedRate: store.data.lastKnownUSDMXNRate,
            cachedDate: store.data.lastKnownRateDate
        )
        isResolvingRate = false

        guard let result else {
            needsManualRate = true
            errorMessage = "Sin conexión y sin tipo de cambio previo. Escribe el tipo de cambio para continuar."
            return
        }

        if result.isFromCache {
            noticeMessage = "Tipo de cambio del \(Self.dateFormatter.string(from: result.asOf)), sin conexión."
        } else {
            store.recordExchangeRate(result.rate, date: result.asOf)
        }
        commit(amount: amount, rate: result.rate)
    }

    private func commit(amount: Decimal, rate: Double?) {
        store.addEntry(
            amount: amount,
            currency: currency,
            kind: kind,
            category: kind == .expense ? category : nil,
            note: noteText,
            exchangeRate: rate
        )
        amountText = ""
        noteText = ""
        // Listo para el siguiente sin tocar el mouse.
        amountFocused = true
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
}
