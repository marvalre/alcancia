import XCTest
@testable import AlcanciaCore

private struct FakeFetcher: ExchangeRateFetching {
    let result: Double?
    func fetchUSDToMXNRate() async -> Double? { result }
}

final class ExchangeRateServiceTests: XCTestCase {
    func testUsesLiveRateWhenFetchSucceeds() async {
        let service = ExchangeRateService(fetcher: FakeFetcher(result: 18.5))
        let result = await service.resolveRate(cachedRate: 17.0, cachedDate: Date())
        XCTAssertEqual(result?.rate, 18.5)
        XCTAssertEqual(result?.isFromCache, false)
    }

    func testFallsBackToCachedRateWhenFetchFails() async {
        let cachedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let service = ExchangeRateService(fetcher: FakeFetcher(result: nil))
        let result = await service.resolveRate(cachedRate: 17.25, cachedDate: cachedDate)
        XCTAssertEqual(result?.rate, 17.25)
        XCTAssertEqual(result?.isFromCache, true)
        XCTAssertEqual(result?.asOf, cachedDate)
    }

    func testReturnsNilWhenFetchFailsAndNoCacheExists() async {
        let service = ExchangeRateService(fetcher: FakeFetcher(result: nil))
        let result = await service.resolveRate(cachedRate: nil, cachedDate: nil)
        XCTAssertNil(result)
    }
}
