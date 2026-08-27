// Sources/AlcanciaCore/AlcanciaStore.swift
import Foundation
import CoreGraphics

public struct AlcanciaData: Codable {
    public var schemaVersion: Int
    public var monthlyBudgetMXN: Decimal?
    public var monthlyBudgets: [MonthKey: Decimal]
    public var balanceAdjustments: [BalanceAdjustment]
    public var skippedRecurringPeriods: [UUID: [MonthKey]]
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
    /// Si `true`, el número grande del encabezado muestra el saldo real
    /// (ingresos menos gastos, de todo el tiempo) en vez de lo gastado este
    /// mes. Por defecto apagado: la identidad de la app sigue siendo control
    /// de gasto, esto es una lectura alterna opcional.
    public var showsBalance: Bool

    public init(
        schemaVersion: Int = 2,
        monthlyBudgetMXN: Decimal? = nil,
        monthlyBudgets: [MonthKey: Decimal] = [:],
        balanceAdjustments: [BalanceAdjustment] = [],
        skippedRecurringPeriods: [UUID: [MonthKey]] = [:],
        entries: [Entry] = [],
        lastKnownUSDMXNRate: Double? = nil,
        lastKnownRateDate: Date? = nil,
        launchAtLogin: Bool = false,
        lastUsedCategory: ExpenseCategory? = nil,
        showsDesktopPanel: Bool = false,
        desktopPanelOrigin: [Double]? = nil,
        recurringExpenses: [RecurringExpense] = [],
        lastUsedIsBusiness: Bool = false,
        showsBalance: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.monthlyBudgetMXN = monthlyBudgetMXN
        self.monthlyBudgets = monthlyBudgets
        self.balanceAdjustments = balanceAdjustments
        self.skippedRecurringPeriods = skippedRecurringPeriods
        self.entries = entries
        self.lastKnownUSDMXNRate = lastKnownUSDMXNRate
        self.lastKnownRateDate = lastKnownRateDate
        self.launchAtLogin = launchAtLogin
        self.lastUsedCategory = lastUsedCategory
        self.showsDesktopPanel = showsDesktopPanel
        self.desktopPanelOrigin = desktopPanelOrigin
        self.recurringExpenses = recurringExpenses
        self.lastUsedIsBusiness = lastUsedIsBusiness
        self.showsBalance = showsBalance
    }

    /// Todo campo agregado después de la primera versión se decodifica con
    /// `decodeIfPresent`. Un archivo viejo al que le falte cualquiera de ellos
    /// tiene que abrirse igual: si falla, `AlcanciaStore.load` lo pone en
    /// cuarentena y al usuario le parece que la app le borró su dinero.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        entries = try container.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        monthlyBudgetMXN = try container.decodeIfPresent(Decimal.self, forKey: .monthlyBudgetMXN)
        monthlyBudgets = try container.decodeIfPresent([MonthKey: Decimal].self, forKey: .monthlyBudgets) ?? [:]
        balanceAdjustments = try container.decodeIfPresent([BalanceAdjustment].self, forKey: .balanceAdjustments) ?? []
        skippedRecurringPeriods = try container.decodeIfPresent([UUID: [MonthKey]].self, forKey: .skippedRecurringPeriods) ?? [:]
        lastKnownUSDMXNRate = try container.decodeIfPresent(Double.self, forKey: .lastKnownUSDMXNRate)
        lastKnownRateDate = try container.decodeIfPresent(Date.self, forKey: .lastKnownRateDate)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        lastUsedCategory = try container.decodeIfPresent(ExpenseCategory.self, forKey: .lastUsedCategory)
        showsDesktopPanel = try container.decodeIfPresent(Bool.self, forKey: .showsDesktopPanel) ?? false
        desktopPanelOrigin = try container.decodeIfPresent([Double].self, forKey: .desktopPanelOrigin)
        recurringExpenses = try container.decodeIfPresent([RecurringExpense].self, forKey: .recurringExpenses) ?? []
        lastUsedIsBusiness = try container.decodeIfPresent(Bool.self, forKey: .lastUsedIsBusiness) ?? false
        showsBalance = try container.decodeIfPresent(Bool.self, forKey: .showsBalance) ?? false
    }
}

