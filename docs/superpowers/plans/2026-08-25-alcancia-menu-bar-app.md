# Alcancía Menu Bar App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build "Alcancía", a macOS menu-bar-only app that tracks money earned locally, with an optional savings goal and USD→MXN conversion.

**Architecture:** Swift Package with two targets — `AlcanciaCore` (pure Foundation logic: models, JSON persistence, exchange-rate resolution, goal math, fully unit tested) and `Alcancia` (SwiftUI `MenuBarExtra` app consuming `AlcanciaCore`, verified manually since the repo's other menu bar apps don't carry UI tests either). Packaged into `Alcancía.app` via a shell script that ad-hoc code-signs the binary, matching `bitacora/` and `ojo/`.

**Tech Stack:** Swift 5.10, SwiftUI, `MenuBarExtra`, `ServiceManagement` (`SMAppService`) for launch-at-login, `URLSession` for the exchange rate call, no third-party dependencies.

**Spec:** [`docs/superpowers/specs/2026-08-25-alcancia-design.md`](../specs/2026-08-25-alcancia-design.md)

## Global Constraints

- Platform: macOS 14+ (`platforms: [.macOS(.v14)]` in Package.swift), `swift-tools-version: 5.10`.
- No third-party dependencies — only Foundation, SwiftUI, ServiceManagement.
- All data is local: JSON file at `~/Library/Application Support/Alcancia/data.json`, no network calls except the exchange-rate lookup.
- Base currency is MXN. USD entries are converted to MXN at add-time using `https://api.frankfurter.app/latest?from=USD&to=MXN` (no API key required).
- Packaged app must have `LSUIElement = true` (no Dock icon, menu-bar only) and be ad-hoc code-signed (`codesign --force --deep --sign -`), same as `bitacora/build_app.sh` and `ojo/build_app.sh`.
- Bundle identifier: `com.mvisuals.alcancia`. Display name: `Alcancía`.

---

## File Structure

```
alcancia/
  Package.swift
  .gitignore
  README.md
  build_app.sh
  Sources/
    AlcanciaCore/
      Entry.swift                 (Currency enum, Entry struct)
      GoalProgress.swift          (goal % / fraction math)
      AlcanciaStore.swift         (AlcanciaData, persistence, totals, formatting)
      ExchangeRateService.swift   (fetcher protocol + Frankfurter impl + resolveRate)
    Alcancia/
      AlcanciaAppMain.swift       (@main App, MenuBarExtra)
      MenuBarView.swift
      AddEntryView.swift
      HistoryView.swift
      SettingsView.swift
      LoginItemManager.swift
  Tests/
    AlcanciaCoreTests/
      EntryTests.swift
      GoalProgressTests.swift
      AlcanciaStoreTests.swift
      ExchangeRateServiceTests.swift
```

---

### Task 1: Package scaffold + Entry/Currency model

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/AlcanciaCore/Entry.swift`
- Create: `Sources/Alcancia/AlcanciaAppMain.swift`
- Test: `Tests/AlcanciaCoreTests/EntryTests.swift`

**Interfaces:**
- Produces: `public enum Currency: String, Codable, CaseIterable { case mxn, usd }`
- Produces: `public struct Entry: Identifiable, Codable, Equatable` with `id: UUID`, `amount: Decimal`, `currency: Currency`, `amountInMXN: Decimal`, `exchangeRateUsed: Double?`, `date: Date`, and `init(id: UUID = UUID(), amount: Decimal, currency: Currency, amountInMXN: Decimal, exchangeRateUsed: Double? = nil, date: Date = Date())`.

- [ ] **Step 1: Create the package manifest**

```swift
// Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Alcancia",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Alcancia", targets: ["Alcancia"]),
        .library(name: "AlcanciaCore", targets: ["AlcanciaCore"])
    ],
    targets: [
        .target(name: "AlcanciaCore"),
        .executableTarget(name: "Alcancia", dependencies: ["AlcanciaCore"]),
        .testTarget(name: "AlcanciaCoreTests", dependencies: ["AlcanciaCore"])
    ]
)
```

- [ ] **Step 2: Add `.gitignore`**

```
.build/
*.app
.swiftpm/
```

- [ ] **Step 3: Add a minimal but real app entry point so the executable target builds**

```swift
// Sources/Alcancia/AlcanciaAppMain.swift
import SwiftUI

