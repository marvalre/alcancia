import XCTest
@testable import AlcanciaCore

final class EntryFilterTests: XCTestCase {
    private let entries: [Entry] = [
        Entry(
            amount: 120,
            currency: .mxn,
            amountInMXN: 120,
            kind: .expense,
            category: .comida,
            note: "Tacos",
            isBusiness: false
        ),
        Entry(
            amount: 500,
            currency: .mxn,
            amountInMXN: 500,
            kind: .expense,
            category: .software,
            note: "Adobe",
            isBusiness: true
        ),
        Entry(
            amount: 2_000,
            currency: .mxn,
            amountInMXN: 2_000,
            kind: .income,
            note: "Proyecto web"
        )
    ]

    func testSearchMatchesNotesCaseAndDiacriticInsensitively() {
        let result = EntryFilter(query: "TÁCOS").apply(to: entries)

        XCTAssertEqual(result.map(\.note), ["Tacos"])
    }

    func testKindAndCategoryFiltersCompose() {
        let result = EntryFilter(kind: .expense, category: .software).apply(to: entries)

        XCTAssertEqual(result.map(\.note), ["Adobe"])
    }

    func testBusinessFilterDistinguishesBusinessAndPersonalExpenses() {
        XCTAssertEqual(
            EntryFilter(business: true).apply(to: entries).map(\.note),
            ["Adobe"]
        )
        XCTAssertEqual(
            EntryFilter(business: false).apply(to: entries).map(\.note),
            ["Tacos"]
        )
    }

    func testEmptyFilterPreservesInputOrder() {
        XCTAssertEqual(EntryFilter().apply(to: entries), entries)
    }
}
