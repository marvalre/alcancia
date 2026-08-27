// Sources/AlcanciaCore/AlcanciaStore.swift
import Foundation
import CoreGraphics

public struct AlcanciaData: Codable {
    public var monthlyBudgetMXN: Decimal?
    public var entries: [Entry]
    public var lastKnownUSDMXNRate: Double?
    public var lastKnownRateDate: Date?
    public var launchAtLogin: Bool
    public var lastUsedCategory: ExpenseCategory?
    public var showsDesktopPanel: Bool
    /// [x, y] de la esquina del panel flotante, para restaurarlo donde quedó.
    public var desktopPanelOrigin: [Double]?
    public var recurringExpenses: [RecurringExpense]
    public var lastUsedIsBusiness: Bool

    public init(
        monthlyBudgetMXN: Decimal? = nil,
        entries: [Entry] = [],
        lastKnownUSDMXNRate: Double? = nil,
        lastKnownRateDate: Date? = nil,
        launchAtLogin: Bool = false,
        lastUsedCategory: ExpenseCategory? = nil,
        showsDesktopPanel: Bool = false,
        desktopPanelOrigin: [Double]? = nil,
        recurringExpenses: [RecurringExpense] = [],
        lastUsedIsBusiness: Bool = false
    ) {
        self.monthlyBudgetMXN = monthlyBudgetMXN
        self.entries = entries
        self.lastKnownUSDMXNRate = lastKnownUSDMXNRate
        self.lastKnownRateDate = lastKnownRateDate
        self.launchAtLogin = launchAtLogin
        self.lastUsedCategory = lastUsedCategory
        self.showsDesktopPanel = showsDesktopPanel
        self.desktopPanelOrigin = desktopPanelOrigin
        self.recurringExpenses = recurringExpenses
        self.lastUsedIsBusiness = lastUsedIsBusiness
    }

    /// Todo campo agregado después de la primera versión se decodifica con
    /// `decodeIfPresent`. Un archivo viejo al que le falte cualquiera de ellos
    /// tiene que abrirse igual: si falla, `AlcanciaStore.load` lo pone en
    /// cuarentena y al usuario le parece que la app le borró su dinero.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = try container.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        monthlyBudgetMXN = try container.decodeIfPresent(Decimal.self, forKey: .monthlyBudgetMXN)
        lastKnownUSDMXNRate = try container.decodeIfPresent(Double.self, forKey: .lastKnownUSDMXNRate)
        lastKnownRateDate = try container.decodeIfPresent(Date.self, forKey: .lastKnownRateDate)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        lastUsedCategory = try container.decodeIfPresent(ExpenseCategory.self, forKey: .lastUsedCategory)
        showsDesktopPanel = try container.decodeIfPresent(Bool.self, forKey: .showsDesktopPanel) ?? false
        desktopPanelOrigin = try container.decodeIfPresent([Double].self, forKey: .desktopPanelOrigin)
        recurringExpenses = try container.decodeIfPresent([RecurringExpense].self, forKey: .recurringExpenses) ?? []
        lastUsedIsBusiness = try container.decodeIfPresent(Bool.self, forKey: .lastUsedIsBusiness) ?? false
    }
}

@MainActor
public final class AlcanciaStore: ObservableObject {
    @Published public private(set) var data: AlcanciaData

    private let fileURL: URL
    private let calendar: Calendar

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()