@main
struct AlcanciaAppMain: App {
    var body: some Scene {
        MenuBarExtra("Alcancía", systemImage: "banknote.fill") {
            Text("Alcancía")
        }
    }
}
```

(This file is fully replaced in Task 8 once the real store and views exist.)

- [ ] **Step 4: Write the failing test for `Entry`**

```swift
// Tests/AlcanciaCoreTests/EntryTests.swift
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
```

- [ ] **Step 5: Run the test to see it fail (type doesn't exist yet)**

Run: `cd alcancia && swift test --filter EntryTests`
Expected: FAIL — `cannot find type 'Entry' in scope` (or similar, since `AlcanciaCore` is still empty).

- [ ] **Step 6: Implement `Currency` and `Entry`**

```swift
// Sources/AlcanciaCore/Entry.swift
import Foundation

public enum Currency: String, Codable, CaseIterable {
    case mxn
    case usd
}

public struct Entry: Identifiable, Codable, Equatable {
    public let id: UUID
    public var amount: Decimal
    public var currency: Currency
    public var amountInMXN: Decimal
    public var exchangeRateUsed: Double?
    public var date: Date

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        currency: Currency,
        amountInMXN: Decimal,
        exchangeRateUsed: Double? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.amountInMXN = amountInMXN
        self.exchangeRateUsed = exchangeRateUsed
        self.date = date
    }
}
```

- [ ] **Step 7: Run the tests and the full build to confirm everything compiles and passes**

Run: `cd alcancia && swift build && swift test --filter EntryTests`
Expected: build succeeds, both `EntryTests` pass.

- [ ] **Step 8: Commit**

```bash
cd alcancia
git add Package.swift .gitignore Sources/AlcanciaCore/Entry.swift Sources/Alcancia/AlcanciaAppMain.swift Tests/AlcanciaCoreTests/EntryTests.swift
git commit -m "Scaffold Alcancia package with Entry/Currency model"
```

---

### Task 2: Goal progress math

**Files:**
- Create: `Sources/AlcanciaCore/GoalProgress.swift`
- Test: `Tests/AlcanciaCoreTests/GoalProgressTests.swift`

**Interfaces:**
- Consumes: nothing beyond `Foundation.Decimal`.
- Produces: `public struct GoalProgress { public init(totalMXN: Decimal, goalMXN: Decimal?); public var fraction: Double? /* capped 0...1 */; public var percentText: String? /* uncapped, e.g. "120%" */ }`. `AlcanciaStore` (Task 3) will construct this type to compute `menuBarSummary`.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/AlcanciaCoreTests/GoalProgressTests.swift
import XCTest
@testable import AlcanciaCore

final class GoalProgressTests: XCTestCase {
    func testNoGoalReturnsNilFractionAndPercent() {
        let progress = GoalProgress(totalMXN: 500, goalMXN: nil)
        XCTAssertNil(progress.fraction)
        XCTAssertNil(progress.percentText)
    }

    func testZeroGoalTreatedAsNoGoal() {
        let progress = GoalProgress(totalMXN: 500, goalMXN: 0)
        XCTAssertNil(progress.fraction)
        XCTAssertNil(progress.percentText)
    }

    func testPartialProgress() {
        let progress = GoalProgress(totalMXN: 2500, goalMXN: 10000)
        XCTAssertEqual(progress.fraction ?? -1, 0.25, accuracy: 0.0001)
        XCTAssertEqual(progress.percentText, "25%")
    }

    func testExceedingGoalCapsFractionButNotPercentText() {
        let progress = GoalProgress(totalMXN: 12000, goalMXN: 10000)
        XCTAssertEqual(progress.fraction ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertEqual(progress.percentText, "120%")
    }
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd alcancia && swift test --filter GoalProgressTests`
Expected: FAIL — `cannot find type 'GoalProgress' in scope`.

- [ ] **Step 3: Implement `GoalProgress`**

