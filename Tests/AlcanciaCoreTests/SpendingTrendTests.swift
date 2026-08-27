import XCTest
@testable import AlcanciaCore

final class SpendingTrendTests: XCTestCase {
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

    private func expense(_ amount: Decimal, on date: Date) -> Entry {
        Entry(amount: amount, currency: .mxn, amountInMXN: amount,
              date: date, kind: .expense, category: .comida)
    }

    func testReturnsExactlyRequestedMonthsOldestFirst() {
        let trend = SpendingTrend(entries: [], endingAt: date(2026, 8, 15), months: 6, calendar: calendar)
        XCTAssertEqual(trend.series.count, 6)

        let expectedMonths = (0..<6).map { offset in
            date(2026, 3 + offset, 1, 0)
        }
        XCTAssertEqual(trend.series.map(\.month), expectedMonths)
    }

    func testEmptyMonthsShowZeroInsteadOfBeingOmitted() {
        let entries = [expense(500, on: date(2026, 8, 5))]
        let trend = SpendingTrend(entries: entries, endingAt: date(2026, 8, 15), months: 6, calendar: calendar)

        XCTAssertEqual(trend.series.count, 6)
        // Todos los meses salvo agosto no tienen gasto y deben aparecer en 0,
        // no desaparecer de la serie.
        for monthSpending in trend.series.dropLast() {
            XCTAssertEqual(monthSpending.totalMXN, 0)
        }
        XCTAssertEqual(trend.series.last?.totalMXN, 500)
    }

    func testOnlyTheLastMonthIsFlaggedAsCurrent() {
        let trend = SpendingTrend(entries: [], endingAt: date(2026, 8, 15), months: 6, calendar: calendar)
        for monthSpending in trend.series.dropLast() {
            XCTAssertFalse(monthSpending.isCurrent)
        }
        XCTAssertTrue(trend.series.last?.isCurrent ?? false)
    }

    func testSumsSpendingWithinEachMonthAndIgnoresOtherMonths() {
        let entries = [
            expense(100, on: date(2026, 6, 5)),
            expense(50, on: date(2026, 6, 20)),
            expense(300, on: date(2026, 8, 5))
        ]
        let trend = SpendingTrend(entries: entries, endingAt: date(2026, 8, 15), months: 6, calendar: calendar)

        let june = trend.series.first { calendar.component(.month, from: $0.month) == 6 }
        XCTAssertEqual(june?.totalMXN, 150)
        XCTAssertEqual(trend.series.last?.totalMXN, 300)
    }

    func testDefaultsToSixMonths() {
        let trend = SpendingTrend(entries: [], endingAt: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(trend.series.count, 6)
    }

    func testCustomMonthCount() {
        let trend = SpendingTrend(entries: [], endingAt: date(2026, 8, 15), months: 3, calendar: calendar)
        XCTAssertEqual(trend.series.count, 3)
        XCTAssertEqual(
            trend.series.map(\.month),
            [date(2026, 6, 1, 0), date(2026, 7, 1, 0), date(2026, 8, 1, 0)]
        )
    }
}
