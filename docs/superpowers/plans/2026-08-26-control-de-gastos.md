# Expense-Control Pivot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Alcancía from an income-and-savings-goal tracker into an expense-control app: monthly budget, categories, sub-3-second capture, per-month breakdown, and a piggy bank that drains as the month's budget is spent.

**Architecture:** Same two-target Swift package. `AlcanciaCore` gains `Category`, `EntryKind`, `BudgetProgress` (replacing `GoalProgress`), and `MonthlySummary` — all pure, all unit tested. The `Alcancia` SwiftUI target is recomposed around a month view with an auto-focused quick-add row, plus a new floating desktop panel. Persistence stays a single local JSON file, now decoded tolerantly so files written by the previous version survive.

**Tech Stack:** Swift 5.10, SwiftUI, AppKit (`NSPanel` for the desktop panel), ServiceManagement, no third-party dependencies.

**Spec:** [`docs/superpowers/specs/2026-08-26-control-de-gastos-design.md`](../specs/2026-08-26-control-de-gastos-design.md)

## Global Constraints

- Platform macOS 14+, `swift-tools-version: 5.10`, no third-party dependencies.
- **Every field added after the first version MUST be decoded with `decodeIfPresent` plus a default.** A decode failure makes `AlcanciaStore.load` quarantine the file and start empty, which reads to the user as "the app deleted my money". This is the single highest-stakes rule in the plan.
- Entries written by the previous version have no `kind` and decode as `.income` (that version only tracked money earned), with `category: nil` and `note: nil`.
- Base currency MXN. `formattedAmount` keeps 0 fraction digits and the `es_MX` locale — display rounds, storage stays exact `Decimal`.
- All money math is `Decimal`. Any `Decimal → Int` conversion must clamp first (a tiny budget once overflowed `Int` and crash-looped the app).
- UI copy is Spanish (Mexico), matching the existing app.
- SwiftUI views carry no automated tests — this repo's established pattern. A clean `swift build` with **zero warnings** is the acceptance bar for view tasks.

---

## File Structure

```
Sources/AlcanciaCore/
  Entry.swift              MODIFY  Entry + Currency + EntryKind, tolerant decoding
  Category.swift           CREATE  category enum with emoji + Spanish label
  BudgetProgress.swift     CREATE  added in Task 2; GoalProgress.swift deleted in Task 7
  MonthlySummary.swift     CREATE  per-month totals + category breakdown
  AlcanciaStore.swift      MODIFY  budget, categories, per-month queries
  ExchangeRateService.swift        unchanged
Sources/Alcancia/
  AlcanciaAppMain.swift    MODIFY  piggy reflects remaining budget
  MenuBarView.swift        MODIFY  recomposed around the month
  MonthHeaderView.swift    CREATE  month navigation + budget bar
  QuickAddView.swift       CREATE  added in Task 5; AddEntryView.swift deleted in Task 7
  CategoryRowView.swift    CREATE  emoji picker row
  CategoryBreakdownView.swift CREATE  per-category bars
  HistoryView.swift        MODIFY  category, note, sign, colour
  SettingsView.swift       MODIFY  budget instead of goal, panel toggle
  DesktopPanelController.swift CREATE floating NSPanel
  DesktopPanelView.swift   CREATE  its contents
  PiggyBankIcon.swift              unchanged
  LoginItemManager.swift           unchanged
Tests/AlcanciaCoreTests/
  EntryTests.swift         MODIFY  + legacy-format migration test
  CategoryTests.swift      CREATE
  BudgetProgressTests.swift CREATE added in Task 2; GoalProgressTests.swift deleted in Task 7
  MonthlySummaryTests.swift CREATE
  AlcanciaStoreTests.swift MODIFY  budget, kinds, categories, legacy file
  ExchangeRateServiceTests.swift   unchanged
```

---

### Task 1: Category + EntryKind + tolerant Entry decoding

**Files:**
- Create: `Sources/AlcanciaCore/Category.swift`
- Modify: `Sources/AlcanciaCore/Entry.swift`
- Test: `Tests/AlcanciaCoreTests/CategoryTests.swift` (create), `Tests/AlcanciaCoreTests/EntryTests.swift` (modify)

**Interfaces:**
- Produces: `public enum Category: String, Codable, CaseIterable, Identifiable` with cases `comida, mercado, transporte, casa, software, ocio, salud, otro` and properties `emoji: String`, `label: String`.
- Produces: `public enum EntryKind: String, Codable, CaseIterable { case expense, income }`.
- Produces: `Entry` gaining `kind: EntryKind`, `category: Category?`, `note: String?`, with `init(id:amount:currency:amountInMXN:exchangeRateUsed:date:kind:category:note:)` — `kind` defaults to `.expense`, `category` and `note` to `nil`.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/AlcanciaCoreTests/CategoryTests.swift
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
```

```swift
// Tests/AlcanciaCoreTests/EntryTests.swift — REPLACE the whole file
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
            note: "Adobe"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        let decoded = try makeDecoder().decode(Entry.self, from: data)
        XCTAssertEqual(decoded, entry)
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
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd alcancia && swift test --filter EntryTests 2>&1 | tail -20`
Expected: FAIL — `Entry` has no `kind`, and `Category` does not exist.

- [ ] **Step 3: Create `Category.swift`**

```swift
// Sources/AlcanciaCore/Category.swift
import Foundation

/// Las categorías de gasto. Son fijas a propósito: elegir de ocho emojis es
/// un clic, y mantener la captura por debajo de tres segundos manda sobre la
/// flexibilidad de tener categorías personalizadas.
public enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
    case comida
    case mercado
    case transporte
    case casa
    case software
    case ocio
    case salud
    case otro

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .comida: return "🍔"
        case .mercado: return "🛒"
        case .transporte: return "🚗"
        case .casa: return "🏠"
        case .software: return "💻"
        case .ocio: return "🎬"
        case .salud: return "💊"
        case .otro: return "📦"
        }
    }

    public var label: String {
        switch self {
        case .comida: return "Comida"
        case .mercado: return "Súper"
        case .transporte: return "Transporte"
        case .casa: return "Casa"
        case .software: return "Software"
        case .ocio: return "Ocio"
        case .salud: return "Salud"
        case .otro: return "Otro"
        }
    }
}
```

- [ ] **Step 4: Rewrite `Entry.swift` with tolerant decoding**

```swift
// Sources/AlcanciaCore/Entry.swift
import Foundation

public enum Currency: String, Codable, CaseIterable {
    case mxn
    case usd
}

public enum EntryKind: String, Codable, CaseIterable, Sendable {
    case expense
    case income
}

public struct Entry: Identifiable, Codable, Equatable {
    public let id: UUID
    public var amount: Decimal
    public var currency: Currency
    public var amountInMXN: Decimal
    public var exchangeRateUsed: Double?
    public var date: Date
    public var kind: EntryKind
    public var category: Category?
    public var note: String?

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        currency: Currency,
        amountInMXN: Decimal,
        exchangeRateUsed: Double? = nil,
        date: Date = Date(),
        kind: EntryKind = .expense,
        category: Category? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.amountInMXN = amountInMXN
        self.exchangeRateUsed = exchangeRateUsed
        self.date = date
        self.kind = kind
        self.category = category
        self.note = note
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        amount = try container.decode(Decimal.self, forKey: .amount)
        currency = try container.decode(Currency.self, forKey: .currency)
        amountInMXN = try container.decode(Decimal.self, forKey: .amountInMXN)
        exchangeRateUsed = try container.decodeIfPresent(Double.self, forKey: .exchangeRateUsed)
        date = try container.decode(Date.self, forKey: .date)
        // Campos agregados después de la primera versión. Un movimiento sin
        // `kind` viene de la versión que sólo registraba dinero ganado, así que
        // se lee como ingreso — nunca como gasto, que falsearía los totales.
        kind = try container.decodeIfPresent(EntryKind.self, forKey: .kind) ?? .income
        category = try container.decodeIfPresent(Category.self, forKey: .category)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}
