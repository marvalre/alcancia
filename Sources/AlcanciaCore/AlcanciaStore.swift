import Foundation

public struct AlcanciaData: Codable {
    public var goalMXN: Decimal?
    public var entries: [Entry]
    public var lastKnownUSDMXNRate: Double?
    public var lastKnownRateDate: Date?
    public var launchAtLogin: Bool

    public init(
        goalMXN: Decimal? = nil,
        entries: [Entry] = [],
        lastKnownUSDMXNRate: Double? = nil,
        lastKnownRateDate: Date? = nil,
        launchAtLogin: Bool = false
    ) {
        self.goalMXN = goalMXN
        self.entries = entries
        self.lastKnownUSDMXNRate = lastKnownUSDMXNRate
        self.lastKnownRateDate = lastKnownRateDate
        self.launchAtLogin = launchAtLogin
    }
}

@MainActor
public final class AlcanciaStore: ObservableObject {
    @Published public private(set) var data: AlcanciaData

    private let fileURL: URL

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()

    public init(fileURL: URL = AlcanciaStore.defaultFileURL()) {
        self.fileURL = fileURL
        self.data = Self.load(from: fileURL)
    }

    nonisolated public static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let dir = appSupport.appendingPathComponent("Alcancia", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    public var totalMXN: Decimal {
        data.entries.reduce(Decimal(0)) { $0 + $1.amountInMXN }
    }

    @discardableResult
    public func addEntry(
        amount: Decimal,
        currency: Currency,
        exchangeRate: Double? = nil,
        date: Date = Date()
    ) -> Entry {
        let amountInMXN: Decimal
        let rateUsed: Double?
        switch currency {
        case .mxn:
            amountInMXN = amount
            rateUsed = nil
        case .usd:
            let rate = exchangeRate ?? data.lastKnownUSDMXNRate ?? 1
            amountInMXN = amount * Decimal(rate)
            rateUsed = rate
        }
        let entry = Entry(
            amount: amount,
            currency: currency,
            amountInMXN: amountInMXN,
            exchangeRateUsed: rateUsed,
            date: date
        )
        data.entries.append(entry)
        save()
        return entry
    }

    public func deleteEntry(id: UUID) {
        data.entries.removeAll { $0.id == id }
        save()
    }

    public func setGoal(_ amount: Decimal?) {
        data.goalMXN = amount
        save()
    }

    public func resetAllEntries() {
        data.entries = []
        save()
    }

    public func recordExchangeRate(_ rate: Double, date: Date = Date()) {
        data.lastKnownUSDMXNRate = rate
        data.lastKnownRateDate = date
        save()
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        data.launchAtLogin = enabled
        save()
    }

    public func formattedAmount(_ amount: Decimal) -> String {
        Self.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }

    public var formattedTotal: String {
        formattedAmount(totalMXN)
    }

    public var menuBarSummary: String {
        if let goalMXN = data.goalMXN, goalMXN > 0 {
            let progress = GoalProgress(totalMXN: totalMXN, goalMXN: goalMXN)
            return progress.percentText ?? formattedTotal
        }
        return formattedTotal
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let payload = try encoder.encode(data)
            try payload.write(to: fileURL, options: .atomic)
        } catch {
            print("Alcancía: no se pudo guardar los datos: \(error)")
        }
    }

    nonisolated private static func load(from url: URL) -> AlcanciaData {
        guard let raw = try? Data(contentsOf: url) else {
            return AlcanciaData()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(AlcanciaData.self, from: raw) {
            return decoded
        }
        let corruptURL = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
        try? FileManager.default.moveItem(at: url, to: corruptURL)
        return AlcanciaData()
    }
}