    public init(
        fileURL: URL = AlcanciaStore.defaultFileURL(),
        calendar: Calendar = .current
    ) {
        self.fileURL = fileURL
        self.calendar = calendar
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

    // MARK: - Consultas

    public func summary(for month: Date) -> MonthlySummary {
        MonthlySummary(entries: data.entries, month: month, calendar: calendar)
    }

    public func budgetProgress(for month: Date) -> BudgetProgress {
        BudgetProgress(
            spentMXN: summary(for: month).totalSpentMXN,
            budgetMXN: data.monthlyBudgetMXN
        )
    }

    public func spendingTrend(months: Int = 6, endingAt month: Date) -> SpendingTrend {
        SpendingTrend(entries: data.entries, endingAt: month, months: months, calendar: calendar)
    }

    /// Lo que lee VoiceOver del ícono de la barra de menú.
    public func menuBarAccessibilityLabel(for month: Date) -> String {
        let spent = formattedAmount(summary(for: month).totalSpentMXN)
        guard let budget = data.monthlyBudgetMXN, budget > 0 else {
            return "Gastado \(spent) este mes"
        }
        return "Gastado \(spent) de \(formattedAmount(budget)) este mes"
    }

    // MARK: - Movimientos

    @discardableResult
    public func addEntry(
        amount: Decimal,
        currency: Currency,
        kind: EntryKind = .expense,
        category: ExpenseCategory? = nil,
        note: String? = nil,
        exchangeRate: Double? = nil,
        date: Date = Date(),
        isBusiness: Bool = false
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

        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = Entry(
            amount: amount,
            currency: currency,
            amountInMXN: amountInMXN,
            exchangeRateUsed: rateUsed,
            date: date,
            kind: kind,
            category: kind == .expense ? (category ?? .otro) : nil,
            note: (cleanNote?.isEmpty ?? true) ? nil : cleanNote,
            isBusiness: kind == .expense ? isBusiness : false
        )
        data.entries.append(entry)
        // Sólo los gastos mueven la categoría y el interruptor de negocio por
        // defecto de la captura rápida.
        if kind == .expense, let category {
            data.lastUsedCategory = category
        }
        if kind == .expense {
            data.lastUsedIsBusiness = isBusiness
        }
        save()
        return entry
    }

    public func deleteEntry(id: UUID) {
        data.entries.removeAll { $0.id == id }
        save()
    }

    public func resetAllEntries() {
        data.entries = []
        save()
    }

    // MARK: - Gastos recurrentes

    @discardableResult
    public func addRecurringExpense(
        name: String,
        amountMXN: Decimal,
        category: ExpenseCategory,
        isBusiness: Bool = false
    ) -> RecurringExpense {
        let recurring = RecurringExpense(
            name: name,
            amountMXN: amountMXN,
            category: category,
            isBusiness: isBusiness
        )
        data.recurringExpenses.append(recurring)
        save()
        return recurring
    }

    public func updateRecurringExpense(_ recurring: RecurringExpense) {
        guard let index = data.recurringExpenses.firstIndex(where: { $0.id == recurring.id }) else { return }
        data.recurringExpenses[index] = recurring
        save()
    }

    public func deleteRecurringExpense(id: UUID) {
        data.recurringExpenses.removeAll { $0.id == id }
        save()
    }

    /// Recurrentes que todavía no tienen un movimiento en `month`. "Registrado"
    /// significa que existe un movimiento cuyo `note` coincide exactamente con
    /// el `name` de la recurrente — evita duplicados sin necesidad de otro
    /// campo de enlace.
    public func unloggedRecurring(for month: Date) -> [RecurringExpense] {
        let loggedNotes = Set(summary(for: month).entriesInMonth.compactMap(\.note))
        return data.recurringExpenses.filter { !loggedNotes.contains($0.name) }
    }

    /// Crea un movimiento de gasto por cada recurrente sin registrar de
    /// `month`, fechado hoy (no en la fecha del mes que se está viendo).
    /// Correrlo dos veces no duplica nada: la segunda vez ya no hay
    /// recurrentes sin registrar.
    public func logRecurring(for month: Date) {
        for recurring in unloggedRecurring(for: month) {
            addEntry(
                amount: recurring.amountMXN,
                currency: .mxn,
                kind: .expense,
                category: recurring.category,
                note: recurring.name,
                date: Date(),
                isBusiness: recurring.isBusiness
            )
        }
    }

    // MARK: - Ajustes

    public func setMonthlyBudget(_ amount: Decimal?) {
        data.monthlyBudgetMXN = amount
        save()
    }

    public func setLastUsedCategory(_ category: ExpenseCategory) {
        data.lastUsedCategory = category
        save()
    }

    public func setLastUsedIsBusiness(_ isBusiness: Bool) {
        data.lastUsedIsBusiness = isBusiness
        save()
    }

    public func setShowsDesktopPanel(_ shows: Bool) {
        data.showsDesktopPanel = shows
        save()
    }

    public func setDesktopPanelOrigin(_ origin: CGPoint?) {
        data.desktopPanelOrigin = origin.map { [Double($0.x), Double($0.y)] }
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

    // MARK: - Formato

    public func formattedAmount(_ amount: Decimal) -> String {
        Self.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }

    // MARK: - Persistencia

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