```

- [ ] **Step 5: Run the tests to confirm they pass**

Run: `cd alcancia && swift build && swift test 2>&1 | tail -6`
Expected: build succeeds and the whole suite passes — 4 `EntryTests`, 2 new `CategoryTests`, and everything that already existed. `Entry`'s new fields all have defaults, so existing callers keep compiling untouched.

If the package does not build here, stop and report it rather than pressing on: every task in this plan is required to leave `swift build` and `swift test` green, because `swift test` compiles the executable target too and a broken UI silently blocks the entire suite.

- [ ] **Step 6: Commit**

```bash
cd alcancia
git add Sources/AlcanciaCore/Category.swift Sources/AlcanciaCore/Entry.swift Tests/AlcanciaCoreTests/CategoryTests.swift Tests/AlcanciaCoreTests/EntryTests.swift
git commit -m "Add expense categories and entry kinds with tolerant decoding"
```

---

### Task 2: BudgetProgress (added alongside GoalProgress)

**Files:**
- Create: `Sources/AlcanciaCore/BudgetProgress.swift`
- Create: `Tests/AlcanciaCoreTests/BudgetProgressTests.swift`

**Interfaces:**
- Consumes: nothing beyond Foundation.
- Produces: `public struct BudgetProgress { public init(spentMXN: Decimal, budgetMXN: Decimal?); public var remainingMXN: Decimal?; public var fractionRemaining: Double?; public var isOverBudget: Bool; public var percentSpentText: String? }`. `AlcanciaStore` (Task 4) and `MenuBarView` (Task 8) consume it.

**This task is purely additive.** `GoalProgress.swift` and `GoalProgressTests.swift` stay exactly where they are: `AlcanciaStore.menuBarSummary` and `AlcanciaAppMain` still reference `GoalProgress`, and `swift test` builds the executable target too — deleting it here would stop the whole suite from running, not just this task's tests. Both files are removed in Task 7, in the same commit that drops their last caller.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/AlcanciaCoreTests/BudgetProgressTests.swift
import XCTest
@testable import AlcanciaCore

final class BudgetProgressTests: XCTestCase {
    func testNoBudgetLeavesEverythingUnknown() {
        let progress = BudgetProgress(spentMXN: 500, budgetMXN: nil)
        XCTAssertNil(progress.remainingMXN)
        XCTAssertNil(progress.fractionRemaining)
        XCTAssertNil(progress.percentSpentText)
        XCTAssertFalse(progress.isOverBudget)
    }

    func testZeroBudgetTreatedAsNoBudget() {
        let progress = BudgetProgress(spentMXN: 500, budgetMXN: 0)
        XCTAssertNil(progress.fractionRemaining)
        XCTAssertFalse(progress.isOverBudget)
    }

    func testUntouchedBudgetIsFull() {
        let progress = BudgetProgress(spentMXN: 0, budgetMXN: 8000)
        XCTAssertEqual(progress.fractionRemaining ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertEqual(progress.remainingMXN, 8000)
        XCTAssertEqual(progress.percentSpentText, "0%")
        XCTAssertFalse(progress.isOverBudget)
    }

    func testHalfSpent() {
        let progress = BudgetProgress(spentMXN: 4000, budgetMXN: 8000)
        XCTAssertEqual(progress.fractionRemaining ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(progress.remainingMXN, 4000)
        XCTAssertEqual(progress.percentSpentText, "50%")
        XCTAssertFalse(progress.isOverBudget)
    }

    func testExactlySpentIsNotOverBudget() {
        let progress = BudgetProgress(spentMXN: 8000, budgetMXN: 8000)
        XCTAssertEqual(progress.fractionRemaining ?? -1, 0.0, accuracy: 0.0001)
        XCTAssertEqual(progress.remainingMXN, 0)
        XCTAssertFalse(progress.isOverBudget)
    }

    func testOverBudgetEmptiesThePiggyAndReportsTheOverage() {
        let progress = BudgetProgress(spentMXN: 9000, budgetMXN: 8000)
        XCTAssertEqual(progress.fractionRemaining ?? -1, 0.0, accuracy: 0.0001)
        XCTAssertEqual(progress.remainingMXN, -1000)
        XCTAssertTrue(progress.isOverBudget)
        XCTAssertEqual(progress.percentSpentText, "113%")
    }

    /// Un presupuesto absurdamente chico desbordaba Int y tiraba la app en un
    /// ciclo de arranque; el porcentaje tiene que acotarse antes de convertir.
    func testAbsurdlySmallBudgetDoesNotCrash() {
        let progress = BudgetProgress(
            spentMXN: 1000,
            budgetMXN: Decimal(string: "0.0000000000000000001")!
        )
        XCTAssertEqual(progress.percentSpentText, "999999999999%")
        XCTAssertEqual(progress.fractionRemaining ?? -1, 0.0, accuracy: 0.0001)
        XCTAssertTrue(progress.isOverBudget)
    }
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd alcancia && swift test --filter BudgetProgressTests`
Expected: FAIL — `cannot find 'BudgetProgress' in scope`.

- [ ] **Step 3: Create `BudgetProgress.swift`**

```swift
// Sources/AlcanciaCore/BudgetProgress.swift
import Foundation

/// Cuánto del presupuesto del mes queda. El cerdito de la barra de menú se
/// rellena con `fractionRemaining`: lleno al empezar el mes, vacío cuando se
/// acabó.
public struct BudgetProgress {
    public let spentMXN: Decimal
    public let budgetMXN: Decimal?

    public init(spentMXN: Decimal, budgetMXN: Decimal?) {
        self.spentMXN = spentMXN
        self.budgetMXN = budgetMXN
    }

    /// Un presupuesto de cero o menos cuenta como "sin presupuesto".
    private var activeBudget: Decimal? {
        guard let budgetMXN, budgetMXN > 0 else { return nil }
        return budgetMXN
    }

    /// Negativo cuando te pasaste.
    public var remainingMXN: Decimal? {
        guard let activeBudget else { return nil }
        return activeBudget - spentMXN
    }

    /// Acotada a 0...1 por ambos extremos, lista para `ProgressView` y para el
    /// relleno del cerdito.
    public var fractionRemaining: Double? {
        guard let activeBudget, let remainingMXN else { return nil }
        let ratio = remainingMXN / activeBudget
        let value = NSDecimalNumber(decimal: ratio).doubleValue
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    public var isOverBudget: Bool {
        guard let remainingMXN else { return false }
        return remainingMXN < 0
    }

    /// Sin acotar por arriba: puede pasar de 100% cuando te pasaste. Se acota
    /// antes de convertir a Int para que un presupuesto minúsculo no desborde.
    public var percentSpentText: String? {
        guard let activeBudget else { return nil }
        let ratio = spentMXN / activeBudget
        let value = NSDecimalNumber(decimal: ratio).doubleValue
        guard value.isFinite else { return nil }
        let scaled = min((value * 100).rounded(), 999_999_999_999)
        return "\(Int(max(scaled, 0)))%"
    }
}
```

- [ ] **Step 4: Run the whole suite**

Run: `cd alcancia && swift build && swift test 2>&1 | tail -6`
Expected: build succeeds and every test passes — the 7 new `BudgetProgressTests` plus everything that already existed. The package must stay green; nothing was removed.

- [ ] **Step 5: Commit**

```bash
cd alcancia
git add Sources/AlcanciaCore/BudgetProgress.swift Tests/AlcanciaCoreTests/BudgetProgressTests.swift
git commit -m "Add BudgetProgress alongside the existing goal math"
```

---

### Task 3: MonthlySummary

**Files:**
- Create: `Sources/AlcanciaCore/MonthlySummary.swift`
- Test: `Tests/AlcanciaCoreTests/MonthlySummaryTests.swift`

**Interfaces:**
- Consumes: `Entry`, `EntryKind`, `Category` (Task 1).
- Produces: `public struct CategoryTotal: Identifiable, Equatable { public let category: Category; public let amountMXN: Decimal; public let fractionOfTotal: Double; public var id: String }` and `public struct MonthlySummary { public init(entries: [Entry], month: Date, calendar: Calendar = .current); public let month: Date; public let entriesInMonth: [Entry]; public let totalSpentMXN: Decimal; public let totalIncomeMXN: Decimal; public let byCategory: [CategoryTotal] }`. `AlcanciaStore` (Task 4) and the views (Tasks 7-8) consume it.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/AlcanciaCoreTests/MonthlySummaryTests.swift
import XCTest
@testable import AlcanciaCore

