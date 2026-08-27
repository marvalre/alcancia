import XCTest
@testable import AlcanciaCore

final class MoneyParserTests: XCTestCase {
    func testParsesCommaDecimalWithoutTreatingItAsAThousandsSeparator() {
        XCTAssertEqual(MoneyParser.parse("12,50"), 12.5)
    }

    func testParsesCommonMexicanCurrencyFormatting() {
        XCTAssertEqual(MoneyParser.parse("$ 1,234.50"), 1_234.5)
    }

    func testRejectsEmptyAndNonPositiveAmounts() {
        XCTAssertNil(MoneyParser.parse(""))
        XCTAssertNil(MoneyParser.parse("0"))
        XCTAssertNil(MoneyParser.parse("-1"))
    }

    func testBalanceParserAcceptsZeroAndDebt() {
        XCTAssertEqual(MoneyParser.parseBalance("0"), 0)
        XCTAssertEqual(MoneyParser.parseBalance("-250,50"), Decimal(string: "-250.50"))
    }
}