@MainActor
public final class AlcanciaStore: ObservableObject {
    @Published public private(set) var data: AlcanciaData
    @Published public private(set) var status: StoreStatus

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
        let loaded = Self.load(from: fileURL)
        var migrated = loaded.data
        if migrated.monthlyBudgets.isEmpty, let legacyBudget = migrated.monthlyBudgetMXN {
            migrated.monthlyBudgets[MonthKey(date: Date(), calendar: calendar)] = legacyBudget
        }
        self.data = migrated
        self.status = loaded.status
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
            budgetMXN: budget(for: month)
        )
    }

    public func spendingTrend(months: Int = 6, endingAt month: Date) -> SpendingTrend {
        SpendingTrend(entries: data.entries, endingAt: month, months: months, calendar: calendar)
    }

    /// El dinero que de verdad tienes: todos los ingresos menos todos los
    /// gastos, de todo el tiempo. A diferencia de `summary(for:).totalSpentMXN`,
    /// no se reinicia cada mes — es un saldo, no un corte mensual.
    public var balanceMXN: Decimal {
        balance(at: Date())
    }

    public func balance(at date: Date) -> Decimal {
        let anchor = data.balanceAdjustments
            .filter { $0.date <= date }
            .max { $0.date < $1.date }
        let entries = data.entries.filter { entry in
            entry.date <= date && (anchor == nil || entry.date > anchor!.date)
        }
        return entries.reduce(anchor?.amountMXN ?? Decimal(0)) { partial, entry in
            switch entry.kind {
            case .income:
                return partial + entry.amountInMXN
            case .expense:
                return partial - entry.amountInMXN
            }
        }
    }

    public func openingBalance(for month: Date) -> Decimal {
        balance(at: calendar.dateInterval(of: .month, for: month)!.start)
    }

    public func closingBalance(for month: Date) -> Decimal {
        let start = calendar.dateInterval(of: .month, for: month)!.start
        return balance(at: calendar.date(byAdding: .month, value: 1, to: start)!)
    }

    public func budget(for month: Date) -> Decimal? {
        let key = MonthKey(date: month, calendar: calendar)
        return data.monthlyBudgets[key]
    }

    /// Lo que lee VoiceOver del ícono de la barra de menú.
    public func menuBarAccessibilityLabel(for month: Date) -> String {
        let spent = formattedAmount(summary(for: month).totalSpentMXN)
        guard let budget = budget(for: month), budget > 0 else {
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
        switch addEntryResult(amount: amount, currency: currency, kind: kind, category: category, note: note, exchangeRate: exchangeRate, date: date, isBusiness: isBusiness) {
        case .success(let entry): return entry
        case .failure(let error): preconditionFailure("No se pudo registrar el movimiento: \(error)")
        }
    }

    public func addEntryResult(
        amount: Decimal,
        currency: Currency,
        kind: EntryKind = .expense,
        category: ExpenseCategory? = nil,
        note: String? = nil,
        exchangeRate: Double? = nil,
        date: Date = Date(),
        isBusiness: Bool = false,
        recurringExpenseID: UUID? = nil,
        recurringPeriod: MonthKey? = nil
    ) -> Result<Entry, StoreError> {
        guard amount > 0 else { return .failure(.invalidAmount) }
        let amountInMXN: Decimal
        let rateUsed: Double?
        switch currency {
        case .mxn:
            amountInMXN = amount
            rateUsed = nil
        case .usd:
            guard let rate = exchangeRate ?? data.lastKnownUSDMXNRate else { return .failure(.missingUSDExchangeRate) }
            guard rate.isFinite, rate > 0 else { return .failure(.invalidExchangeRate) }
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
            isBusiness: kind == .expense ? isBusiness : false,
            recurringExpenseID: recurringExpenseID,
            recurringPeriod: recurringPeriod
        )
        let result = mutate { candidate in
            candidate.entries.append(entry)
        // Sólo los gastos mueven la categoría y el interruptor de negocio por
        // defecto de la captura rápida.
            if kind == .expense, let category { candidate.lastUsedCategory = category }
            if kind == .expense { candidate.lastUsedIsBusiness = isBusiness }
        }
        return result.map { entry }
    }

    public func deleteEntry(id: UUID) {
        _ = mutate { candidate in candidate.entries.removeAll { $0.id == id } }
    }

    public func updateEntry(_ entry: Entry) -> Result<Void, StoreError> {
        guard entry.amount > 0, entry.amountInMXN > 0 else { return .failure(.invalidAmount) }
        return mutate { candidate in
            guard let index = candidate.entries.firstIndex(where: { $0.id == entry.id }) else { return }
            candidate.entries[index] = entry
        }
    }

    public func restoreEntry(_ entry: Entry) -> Result<Void, StoreError> {
        guard entry.amount > 0, entry.amountInMXN > 0 else { return .failure(.invalidAmount) }
        return mutate { candidate in
            guard !candidate.entries.contains(where: { $0.id == entry.id }) else { return }
            candidate.entries.append(entry)
        }
    }

    @discardableResult
    public func resetAllEntries() -> Result<Void, StoreError> {
        mutate { $0.entries = [] }
    }

    // MARK: - Gastos recurrentes

    @discardableResult
    public func addRecurringExpense(
        name: String,
        amountMXN: Decimal,
        category: ExpenseCategory,
        isBusiness: Bool = false
    ) -> Result<RecurringExpense, StoreError> {
        guard amountMXN > 0 else { return .failure(.invalidAmount) }
        let recurring = RecurringExpense(
            name: name,
            amountMXN: amountMXN,
            category: category,
            isBusiness: isBusiness
        )
        return mutate { $0.recurringExpenses.append(recurring) }.map { recurring }
    }

    public func updateRecurringExpense(_ recurring: RecurringExpense) {
        guard let index = data.recurringExpenses.firstIndex(where: { $0.id == recurring.id }) else { return }
        _ = mutate { $0.recurringExpenses[index] = recurring }
    }

    public func deleteRecurringExpense(id: UUID) {
        _ = mutate { candidate in candidate.recurringExpenses.removeAll { $0.id == id } }
    }

    public func unloggedRecurring(for month: Date) -> [RecurringExpense] {
        let key = MonthKey(date: month, calendar: calendar)
        let logged = Set(data.entries.compactMap { entry -> UUID? in
            entry.recurringPeriod == key ? entry.recurringExpenseID : nil
        })
        return data.recurringExpenses.filter {
            !logged.contains($0.id) && !(data.skippedRecurringPeriods[$0.id] ?? []).contains(key)
        }
    }

    /// Crea un movimiento de gasto por cada recurrente sin registrar de
    /// `month`, fechado hoy (no en la fecha del mes que se está viendo).
    /// Correrlo dos veces no duplica nada: la segunda vez ya no hay
    /// recurrentes sin registrar.
    public func logRecurring(for month: Date) {
        _ = logRecurringResult(for: month)
    }

    @discardableResult
    public func logRecurringResult(for month: Date) -> Result<Int, StoreError> {
        let pending = unloggedRecurring(for: month)
        guard !pending.isEmpty else { return .success(0) }
        guard pending.allSatisfy({ $0.amountMXN > 0 }) else { return .failure(.invalidAmount) }
        let period = MonthKey(date: month, calendar: calendar)
        let now = Date()
        let entries = pending.map { recurring in
            Entry(
                amount: recurring.amountMXN,
                currency: .mxn,
                amountInMXN: recurring.amountMXN,
                date: now,
                kind: .expense,
                category: recurring.category,
                note: recurring.name,
                isBusiness: recurring.isBusiness,
                recurringExpenseID: recurring.id,
                recurringPeriod: period
            )
        }
        return mutate { candidate in
            candidate.entries.append(contentsOf: entries)
            if let last = pending.last {
                candidate.lastUsedCategory = last.category
                candidate.lastUsedIsBusiness = last.isBusiness
            }
        }.map { entries.count }
    }

    public func skipRecurring(id: UUID, for month: Date) {
        let key = MonthKey(date: month, calendar: calendar)
        _ = mutate { candidate in
            var periods = candidate.skippedRecurringPeriods[id] ?? []
            if !periods.contains(key) { periods.append(key) }
            candidate.skippedRecurringPeriods[id] = periods
        }
    }

    // MARK: - Ajustes

    @discardableResult
    public func setMonthlyBudget(_ amount: Decimal?) -> Result<Void, StoreError> {
        guard amount == nil || amount! > 0 else { return .failure(.invalidAmount) }
        let key = MonthKey(date: Date(), calendar: calendar)
        return mutate { candidate in
            candidate.monthlyBudgetMXN = amount
            if let amount { candidate.monthlyBudgets[key] = amount }
            else { candidate.monthlyBudgets.removeValue(forKey: key) }
        }
    }

    @discardableResult
    public func setBudget(_ amount: Decimal?, for month: Date) -> Result<Void, StoreError> {
        guard amount == nil || amount! > 0 else { return .failure(.invalidAmount) }
        let key = MonthKey(date: month, calendar: calendar)
        return mutate { candidate in
            if let amount { candidate.monthlyBudgets[key] = amount }
            else { candidate.monthlyBudgets.removeValue(forKey: key) }
            if MonthKey(date: Date(), calendar: calendar) == key { candidate.monthlyBudgetMXN = amount }
        }
    }

    @discardableResult
    public func setBalance(_ amount: Decimal, note: String? = nil, date: Date = Date()) -> Result<Void, StoreError> {
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let adjustment = BalanceAdjustment(amountMXN: amount, date: date, note: (cleanNote?.isEmpty ?? true) ? nil : cleanNote)
        return mutate { $0.balanceAdjustments.append(adjustment) }
    }

    /// Guarda el saldo inicial y el presupuesto del onboarding como una sola
    /// mutación: si cualquiera de los dos no puede persistirse, ninguno se
    /// publica ni queda parcialmente guardado.
    public func completeOnboarding(balance: Decimal, budget: Decimal?) -> Result<Void, StoreError> {
        guard budget == nil || budget! > 0 else { return .failure(.invalidAmount) }
        let adjustment = BalanceAdjustment(amountMXN: balance, note: "Saldo inicial")
        let key = MonthKey(date: Date(), calendar: calendar)
        return mutate { candidate in
            candidate.balanceAdjustments.append(adjustment)
            if let budget {
                candidate.monthlyBudgets[key] = budget
                candidate.monthlyBudgetMXN = budget
            }
        }
    }

    public func setLastUsedCategory(_ category: ExpenseCategory) {
        _ = mutate { $0.lastUsedCategory = category }
    }

    public func setLastUsedIsBusiness(_ isBusiness: Bool) {
        _ = mutate { $0.lastUsedIsBusiness = isBusiness }
    }

    public func setShowsDesktopPanel(_ shows: Bool) {
        _ = mutate { $0.showsDesktopPanel = shows }
    }

    public func setShowsBalance(_ shows: Bool) {
        _ = mutate { $0.showsBalance = shows }
    }

    public func setDesktopPanelOrigin(_ origin: CGPoint?) {
        _ = mutate { $0.desktopPanelOrigin = origin.map { [Double($0.x), Double($0.y)] } }
    }

    public func recordExchangeRate(_ rate: Double, date: Date = Date()) {
        guard rate.isFinite, rate > 0 else { return }
        _ = mutate { candidate in candidate.lastKnownUSDMXNRate = rate; candidate.lastKnownRateDate = date }
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        _ = mutate { $0.launchAtLogin = enabled }
    }

    // MARK: - Formato

    public func formattedAmount(_ amount: Decimal) -> String {
        Self.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }

    // MARK: - Persistencia

    private func mutate(_ change: (inout AlcanciaData) -> Void) -> Result<Void, StoreError> {
        guard status != .unrecoverableData else { return .failure(.recoveryRequired) }
        var candidate = data
        change(&candidate)
        do {
            try save(candidate)
            data = candidate
            status = .healthy
            return .success(())
        } catch {
            return .failure(.persistenceFailed)
        }
    }

    private func save(_ candidate: AlcanciaData) throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let payload = try encoder.encode(candidate)
            try rotateBackups()
            try payload.write(to: fileURL, options: .atomic)
        } catch {
            throw StoreError.persistenceFailed
        }
    }

    private func rotateBackups() throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else { return }
        for index in stride(from: 5, through: 1, by: -1) {
            let destination = fileURL.appendingPathExtension("backup-\(index)")
            let source = index == 1 ? fileURL : fileURL.appendingPathExtension("backup-\(index - 1)")
            if manager.fileExists(atPath: source.path) {
                if manager.fileExists(atPath: destination.path) { try manager.removeItem(at: destination) }
                try manager.copyItem(at: source, to: destination)
            }
        }
    }

    @discardableResult
    public func restoreLatestBackup() -> Result<Void, StoreError> {
        for index in 1...5 {
            let backup = fileURL.appendingPathExtension("backup-\(index)")
            guard let raw = try? Data(contentsOf: backup), let recovered = Self.decode(raw) else { continue }
            do {
                try save(recovered)
                data = recovered
                status = .healthy
                return .success(())
            } catch { return .failure(.persistenceFailed) }
        }
        return .failure(.noBackupAvailable)
    }

    nonisolated private static func load(from url: URL) -> (data: AlcanciaData, status: StoreStatus) {
        guard let raw = try? Data(contentsOf: url) else { return (AlcanciaData(), .healthy) }
        if let decoded = decode(raw) { return (decoded, .healthy) }
        for index in 1...5 {
            let backup = url.appendingPathExtension("backup-\(index)")
            if let raw = try? Data(contentsOf: backup), let decoded = decode(raw) {
                return (decoded, .recoveredFromBackup)
            }
        }
        return (AlcanciaData(), .unrecoverableData)
    }

    nonisolated private static func decode(_ raw: Data) -> AlcanciaData? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AlcanciaData.self, from: raw)
    }
}
