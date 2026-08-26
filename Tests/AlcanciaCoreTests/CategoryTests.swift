import XCTest
@testable import AlcanciaCore

final class CategoryTests: XCTestCase {
    func testEveryCategoryHasEmojiAndLabel() {
        for category in Category.allCases {
            XCTAssertFalse(category.emoji.isEmpty, "\(category) sin emoji")
            XCTAssertFalse(category.label.isEmpty, "\(category) sin etiqueta")
        }
    }

    func testCategoryOrderIsStableForThePicker() {
        XCTAssertEqual(
            Category.allCases,
            [.comida, .mercado, .transporte, .casa, .software, .ocio, .salud, .otro]
        )
    }
}
