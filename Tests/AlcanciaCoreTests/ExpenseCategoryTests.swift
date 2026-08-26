import XCTest
@testable import AlcanciaCore

final class ExpenseCategoryTests: XCTestCase {
    func testEveryCategoryHasEmojiAndLabel() {
        for category in ExpenseCategory.allCases {
            XCTAssertFalse(category.emoji.isEmpty, "\(category) sin emoji")
            XCTAssertFalse(category.label.isEmpty, "\(category) sin etiqueta")
        }
    }

    func testCategoryOrderIsStableForThePicker() {
        XCTAssertEqual(
            ExpenseCategory.allCases,
            [.comida, .mercado, .transporte, .casa, .software, .ocio, .salud, .otro]
        )
    }
}
