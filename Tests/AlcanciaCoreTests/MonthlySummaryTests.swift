import XCTest
@testable import AlcanciaCore

final class MonthlySummaryTests: XCTestCase {
    /// Calendario fijo para que los límites de mes no dependan de la máquina.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour
        ))!
    }

    private func expense(
        _ amount: Decimal,
        _ category: AlcanciaCore.ExpenseCategory,
        on date: Date,
        isBusiness: Bool = false
    ) -> Entry {
        Entry(amount: amount, currency: .mxn, amountInMXN: amount,
              date: date, kind: .expense, category: category, isBusiness: isBusiness)
    }

    private func income(_ amount: Decimal, on date: Date) -> Entry {
        Entry(amount: amount, currency: .mxn, amountInMXN: amount,
              date: date, kind: .income)
    }

    func testEmptyMonthTotalsZero() {
        let summary = MonthlySummary(entries: [], month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.totalSpentMXN, 0)
        XCTAssertEqual(summary.totalIncomeMXN, 0)
        XCTAssertTrue(summary.byCategory.isEmpty)
        XCTAssertTrue(summary.entriesInMonth.isEmpty)
    }

    func testIncomeDoesNotCountAsSpending() {
        let entries = [
            expense(300, .comida, on: date(2026, 8, 5)),
            income(5000, on: date(2026, 8, 6))
        ]
        let summary = MonthlySummary(entries: entries, month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.totalSpentMXN, 300)
        XCTAssertEqual(summary.totalIncomeMXN, 5000)
        XCTAssertEqual(summary.byCategory.count, 1)
    }

    func testOnlyEntriesInsideTheMonthCount() {
        let entries = [
            expense(100, .comida, on: date(2026, 7, 31, 23)),
            expense(200, .comida, on: date(2026, 8, 1, 0)),
            expense(400, .comida, on: date(2026, 8, 31, 23)),
            expense(800, .comida, on: date(2026, 9, 1, 0))
        ]
        let summary = MonthlySummary(entries: entries, month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.totalSpentMXN, 600)
        XCTAssertEqual(summary.entriesInMonth.count, 2)
    }

    func testCategoryBreakdownIsSortedLargestFirstWithShares() {
        let entries = [
            expense(100, .comida, on: date(2026, 8, 2)),
            expense(300, .transporte, on: date(2026, 8, 3)),
            expense(100, .comida, on: date(2026, 8, 4))
        ]
        let summary = MonthlySummary(entries: entries, month: date(2026, 8, 15), calendar: calendar)

        XCTAssertEqual(summary.byCategory.map(\.category), [.transporte, .comida])
        XCTAssertEqual(summary.byCategory[0].amountMXN, 300)
        XCTAssertEqual(summary.byCategory[1].amountMXN, 200)
        XCTAssertEqual(summary.byCategory[0].fractionOfTotal, 0.6, accuracy: 0.0001)
        XCTAssertEqual(summary.byCategory[1].fractionOfTotal, 0.4, accuracy: 0.0001)
    }

    func testExpenseWithoutCategoryFallsUnderOtro() {
        let entry = Entry(amount: 250, currency: .mxn, amountInMXN: 250,
                          date: date(2026, 8, 7), kind: .expense, category: nil)
        let summary = MonthlySummary(entries: [entry], month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.byCategory.map(\.category), [.otro])
        XCTAssertEqual(summary.totalSpentMXN, 250)
    }

    func testTotalBusinessExcludesPersonalExpensesAndIncome() {
        let entries = [
            expense(300, .software, on: date(2026, 8, 5), isBusiness: true),
            expense(100, .comida, on: date(2026, 8, 6), isBusiness: false),
            income(5000, on: date(2026, 8, 7))
        ]
        let summary = MonthlySummary(entries: entries, month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.totalBusinessMXN, 300)
        XCTAssertEqual(summary.totalSpentMXN, 400)
    }

    func testTotalBusinessIsZeroWhenNothingIsMarkedBusiness() {
        let entries = [expense(200, .comida, on: date(2026, 8, 5))]
        let summary = MonthlySummary(entries: entries, month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.totalBusinessMXN, 0)
    }

    func testEntriesInMonthAreNewestFirst() {
        let older = expense(100, .comida, on: date(2026, 8, 2))
        let newer = expense(200, .comida, on: date(2026, 8, 20))
        let summary = MonthlySummary(entries: [older, newer], month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.entriesInMonth.first?.id, newer.id)
        XCTAssertEqual(summary.entriesInMonth.last?.id, older.id)
    }
}
