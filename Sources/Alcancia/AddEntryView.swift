import SwiftUI
import AlcanciaCore

struct AddEntryView: View {
    @ObservedObject var store: AlcanciaStore

    @State private var amountText: String = ""
    @State private var currency: Currency = .mxn
    @State private var isResolvingRate = false
    @State private var needsManualRate = false
    @State private var manualRateText: String = ""
    @State private var errorMessage: String?

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }

    private var parsedManualRate: Double? {
        Double(manualRateText.replacingOccurrences(of: ",", with: ""))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Monto", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                Picker("Moneda", selection: $currency) {
                    Text("MXN").tag(Currency.mxn)
                    Text("USD").tag(Currency.usd)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 110)
                .onChange(of: currency) { _, _ in
                    needsManualRate = false
                    errorMessage = nil
                }
            }

            if needsManualRate {
                HStack(spacing: 8) {
                    Text("Tipo de cambio USD→MXN:")
                        .font(.caption)
                    TextField("ej. 18.50", text: $manualRateText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await addEntry() }
            } label: {
                if isResolvingRate {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Agregar")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAddDisabled)
        }
        .padding(14)
    }

    private var isAddDisabled: Bool {
        guard let amount = parsedAmount, amount > 0 else { return true }
        if isResolvingRate { return true }
        if needsManualRate {
            guard let rate = parsedManualRate, rate > 0 else { return true }
        }
        return false
    }

    @MainActor
    private func addEntry() async {
        guard let amount = parsedAmount, amount > 0 else { return }
        errorMessage = nil

        if currency == .mxn {
            store.addEntry(amount: amount, currency: .mxn)
            amountText = ""
            return
        }

        if needsManualRate {
            guard let rate = parsedManualRate, rate > 0 else { return }
            store.recordExchangeRate(rate)
            store.addEntry(amount: amount, currency: .usd, exchangeRate: rate)
            amountText = ""
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

        if !result.isFromCache {
            store.recordExchangeRate(result.rate, date: result.asOf)
        }
        store.addEntry(amount: amount, currency: .usd, exchangeRate: result.rate)
        amountText = ""
    }
}