```swift
// Sources/AlcanciaCore/GoalProgress.swift
import Foundation

public struct GoalProgress {
    public let totalMXN: Decimal
    public let goalMXN: Decimal?

    public init(totalMXN: Decimal, goalMXN: Decimal?) {
        self.totalMXN = totalMXN
        self.goalMXN = goalMXN
    }

    private var rawFraction: Double? {
        guard let goalMXN, goalMXN > 0 else { return nil }
        let ratio = totalMXN / goalMXN
        return NSDecimalNumber(decimal: ratio).doubleValue
    }

    /// Capped to 1.0 — safe to feed directly into `ProgressView(value:)`.
    public var fraction: Double? {
        guard let rawFraction else { return nil }
        return min(rawFraction, 1.0)
    }

    /// Not capped — can exceed "100%" when the goal was surpassed.
    public var percentText: String? {
        guard let rawFraction else { return nil }
        let percent = Int((rawFraction * 100).rounded())
        return "\(percent)%"
    }
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `cd alcancia && swift test --filter GoalProgressTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd alcancia
git add Sources/AlcanciaCore/GoalProgress.swift Tests/AlcanciaCoreTests/GoalProgressTests.swift
git commit -m "Add GoalProgress calculation"
```

---

### Task 3: AlcanciaStore — persistence, totals, formatting

**Files:**
- Create: `Sources/AlcanciaCore/AlcanciaStore.swift`
- Test: `Tests/AlcanciaCoreTests/AlcanciaStoreTests.swift`

**Interfaces:**
- Consumes: `Entry`, `Currency` (Task 1), `GoalProgress` (Task 2).
- Produces:
  - `public struct AlcanciaData: Codable { public var goalMXN: Decimal?; public var entries: [Entry]; public var lastKnownUSDMXNRate: Double?; public var lastKnownRateDate: Date?; public var launchAtLogin: Bool }`
  - `@MainActor public final class AlcanciaStore: ObservableObject`, `@Published public private(set) var data: AlcanciaData`
  - `public init(fileURL: URL = AlcanciaStore.defaultFileURL())`
  - `public static func defaultFileURL() -> URL`
  - `public var totalMXN: Decimal`
  - `@discardableResult public func addEntry(amount: Decimal, currency: Currency, exchangeRate: Double? = nil, date: Date = Date()) -> Entry`
  - `public func deleteEntry(id: UUID)`
  - `public func setGoal(_ amount: Decimal?)`
  - `public func resetAllEntries()`
  - `public func recordExchangeRate(_ rate: Double, date: Date = Date())`
  - `public func setLaunchAtLogin(_ enabled: Bool)`
  - `public func formattedAmount(_ amount: Decimal) -> String`
  - `public var formattedTotal: String`
  - `public var menuBarSummary: String` (percent-of-goal if a goal is set, otherwise the formatted total) — used by `Alcancia` (Task 8) for the menu bar label.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/AlcanciaCoreTests/AlcanciaStoreTests.swift
import XCTest
@testable import AlcanciaCore

@MainActor
final class AlcanciaStoreTests: XCTestCase {
    private func makeTempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("alcancia-test-\(UUID().uuidString).json")
    }

    func testAddingMXNEntriesIncreasesTotal() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 100, currency: .mxn)
        store.addEntry(amount: 50, currency: .mxn)
        XCTAssertEqual(store.totalMXN, 150)
    }

    func testAddingUSDEntryConvertsUsingGivenRate() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 10, currency: .usd, exchangeRate: 18.0)
        XCTAssertEqual(store.totalMXN, 180)
    }

    func testDeletingEntryRemovesItFromTotal() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let entry = store.addEntry(amount: 100, currency: .mxn)
        store.addEntry(amount: 50, currency: .mxn)
        store.deleteEntry(id: entry.id)
        XCTAssertEqual(store.totalMXN, 50)
    }

    func testSetAndClearGoal() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setGoal(1000)
        XCTAssertEqual(store.data.goalMXN, 1000)
        store.setGoal(nil)
        XCTAssertNil(store.data.goalMXN)
    }

    func testResetAllEntriesKeepsGoal() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setGoal(1000)
        store.addEntry(amount: 100, currency: .mxn)
        store.resetAllEntries()
        XCTAssertEqual(store.totalMXN, 0)
        XCTAssertEqual(store.data.goalMXN, 1000)
    }

    func testDataPersistsAcrossStoreInstances() {
        let url = makeTempFileURL()
        let store1 = AlcanciaStore(fileURL: url)
        store1.addEntry(amount: 250, currency: .mxn)
        store1.setGoal(5000)

        let store2 = AlcanciaStore(fileURL: url)
        XCTAssertEqual(store2.totalMXN, 250)
        XCTAssertEqual(store2.data.goalMXN, 5000)
    }

    func testCorruptFileFallsBackToEmptyDataWithoutCrashing() throws {
        let url = makeTempFileURL()
        try "not valid json".write(to: url, atomically: true, encoding: .utf8)
        let store = AlcanciaStore(fileURL: url)
        XCTAssertEqual(store.totalMXN, 0)
        XCTAssertNil(store.data.goalMXN)
    }

    func testRecordExchangeRateStoresRateAndDate() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        store.recordExchangeRate(18.75, date: date)
        XCTAssertEqual(store.data.lastKnownUSDMXNRate, 18.75)
        XCTAssertEqual(store.data.lastKnownRateDate, date)
    }

    func testFormattedAmountUsesPesoFormatting() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let formatted = store.formattedAmount(3240)
        XCTAssertTrue(formatted.contains("3,240"), formatted)
        XCTAssertTrue(formatted.contains("$"), formatted)
    }

    func testMenuBarSummaryShowsTotalWhenNoGoal() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 1000, currency: .mxn)
        XCTAssertTrue(store.menuBarSummary.contains("1,000"), store.menuBarSummary)
    }

    func testMenuBarSummaryShowsPercentWhenGoalSet() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setGoal(1000)
        store.addEntry(amount: 250, currency: .mxn)
        XCTAssertEqual(store.menuBarSummary, "25%")
    }
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd alcancia && swift test --filter AlcanciaStoreTests`
Expected: FAIL — `cannot find type 'AlcanciaStore' in scope`.

