import XCTest
@testable import AlcanciaCore

final class GoalProgressTests: XCTestCase {
    func testNoGoalReturnsNilFractionAndPercent() {
        let progress = GoalProgress(totalMXN: 500, goalMXN: nil)
        XCTAssertNil(progress.fraction)
        XCTAssertNil(progress.percentText)
    }

    func testZeroGoalTreatedAsNoGoal() {
        let progress = GoalProgress(totalMXN: 500, goalMXN: 0)
        XCTAssertNil(progress.fraction)
        XCTAssertNil(progress.percentText)
    }

    func testPartialProgress() {
        let progress = GoalProgress(totalMXN: 2500, goalMXN: 10000)
        XCTAssertEqual(progress.fraction ?? -1, 0.25, accuracy: 0.0001)
        XCTAssertEqual(progress.percentText, "25%")
    }

    func testExceedingGoalCapsFractionButNotPercentText() {
        let progress = GoalProgress(totalMXN: 12000, goalMXN: 10000)
        XCTAssertEqual(progress.fraction ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertEqual(progress.percentText, "120%")
    }

    func testAbsurdlySmallGoalDoesNotCrash() {
        let progress = GoalProgress(totalMXN: 1000, goalMXN: Decimal(string: "0.0000000000000000001")!)
        XCTAssertEqual(progress.percentText, "999999999999%")
    }
}
