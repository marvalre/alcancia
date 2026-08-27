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
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchUSDToMXNRate() async -> Double? {
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=USD&to=MXN") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
            guard let rate = decoded.rates["MXN"], rate.isFinite, rate > 0 else { return nil }
            return rate
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
        switch await resolveRateResult(cachedRate: cachedRate, cachedDate: cachedDate) {
        case .success(let result): return result
        case .failure: return nil
        }
    }

    public func resolveRateResult(cachedRate: Double?, cachedDate: Date?) async -> Result<ExchangeRateResult, StoreError> {
        if let liveRate = await fetcher.fetchUSDToMXNRate(), liveRate.isFinite, liveRate > 0 {
            return .success(ExchangeRateResult(rate: liveRate, isFromCache: false, asOf: Date()))
        }
        if let cachedRate, let cachedDate, cachedRate.isFinite, cachedRate > 0 {
            return .success(ExchangeRateResult(rate: cachedRate, isFromCache: true, asOf: cachedDate))
        }
        return .failure(.invalidExchangeRate)
    }
}