- [ ] **Step 3: Implement `AlcanciaData` and `AlcanciaStore`**

```swift
// Sources/AlcanciaCore/AlcanciaStore.swift
import Foundation

public struct AlcanciaData: Codable {
    public var goalMXN: Decimal?
    public var entries: [Entry]
    public var lastKnownUSDMXNRate: Double?
    public var lastKnownRateDate: Date?
    public var launchAtLogin: Bool

    public init(
        goalMXN: Decimal? = nil,
        entries: [Entry] = [],
        lastKnownUSDMXNRate: Double? = nil,
        lastKnownRateDate: Date? = nil,
        launchAtLogin: Bool = false
    ) {
        self.goalMXN = goalMXN
        self.entries = entries
        self.lastKnownUSDMXNRate = lastKnownUSDMXNRate
        self.lastKnownRateDate = lastKnownRateDate
        self.launchAtLogin = launchAtLogin
    }
}

@MainActor
public final class AlcanciaStore: ObservableObject {
    @Published public private(set) var data: AlcanciaData

    private let fileURL: URL

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()

    public init(fileURL: URL = AlcanciaStore.defaultFileURL()) {
        self.fileURL = fileURL
        self.data = Self.load(from: fileURL)
    }

    public static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let dir = appSupport.appendingPathComponent("Alcancia", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    public var totalMXN: Decimal {
        data.entries.reduce(Decimal(0)) { $0 + $1.amountInMXN }
    }

    @discardableResult
    public func addEntry(
        amount: Decimal,
        currency: Currency,
        exchangeRate: Double? = nil,
        date: Date = Date()
    ) -> Entry {
        let amountInMXN: Decimal
        let rateUsed: Double?
        switch currency {
        case .mxn:
            amountInMXN = amount
            rateUsed = nil
        case .usd:
            let rate = exchangeRate ?? data.lastKnownUSDMXNRate ?? 1
            amountInMXN = amount * Decimal(rate)
            rateUsed = rate
        }
        let entry = Entry(
            amount: amount,
            currency: currency,
            amountInMXN: amountInMXN,
            exchangeRateUsed: rateUsed,
            date: date
        )
        data.entries.append(entry)
        save()
        return entry
    }

    public func deleteEntry(id: UUID) {
        data.entries.removeAll { $0.id == id }
        save()
    }

    public func setGoal(_ amount: Decimal?) {
        data.goalMXN = amount
        save()
    }

    public func resetAllEntries() {
        data.entries = []
        save()
    }

    public func recordExchangeRate(_ rate: Double, date: Date = Date()) {
        data.lastKnownUSDMXNRate = rate
        data.lastKnownRateDate = date
        save()
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        data.launchAtLogin = enabled
        save()
    }

    public func formattedAmount(_ amount: Decimal) -> String {
        Self.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }

    public var formattedTotal: String {
        formattedAmount(totalMXN)
    }

    public var menuBarSummary: String {
        if let goalMXN = data.goalMXN, goalMXN > 0 {
            let progress = GoalProgress(totalMXN: totalMXN, goalMXN: goalMXN)
            return progress.percentText ?? formattedTotal
        }
        return formattedTotal
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let payload = try encoder.encode(data)
            try payload.write(to: fileURL, options: .atomic)
        } catch {
            print("Alcancía: no se pudo guardar los datos: \(error)")
        }
    }

    private static func load(from url: URL) -> AlcanciaData {
        guard let raw = try? Data(contentsOf: url) else {
            return AlcanciaData()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(AlcanciaData.self, from: raw) {
            return decoded
        }
        let corruptURL = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
        try? FileManager.default.moveItem(at: url, to: corruptURL)
        return AlcanciaData()
    }
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `cd alcancia && swift test --filter AlcanciaStoreTests`
Expected: PASS (10 tests).

- [ ] **Step 5: Run the whole suite to make sure nothing else broke**

Run: `cd alcancia && swift build && swift test`
Expected: build succeeds, all tests pass.

- [ ] **Step 6: Commit**

```bash
cd alcancia
git add Sources/AlcanciaCore/AlcanciaStore.swift Tests/AlcanciaCoreTests/AlcanciaStoreTests.swift
git commit -m "Add AlcanciaStore with JSON persistence, totals, and formatting"
```

---

### Task 4: Exchange rate service (USD → MXN, with offline fallback)

**Files:**
- Create: `Sources/AlcanciaCore/ExchangeRateService.swift`
- Test: `Tests/AlcanciaCoreTests/ExchangeRateServiceTests.swift`

**Interfaces:**
- Consumes: nothing beyond Foundation.
- Produces:
  - `public struct ExchangeRateResult: Equatable { public let rate: Double; public let isFromCache: Bool; public let asOf: Date }`
  - `public protocol ExchangeRateFetching { func fetchUSDToMXNRate() async -> Double? }`
  - `public struct FrankfurterExchangeRateFetcher: ExchangeRateFetching` — real implementation calling `https://api.frankfurter.app/latest?from=USD&to=MXN`.
  - `public struct ExchangeRateService { public init(fetcher: ExchangeRateFetching = FrankfurterExchangeRateFetcher()); public func resolveRate(cachedRate: Double?, cachedDate: Date?) async -> ExchangeRateResult? }` — used by `AddEntryView` (Task 5).