final class MonthlySummaryTests: XCTestCase {
    /// Calendario fijo para que los límites de mes no dependan de la máquina.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour
        ))!
    }

    private func expense(_ amount: Decimal, _ category: Category, on date: Date) -> Entry {
        Entry(amount: amount, currency: .mxn, amountInMXN: amount,
              date: date, kind: .expense, category: category)
    }

    private func income(_ amount: Decimal, on date: Date) -> Entry {
        Entry(amount: amount, currency: .mxn, amountInMXN: amount,
              date: date, kind: .income)
    }

    func testEmptyMonthTotalsZero() {
        let summary = MonthlySummary(entries: [], month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.totalSpentMXN, 0)
        XCTAssertEqual(summary.totalIncomeMXN, 0)
        XCTAssertTrue(summary.byCategory.isEmpty)
        XCTAssertTrue(summary.entriesInMonth.isEmpty)
    }

    func testIncomeDoesNotCountAsSpending() {
        let entries = [
            expense(300, .comida, on: date(2026, 8, 5)),
            income(5000, on: date(2026, 8, 6))
        ]
        let summary = MonthlySummary(entries: entries, month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.totalSpentMXN, 300)
        XCTAssertEqual(summary.totalIncomeMXN, 5000)
        XCTAssertEqual(summary.byCategory.count, 1)
    }

    func testOnlyEntriesInsideTheMonthCount() {
        let entries = [
            expense(100, .comida, on: date(2026, 7, 31, 23)),
            expense(200, .comida, on: date(2026, 8, 1, 0)),
            expense(400, .comida, on: date(2026, 8, 31, 23)),
            expense(800, .comida, on: date(2026, 9, 1, 0))
        ]
        let summary = MonthlySummary(entries: entries, month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.totalSpentMXN, 600)
        XCTAssertEqual(summary.entriesInMonth.count, 2)
    }

    func testCategoryBreakdownIsSortedLargestFirstWithShares() {
        let entries = [
            expense(100, .comida, on: date(2026, 8, 2)),
            expense(300, .transporte, on: date(2026, 8, 3)),
            expense(100, .comida, on: date(2026, 8, 4))
        ]
        let summary = MonthlySummary(entries: entries, month: date(2026, 8, 15), calendar: calendar)

        XCTAssertEqual(summary.byCategory.map(\.category), [.transporte, .comida])
        XCTAssertEqual(summary.byCategory[0].amountMXN, 300)
        XCTAssertEqual(summary.byCategory[1].amountMXN, 200)
        XCTAssertEqual(summary.byCategory[0].fractionOfTotal, 0.6, accuracy: 0.0001)
        XCTAssertEqual(summary.byCategory[1].fractionOfTotal, 0.4, accuracy: 0.0001)
    }

    func testExpenseWithoutCategoryFallsUnderOtro() {
        let entry = Entry(amount: 250, currency: .mxn, amountInMXN: 250,
                          date: date(2026, 8, 7), kind: .expense, category: nil)
        let summary = MonthlySummary(entries: [entry], month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.byCategory.map(\.category), [.otro])
        XCTAssertEqual(summary.totalSpentMXN, 250)
    }

    func testEntriesInMonthAreNewestFirst() {
        let older = expense(100, .comida, on: date(2026, 8, 2))
        let newer = expense(200, .comida, on: date(2026, 8, 20))
        let summary = MonthlySummary(entries: [older, newer], month: date(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(summary.entriesInMonth.first?.id, newer.id)
        XCTAssertEqual(summary.entriesInMonth.last?.id, older.id)
    }
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd alcancia && swift test --filter MonthlySummaryTests`
Expected: FAIL — `cannot find 'MonthlySummary' in scope`.

- [ ] **Step 3: Create `MonthlySummary.swift`**

```swift
// Sources/AlcanciaCore/MonthlySummary.swift
import Foundation

public struct CategoryTotal: Identifiable, Equatable {
    public let category: Category
    public let amountMXN: Decimal
    /// Parte del gasto total del mes, de 0 a 1, para dibujar la barra.
    public let fractionOfTotal: Double

    public var id: String { category.rawValue }

    public init(category: Category, amountMXN: Decimal, fractionOfTotal: Double) {
        self.category = category
        self.amountMXN = amountMXN
        self.fractionOfTotal = fractionOfTotal
    }
}

/// Todo lo que la interfaz necesita saber de un mes, calculado de una pasada.
public struct MonthlySummary {
    public let month: Date
    /// Del más reciente al más viejo.
    public let entriesInMonth: [Entry]
    public let totalSpentMXN: Decimal
    public let totalIncomeMXN: Decimal
    /// Sólo categorías con gasto, de mayor a menor.
    public let byCategory: [CategoryTotal]

    public init(entries: [Entry], month: Date, calendar: Calendar = .current) {
        self.month = month

        guard let interval = calendar.dateInterval(of: .month, for: month) else {
            self.entriesInMonth = []
            self.totalSpentMXN = 0
            self.totalIncomeMXN = 0
            self.byCategory = []
            return
        }

        let inMonth = entries
            .filter { interval.contains($0.date) }
            .sorted { $0.date > $1.date }
        self.entriesInMonth = inMonth

        let expenses = inMonth.filter { $0.kind == .expense }
        let spent = expenses.reduce(Decimal(0)) { $0 + $1.amountInMXN }
        self.totalSpentMXN = spent
        self.totalIncomeMXN = inMonth
            .filter { $0.kind == .income }
            .reduce(Decimal(0)) { $0 + $1.amountInMXN }

        var totals: [Category: Decimal] = [:]
        for expense in expenses {
            // Un gasto sin categoría cuenta como "Otro" en vez de desaparecer
            // del desglose.
            let category = expense.category ?? .otro
            totals[category, default: 0] += expense.amountInMXN
        }

        let spentDouble = NSDecimalNumber(decimal: spent).doubleValue
        self.byCategory = totals
            .map { category, amount in
                let share = spentDouble > 0
                    ? NSDecimalNumber(decimal: amount).doubleValue / spentDouble
                    : 0
                return CategoryTotal(
                    category: category,
                    amountMXN: amount,
                    fractionOfTotal: share
                )
            }
            .sorted { left, right in
                // Empate resuelto por el orden fijo del enum, para que la lista
                // no baile entre renders.
                if left.amountMXN == right.amountMXN {
                    return categoryOrder(left.category) < categoryOrder(right.category)
                }
                return left.amountMXN > right.amountMXN
            }
    }
}

private func categoryOrder(_ category: Category) -> Int {
    Category.allCases.firstIndex(of: category) ?? Category.allCases.count
}
```

- [ ] **Step 4: Run the whole suite**

Run: `cd alcancia && swift build && swift test 2>&1 | tail -6`
Expected: build succeeds and every test passes, including the 6 new `MonthlySummaryTests`. This task is additive; the package stays green.

- [ ] **Step 5: Commit**

```bash
cd alcancia
git add Sources/AlcanciaCore/MonthlySummary.swift Tests/AlcanciaCoreTests/MonthlySummaryTests.swift
git commit -m "Add MonthlySummary with per-category breakdown"
```

---

### Task 4: AlcanciaStore — budget, kinds, categories, per-month queries

**Files:**
- Modify: `Sources/AlcanciaCore/AlcanciaStore.swift`
- Modify: `Tests/AlcanciaCoreTests/AlcanciaStoreTests.swift`

**Interfaces:**
- Consumes: `Entry`, `EntryKind`, `Category` (Task 1), `BudgetProgress` (Task 2), `MonthlySummary` (Task 3).
- Produces:
  - `AlcanciaData` gaining `monthlyBudgetMXN: Decimal?`, `lastUsedCategory: Category?`, `showsDesktopPanel: Bool`, `desktopPanelOrigin: [Double]?`; losing `goalMXN`; with a tolerant `init(from decoder:)`.
  - `addEntry(amount:currency:kind:category:note:exchangeRate:date:) -> Entry`
  - `setMonthlyBudget(_ amount: Decimal?)`
  - `setLastUsedCategory(_ category: Category)`
  - `setShowsDesktopPanel(_ shows: Bool)`, `setDesktopPanelOrigin(_ origin: CGPoint?)`
  - `summary(for month: Date) -> MonthlySummary`
  - `budgetProgress(for month: Date) -> BudgetProgress`
  - `menuBarAccessibilityLabel(for month: Date) -> String`
  - keeps `deleteEntry(id:)`, `resetAllEntries()`, `recordExchangeRate(_:date:)`, `setLaunchAtLogin(_:)`, `formattedAmount(_:)`
  - **keeps, temporarily**, `goalMXN`, `setGoal(_:)`, `totalMXN`, `formattedTotal`, `menuBarSummary`. The old views still call these, and `swift test` compiles the executable target — dropping them here would break the build and silently stop the entire suite from running. Task 7 removes them in the same commit that removes their last caller. This is an expand-then-contract migration: expand now, contract once the UI has moved over.

`setDesktopPanelOrigin` takes a `CGPoint?` and stores `[x, y]`; import `CoreGraphics` for `CGPoint`.

`AlcanciaData` keeps `goalMXN` for now so `SettingsView` keeps compiling. It is decoded tolerantly like every other optional field and is removed in Task 7.

- [ ] **Step 1: Write the failing tests — REPLACE the whole test file**

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

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testAddingExpensesAccumulatesInTheMonth() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 300, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 5))
        store.addEntry(amount: 200, currency: .mxn, kind: .expense,
                       category: .transporte, date: date(2026, 8, 6))

        let summary = store.summary(for: date(2026, 8, 15))
        XCTAssertEqual(summary.totalSpentMXN, 500)
    }

    func testIncomeIsTrackedSeparatelyFromSpending() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 5000, currency: .mxn, kind: .income, date: date(2026, 8, 5))
        store.addEntry(amount: 300, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 5))

        let summary = store.summary(for: date(2026, 8, 15))
        XCTAssertEqual(summary.totalIncomeMXN, 5000)
        XCTAssertEqual(summary.totalSpentMXN, 300)
    }

    func testUSDExpenseConvertsWithGivenRate() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 10, currency: .usd, kind: .expense,
                       category: .software, exchangeRate: 18.0, date: date(2026, 8, 5))
        XCTAssertEqual(store.summary(for: date(2026, 8, 15)).totalSpentMXN, 180)
    }

    func testAddingAnExpenseRemembersItsCategory() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 100, currency: .mxn, kind: .expense, category: .ocio)
        XCTAssertEqual(store.data.lastUsedCategory, .ocio)
    }

    func testIncomeDoesNotChangeTheRememberedCategory() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.addEntry(amount: 100, currency: .mxn, kind: .expense, category: .ocio)
        store.addEntry(amount: 5000, currency: .mxn, kind: .income)
        XCTAssertEqual(store.data.lastUsedCategory, .ocio)
    }

    func testDeletingAnEntryRemovesItFromTheMonth() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let entry = store.addEntry(amount: 300, currency: .mxn, kind: .expense,
                                   category: .comida, date: date(2026, 8, 5))
        store.addEntry(amount: 200, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 6))
        store.deleteEntry(id: entry.id)
        XCTAssertEqual(store.summary(for: date(2026, 8, 15)).totalSpentMXN, 200)
    }

    func testTotalsStayConsistentAcrossRepeatedAddAndDeleteCycles() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        for _ in 0..<5 {
            let toDelete = store.addEntry(amount: 100, currency: .mxn, kind: .expense,
                                          category: .comida, date: date(2026, 8, 5))
            store.addEntry(amount: 50, currency: .mxn, kind: .expense,
                           category: .comida, date: date(2026, 8, 5))
            store.deleteEntry(id: toDelete.id)
        }
        XCTAssertEqual(store.summary(for: date(2026, 8, 15)).totalSpentMXN, 250)
    }

    func testBudgetProgressReflectsTheMonthsSpending() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setMonthlyBudget(1000)
        store.addEntry(amount: 250, currency: .mxn, kind: .expense,
                       category: .comida, date: date(2026, 8, 5))

        let progress = store.budgetProgress(for: date(2026, 8, 15))
        XCTAssertEqual(progress.fractionRemaining ?? -1, 0.75, accuracy: 0.0001)
        XCTAssertEqual(progress.remainingMXN, 750)
    }

    func testSetAndClearBudget() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setMonthlyBudget(8000)
        XCTAssertEqual(store.data.monthlyBudgetMXN, 8000)
        store.setMonthlyBudget(nil)
        XCTAssertNil(store.data.monthlyBudgetMXN)
    }

    func testResetAllEntriesKeepsTheBudget() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        store.setMonthlyBudget(8000)
        store.addEntry(amount: 100, currency: .mxn, kind: .expense, category: .comida)
        store.resetAllEntries()
        XCTAssertEqual(store.summary(for: Date()).totalSpentMXN, 0)
        XCTAssertEqual(store.data.monthlyBudgetMXN, 8000)
    }

    func testDataPersistsAcrossStoreInstances() {
        let url = makeTempFileURL()
        let first = AlcanciaStore(fileURL: url)
        first.setMonthlyBudget(8000)
        first.addEntry(amount: 250, currency: .mxn, kind: .expense,
                       category: .mercado, date: date(2026, 8, 5))

        let second = AlcanciaStore(fileURL: url)
        XCTAssertEqual(second.data.monthlyBudgetMXN, 8000)
        XCTAssertEqual(second.summary(for: date(2026, 8, 15)).totalSpentMXN, 250)
        XCTAssertEqual(second.data.lastUsedCategory, .mercado)
    }

    func testDesktopPanelPreferencesPersist() {
        let url = makeTempFileURL()
        let first = AlcanciaStore(fileURL: url)
        first.setShowsDesktopPanel(true)
        first.setDesktopPanelOrigin(CGPoint(x: 120, y: 340))

        let second = AlcanciaStore(fileURL: url)
        XCTAssertTrue(second.data.showsDesktopPanel)
        XCTAssertEqual(second.data.desktopPanelOrigin ?? [], [120, 340])
    }

    func testCorruptFileFallsBackToEmptyDataWithoutCrashing() throws {
        let url = makeTempFileURL()
        try "not valid json".write(to: url, atomically: true, encoding: .utf8)
        let store = AlcanciaStore(fileURL: url)
        XCTAssertEqual(store.summary(for: Date()).totalSpentMXN, 0)
        XCTAssertNil(store.data.monthlyBudgetMXN)
    }

    /// El archivo que dejó la versión anterior tiene que abrirse sin perder
    /// nada. Si esto falla, al usuario le parece que la app borró su dinero.
    func testLoadsFileWrittenByThePreviousVersion() throws {
        let url = makeTempFileURL()
        let legacy = """
        {
          "entries": [
            {
              "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
              "amount": 1500,
              "currency": "mxn",
              "amountInMXN": 1500,
              "date": "2026-08-10T12:00:00Z"
            }
          ],
          "goalMXN": 10000,
          "launchAtLogin": true,
          "lastKnownUSDMXNRate": 18.5,
          "lastKnownRateDate": "2026-08-10T12:00:00Z"
        }
        """
        try legacy.write(to: url, atomically: true, encoding: .utf8)

        let store = AlcanciaStore(fileURL: url)

        XCTAssertEqual(store.data.entries.count, 1, "el movimiento se perdió")
        XCTAssertEqual(store.data.entries.first?.kind, .income)
        XCTAssertEqual(store.data.lastKnownUSDMXNRate, 18.5)
        XCTAssertTrue(store.data.launchAtLogin)
        XCTAssertNil(store.data.monthlyBudgetMXN)
        XCTAssertFalse(store.data.showsDesktopPanel)
    }

    func testFormattedAmountUsesPesoFormatting() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let formatted = store.formattedAmount(3240)
        XCTAssertTrue(formatted.contains("3,240"), formatted)
        XCTAssertTrue(formatted.contains("$"), formatted)
    }

    func testRecordExchangeRateStoresRateAndDate() {
        let store = AlcanciaStore(fileURL: makeTempFileURL())
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        store.recordExchangeRate(18.75, date: when)
        XCTAssertEqual(store.data.lastKnownUSDMXNRate, 18.75)
        XCTAssertEqual(store.data.lastKnownRateDate, when)
    }
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd alcancia && swift test --filter AlcanciaStoreTests`
Expected: FAIL — `addEntry` has no `kind:` parameter, `setMonthlyBudget` does not exist.

- [ ] **Step 3: Rewrite `AlcanciaStore.swift`**

```swift
// Sources/AlcanciaCore/AlcanciaStore.swift
import Foundation
import CoreGraphics

public struct AlcanciaData: Codable {
    public var monthlyBudgetMXN: Decimal?
    /// HEREDADO — la meta de ahorro de la versión anterior. Sigue aquí sólo
    /// para que las vistas viejas compilen mientras se hace el cambio; se va
    /// en la Tarea 7.
    public var goalMXN: Decimal?
    public var entries: [Entry]
    public var lastKnownUSDMXNRate: Double?
    public var lastKnownRateDate: Date?
    public var launchAtLogin: Bool
    public var lastUsedCategory: Category?
    public var showsDesktopPanel: Bool
    /// [x, y] de la esquina del panel flotante, para restaurarlo donde quedó.
    public var desktopPanelOrigin: [Double]?

    public init(
        monthlyBudgetMXN: Decimal? = nil,
        goalMXN: Decimal? = nil,
        entries: [Entry] = [],
        lastKnownUSDMXNRate: Double? = nil,
        lastKnownRateDate: Date? = nil,
        launchAtLogin: Bool = false,
        lastUsedCategory: Category? = nil,
        showsDesktopPanel: Bool = false,
        desktopPanelOrigin: [Double]? = nil
    ) {
        self.monthlyBudgetMXN = monthlyBudgetMXN
        self.goalMXN = goalMXN
        self.entries = entries
        self.lastKnownUSDMXNRate = lastKnownUSDMXNRate
        self.lastKnownRateDate = lastKnownRateDate
        self.launchAtLogin = launchAtLogin
        self.lastUsedCategory = lastUsedCategory
        self.showsDesktopPanel = showsDesktopPanel
        self.desktopPanelOrigin = desktopPanelOrigin
    }

    /// Todo campo agregado después de la primera versión se decodifica con
    /// `decodeIfPresent`. Un archivo viejo al que le falte cualquiera de ellos
    /// tiene que abrirse igual: si falla, `AlcanciaStore.load` lo pone en
    /// cuarentena y al usuario le parece que la app le borró su dinero.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = try container.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        monthlyBudgetMXN = try container.decodeIfPresent(Decimal.self, forKey: .monthlyBudgetMXN)
        goalMXN = try container.decodeIfPresent(Decimal.self, forKey: .goalMXN)
        lastKnownUSDMXNRate = try container.decodeIfPresent(Double.self, forKey: .lastKnownUSDMXNRate)
        lastKnownRateDate = try container.decodeIfPresent(Date.self, forKey: .lastKnownRateDate)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        lastUsedCategory = try container.decodeIfPresent(Category.self, forKey: .lastUsedCategory)
        showsDesktopPanel = try container.decodeIfPresent(Bool.self, forKey: .showsDesktopPanel) ?? false
        desktopPanelOrigin = try container.decodeIfPresent([Double].self, forKey: .desktopPanelOrigin)
    }
}

@MainActor
public final class AlcanciaStore: ObservableObject {
    @Published public private(set) var data: AlcanciaData

    private let fileURL: URL
    private let calendar: Calendar

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()

    public init(
        fileURL: URL = AlcanciaStore.defaultFileURL(),
        calendar: Calendar = .current
    ) {
        self.fileURL = fileURL
        self.calendar = calendar
        self.data = Self.load(from: fileURL)
    }

    nonisolated public static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let dir = appSupport.appendingPathComponent("Alcancia", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    // MARK: - Consultas

    public func summary(for month: Date) -> MonthlySummary {
        MonthlySummary(entries: data.entries, month: month, calendar: calendar)
    }

    public func budgetProgress(for month: Date) -> BudgetProgress {
        BudgetProgress(
            spentMXN: summary(for: month).totalSpentMXN,
            budgetMXN: data.monthlyBudgetMXN
        )
    }

    /// Lo que lee VoiceOver del ícono de la barra de menú.
    public func menuBarAccessibilityLabel(for month: Date) -> String {
        let spent = formattedAmount(summary(for: month).totalSpentMXN)
        guard let budget = data.monthlyBudgetMXN, budget > 0 else {
            return "Gastado \(spent) este mes"
        }
        return "Gastado \(spent) de \(formattedAmount(budget)) este mes"
    }

    // MARK: - Movimientos

    @discardableResult
    public func addEntry(
        amount: Decimal,
        currency: Currency,
        kind: EntryKind = .expense,
        category: Category? = nil,
        note: String? = nil,
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

        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = Entry(
            amount: amount,
            currency: currency,
            amountInMXN: amountInMXN,
            exchangeRateUsed: rateUsed,
            date: date,
            kind: kind,
            category: kind == .expense ? (category ?? .otro) : nil,
            note: (cleanNote?.isEmpty ?? true) ? nil : cleanNote
        )
        data.entries.append(entry)
        // Sólo los gastos mueven la categoría por defecto de la captura rápida.
        if kind == .expense, let category {
            data.lastUsedCategory = category
        }
        save()
        return entry
    }

    public func deleteEntry(id: UUID) {
        data.entries.removeAll { $0.id == id }
        save()
    }

    public func resetAllEntries() {
        data.entries = []
        save()
    }

    // MARK: - Ajustes

    public func setMonthlyBudget(_ amount: Decimal?) {
        data.monthlyBudgetMXN = amount
        save()
    }

    public func setLastUsedCategory(_ category: Category) {
        data.lastUsedCategory = category
        save()
    }

    public func setShowsDesktopPanel(_ shows: Bool) {
        data.showsDesktopPanel = shows
        save()
    }

    public func setDesktopPanelOrigin(_ origin: CGPoint?) {
        data.desktopPanelOrigin = origin.map { [Double($0.x), Double($0.y)] }
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

    // MARK: - Formato

    public func formattedAmount(_ amount: Decimal) -> String {
        Self.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }

    // MARK: - Heredado (se elimina en la Tarea 7)
    //
    // Las vistas viejas todavía llaman a esto. `swift test` compila también el
    // ejecutable, así que quitarlo ahora rompería la suite completa en vez de
    // sólo la UI. Se va junto con su último llamador.

    public func setGoal(_ amount: Decimal?) {
        data.goalMXN = amount
        save()
    }

    public var totalMXN: Decimal {
        data.entries.reduce(Decimal(0)) { $0 + $1.amountInMXN }
    }

    public var formattedTotal: String {
        formattedAmount(totalMXN)
    }

    public var menuBarSummary: String {
        if let goalMXN = data.goalMXN, goalMXN > 0 {
            return GoalProgress(totalMXN: totalMXN, goalMXN: goalMXN).percentText ?? formattedTotal
        }
        return formattedTotal
    }

    // MARK: - Persistencia

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

    nonisolated private static func load(from url: URL) -> AlcanciaData {
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

- [ ] **Step 4: Build clean and run the whole suite**

Run: `cd alcancia && swift build 2>&1 | tail -20 && swift test 2>&1 | tail -6`
Expected: the package builds — the legacy members kept above are what let the old views keep compiling — and all 38 tests pass (Entry 4, Category 2, BudgetProgress 7, MonthlySummary 6, AlcanciaStore 16, ExchangeRateService 3).

- [ ] **Step 5: Commit**

```bash
cd alcancia
git add Sources/AlcanciaCore/AlcanciaStore.swift Tests/AlcanciaCoreTests/AlcanciaStoreTests.swift
git commit -m "Rework AlcanciaStore around monthly budgets and categories"
```

---

### Task 5: The capture row — QuickAddView, CategoryRowView, MonthHeaderView

**Files:**
- Create: `Sources/Alcancia/QuickAddView.swift`
- Create: `Sources/Alcancia/CategoryRowView.swift`
- Create: `Sources/Alcancia/MonthHeaderView.swift`

**Interfaces:**
- Consumes: `AlcanciaStore` (Task 4), `ExchangeRateService`, `Category`, `EntryKind`, `Currency`, `BudgetProgress`, `MonthlySummary`.
- Produces: `struct QuickAddView: View { init(store: AlcanciaStore) }`, `struct CategoryRowView: View { init(selection: Binding<Category>) }`, `struct MonthHeaderView: View { init(store: AlcanciaStore, month: Binding<Date>) }` — all consumed by `MenuBarView` in Task 7.

All three ship together because `QuickAddView` embeds `CategoryRowView`; splitting them would leave the package uncompilable between commits. **`AddEntryView.swift` is not deleted here** — `MenuBarView` still calls it, and it still compiles against the legacy store members Task 4 kept. Task 7 deletes it in the same commit that stops calling it.

`QuickAddView` is the view the whole app lives or dies on: the amount field must be focused the moment the popover opens, and Return must commit. Typing an amount and pressing Return is the entire interaction.

- [ ] **Step 1: Create `QuickAddView.swift`**

```swift
// Sources/Alcancia/QuickAddView.swift
import SwiftUI
import AlcanciaCore

/// Captura rápida. La regla que manda: escribir el monto y dar Enter tiene que
/// bastar. Todo lo demás (categoría, concepto, moneda, tipo de movimiento) son
/// ajustes opcionales que arrancan en el valor más probable.
struct QuickAddView: View {
    @ObservedObject var store: AlcanciaStore

    @FocusState private var amountFocused: Bool

    @State private var amountText: String = ""
    @State private var noteText: String = ""
    @State private var kind: EntryKind = .expense
    @State private var currency: Currency = .mxn
    @State private var category: Category = .otro
    @State private var isResolvingRate = false
    @State private var needsManualRate = false
    @State private var manualRateText: String = ""
    @State private var errorMessage: String?
    @State private var noticeMessage: String?

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }

    private var parsedManualRate: Double? {
        Double(manualRateText.replacingOccurrences(of: ",", with: ""))
    }

    private var canSubmit: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        if isResolvingRate { return false }
        if needsManualRate {
            guard let rate = parsedManualRate, rate > 0 else { return false }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("¿Cuánto?", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .focused($amountFocused)
                    .onSubmit(submit)

                Picker("Moneda", selection: $currency) {
                    Text("MXN").tag(Currency.mxn)
                    Text("USD").tag(Currency.usd)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 96)
                .onChange(of: currency) { _, _ in
                    needsManualRate = false
                    errorMessage = nil
                    noticeMessage = nil
                }

                Button(action: submit) {
                    if isResolvingRate {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "return")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .help("Agregar")
            }

            HStack(spacing: 8) {
                TextField("Concepto (opcional)", text: $noteText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit(submit)

                Picker("Tipo", selection: $kind) {
                    Text("Gasto").tag(EntryKind.expense)
                    Text("Ingreso").tag(EntryKind.income)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 130)
            }

            if kind == .expense {
                CategoryRowView(selection: $category)
            }

            if needsManualRate {
                HStack(spacing: 8) {
                    Text("Tipo de cambio USD→MXN:").font(.caption)
                    TextField("ej. 18.50", text: $manualRateText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onSubmit(submit)
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            if let noticeMessage {
                Text(noticeMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onAppear {
            category = store.data.lastUsedCategory ?? .otro
            // El foco es la pieza que hace que capturar tome tres segundos.
            amountFocused = true
        }
    }

    private func submit() {
        guard canSubmit else { return }
        Task { await addEntry() }
    }

    @MainActor
    private func addEntry() async {
        guard let amount = parsedAmount, amount > 0 else { return }
        errorMessage = nil
        noticeMessage = nil

        if currency == .mxn {
            commit(amount: amount, rate: nil)
            return
        }

        if needsManualRate {
            guard let rate = parsedManualRate, rate > 0 else { return }
            store.recordExchangeRate(rate)
            commit(amount: amount, rate: rate)
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

        if result.isFromCache {
            noticeMessage = "Tipo de cambio del \(Self.dateFormatter.string(from: result.asOf)), sin conexión."
        } else {
            store.recordExchangeRate(result.rate, date: result.asOf)
        }
        commit(amount: amount, rate: result.rate)
    }

    private func commit(amount: Decimal, rate: Double?) {
        store.addEntry(
            amount: amount,
            currency: currency,
            kind: kind,
            category: kind == .expense ? category : nil,
            note: noteText,
            exchangeRate: rate
        )
        amountText = ""
        noteText = ""
        // Listo para el siguiente sin tocar el mouse.
        amountFocused = true
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
}
```

- [ ] **Step 2: Create `CategoryRowView.swift`**

```swift
// Sources/Alcancia/CategoryRowView.swift
import SwiftUI
import AlcanciaCore

/// Las ocho categorías en una fila de emojis. Elegir es un clic, no un menú
/// desplegable — la diferencia entre capturar en tres segundos o en diez.
struct CategoryRowView: View {
    @Binding var selection: Category

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Category.allCases) { category in
                Button {
                    selection = category
                } label: {
                    Text(category.emoji)
                        .font(.system(size: 15))
                        .frame(width: 30, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selection == category
                                      ? Color.accentColor.opacity(0.25)
                                      : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selection == category
                                        ? Color.accentColor
                                        : Color.clear,
                                        lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(category.label)
            }
        }
    }
}
```

- [ ] **Step 3: Create `MonthHeaderView.swift`**

```swift
// Sources/Alcancia/MonthHeaderView.swift
import SwiftUI
import AlcanciaCore

/// Navegación entre meses y el estado del presupuesto: el primer vistazo al
/// abrir la app.
struct MonthHeaderView: View {
    @ObservedObject var store: AlcanciaStore
    @Binding var month: Date

    private var summary: MonthlySummary { store.summary(for: month) }
    private var progress: BudgetProgress { store.budgetProgress(for: month) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(Self.monthFormatter.string(from: month).capitalized)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(isShowingCurrentMonth)
            }

            Text(store.formattedAmount(summary.totalSpentMXN))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(progress.isOverBudget ? Color.red : Color.primary)

            if let budget = store.data.monthlyBudgetMXN, budget > 0 {
                ProgressView(value: 1 - (progress.fractionRemaining ?? 0))
                    .tint(progress.isOverBudget ? .red : .accentColor)
                Text(budgetCaption(budget: budget))
                    .font(.caption)
                    .foregroundStyle(progress.isOverBudget ? Color.red : Color.secondary)
            } else {
                Text("Gastado este mes · sin presupuesto definido")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if summary.totalIncomeMXN > 0 {
                Text("Ingresos del mes: \(store.formattedAmount(summary.totalIncomeMXN))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func budgetCaption(budget: Decimal) -> String {
        if progress.isOverBudget, let remaining = progress.remainingMXN {
            return "Te pasaste por \(store.formattedAmount(-remaining))"
        }
        if let remaining = progress.remainingMXN {
            return "de \(store.formattedAmount(budget)) · te quedan \(store.formattedAmount(remaining))"
        }
        return "de \(store.formattedAmount(budget))"
    }

    private var isShowingCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private func shiftMonth(by delta: Int) {
        if let shifted = Calendar.current.date(byAdding: .month, value: delta, to: month) {
            month = shifted
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}
```

- [ ] **Step 4: Build and run the suite**

Run: `cd alcancia && swift build 2>&1 | tail -20 && swift test 2>&1 | tail -6`
Expected: the package builds with **zero warnings** and every test passes. Every task in this plan must leave the package green — `swift test` compiles the executable target too, so a broken view silently blocks the whole suite.

The three new views are not referenced by anything yet; this step only proves they compile.

- [ ] **Step 5: Commit**

```bash
cd alcancia
git add Sources/Alcancia/QuickAddView.swift Sources/Alcancia/CategoryRowView.swift Sources/Alcancia/MonthHeaderView.swift
git commit -m "Add quick-capture row, category picker and month header"
```

---

### Task 6: CategoryBreakdownView

**Files:**
- Create: `Sources/Alcancia/CategoryBreakdownView.swift`

**Interfaces:**
- Consumes: `MonthlySummary`, `CategoryTotal`, `AlcanciaStore`.
- Produces: `struct CategoryBreakdownView: View { init(store: AlcanciaStore, summary: MonthlySummary) }` — consumed by `MenuBarView` in Task 7.

- [ ] **Step 1: Create `CategoryBreakdownView.swift`**

```swift
// Sources/Alcancia/CategoryBreakdownView.swift
import SwiftUI
import AlcanciaCore

/// En qué se fue el dinero del mes, de mayor a menor.
struct CategoryBreakdownView: View {
    @ObservedObject var store: AlcanciaStore
    let summary: MonthlySummary

    var body: some View {
        if summary.byCategory.isEmpty {
            VStack {
                Spacer()
                Text("Sin gastos este mes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(summary.byCategory) { total in
                        row(for: total)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    private func row(for total: CategoryTotal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(total.category.emoji)
                Text(total.category.label)
                    .font(.caption)
                Spacer()
                Text(store.formattedAmount(total.amountMXN))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor)
                        .frame(width: max(2, geometry.size.width * total.fractionOfTotal))
                }
            }
            .frame(height: 6)
        }
    }
}
```

- [ ] **Step 2: Build and run the suite**

Run: `cd alcancia && swift build 2>&1 | tail -20 && swift test 2>&1 | tail -6`
Expected: the package builds with **zero warnings** and every test passes. Every task in this plan must leave the package green — `swift test` compiles the executable target too, so a broken view silently blocks the whole suite.

- [ ] **Step 3: Commit**

```bash
cd alcancia
git add Sources/Alcancia/CategoryBreakdownView.swift
git commit -m "Add per-category spending breakdown"
```

---

### Task 7: The swap — wire the new views in and remove the old ones

**Files:**
- Modify: `Sources/Alcancia/MenuBarView.swift`
- Modify: `Sources/Alcancia/HistoryView.swift`
- Modify: `Sources/Alcancia/SettingsView.swift`
- Modify: `Sources/Alcancia/AlcanciaAppMain.swift`
- Modify: `Sources/AlcanciaCore/AlcanciaStore.swift` (drop the legacy block)
- Delete: `Sources/Alcancia/AddEntryView.swift`
- Delete: `Sources/AlcanciaCore/GoalProgress.swift`
- Delete: `Tests/AlcanciaCoreTests/GoalProgressTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1-6.
- Produces: `HistoryView(store:summary:)` — note the changed initializer, it now takes the visible month's summary instead of reading every entry. `MenuBarView(store:)` and `SettingsView(store:)` keep theirs.

This task is atomic on purpose. It is the contract half of the expand-then-contract migration: the new views go in and, in the same commit, the last callers of the legacy store members disappear along with the members themselves. Splitting it would leave a commit where the package does not build.

Do the edits in the order below and only build at the end — intermediate states will not compile, and that is expected **within** this task.

- [ ] **Step 1: Rewrite `HistoryView.swift`**

```swift
// Sources/Alcancia/HistoryView.swift
import SwiftUI
import AlcanciaCore

/// Los movimientos del mes que se está viendo, del más reciente al más viejo.
struct HistoryView: View {
    @ObservedObject var store: AlcanciaStore
    let summary: MonthlySummary

    @State private var pendingDeleteID: UUID?

    var body: some View {
        Group {
            if summary.entriesInMonth.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(summary.entriesInMonth) { entry in
                            row(for: entry)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .confirmationDialog(
            "¿Borrar este movimiento?",
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
            Text("Sin movimientos este mes")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func row(for entry: Entry) -> some View {
        HStack(spacing: 8) {
            Text(entry.kind == .expense ? (entry.category ?? .otro).emoji : "💰")

            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: entry))
                    .font(.caption)
                Text(Self.dateFormatter.string(from: entry.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(signedAmount(for: entry))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(entry.kind == .expense ? Color.primary : Color.green)
                if entry.currency == .usd {
                    Text("USD \(entry.amount.description)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
        .padding(.vertical, 7)
    }

    private func title(for entry: Entry) -> String {
        if let note = entry.note, !note.isEmpty { return note }
        return entry.kind == .expense
            ? (entry.category ?? .otro).label
            : "Ingreso"
    }

    private func signedAmount(for entry: Entry) -> String {
        let sign = entry.kind == .expense ? "−" : "+"
        return sign + store.formattedAmount(entry.amountInMXN)
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

- [ ] **Step 2: Rewrite `MenuBarView.swift`**

```swift
// Sources/Alcancia/MenuBarView.swift
import SwiftUI
import AlcanciaCore

struct MenuBarView: View {
    @ObservedObject var store: AlcanciaStore

    @State private var month = Date()
    @State private var listMode: ListMode = .movimientos
    @State private var showingSettings = false

    private enum ListMode: String, CaseIterable, Identifiable {
        case movimientos = "Movimientos"
        case categorias = "Por categoría"
        var id: String { rawValue }
    }

    private var summary: MonthlySummary { store.summary(for: month) }

    var body: some View {
        VStack(spacing: 0) {
            MonthHeaderView(store: store, month: $month)
            Divider()
            QuickAddView(store: store)
            Divider()

            Picker("Vista", selection: $listMode) {
                ForEach(ListMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            switch listMode {
            case .movimientos:
                HistoryView(store: store, summary: summary)
            case .categorias:
                CategoryBreakdownView(store: store, summary: summary)
            }

            Divider()
            footer
        }
        .frame(width: 360, height: 560)
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store)
        }
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

- [ ] **Step 3: Rewrite `SettingsView.swift`**

```swift
// Sources/Alcancia/SettingsView.swift
import SwiftUI
import AlcanciaCore

struct SettingsView: View {
    @ObservedObject var store: AlcanciaStore
    @Environment(\.dismiss) private var dismiss

    @State private var budgetText: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var showsDesktopPanel: Bool = false
    @State private var loginItemError: String?
    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ajustes").font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Presupuesto mensual (MXN)").font(.subheadline)
                HStack {
                    TextField("ej. 8000", text: $budgetText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(saveBudget)
                    Button("Guardar", action: saveBudget)
                    if store.data.monthlyBudgetMXN != nil {
                        Button("Quitar") {
                            store.setMonthlyBudget(nil)
                            budgetText = ""
                        }
                        .foregroundStyle(.red)
                    }
                }
                Text("El cerdito de la barra arranca lleno cada mes y se vacía conforme gastas.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let rate = store.data.lastKnownUSDMXNRate {
                Text(exchangeRateText(rate: rate, date: store.data.lastKnownRateDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Mostrar panel en el escritorio", isOn: $showsDesktopPanel)
                .onChange(of: showsDesktopPanel) { _, newValue in
                    store.setShowsDesktopPanel(newValue)
                }

            Toggle("Iniciar con el sistema", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    let succeeded = LoginItemManager.setEnabled(newValue)
                    if succeeded {
                        store.setLaunchAtLogin(newValue)
                        loginItemError = nil
                    } else {
                        loginItemError = "No se pudo cambiar el inicio automático. Revisa Ajustes del Sistema > Elementos de inicio."
                        syncLaunchAtLoginFromSystem()
                    }
                }

            if let loginItemError {
                Text(loginItemError).font(.caption).foregroundStyle(.red)
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
        .frame(width: 320, height: 430)
        .onAppear {
            if let budget = store.data.monthlyBudgetMXN {
                budgetText = "\(budget)"
            }
            showsDesktopPanel = store.data.showsDesktopPanel
            syncLaunchAtLoginFromSystem()
        }
    }

    /// El interruptor refleja el estado real del sistema, no la preferencia
    /// guardada, para que no pueda mentir si el registro falló.
    private func syncLaunchAtLoginFromSystem() {
        let actual = LoginItemManager.isEnabled
        if launchAtLogin != actual {
            launchAtLogin = actual
        }
        if store.data.launchAtLogin != actual {
            store.setLaunchAtLogin(actual)
        }
    }

    private func saveBudget() {
        guard let value = Decimal(string: budgetText.replacingOccurrences(of: ",", with: "")),
              value > 0 else { return }
        store.setMonthlyBudget(value)
    }

    private func exchangeRateText(rate: Double, date: Date?) -> String {
        let text = String(format: "Tipo de cambio guardado: %.2f MXN por USD", rate)
        guard let date else { return text }
        return text + " (\(Self.dateFormatter.string(from: date)))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
}
```

Note `syncLaunchAtLoginFromSystem`: the previous version reassigned `launchAtLogin` inside its own `.onChange`, which re-entered the handler and wiped the error message before it could be read. Assigning only when the value actually differs stops that re-entrant round trip from clearing `loginItemError`.

- [ ] **Step 4: Rewrite `AlcanciaAppMain.swift`**

```swift
// Sources/Alcancia/AlcanciaAppMain.swift
import SwiftUI
import AlcanciaCore

@main
struct AlcanciaAppMain: App {
    @StateObject private var store = AlcanciaStore()

    /// El cerdito muestra lo que queda del presupuesto del mes en curso:
    /// lleno al empezar, vacío cuando se acabó.
    private var remainingFraction: Double? {
        store.budgetProgress(for: Date()).fractionRemaining
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            Image(nsImage: PiggyBankIcon.image(
                progress: remainingFraction,
                accessibilityDescription: store.menuBarAccessibilityLabel(for: Date())
            ))
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 5: Delete the superseded files**

```bash
cd alcancia
rm Sources/Alcancia/AddEntryView.swift
rm Sources/AlcanciaCore/GoalProgress.swift
rm Tests/AlcanciaCoreTests/GoalProgressTests.swift
```

- [ ] **Step 6: Drop the legacy block from `AlcanciaStore.swift`**

Delete the whole `// MARK: - Heredado (se elimina en la Tarea 7)` section — `setGoal(_:)`, `totalMXN`, `formattedTotal` and `menuBarSummary` — and delete the `goalMXN` property from `AlcanciaData`, its parameter and assignment in `init`, and its `decodeIfPresent` line in `init(from:)`.

Dropping `goalMXN` from the struct is safe for existing files: `JSONDecoder` ignores keys it does not know, so a `data.json` that still carries a saved goal keeps loading. The only thing lost is that goal value, which no longer has a place in an expense-control app.

- [ ] **Step 7: Build clean and run the whole suite**

Run: `cd alcancia && rm -rf .build && swift build 2>&1 | tail -30 && swift test 2>&1 | tail -6`
Expected: build succeeds with **zero warnings**; all 38 tests pass. Fix any compile mismatch here rather than deferring it — this is the first moment the new app exists end to end.

- [ ] **Step 8: Headless smoke test**

```bash
cd alcancia
swift run Alcancia > /tmp/alcancia-smoke.log 2>&1 &
RUN_PID=$!
sleep 4
if kill -0 $RUN_PID 2>/dev/null; then
  echo "Sigue viva a los 4s — sin crash de arranque"
  kill $RUN_PID
else
  echo "Se murió sola — revisar el log"
fi
cat /tmp/alcancia-smoke.log
```

Expected: still alive, no exception or crash trace. A `MenuBarExtra` app prints nothing on a healthy launch.

- [ ] **Step 9: Commit**

```bash
cd alcancia
git add -A Sources Tests
git commit -m "Swap the UI over to monthly budgets and drop the savings-goal code"
```

---

### Task 8: Floating desktop panel

**Files:**
- Create: `Sources/Alcancia/DesktopPanelView.swift`
- Create: `Sources/Alcancia/DesktopPanelController.swift`
- Modify: `Sources/Alcancia/AlcanciaAppMain.swift`

**Interfaces:**
- Consumes: `AlcanciaStore`, `BudgetProgress`, `MonthlySummary`, `PiggyBankIcon`.
- Produces: `struct DesktopPanelView: View { init(store: AlcanciaStore) }` and `@MainActor final class DesktopPanelController: ObservableObject { init(store: AlcanciaStore); func update(shows: Bool) }`.

This is the answer to "can it also just be a widget". A real WidgetKit widget needs an App Group, which needs an Apple Developer account this machine does not have — `security find-identity -v -p codesigning` reports zero valid identities. A borderless always-on-top panel gives the same always-visible glance with no signing requirement.

- [ ] **Step 1: Create `DesktopPanelView.swift`**

```swift
// Sources/Alcancia/DesktopPanelView.swift
import SwiftUI
import AlcanciaCore

/// Lo que se ve en el panel flotante: el cerdito y lo que queda del mes.
struct DesktopPanelView: View {
    @ObservedObject var store: AlcanciaStore

    private var progress: BudgetProgress { store.budgetProgress(for: Date()) }
    private var summary: MonthlySummary { store.summary(for: Date()) }

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: PiggyBankIcon.image(
                progress: progress.fractionRemaining,
                accessibilityDescription: "",
                height: 34
            ))
            .renderingMode(.template)
            .foregroundStyle(progress.isOverBudget ? Color.red : Color.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.formattedAmount(summary.totalSpentMXN))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(progress.isOverBudget ? Color.red : Color.primary)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var caption: String {
        guard let budget = store.data.monthlyBudgetMXN, budget > 0 else {
            return "gastado este mes"
        }
        if progress.isOverBudget, let remaining = progress.remainingMXN {
            return "te pasaste por \(store.formattedAmount(-remaining))"
        }
        if let remaining = progress.remainingMXN {
            return "te quedan \(store.formattedAmount(remaining))"
        }
        return "gastado este mes"
    }
}
```

- [ ] **Step 2: Create `DesktopPanelController.swift`**

```swift
// Sources/Alcancia/DesktopPanelController.swift
import AppKit
import SwiftUI
import AlcanciaCore

/// Un `NSPanel` sin bordes que flota sobre el escritorio. Es la alternativa
/// viable al widget de WidgetKit, que necesitaría un App Group y por lo tanto
/// una cuenta de desarrollador de Apple.
@MainActor
final class DesktopPanelController: ObservableObject {
    private var panel: NSPanel?
    private let store: AlcanciaStore
    private var frameObserver: NSObjectProtocol?

    init(store: AlcanciaStore) {
        self.store = store
    }

    func update(shows: Bool) {
        if shows {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        if let panel {
            panel.orderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: DesktopPanelView(store: store))
        hosting.view.frame = NSRect(x: 0, y: 0, width: 210, height: 62)

        let panel = NSPanel(
            contentRect: hosting.view.frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        if let origin = store.data.desktopPanelOrigin, origin.count == 2 {
            panel.setFrameOrigin(NSPoint(x: origin[0], y: origin[1]))
        } else {
            panel.center()
        }

        // Guardamos la posición cuando el usuario suelta el panel, para
        // restaurarlo ahí la próxima vez.
        frameObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] notification in
            guard let moved = notification.object as? NSWindow else { return }
            let origin = moved.frame.origin
            Task { @MainActor in
                self?.store.setDesktopPanelOrigin(origin)
            }
        }

        panel.orderFront(nil)
        self.panel = panel
    }

    private func hide() {
        if let frameObserver {
            NotificationCenter.default.removeObserver(frameObserver)
            self.frameObserver = nil
        }
        panel?.orderOut(nil)
        panel?.contentViewController = nil
        panel = nil
    }
}
```

- [ ] **Step 3: Rewire `AlcanciaAppMain.swift`**

```swift
// Sources/Alcancia/AlcanciaAppMain.swift
import SwiftUI
import AlcanciaCore

@main
struct AlcanciaAppMain: App {
    @StateObject private var store: AlcanciaStore
    @StateObject private var desktopPanel: DesktopPanelController

    init() {
        let store = AlcanciaStore()
        _store = StateObject(wrappedValue: store)
        _desktopPanel = StateObject(wrappedValue: DesktopPanelController(store: store))
    }

    /// El cerdito muestra lo que queda del presupuesto del mes en curso:
    /// lleno al empezar, vacío cuando se acabó.
    private var remainingFraction: Double? {
        store.budgetProgress(for: Date()).fractionRemaining
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
                .onAppear { desktopPanel.update(shows: store.data.showsDesktopPanel) }
                .onChange(of: store.data.showsDesktopPanel) { _, shows in
                    desktopPanel.update(shows: shows)
                }
        } label: {
            Image(nsImage: PiggyBankIcon.image(
                progress: remainingFraction,
                accessibilityDescription: store.menuBarAccessibilityLabel(for: Date())
            ))
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 4: Build clean, run the suite, smoke test**

Run: `cd alcancia && rm -rf .build && swift build 2>&1 | tail -30 && swift test 2>&1 | tail -6`
Expected: zero warnings, all 38 tests pass.

Then repeat Task 7's Step 8 headless smoke test and confirm the app stays alive.

- [ ] **Step 5: Commit**

```bash
cd alcancia
git add Sources/Alcancia/DesktopPanelView.swift Sources/Alcancia/DesktopPanelController.swift Sources/Alcancia/AlcanciaAppMain.swift
git commit -m "Add floating desktop panel as the widget stand-in"
```

---

### Task 9: README and packaging

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: the finished app.
- Produces: documentation matching what was actually built.

- [ ] **Step 1: Rewrite `README.md`**

````markdown
# Alcancía

Control de gastos personal que vive en la barra de menú de macOS. Todo
local, sin cuenta, sin nube.

## La regla que manda sobre el diseño

La razón por la que la gente abandona las apps de gastos no es la falta
de disciplina: es la fricción de capturar. Seis campos y tres menús para
un café de $60 es un mal trato, y se siente para el día nueve. Por eso
aquí registrar un gasto es: clic al cerdito, escribir el monto, Enter.
El campo ya viene enfocado y la categoría es la última que usaste.

## Qué hace

- **Vive en la barra de menú** (sin ícono en el Dock). El ícono es un
  cerdito que **arranca lleno cada mes y se vacía conforme gastas** — un
  vistazo responde "¿cómo voy?" sin abrir nada.
- **Presupuesto mensual.** Defines cuánto te permites gastar; la app te
  dice cuánto llevas y cuánto te queda, y se pone roja si te pasas.
- **Ocho categorías** con emoji, a un clic: comida, súper, transporte,
  casa, software, ocio, salud, otro.
- **Concepto libre** opcional en cada movimiento ("Uber", "Adobe").
- **Vista por mes** con navegación hacia atrás, y desglose de en qué se
  te fue el dinero.
- **Ingresos** también, con conversión automática USD→MXN al capturar
  (tipo de cambio en vivo, con respaldo del último conocido si no hay
  internet).
- **Panel flotante** opcional en el escritorio, arrastrable, que recuerda
  dónde lo dejaste.
- **Iniciar con el sistema**, opcional.

## Sobre el widget

Un widget de verdad de macOS (WidgetKit) necesita una extensión de app y
un App Group para compartir los datos, y eso requiere cuenta de
desarrollador de Apple. Mientras no la haya, el panel flotante del
escritorio da la misma vista siempre visible sin ningún trámite. La
lógica vive separada en `AlcanciaCore`, así que el widget real se puede
agregar después sin rehacer nada.

## Cómo se guarda

Un JSON local en `~/Library/Application Support/Alcancia/data.json`. Sin
telemetría. La única llamada de red es la consulta pública y gratuita del
tipo de cambio USD→MXN (api.frankfurter.app) cuando capturas en dólares.

Los archivos de versiones anteriores se abren sin perder nada: cada campo
nuevo se decodifica con valor por defecto, y los movimientos viejos se
leen como ingresos.

## Estructura

```
alcancia/
  Package.swift
  Sources/
    AlcanciaCore/   # modelo, presupuesto, resumen mensual, tipo de cambio —
                     # sin UI, cubierto por pruebas
    Alcancia/        # la app SwiftUI (MenuBarExtra + panel flotante)
  Tests/
    AlcanciaCoreTests/
  build_app.sh       # empaqueta Alcancía.app firmado ad-hoc
```

## Cómo correrla

```bash
cd alcancia
./build_app.sh
open "Alcancía.app"
```

Para tenerla siempre a la mano:

```bash
mv "Alcancía.app" /Applications/
```

Pruebas:

```bash
swift test
```
````

- [ ] **Step 2: Package and verify**

Run: `cd alcancia && ./build_app.sh && plutil -p "Alcancía.app/Contents/Info.plist" | grep -E "LSUIElement|CFBundleIdentifier" && codesign -dv "Alcancía.app" 2>&1 | grep -i signature`
Expected: finishes with `Listo: ./Alcancía.app`, `LSUIElement => 1`, `CFBundleIdentifier => "com.mvisuals.alcancia"`, `Signature=adhoc`.

- [ ] **Step 3: Commit**

```bash
cd alcancia
git add README.md
git commit -m "Update README for the expense-control app"
```

---

## Post-plan note

`Alcancía.app` and `.build/` stay git-ignored. After Task 9 the working app is at `alcancia/Alcancía.app`.

**Every task must leave `swift build` and `swift test` green.** `swift test` compiles the executable target as well as the library, so a view that does not compile stops the entire suite from running — not just that view's own checks. Tasks 1-6 are additive for exactly this reason, and Task 7 is deliberately atomic.

The single riskiest thing in this plan is the migration of existing `data.json` files (Tasks 1 and 4). `testLoadsFileWrittenByThePreviousVersion` is the test that stands between a working upgrade and a user who believes the app deleted their money — treat any failure there as a stop-the-line event, never as a test to adjust.
