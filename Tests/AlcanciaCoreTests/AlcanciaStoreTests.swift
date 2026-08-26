// Tests/AlcanciaCoreTests/AlcanciaStoreTests.swift
import XCTest
@testable import AlcanciaCore

@MainActor
final class AlcanciaStoreTests: XCTestCase {
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

    func testCorruptFileFallsBackToEmptyDataWithoutCrashing() throws {
        let url = makeTempFileURL()
        try "not valid json".write(to: url, atomically: true, encoding: .utf8)
        let store = AlcanciaStore(fileURL: url)
        XCTAssertEqual(store.summary(for: Date()).totalSpentMXN, 0)
        XCTAssertNil(store.data.monthlyBudgetMXN)
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
}
