// Tests/AlcanciaCoreTests/AlcanciaStoreTests.swift
import XCTest
@testable import AlcanciaCore

@MainActor
final class AlcanciaStoreTests: XCTestCase {
    private func unwrapRecurring(_ result: Result<RecurringExpense, StoreError>) -> RecurringExpense {
        try! result.get()
    }
    private func makeTempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("alcancia-test-\(UUID().uuidString).json")
    }

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testAddingExpensesAccumulatesInTheMonth() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 300, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 5))
        store.addEntry(amount: 200, currency: .mxn, kind: .expense,
                       category: .transporte, date: date(2026, 8, 6))

        let summary = store.summary(for: date(2026, 8, 15))
        XCTAssertEqual(summary.totalSpentMXN, 500)
    }

    func testIncomeIsTrackedSeparatelyFromSpending() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 5000, currency: .mxn, kind: .income, date: date(2026, 8, 5))
        store.addEntry(amount: 300, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 5))

        let summary = store.summary(for: date(2026, 8, 15))
        XCTAssertEqual(summary.totalIncomeMXN, 5000)
        XCTAssertEqual(summary.totalSpentMXN, 300)
    }

    func testUSDExpenseConvertsWithGivenRate() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 10, currency: .usd, kind: .expense,
                       category: .software, exchangeRate: 18.0, date: date(2026, 8, 5))
        XCTAssertEqual(store.summary(for: date(2026, 8, 15)).totalSpentMXN, 180)
    }

    func testAddingAnExpenseRemembersItsCategory() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 100, currency: .mxn, kind: .expense, category: .ocio)
        XCTAssertEqual(store.data.lastUsedCategory, .ocio)
    }

    func testIncomeDoesNotChangeTheRememberedCategory() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 100, currency: .mxn, kind: .expense, category: .ocio)
        store.addEntry(amount: 5000, currency: .mxn, kind: .income)
        XCTAssertEqual(store.data.lastUsedCategory, .ocio)
    }

    func testDeletingAnEntryRemovesItFromTheMonth() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let entry = store.addEntry(amount: 300, currency: .mxn, kind: .expense,
                                   category: .comida, date: date(2026, 8, 5))
        store.addEntry(amount: 200, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 6))
        store.deleteEntry(id: entry.id)
        XCTAssertEqual(store.summary(for: date(2026, 8, 15)).totalSpentMXN, 200)
    }

    func testTotalsStayConsistentAcrossRepeatedAddAndDeleteCycles() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        for _ in 0..<5 {
            let toDelete = store.addEntry(amount: 100, currency: .mxn, kind: .expense,
                                          category: .comida, date: date(2026, 8, 5))
            store.addEntry(amount: 50, currency: .mxn, kind: .expense,
                           category: .comida, date: date(2026, 8, 5))
            store.deleteEntry(id: toDelete.id)
        }
        XCTAssertEqual(store.summary(for: date(2026, 8, 15)).totalSpentMXN, 250)
    }

    func testBudgetProgressReflectsTheMonthsSpending() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setMonthlyBudget(1000)
        store.addEntry(amount: 250, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 5))

        let progress = store.budgetProgress(for: date(2026, 8, 15))
        XCTAssertEqual(progress.fractionRemaining ?? -1, 0.75, accuracy: 0.0001)
        XCTAssertEqual(progress.remainingMXN, 750)
    }

    func testSetAndClearBudget() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setMonthlyBudget(8000)
        XCTAssertEqual(store.data.monthlyBudgetMXN, 8000)
        store.setMonthlyBudget(nil)
        XCTAssertNil(store.data.monthlyBudgetMXN)
    }

    func testResetAllEntriesKeepsTheBudget() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setMonthlyBudget(8000)
        store.addEntry(amount: 100, currency: .mxn, kind: .expense, category: .comida)
        store.resetAllEntries()
        XCTAssertEqual(store.summary(for: Date()).totalSpentMXN, 0)
        XCTAssertEqual(store.data.monthlyBudgetMXN, 8000)
    }

    func testAddingRecurringReportsPersistenceFailureWithoutPublishing() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("alcancia-store-dir-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = AlcanciaStore(fileURL: directory)

        let result = store.addRecurringExpense(name: "Falla", amountMXN: 10, category: .otro)

        XCTAssertEqual(result, .failure(.persistenceFailed))
        XCTAssertTrue(store.data.recurringExpenses.isEmpty)
    }

    func testResetAllEntriesReportsPersistenceFailureWithoutPublishing() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("alcancia-store-dir-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = AlcanciaStore(fileURL: directory)

        let result = store.resetAllEntries()

        guard case .failure(.persistenceFailed) = result else {
            return XCTFail("se esperaba .failure(.persistenceFailed), se obtuvo \(result)")
        }
        XCTAssertTrue(store.data.entries.isEmpty)
    }

    func testCompleteOnboardingIsAtomicAndCanRetryWithoutDuplicateAnchor() {
        let url = makeTempFileURL()
        let store = AlcanciaStore(fileURL: url)

        guard case .success = store.completeOnboarding(balance: 1500, budget: 8000) else {
            return XCTFail("se esperaba que completar el onboarding tuviera éxito")
        }
        XCTAssertEqual(store.data.balanceAdjustments.count, 1)
        XCTAssertEqual(store.data.monthlyBudgets.count, 1)

        let reloaded = AlcanciaStore(fileURL: url)
        XCTAssertEqual(reloaded.data.balanceAdjustments.count, 1)
        XCTAssertEqual(reloaded.data.monthlyBudgets.count, 1)
    }

    func testCompleteOnboardingFailurePublishesNeitherBalanceNorBudget() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("alcancia-store-dir-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = AlcanciaStore(fileURL: directory)

        let result = store.completeOnboarding(balance: 1500, budget: 8000)

        guard case .failure(.persistenceFailed) = result else {
            return XCTFail("se esperaba .failure(.persistenceFailed), se obtuvo \(result)")
        }
        XCTAssertTrue(store.data.balanceAdjustments.isEmpty)
        XCTAssertTrue(store.data.monthlyBudgets.isEmpty)
    }

    func testDataPersistsAcrossStoreInstances() {
        let url = makeTempFileURL()
        let first = AlcanciaStore(fileURL: url)
        first.setMonthlyBudget(8000)
        first.addEntry(amount: 250, currency: .mxn, kind: .expense,
                       category: .mercado, date: date(2026, 8, 5))

        let second = AlcanciaStore(fileURL: url)
        XCTAssertEqual(second.data.monthlyBudgetMXN, 8000)
        XCTAssertEqual(second.summary(for: date(2026, 8, 15)).totalSpentMXN, 250)
        XCTAssertEqual(second.data.lastUsedCategory, .mercado)
    }

    func testDesktopPanelPreferencesPersist() {
        let url = makeTempFileURL()
        let first = AlcanciaStore(fileURL: url)
        first.setShowsDesktopPanel(true)
        first.setDesktopPanelOrigin(CGPoint(x: 120, y: 340))

        let second = AlcanciaStore(fileURL: url)
        XCTAssertTrue(second.data.showsDesktopPanel)
        XCTAssertEqual(second.data.desktopPanelOrigin ?? [], [120, 340])
    }

    func testCorruptFileIsReportedWithoutReplacingTheOriginal() throws {
        let url = makeTempFileURL()
        try "not valid json".write(to: url, atomically: true, encoding: .utf8)
        let store = AlcanciaStore(fileURL: url)
        XCTAssertEqual(store.summary(for: Date()).totalSpentMXN, 0)
        XCTAssertEqual(store.status, .unrecoverableData)
        XCTAssertEqual(try String(contentsOf: url), "not valid json")
    }

    func testUnrecoverableStoreRejectsMutationsAndPreservesOriginal() throws {
        let url = makeTempFileURL()
        try "not valid json".write(to: url, atomically: true, encoding: .utf8)
        let store = AlcanciaStore(fileURL: url)

        guard case .failure(.recoveryRequired) = store.setBalance(500) else {
            return XCTFail("El store corrupto no debe aceptar mutaciones")
        }
        XCTAssertEqual(try String(contentsOf: url), "not valid json")
    }

    /// El archivo que dejó la versión anterior tiene que abrirse sin perder
    /// nada. Si esto falla, al usuario le parece que la app borró su dinero.
    func testLoadsFileWrittenByThePreviousVersion() throws {
        let url = makeTempFileURL()
        let legacy = """
        {
          "entries": [
            {
              "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
              "amount": 1500,
              "currency": "mxn",
              "amountInMXN": 1500,
              "date": "2026-08-10T12:00:00Z"
            }
          ],
          "goalMXN": 10000,
          "launchAtLogin": true,
          "lastKnownUSDMXNRate": 18.5,
          "lastKnownRateDate": "2026-08-10T12:00:00Z"
        }
        """
        try legacy.write(to: url, atomically: true, encoding: .utf8)

        let store = AlcanciaStore(fileURL: url)

        XCTAssertEqual(store.data.entries.count, 1, "el movimiento se perdió")
        XCTAssertEqual(store.data.entries.first?.kind, .income)
        XCTAssertEqual(store.data.lastKnownUSDMXNRate, 18.5)
        XCTAssertTrue(store.data.launchAtLogin)
        XCTAssertNil(store.data.monthlyBudgetMXN)
        XCTAssertFalse(store.data.showsDesktopPanel)
    }

    func testFormattedAmountUsesPesoFormatting() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let formatted = store.formattedAmount(3240)
        XCTAssertTrue(formatted.contains("3,240"), formatted)
        XCTAssertTrue(formatted.contains("$"), formatted)
    }

    func testRecordExchangeRateStoresRateAndDate() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        store.recordExchangeRate(18.75, date: when)
        XCTAssertEqual(store.data.lastKnownUSDMXNRate, 18.75)
        XCTAssertEqual(store.data.lastKnownRateDate, when)
    }

    // MARK: - Gasto de negocio

    func testAddingABusinessExpenseMarksTheEntryAndTheMonthTotal() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        store.addEntry(amount: 300, currency: .mxn, kind: .expense,
                       category: .software, date: date(2026, 8, 5), isBusiness: true)
        store.addEntry(amount: 100, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 6), isBusiness: false)

        let summary = store.summary(for: date(2026, 8, 15))
        XCTAssertEqual(summary.totalBusinessMXN, 300)
        XCTAssertEqual(summary.totalSpentMXN, 400)
    }

    func testAddingAnExpenseRemembersTheBusinessSwitch() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 100, currency: .mxn, kind: .expense,
                       category: .software, isBusiness: true)
        XCTAssertTrue(store.data.lastUsedIsBusiness)

        store.addEntry(amount: 50, currency: .mxn, kind: .expense,
                       category: .comida, isBusiness: false)
        XCTAssertFalse(store.data.lastUsedIsBusiness)
    }

    func testIncomeDoesNotChangeTheRememberedBusinessSwitch() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 100, currency: .mxn, kind: .expense,
                       category: .software, isBusiness: true)
        store.addEntry(amount: 5000, currency: .mxn, kind: .income)
        XCTAssertTrue(store.data.lastUsedIsBusiness)
    }

    func testSetLastUsedIsBusinessPersists() {
        let url = makeTempFileURL()
        let first = AlcanciaStore(fileURL: url)
        first.setLastUsedIsBusiness(true)

        let second = AlcanciaStore(fileURL: url)
        XCTAssertTrue(second.data.lastUsedIsBusiness)
    }

    // MARK: - Tendencia de gasto

    func testSpendingTrendDelegatesToSpendingTrendType() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        store.addEntry(amount: 300, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 5))
        let trend = store.spendingTrend(months: 3, endingAt: date(2026, 8, 15))
        XCTAssertEqual(trend.series.count, 3)
        XCTAssertEqual(trend.series.last?.totalMXN, 300)
        XCTAssertTrue(trend.series.last?.isCurrent ?? false)
    }

    // MARK: - Gastos recurrentes

    func testAddUpdateAndDeleteRecurringExpense() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let recurring = unwrapRecurring(store.addRecurringExpense(
            name: "Adobe CC", amountMXN: 399, category: .software, isBusiness: true
        ))
        XCTAssertEqual(store.data.recurringExpenses.count, 1)

        var updated = recurring
        updated.amountMXN = 450
        store.updateRecurringExpense(updated)
        XCTAssertEqual(store.data.recurringExpenses.first?.amountMXN, 450)

        store.deleteRecurringExpense(id: recurring.id)
        XCTAssertTrue(store.data.recurringExpenses.isEmpty)
    }

    func testManualNoteDoesNotMarkARecurringTemplateAsLogged() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        let adobe = unwrapRecurring(store.addRecurringExpense(name: "Adobe CC", amountMXN: 399, category: .software))
        store.addRecurringExpense(name: "Figma", amountMXN: 200, category: .software)

        // Ya hay un movimiento este mes cuyo note coincide con "Adobe CC".
        store.addEntry(amount: 399, currency: .mxn, kind: .expense,
                       category: .software, note: "Adobe CC", date: date(2026, 8, 3))

        let unlogged = store.unloggedRecurring(for: date(2026, 8, 15))
        XCTAssertEqual(Set(unlogged.map(\.id)), Set([adobe.id, store.data.recurringExpenses[1].id]))
    }

    func testLogRecurringCreatesOneEntryPerUnloggedTemplateDatedToday() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        store.addRecurringExpense(name: "Adobe CC", amountMXN: 399, category: .software, isBusiness: true)
        store.addRecurringExpense(name: "Figma", amountMXN: 200, category: .software)

        let today = calendar.startOfDay(for: Date())
        let currentMonth = today
        store.logRecurring(for: currentMonth)

        let summary = store.summary(for: currentMonth)
        XCTAssertEqual(summary.entriesInMonth.count, 2)
        XCTAssertEqual(Set(summary.entriesInMonth.compactMap(\.note)), ["Adobe CC", "Figma"])
        let adobeEntry = summary.entriesInMonth.first { $0.note == "Adobe CC" }
        XCTAssertEqual(adobeEntry?.isBusiness, true)
        XCTAssertEqual(adobeEntry?.category, .software)
    }

    func testLogRecurringIsIdempotent() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        store.addRecurringExpense(name: "Adobe CC", amountMXN: 399, category: .software)

        let today = Date()
        store.logRecurring(for: today)
        store.logRecurring(for: today)

        let summary = store.summary(for: today)
        XCTAssertEqual(summary.entriesInMonth.count, 1)
    }

    func testRecurringExpensesPersistAcrossStoreInstances() {
        let url = makeTempFileURL()
        let first = AlcanciaStore(fileURL: url)
        first.addRecurringExpense(name: "ChatGPT", amountMXN: 350, category: .software)

        let second = AlcanciaStore(fileURL: url)
        XCTAssertEqual(second.data.recurringExpenses.map(\.name), ["ChatGPT"])
    }

    // MARK: - Saldo (ingresos menos gastos, de todo el tiempo)

    func testBalanceWithOnlyIncome() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 5000, currency: .mxn, kind: .income, date: date(2026, 8, 5))
        store.addEntry(amount: 1000, currency: .mxn, kind: .income, date: date(2026, 7, 5))
        XCTAssertEqual(store.balanceMXN, 6000)
    }

    /// Los números reales del usuario: ingresos 4531, gastos 1300, saldo 3231.
    /// Fijado exactamente para no volver a romper la aritmética.
    func testBalanceSubtractsExpensesFromIncomeExactly() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 4531, currency: .mxn, kind: .income, date: date(2026, 8, 1))
        store.addEntry(amount: 1300, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 5))
        XCTAssertEqual(store.balanceMXN, 3231)
    }

    func testBalanceIsNegativeWhenExpensesExceedIncome() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 500, currency: .mxn, kind: .income, date: date(2026, 8, 1))
        store.addEntry(amount: 1300, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 5))
        XCTAssertEqual(store.balanceMXN, -800)
    }

    func testBalanceIgnoresMonthBoundariesAndCountsAllEntries() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 2000, currency: .mxn, kind: .income, date: date(2026, 1, 5))
        store.addEntry(amount: 300, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 3, 5))
        store.addEntry(amount: 1000, currency: .mxn, kind: .income, date: date(2026, 8, 5))
        store.addEntry(amount: 200, currency: .mxn, kind: .expense,
                       category: .transporte, date: date(2026, 8, 20))
        // Nada de esto se filtra por mes: el saldo suma todo el historial.
        XCTAssertEqual(store.balanceMXN, 2500)
    }

    func testShowsBalanceDefaultsToFalseAndPersistsAcrossStoreInstances() {
        let url = makeTempFileURL()
        let first = AlcanciaStore(fileURL: url)
        XCTAssertFalse(first.data.showsBalance)

        first.setShowsBalance(true)
        let second = AlcanciaStore(fileURL: url)
        XCTAssertTrue(second.data.showsBalance)
    }

    // MARK: - Saldo anclado y presupuestos históricos

    func testBalanceAnchorIgnoresEarlierEntriesAndIncludesLaterEntries() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        store.addEntry(amount: 5_000, currency: .mxn, kind: .income, date: date(2026, 8, 1))
        store.setBalance(1_000, note: "Saldo contado", date: date(2026, 8, 10))
        store.addEntry(amount: 200, currency: .mxn, kind: .expense, category: .comida, date: date(2026, 8, 11))

        XCTAssertEqual(store.balance(at: date(2026, 8, 12)), 800)
    }

    func testMonthClosingBalanceBecomesTheNextMonthsOpeningBalance() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        store.setBalance(1_000, date: date(2026, 8, 1))
        store.addEntry(amount: 150, currency: .mxn, kind: .expense, category: .comida, date: date(2026, 8, 15))

        XCTAssertEqual(store.closingBalance(for: date(2026, 8, 20)), 850)
        XCTAssertEqual(store.openingBalance(for: date(2026, 9, 20)), 850)
    }

    func testChangingSeptemberBudgetLeavesAugustBudgetUnchanged() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        store.setBudget(1_000, for: date(2026, 8, 12))
        store.setBudget(2_000, for: date(2026, 9, 12))

        XCTAssertEqual(store.budget(for: date(2026, 8, 20)), 1_000)
        XCTAssertEqual(store.budget(for: date(2026, 9, 20)), 2_000)
    }

    func testRecurringTemplatesWithTheSameNameRemainIndependent() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        let first = unwrapRecurring(store.addRecurringExpense(name: "Suscripción", amountMXN: 100, category: .software))
        let second = unwrapRecurring(store.addRecurringExpense(name: "Suscripción", amountMXN: 200, category: .software))
        let month = Date()

        store.logRecurring(for: month)

        XCTAssertEqual(Set(store.summary(for: month).entriesInMonth.compactMap(\.recurringExpenseID)), Set([first.id, second.id]))
    }

    func testMovingARecurringEntryChangesTheMonthItMarksAsLogged() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        let recurring = unwrapRecurring(store.addRecurringExpense(name: "Internet", amountMXN: 600, category: .casa))
        let august = date(2026, 8, 15)
        let september = date(2026, 9, 15)
        store.logRecurring(for: august)

        guard var entry = store.data.entries.first else {
            return XCTFail("Debió existir el movimiento recurrente de agosto")
        }
        entry.date = september
        guard case .success = store.updateEntry(entry) else {
            return XCTFail("Mover el movimiento recurrente debió guardarse")
        }

        XCTAssertEqual(store.unloggedRecurring(for: august).map(\.id), [recurring.id])
        XCTAssertTrue(store.unloggedRecurring(for: september).isEmpty)
    }

    func testSkippingRecurringExpenseOnlySkipsThatTemplateForThatMonth() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        let first = unwrapRecurring(store.addRecurringExpense(name: "Suscripción", amountMXN: 100, category: .software))
        let second = unwrapRecurring(store.addRecurringExpense(name: "Suscripción", amountMXN: 200, category: .software))
        let august = date(2026, 8, 15)

        store.skipRecurring(id: first.id, for: august)

        XCTAssertEqual(store.unloggedRecurring(for: august).map(\.id), [second.id])
    }

    // MARK: - Persistencia recuperable y validación

    func testFailedSaveDoesNotPublishTheCandidateMutation() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("data.json")
        let store = AlcanciaStore(fileURL: url, calendar: calendar)

        guard case .failure(.persistenceFailed) = store.setBudget(1_000, for: date(2026, 8, 1)) else {
            return XCTFail("La mutación debió informar un error de persistencia")
        }
        XCTAssertNil(store.budget(for: date(2026, 8, 15)))
    }

    func testSuccessfulMutationPublishesOnlyAfterSaving() throws {
        let url = makeTempFileURL()
        let store = AlcanciaStore(fileURL: url, calendar: calendar)

        guard case .success = store.setBudget(1_000, for: date(2026, 8, 1)) else {
            return XCTFail("La mutación debió guardarse")
        }
        XCTAssertEqual(store.budget(for: date(2026, 8, 15)), 1_000)
        XCTAssertFalse(try Data(contentsOf: url).isEmpty)
    }

    func testPersistenceKeepsFiveRotatingBackups() throws {
        let url = makeTempFileURL()
        let store = AlcanciaStore(fileURL: url, calendar: calendar)
        for amount in 1...6 {
            guard case .success = store.setBudget(Decimal(amount), for: date(2026, 8, 1)) else {
                return XCTFail("El presupuesto \(amount) debió guardarse")
            }
        }

        for index in 1...5 {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("backup-\(index)").path))
        }
    }

    func testCorruptPrimaryLoadsTheMostRecentValidBackup() throws {
        let url = makeTempFileURL()
        let backup = AlcanciaData(monthlyBudgetMXN: 777)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(backup).write(to: url.appendingPathExtension("backup-1"))
        try "corrupt".write(to: url, atomically: true, encoding: .utf8)

        let store = AlcanciaStore(fileURL: url, calendar: calendar)

        XCTAssertEqual(store.status, .recoveredFromBackup)
        XCTAssertEqual(store.data.monthlyBudgetMXN, 777)
        XCTAssertEqual(try String(contentsOf: url), "corrupt")
    }

    func testMutationBoundaryRejectsInvalidAmountsAndRates() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)

        XCTAssertEqual(store.addEntryResult(amount: 0, currency: .mxn), .failure(.invalidAmount))
        XCTAssertEqual(store.addEntryResult(amount: 1, currency: .usd, exchangeRate: 0), .failure(.invalidExchangeRate))
        XCTAssertEqual(store.addEntryResult(amount: 1, currency: .usd), .failure(.missingUSDExchangeRate))
    }

    func testRestoringADeletedEntryPreservesItsIdentityAndTotals() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        let entry = store.addEntry(amount: 250, currency: .mxn, category: .comida)
        store.deleteEntry(id: entry.id)

        guard case .success = store.restoreEntry(entry) else {
            return XCTFail("El movimiento eliminado debió restaurarse")
        }
        XCTAssertEqual(store.data.entries.map(\.id), [entry.id])
        XCTAssertEqual(store.summary(for: Date()).totalSpentMXN, 250)
    }

    /// Antes, editar un movimiento que ya no existe (p. ej. se borró en otra
    /// parte antes de que un "deshacer" pendiente se disparara) reportaba
    /// éxito sin escribir nada — el llamador creía que se guardó un cambio
    /// que nunca ocurrió.
    func testUpdatingANonExistentEntryReportsNotFoundInsteadOfFalseSuccess() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        let entry = store.addEntry(amount: 250, currency: .mxn, category: .comida)
        store.deleteEntry(id: entry.id)

        guard case .failure(.entryNotFound) = store.updateEntry(entry) else {
            return XCTFail("Editar un movimiento borrado no debió reportar éxito")
        }
        XCTAssertTrue(store.data.entries.isEmpty)
    }

    func testRestoringAnEntryThatAlreadyExistsReportsAlreadyExists() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        let entry = store.addEntry(amount: 250, currency: .mxn, category: .comida)

        guard case .failure(.entryAlreadyExists) = store.restoreEntry(entry) else {
            return XCTFail("Restaurar un movimiento que ya existe no debió reportar éxito silencioso")
        }
        XCTAssertEqual(store.data.entries.count, 1)
    }

    func testLoggingRecurringExpensesUsesOneObservableResult() {
        let store = AlcanciaStore(fileURL: makeTempFileURL(), calendar: calendar)
        store.addRecurringExpense(name: "Adobe", amountMXN: 399, category: .software)
        store.addRecurringExpense(name: "Música", amountMXN: 129, category: .ocio)

        guard case .success(let count) = store.logRecurringResult(for: Date()) else {
            return XCTFail("Las recurrentes debieron guardarse juntas")
        }
        XCTAssertEqual(count, 2)
        XCTAssertEqual(store.data.entries.count, 2)
    }
}
