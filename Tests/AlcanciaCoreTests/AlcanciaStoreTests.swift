// Tests/AlcanciaCoreTests/AlcanciaStoreTests.swift
import XCTest
@testable import AlcanciaCore

@MainActor
final class AlcanciaStoreTests: XCTestCase {
    private func makeTempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("alcancia-test-\(UUID().uuidString).json")
    }

    func testAddingMXNEntriesIncreasesTotal() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 100, currency: .mxn)
        store.addEntry(amount: 50, currency: .mxn)
        XCTAssertEqual(store.totalMXN, 150)
    }

    func testAddingUSDEntryConvertsUsingGivenRate() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 10, currency: .usd, exchangeRate: 18.0)
        XCTAssertEqual(store.totalMXN, 180)
    }

    func testDeletingEntryRemovesItFromTotal() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let entry = store.addEntry(amount: 100, currency: .mxn)
        store.addEntry(amount: 50, currency: .mxn)
        store.deleteEntry(id: entry.id)
        XCTAssertEqual(store.totalMXN, 50)
    }

    func testSetAndClearGoal() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setGoal(1000)
        XCTAssertEqual(store.data.goalMXN, 1000)
        store.setGoal(nil)
        XCTAssertNil(store.data.goalMXN)
    }

    func testResetAllEntriesKeepsGoal() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setGoal(1000)
        store.addEntry(amount: 100, currency: .mxn)
        store.resetAllEntries()
        XCTAssertEqual(store.totalMXN, 0)
        XCTAssertEqual(store.data.goalMXN, 1000)
    }

    func testDataPersistsAcrossStoreInstances() {
        let url = makeTempFileURL()
        let store1 = AlcanciaStore(fileURL: url)
        store1.addEntry(amount: 250, currency: .mxn)
        store1.setGoal(5000)

        let store2 = AlcanciaStore(fileURL: url)
        XCTAssertEqual(store2.totalMXN, 250)
        XCTAssertEqual(store2.data.goalMXN, 5000)
    }

    func testCorruptFileFallsBackToEmptyDataWithoutCrashing() throws {
        let url = makeTempFileURL()
        try "not valid json".write(to: url, atomically: true, encoding: .utf8)
        let store = AlcanciaStore(fileURL: url)
        XCTAssertEqual(store.totalMXN, 0)
        XCTAssertNil(store.data.goalMXN)
    }

    func testRecordExchangeRateStoresRateAndDate() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        store.recordExchangeRate(18.75, date: date)
        XCTAssertEqual(store.data.lastKnownUSDMXNRate, 18.75)
        XCTAssertEqual(store.data.lastKnownRateDate, date)
    }

    func testFormattedAmountUsesPesoFormatting() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let formatted = store.formattedAmount(3240)
        XCTAssertTrue(formatted.contains("3,240"), formatted)
        XCTAssertTrue(formatted.contains("$"), formatted)
    }

    func testMenuBarSummaryShowsTotalWhenNoGoal() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 1000, currency: .mxn)
        XCTAssertTrue(store.menuBarSummary.contains("1,000"), store.menuBarSummary)
    }

    func testMenuBarSummaryShowsPercentWhenGoalSet() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setGoal(1000)
        store.addEntry(amount: 250, currency: .mxn)
        XCTAssertEqual(store.menuBarSummary, "25%")
    }

    func testTotalStaysConsistentAcrossRepeatedAddAndDeleteCycles() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        for _ in 0..<5 {
            let toDelete = store.addEntry(amount: 100, currency: .mxn)
            store.addEntry(amount: 50, currency: .mxn)
            store.deleteEntry(id: toDelete.id)
        }
        XCTAssertEqual(store.totalMXN, 250)
    }
}
