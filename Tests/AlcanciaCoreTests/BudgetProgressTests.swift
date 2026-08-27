import XCTest
@testable import AlcanciaCore

final class BudgetProgressTests: XCTestCase {
    func testNoBudgetLeavesEverythingUnknown() {
        let progress = BudgetProgress(spentMXN: 500, budgetMXN: nil)
        XCTAssertNil(progress.remainingMXN)
        XCTAssertNil(progress.fractionRemaining)
        XCTAssertNil(progress.percentSpentText)
        XCTAssertFalse(progress.isOverBudget)
    }

    func testZeroBudgetTreatedAsNoBudget() {
        let progress = BudgetProgress(spentMXN: 500, budgetMXN: 0)
        XCTAssertNil(progress.fractionRemaining)
        XCTAssertFalse(progress.isOverBudget)
    }

    func testUntouchedBudgetIsFull() {
        let progress = BudgetProgress(spentMXN: 0, budgetMXN: 8000)
        XCTAssertEqual(progress.fractionRemaining ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertEqual(progress.remainingMXN, 8000)
        XCTAssertEqual(progress.percentSpentText, "0%")
        XCTAssertFalse(progress.isOverBudget)
    }

    func testHalfSpent() {
        let progress = BudgetProgress(spentMXN: 4000, budgetMXN: 8000)
        XCTAssertEqual(progress.fractionRemaining ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(progress.remainingMXN, 4000)
        XCTAssertEqual(progress.percentSpentText, "50%")
        XCTAssertFalse(progress.isOverBudget)
    }

    func testExactlySpentIsNotOverBudget() {
        let progress = BudgetProgress(spentMXN: 8000, budgetMXN: 8000)
        XCTAssertEqual(progress.fractionRemaining ?? -1, 0.0, accuracy: 0.0001)
        XCTAssertEqual(progress.remainingMXN, 0)
        XCTAssertFalse(progress.isOverBudget)
    }

    func testOverBudgetEmptiesThePiggyAndReportsTheOverage() {
        let progress = BudgetProgress(spentMXN: 9000, budgetMXN: 8000)
        XCTAssertEqual(progress.fractionRemaining ?? -1, 0.0, accuracy: 0.0001)
        XCTAssertEqual(progress.remainingMXN, -1000)
        XCTAssertTrue(progress.isOverBudget)
        XCTAssertEqual(progress.percentSpentText, "113%")
    }

    /// Un presupuesto absurdamente chico desbordaba Int y tiraba la app en un
    /// ciclo de arranque; el porcentaje tiene que acotarse antes de convertir.
    func testAbsurdlySmallBudgetDoesNotCrash() {
        let progress = BudgetProgress(
            spentMXN: 1000,
            budgetMXN: Decimal(string: "0.0000000000000000001")!
        )
        XCTAssertEqual(progress.percentSpentText, "999999999999%")
        XCTAssertEqual(progress.fractionRemaining ?? -1, 0.0, accuracy: 0.0001)
        XCTAssertTrue(progress.isOverBudget)
    }

    // MARK: - dailyAllowance

    func testDailyAllowanceIsNilWithoutBudget() {
        let progress = BudgetProgress(spentMXN: 500, budgetMXN: nil)
        XCTAssertNil(progress.dailyAllowance(remainingDays: 10))
    }

    func testDailyAllowanceIsNilWhenOverBudget() {
        let progress = BudgetProgress(spentMXN: 9000, budgetMXN: 8000)
        XCTAssertNil(progress.dailyAllowance(remainingDays: 10))
    }

    func testDailyAllowanceIsNilWithZeroOrNegativeDays() {
        let progress = BudgetProgress(spentMXN: 5000, budgetMXN: 8000)
        XCTAssertNil(progress.dailyAllowance(remainingDays: 0))
        XCTAssertNil(progress.dailyAllowance(remainingDays: -3))
    }

    func testDailyAllowanceSplitsRemainingAcrossDays() {
        let progress = BudgetProgress(spentMXN: 5000, budgetMXN: 8000)
        XCTAssertEqual(progress.dailyAllowance(remainingDays: 10), 300)
    }
}