- [ ] **Step 1: Write the failing tests using a fake fetcher (no real network calls in tests)**

```swift
// Tests/AlcanciaCoreTests/ExchangeRateServiceTests.swift
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
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd alcancia && swift test --filter ExchangeRateServiceTests`
Expected: FAIL — `cannot find type 'ExchangeRateFetching' in scope`.

- [ ] **Step 3: Implement the service**

```swift
// Sources/AlcanciaCore/ExchangeRateService.swift
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
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `cd alcancia && swift test --filter ExchangeRateServiceTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd alcancia
git add Sources/AlcanciaCore/ExchangeRateService.swift Tests/AlcanciaCoreTests/ExchangeRateServiceTests.swift
git commit -m "Add ExchangeRateService with offline fallback"
```

---

### Task 5: AddEntryView (add money, USD conversion, manual-rate fallback)

**Files:**
- Create: `Sources/Alcancia/AddEntryView.swift`

**Interfaces:**
- Consumes: `AlcanciaStore` (Task 3): `store.data.lastKnownUSDMXNRate`, `store.data.lastKnownRateDate`, `store.addEntry(amount:currency:exchangeRate:date:)`, `store.recordExchangeRate(_:date:)`. `ExchangeRateService` (Task 4): `resolveRate(cachedRate:cachedDate:)`.
- Produces: `struct AddEntryView: View { init(store: AlcanciaStore) }` — consumed by `MenuBarView` in Task 7.

There are no automated UI tests in this repo's menu bar apps (see `bitacora/`, `ojo/`); this view is verified by compiling and, once wired into the app in Task 7, by manual click-through. This task's deliverable is verified by a successful build.

- [ ] **Step 1: Implement the view**

```swift
// Sources/Alcancia/AddEntryView.swift
import SwiftUI
import AlcanciaCore

struct AddEntryView: View {
    @ObservedObject var store: AlcanciaStore

    @State private var amountText: String = ""
    @State private var currency: Currency = .mxn
    @State private var isResolvingRate = false
    @State private var needsManualRate = false
    @State private var manualRateText: String = ""
    @State private var errorMessage: String?

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }

    private var parsedManualRate: Double? {
        Double(manualRateText.replacingOccurrences(of: ",", with: ""))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Monto", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                Picker("Moneda", selection: $currency) {
                    Text("MXN").tag(Currency.mxn)
                    Text("USD").tag(Currency.usd)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 110)
                .onChange(of: currency) { _, _ in
                    needsManualRate = false
                    errorMessage = nil
                }
            }

            if needsManualRate {
                HStack(spacing: 8) {
                    Text("Tipo de cambio USD→MXN:")
                        .font(.caption)
                    TextField("ej. 18.50", text: $manualRateText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await addEntry() }
            } label: {
                if isResolvingRate {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Agregar")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAddDisabled)
        }
        .padding(14)
    }

    private var isAddDisabled: Bool {
        guard let amount = parsedAmount, amount > 0 else { return true }
        if isResolvingRate { return true }
        if needsManualRate {
            guard let rate = parsedManualRate, rate > 0 else { return true }
        }
        return false
    }

    @MainActor
    private func addEntry() async {
        guard let amount = parsedAmount, amount > 0 else { return }
        errorMessage = nil

        if currency == .mxn {
            store.addEntry(amount: amount, currency: .mxn)
            amountText = ""
            return
        }

        if needsManualRate {
            guard let rate = parsedManualRate, rate > 0 else { return }
            store.recordExchangeRate(rate)
            store.addEntry(amount: amount, currency: .usd, exchangeRate: rate)
            amountText = ""
            manualRateText = ""
            needsManualRate = false
            return
        }

        isResolvingRate = true
        let service = ExchangeRateService()
        let result = await service.resolveRate(
            cachedRate: store.data.lastKnownUSDMXNRate,
            cachedDate: store.data.lastKnownRateDate
        )
        isResolvingRate = false

        guard let result else {
            needsManualRate = true
            errorMessage = "Sin conexión y sin tipo de cambio previo. Escribe el tipo de cambio para continuar."
            return
        }

        if !result.isFromCache {
            store.recordExchangeRate(result.rate, date: result.asOf)
        }
        store.addEntry(amount: amount, currency: .usd, exchangeRate: result.rate)
        amountText = ""
    }
}
```

- [ ] **Step 2: Confirm it compiles**

Run: `cd alcancia && swift build`
Expected: build succeeds (this file isn't referenced anywhere yet, so SwiftPM compiles it as part of the `Alcancia` target with no warnings about being unused).

- [ ] **Step 3: Commit**

```bash
cd alcancia
git add Sources/Alcancia/AddEntryView.swift
git commit -m "Add AddEntryView with USD conversion and manual-rate fallback"
```

---

### Task 6: HistoryView (list entries, delete with confirmation)

**Files:**
- Create: `Sources/Alcancia/HistoryView.swift`

**Interfaces:**
- Consumes: `AlcanciaStore.data.entries`, `AlcanciaStore.formattedAmount(_:)`, `AlcanciaStore.deleteEntry(id:)`, `Entry` fields (`id`, `amountInMXN`, `amount`, `currency`, `date`).
- Produces: `struct HistoryView: View { init(store: AlcanciaStore) }` — consumed by `MenuBarView` in Task 7.

- [ ] **Step 1: Implement the view**

```swift
// Sources/Alcancia/HistoryView.swift
import SwiftUI
import AlcanciaCore

