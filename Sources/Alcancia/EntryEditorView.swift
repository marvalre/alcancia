import SwiftUI
import AlcanciaCore

struct EntryEditorView: View {
    @ObservedObject var store: AlcanciaStore
    let original: Entry
    let onCancel: () -> Void
    let onSaved: (Entry, Entry) -> Void

    @State private var amountText: String
    @State private var noteText: String
    @State private var kind: EntryKind
    @State private var currency: Currency
    @State private var category: ExpenseCategory
    @State private var isBusiness: Bool
    @State private var date: Date
    @State private var errorMessage: String?

    init(
        store: AlcanciaStore,
        entry: Entry,
        onCancel: @escaping () -> Void,
        onSaved: @escaping (Entry, Entry) -> Void
    ) {
        self.store = store
        self.original = entry
        self.onCancel = onCancel
        self.onSaved = onSaved
        _amountText = State(initialValue: NSDecimalNumber(decimal: entry.amount).stringValue)
        _noteText = State(initialValue: entry.note ?? "")
        _kind = State(initialValue: entry.kind)
        _currency = State(initialValue: entry.currency)
        _category = State(initialValue: entry.category ?? .otro)
        _isBusiness = State(initialValue: entry.isBusiness)
        _date = State(initialValue: entry.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                TextField("Monto", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                Picker("Moneda", selection: $currency) {
                    Text("MXN").tag(Currency.mxn)
                    Text("USD").tag(Currency.usd)
                }
                .frame(width: 90)
            }

            TextField("Concepto", text: $noteText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Picker("Tipo", selection: $kind) {
                    Text("Gasto").tag(EntryKind.expense)
                    Text("Ingreso").tag(EntryKind.income)
                }
                .frame(width: 120)

                if kind == .expense {
                    Picker("Categoría", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { value in
                            Text("\(value.emoji) \(value.label)").tag(value)
                        }
                    }
                    Toggle("Negocio", isOn: $isBusiness).font(.caption)
                }
            }

            DatePicker("Fecha", selection: $date)
                .datePickerStyle(.compact)
                .font(.caption)

            if let errorMessage {
                Text(errorMessage).font(.caption2).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancelar", action: onCancel).controlSize(.small)
                Button("Guardar", action: save)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(MoneyParser.parse(amountText) == nil)
            }
        }
    }

    private func save() {
        guard let amount = MoneyParser.parse(amountText) else { return }
        var updated = original
        updated.amount = amount
        updated.currency = currency
        updated.kind = kind
        updated.category = kind == .expense ? category : nil
        updated.note = noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil : noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.isBusiness = kind == .expense && isBusiness
        updated.date = date

        switch currency {
        case .mxn:
            updated.amountInMXN = amount
            updated.exchangeRateUsed = nil
        case .usd:
            guard let rate = original.exchangeRateUsed ?? store.data.lastKnownUSDMXNRate,
                  rate.isFinite, rate > 0 else {
                errorMessage = "No hay tipo de cambio disponible para editar este movimiento en USD."
                return
            }
            updated.amountInMXN = amount * Decimal(rate)
            updated.exchangeRateUsed = rate
        }

        switch store.updateEntry(updated) {
        case .success: onSaved(original, updated)
        case .failure: errorMessage = "No se pudo guardar el cambio."
        }
    }
}
