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

    /// Antes, cuando el mismo separador se repetía, se comparaba por VALOR
    /// del carácter en vez de por posición: TODAS las ocurrencias del
    /// separador elegido se volvían punto decimal, no sólo la última.
    /// "1.234.56" (estilo europeo, punto de miles + punto decimal) truncaba
    /// en silencio a 1.234 — un error de ~1000x sin ningún aviso.
    func testRepeatedDotIsThousandsSeparatorNotADoubleDecimal() {
        XCTAssertEqual(MoneyParser.parse("1.234.56"), Decimal(string: "1234.56"))
        XCTAssertEqual(MoneyParser.parse("100.999.99"), Decimal(string: "100999.99"))
    }

    func testRepeatedCommaIsThousandsSeparatorNotADoubleDecimal() {
        XCTAssertEqual(MoneyParser.parse("12,345,67"), Decimal(string: "12345.67"))
    }

    func testMixedSeparatorsWithMultipleThousandsGroupsStillParseCorrectly() {
        XCTAssertEqual(MoneyParser.parse("1,234,567.89"), Decimal(string: "1234567.89"))
        XCTAssertEqual(MoneyParser.parse("1.234.567,89"), Decimal(string: "1234567.89"))
    }
}