struct HistoryView: View {
    @ObservedObject var store: AlcanciaStore
    @State private var pendingDeleteID: UUID?

    private var sortedEntries: [Entry] {
        store.data.entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if sortedEntries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedEntries) { entry in
                            row(for: entry)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .confirmationDialog(
            "¿Borrar esta entrada?",
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { isPresented in
                    if !isPresented { pendingDeleteID = nil }
                }
            )
        ) {
            Button("Borrar", role: .destructive) {
                if let id = pendingDeleteID {
                    store.deleteEntry(id: id)
                }
                pendingDeleteID = nil
            }
            Button("Cancelar", role: .cancel) {
                pendingDeleteID = nil
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("Todavía no has agregado nada")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func row(for entry: Entry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.formattedAmount(entry.amountInMXN))
                    .font(.subheadline)
                Text(Self.dateFormatter.string(from: entry.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if entry.currency == .usd {
                Text("USD \(entry.amount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button {
                pendingDeleteID = entry.id
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
}
```

- [ ] **Step 2: Confirm it compiles**

Run: `cd alcancia && swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
cd alcancia
git add Sources/Alcancia/HistoryView.swift
git commit -m "Add HistoryView with per-entry delete confirmation"
```

---

### Task 7: SettingsView + launch-at-login

**Files:**
- Create: `Sources/Alcancia/LoginItemManager.swift`
- Create: `Sources/Alcancia/SettingsView.swift`

**Interfaces:**
- Consumes: `AlcanciaStore.data.goalMXN`, `.lastKnownUSDMXNRate`, `.lastKnownRateDate`, `.launchAtLogin`; `store.setGoal(_:)`, `store.resetAllEntries()`, `store.setLaunchAtLogin(_:)`.
- Produces: `enum LoginItemManager { static func setEnabled(_ enabled: Bool) }`; `struct SettingsView: View { init(store: AlcanciaStore) }` — consumed by `MenuBarView` in Task 8.

- [ ] **Step 1: Implement the login-item wrapper**

```swift
// Sources/Alcancia/LoginItemManager.swift
import Foundation
import ServiceManagement

enum LoginItemManager {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Alcancía: no se pudo cambiar el inicio automático: \(error)")
        }
    }
}
```

- [ ] **Step 2: Implement the settings view**

```swift
// Sources/Alcancia/SettingsView.swift
import SwiftUI
import AlcanciaCore

struct SettingsView: View {
    @ObservedObject var store: AlcanciaStore
    @Environment(\.dismiss) private var dismiss

    @State private var goalText: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ajustes")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Meta (MXN)")
                    .font(.subheadline)
                HStack {
                    TextField("ej. 10000", text: $goalText)
                        .textFieldStyle(.roundedBorder)
                    Button("Guardar") {
                        saveGoal()
                    }
                    if store.data.goalMXN != nil {
                        Button("Quitar meta") {
                            store.setGoal(nil)
                            goalText = ""
                        }
                        .foregroundStyle(.red)
                    }
                }
            }

            if let rate = store.data.lastKnownUSDMXNRate {
                Text(exchangeRateText(rate: rate, date: store.data.lastKnownRateDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Iniciar con el sistema", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LoginItemManager.setEnabled(newValue)
                    store.setLaunchAtLogin(newValue)
                }

            Divider()

            Button("Borrar todo el historial", role: .destructive) {
                showingResetConfirmation = true
            }
            .confirmationDialog(
                "¿Borrar todo el historial? Esta acción no se puede deshacer.",
                isPresented: $showingResetConfirmation
            ) {
                Button("Borrar todo", role: .destructive) {
                    store.resetAllEntries()
                }
                Button("Cancelar", role: .cancel) {}
            }

            Spacer()

            Button("Cerrar") { dismiss() }
        }
        .padding(20)
        .frame(width: 300, height: 380)
        .onAppear {
            if let goal = store.data.goalMXN {
                goalText = "\(goal)"
            }
            launchAtLogin = store.data.launchAtLogin
        }
    }

    private func saveGoal() {
        guard let value = Decimal(string: goalText.replacingOccurrences(of: ",", with: "")),
              value > 0 else { return }
        store.setGoal(value)
    }

    private func exchangeRateText(rate: Double, date: Date?) -> String {
        let rateText = String(format: "Tipo de cambio guardado: %.2f MXN por USD", rate)
        guard let date else { return rateText }
        return rateText + " (\(Self.dateFormatter.string(from: date)))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
}
```

- [ ] **Step 3: Confirm it compiles**

Run: `cd alcancia && swift build`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
cd alcancia
git add Sources/Alcancia/LoginItemManager.swift Sources/Alcancia/SettingsView.swift
git commit -m "Add SettingsView with goal management and launch-at-login"
```

---

### Task 8: Wire it all together — MenuBarView + real app entry point

**Files:**
- Create: `Sources/Alcancia/MenuBarView.swift`
- Modify: `Sources/Alcancia/AlcanciaAppMain.swift` (replace the Task 1 placeholder body entirely)

**Interfaces:**
- Consumes: `AlcanciaStore` (Task 3), `GoalProgress` (Task 2), `AddEntryView` (Task 5), `HistoryView` (Task 6), `SettingsView` (Task 7).
- Produces: `struct MenuBarView: View { init(store: AlcanciaStore) }`; the app now boots a real `AlcanciaStore()` backed by the default file location.

- [ ] **Step 1: Implement `MenuBarView`**

```swift
// Sources/Alcancia/MenuBarView.swift
import SwiftUI
import AlcanciaCore

struct MenuBarView: View {
    @ObservedObject var store: AlcanciaStore
    @State private var showingSettings = false

    private var goalProgress: GoalProgress {
        GoalProgress(totalMXN: store.totalMXN, goalMXN: store.data.goalMXN)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            AddEntryView(store: store)
            Divider()
            HistoryView(store: store)
            Divider()
            footer
        }
        .frame(width: 320, height: 460)
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.formattedTotal)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            if let goalMXN = store.data.goalMXN, let fraction = goalProgress.fraction {
                ProgressView(value: fraction)
                Text("\(store.formattedTotal) de \(store.formattedAmount(goalMXN))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Sin meta definida")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    private var footer: some View {
        HStack {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("Salir") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
```

- [ ] **Step 2: Replace the placeholder app entry point**

```swift
// Sources/Alcancia/AlcanciaAppMain.swift
import SwiftUI
import AlcanciaCore

@main
struct AlcanciaAppMain: App {
    @StateObject private var store = AlcanciaStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            Text(store.menuBarSummary)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 3: Build and run it directly (no packaging yet) to smoke-test the whole flow**

Run: `cd alcancia && swift build && swift run Alcancia`

While it's running, manually verify in the live menu bar item (top-right of the screen):
- A menu bar item appears showing `$0` (or whatever the current total formats to).
- Clicking it opens the popover: total, "Sin meta definida", an amount field with MXN/USD picker, an empty history list, and gear/Salir buttons.
- Type `100` and click "Agregar" — the total updates to `$100` and a history row appears.
- Click the trash icon on that row, confirm — the entry disappears and the total goes back to `$0`.
- Click the gear icon, type `1000` in "Meta (MXN)", click "Guardar", close settings — the header now shows a progress bar and "$0 de $1,000", and the menu bar label switches to a percentage.
- Click "Salir" to quit the running instance (`Ctrl+C` in the terminal also works if "Salir" doesn't trigger inside `swift run`).

Expected: all of the above works as described. Fix any issue before moving on — this is the first time the whole app runs end to end.

- [ ] **Step 4: Run the full test suite once more**

Run: `cd alcancia && swift test`
Expected: all `AlcanciaCoreTests` still pass (UI changes don't touch `AlcanciaCore`).

- [ ] **Step 5: Commit**

```bash
cd alcancia
git add Sources/Alcancia/MenuBarView.swift Sources/Alcancia/AlcanciaAppMain.swift
git commit -m "Wire MenuBarView and real AlcanciaStore into the app entry point"
```

---

### Task 9: Packaging script + README

**Files:**
- Create: `build_app.sh`
- Create: `README.md`

**Interfaces:**
- Consumes: the `Alcancia` executable target (Task 8).
- Produces: `Alcancía.app` bundle in the project root, ad-hoc signed, `LSUIElement = true`.

- [ ] **Step 1: Create `build_app.sh`, adapted from `bitacora/build_app.sh` with this project's names**

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Alcancía"
BIN_NAME="Alcancia"
BUILD_CONFIG="release"

echo "Compilando en modo $BUILD_CONFIG..."
swift build -c "$BUILD_CONFIG"

BIN_PATH=$(swift build -c "$BUILD_CONFIG" --show-bin-path)
APP_BUNDLE="./${APP_NAME}.app"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH/$BIN_NAME" "$APP_BUNDLE/Contents/MacOS/$BIN_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$BIN_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.mvisuals.alcancia</string>
    <key>CFBundleExecutable</key>
    <string>${BIN_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Firmando ad-hoc para que Gatekeeper lo deje correr localmente..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Listo: $APP_BUNDLE"
echo "Abrilo con: open \"$APP_BUNDLE\""
echo "O movelo a /Applications para tenerlo siempre disponible."
```

- [ ] **Step 2: Make it executable and run it**

Run: `cd alcancia && chmod +x build_app.sh && ./build_app.sh`
Expected: ends with `Listo: ./Alcancía.app`, no codesign errors.

- [ ] **Step 3: Launch the packaged app and verify it behaves like Task 8's `swift run` smoke test**

Run: `open "alcancia/Alcancía.app"`

Verify: the menu bar item appears (no Dock icon, since `LSUIElement` is true), clicking it opens the same popover as before, adding an entry in MXN works, adding one in USD triggers the live exchange-rate lookup (or the manual-rate field if offline) and converts correctly, and the "Iniciar con el sistema" toggle in settings doesn't crash the app (macOS may prompt for Login Items approval — that's expected `SMAppService` behavior, not a bug).

- [ ] **Step 4: Write `README.md`**

```markdown
# Alcancía

Una app nativa de barra de menú para macOS que lleva el registro del
dinero que vas ganando. Todo local, sin cuenta, sin nube — mismo
espíritu que Bitácora y Ojo en este repo.

## Qué hace

- **Vive en la barra de menú** (sin ícono en el Dock). El ícono
  muestra el total acumulado en pesos, o el porcentaje de avance si
  definiste una meta.
- **Agregar dinero ganado**: escribes un monto en pesos o dólares; si
  es en dólares, se convierte automáticamente a pesos usando el tipo
  de cambio del momento (o el último guardado si no hay internet).
- **Meta opcional**: si defines una meta en pesos, ves una barra de
  progreso y el porcentaje en el ícono. Sin meta, solo ves el total.
- **Historial**: cada entrada queda con su fecha; puedes borrar
  alguna si te equivocaste.
- **Ajustes**: definir/quitar la meta, ver el tipo de cambio guardado,
  borrar todo el historial, e iniciar automáticamente con el sistema.

## Cómo se guarda

Todo en un archivo JSON local en
`~/Library/Application Support/Alcancia/data.json`. Sin telemetría,
sin red — salvo la consulta pública y gratuita del tipo de cambio
USD→MXN (api.frankfurter.app) cuando agregas una entrada en dólares.

## Estructura

\```
alcancia/
  Package.swift
  Sources/
    AlcanciaCore/   # modelos, persistencia, tipo de cambio, meta —
                     # sin UI, 100% testeado con `swift test`
    Alcancia/        # la app SwiftUI (MenuBarExtra)
  Tests/
    AlcanciaCoreTests/
  build_app.sh       # empaqueta Alcancía.app firmado ad-hoc
\```

## Cómo correrla

Compilarla y empaquetarla:

\```bash
cd alcancia
./build_app.sh
open "Alcancía.app"
\```

O moverla a `/Applications` para tenerla siempre a mano:

\```bash
mv "Alcancía.app" /Applications/
\```

Para correr solo los tests:

\```bash
swift test
\```

Para correr sin empaquetar, mientras desarrollas:

\```bash
swift run Alcancia
\```
```

- [ ] **Step 5: Commit**

```bash
cd alcancia
git add build_app.sh README.md
git commit -m "Add packaging script and README"
```

---

## Post-plan note

`Alcancía.app` and `.build/` are git-ignored (Task 1's `.gitignore`), so the built app itself isn't committed — only source. After Task 9, the working app lives at `alcancia/Alcancía.app`; move it to `/Applications` if it should survive the source folder being cleaned up.
