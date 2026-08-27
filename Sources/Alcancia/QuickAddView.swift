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
    @State private var isBusiness = false
    @State private var isResolvingRate = false
    @State private var needsManualRate = false
    @State private var manualRateText: String = ""
    @State private var errorMessage: String?
    @State private var noticeMessage: String?

    private var parsedAmount: Decimal? {
        MoneyParser.parse(amountText)
    }

    private var parsedManualRate: Double? {
        MoneyParser.parse(manualRateText).map { NSDecimalNumber(decimal: $0).doubleValue }
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
                .accessibilityLabel("Agregar movimiento")
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

                // Sólo tiene sentido para gastos: un ingreso no es "de negocio".
                if kind == .expense {
                    Toggle(isOn: $isBusiness) {
                        Text("Negocio").font(.caption2)
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                }
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
        .disabled(isResolvingRate)
        .onAppear {
            category = store.data.lastUsedCategory ?? .otro
            isBusiness = store.data.lastUsedIsBusiness
            // El foco es la pieza que hace que capturar tome tres segundos.
            amountFocused = true
        }
    }

    private func submit() {
        guard canSubmit else { return }
        let submission = Submission(
            amount: parsedAmount!,
            currency: currency,
            kind: kind,
            category: category,
            note: noteText,
            isBusiness: isBusiness,
            manualRate: needsManualRate ? parsedManualRate : nil
        )
        if currency == .usd && !needsManualRate { isResolvingRate = true }
        Task { await addEntry(submission) }
    }

    @MainActor
    private func addEntry(_ submission: Submission) async {
        errorMessage = nil
        noticeMessage = nil

        if submission.currency == .mxn {
            commit(submission, rate: nil)
            return
        }

        if let rate = submission.manualRate {
            store.recordExchangeRate(rate)
            commit(submission, rate: rate)
            manualRateText = ""
            needsManualRate = false
            return
        }

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
        commit(submission, rate: result.rate)
    }

    private func commit(_ submission: Submission, rate: Double?) {
        let result = store.addEntryResult(
            amount: submission.amount,
            currency: submission.currency,
            kind: submission.kind,
            category: submission.kind == .expense ? submission.category : nil,
            note: submission.note,
            exchangeRate: rate,
            isBusiness: submission.isBusiness
        )
        guard case .success = result else {
            errorMessage = "No se pudo guardar el movimiento. Revisa el archivo de datos en Ajustes."
            return
        }
        amountText = ""
        noteText = ""
        // Listo para el siguiente sin tocar el mouse.
        amountFocused = true
    }

    private struct Submission {
        let amount: Decimal
        let currency: Currency
        let kind: EntryKind
        let category: ExpenseCategory
        let note: String
        let isBusiness: Bool
        let manualRate: Double?
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
}
