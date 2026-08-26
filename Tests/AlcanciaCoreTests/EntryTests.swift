import XCTest
@testable import AlcanciaCore

final class EntryTests: XCTestCase {
    func testEntryHasUniqueIdentifiersByDefault() {
        let a = Entry(amount: 100, currency: .mxn, amountInMXN: 100)
        let b = Entry(amount: 100, currency: .mxn, amountInMXN: 100)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testEntryRoundTripsThroughJSON() throws {
        let entry = Entry(
            amount: 10,
            currency: .usd,
            amountInMXN: 185,
            exchangeRateUsed: 18.5,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Entry.self, from: data)

        XCTAssertEqual(decoded, entry)
    }
}
