import XCTest
@testable import AlcanciaCore

final class EntryTests: XCTestCase {
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func testEntryHasUniqueIdentifiersByDefault() {
        let a = Entry(amount: 100, currency: .mxn, amountInMXN: 100)
        let b = Entry(amount: 100, currency: .mxn, amountInMXN: 100)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testNewEntriesDefaultToExpense() {
        let entry = Entry(amount: 100, currency: .mxn, amountInMXN: 100)
        XCTAssertEqual(entry.kind, .expense)
        XCTAssertNil(entry.category)
        XCTAssertNil(entry.note)
        XCTAssertFalse(entry.isBusiness)
    }

    func testEntryRoundTripsThroughJSON() throws {
        let entry = Entry(
            amount: 10,
            currency: .usd,
            amountInMXN: 185,
            exchangeRateUsed: 18.5,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .expense,
            category: .software,
            note: "Adobe",
            isBusiness: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        let decoded = try makeDecoder().decode(Entry.self, from: data)
        XCTAssertEqual(decoded, entry)
        XCTAssertTrue(decoded.isBusiness)
    }

    /// Un archivo que ya conoce `kind`/`category`/`note` pero es de antes de
    /// que existiera el interruptor de negocio debe leer `isBusiness` como
    /// `false`, no fallar.
    func testDecodesEntryWithoutIsBusinessAsFalse() throws {
        let json = """
        {
          "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
          "amount": 300,
          "currency": "mxn",
          "amountInMXN": 300,
          "date": "2026-08-01T12:00:00Z",
          "kind": "expense",
          "category": "comida"
        }
        """.data(using: .utf8)!

        let entry = try makeDecoder().decode(Entry.self, from: json)
        XCTAssertFalse(entry.isBusiness)
    }

    /// Un archivo escrito por la versión anterior no trae kind/category/note.
    /// Si esto falla, la app trata el archivo del usuario como corrupto.
    func testDecodesLegacyEntryWithoutKindCategoryOrNote() throws {
        let legacy = """
        {
          "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
          "amount": 1500,
          "currency": "mxn",
          "amountInMXN": 1500,
          "date": "2026-08-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let entry = try makeDecoder().decode(Entry.self, from: legacy)

        XCTAssertEqual(entry.amountInMXN, 1500)
        XCTAssertEqual(entry.kind, .income, "los movimientos viejos eran dinero ganado")
        XCTAssertNil(entry.category)
        XCTAssertNil(entry.note)
        XCTAssertNil(entry.exchangeRateUsed)
    }
}
