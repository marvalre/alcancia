import Foundation

public struct ExchangeRateResult: Equatable {
    public let rate: Double
    public let isFromCache: Bool
    public let asOf: Date

    public init(rate: Double, isFromCache: Bool, asOf: Date) {
        self.rate = rate
        self.isFromCache = isFromCache
        self.asOf = asOf
    }
}

public protocol ExchangeRateFetching {
    func fetchUSDToMXNRate() async -> Double?
}

public struct FrankfurterExchangeRateFetcher: ExchangeRateFetching {
    public init() {}

    public func fetchUSDToMXNRate() async -> Double? {
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=USD&to=MXN") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
            return decoded.rates["MXN"]
        } catch {
            return nil
        }
    }

    private struct FrankfurterResponse: Decodable {
        let rates: [String: Double]
    }
}

public struct ExchangeRateService {
    private let fetcher: ExchangeRateFetching

    public init(fetcher: ExchangeRateFetching = FrankfurterExchangeRateFetcher()) {
        self.fetcher = fetcher
    }

    public func resolveRate(cachedRate: Double?, cachedDate: Date?) async -> ExchangeRateResult? {
        if let liveRate = await fetcher.fetchUSDToMXNRate() {
            return ExchangeRateResult(rate: liveRate, isFromCache: false, asOf: Date())
        }
        if let cachedRate, let cachedDate {
            return ExchangeRateResult(rate: cachedRate, isFromCache: true, asOf: cachedDate)
        }
        return nil
    }
}
