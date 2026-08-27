# Alcancía Confidence and Portability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add reliable persistence, continuous real balance, monthly budgets, robust recurring expenses, editing/search/undo, configurable hotkey, onboarding, accessibility, and CSV/JSON/XLSX export.

**Architecture:** Keep the two-target Swift package. Add small value types and pure services to `AlcanciaCore`; keep AppKit dialogs/controllers in `Alcancia`. Financial state is derived from entries and dated balance anchors, never monthly snapshots.

**Tech Stack:** Swift 5.10 language mode, Swift 6.2 toolchain, Foundation, SwiftUI, AppKit, Carbon, XCTest; no third-party runtime dependencies.

**Spec:** `docs/superpowers/specs/2026-08-27-alcancia-confianza-y-portabilidad-design.md`

## Global Constraints

- macOS 14+, `swift-tools-version: 5.10`, no third-party runtime dependencies.
- Existing `data.json` files must decode without losing entries.
- Every new persisted field uses `decodeIfPresent` with a safe default.
- Money math uses `Decimal`; remote `Double` rates are validated before conversion.
- Mutations publish only after successful persistence.
- Tests use temporary files and never the user's Application Support data.
- UI copy remains Spanish (Mexico).
- XLSX output is native OOXML and independently readable by `openpyxl`.

---

### Task 1: Financial ledger, monthly budgets, and recurrence identity

**Files:**
- Create: `Sources/AlcanciaCore/BalanceAdjustment.swift`
- Create: `Sources/AlcanciaCore/MonthKey.swift`
- Modify: `Sources/AlcanciaCore/Entry.swift`
- Modify: `Sources/AlcanciaCore/AlcanciaStore.swift`
- Modify: `Sources/AlcanciaCore/RecurringExpense.swift`
- Test: `Tests/AlcanciaCoreTests/AlcanciaStoreTests.swift`
- Test: `Tests/AlcanciaCoreTests/EntryTests.swift`

**Interfaces:**
- Produces: `BalanceAdjustment`, `MonthKey`, `openingBalance(for:)`, `closingBalance(for:)`, `setBalance(_:note:date:)`, `budget(for:)`, `setBudget(_:for:)`, `updateEntry(_:)`, `skipRecurring(id:for:)`.
- Consumes: existing `Entry`, `RecurringExpense`, `MonthlySummary`.

- [ ] Write failing tests proving a balance anchor ignores earlier entries, later entries change the balance, month closing rolls into next opening, changing September's budget leaves August unchanged, duplicate recurring names remain independent, and a manual note does not mark a recurring template as logged.
- [ ] Run `swift test --filter AlcanciaStoreTests` and verify failures are caused by missing APIs/behavior.
- [ ] Add the value types and tolerant Codable fields. Preserve legacy behavior when no balance adjustment exists.
- [ ] Implement the derived balance and month-keyed budget APIs plus stable recurring identity/skip periods.
- [ ] Run focused tests, then the full suite; both must pass with no warnings.

### Task 2: Transactional persistence, backups, validation, and recovery

**Files:**
- Create: `Sources/AlcanciaCore/StoreError.swift`
- Create: `Sources/AlcanciaCore/MoneyParser.swift`
- Modify: `Sources/AlcanciaCore/AlcanciaStore.swift`
- Modify: `Sources/AlcanciaCore/ExchangeRateService.swift`
- Test: `Tests/AlcanciaCoreTests/AlcanciaStoreTests.swift`
- Test: `Tests/AlcanciaCoreTests/ExchangeRateServiceTests.swift`
- Create: `Tests/AlcanciaCoreTests/MoneyParserTests.swift`

**Interfaces:**
- Produces: `StoreError`, `StoreStatus`, throwing/result mutation boundary, `restoreLatestBackup()`, `MoneyParser.parse(_:)`.
- Consumes: Task 1's updated store data and mutation APIs.

- [ ] Write failing tests for unwritable destinations, publish-after-save, five-backup rotation, corrupt-primary recovery, invalid amounts/rates, missing USD rate, HTTP failure, and comma-decimal parsing.
- [ ] Run each focused test and verify the expected RED failure.
- [ ] Implement transactional mutation through one internal helper, backup rotation, recoverable load state, validation and localized parsing.
- [ ] Make the exchange fetcher validate HTTP 2xx and positive finite rates.
- [ ] Run focused tests and full suite to GREEN.

### Task 3: Native CSV, JSON, and XLSX exporters

**Files:**
- Create: `Sources/AlcanciaCore/DataExporter.swift`
- Create: `Sources/AlcanciaCore/XLSXWriter.swift`
- Create: `Sources/AlcanciaCore/ZIPArchiveWriter.swift`
- Create: `Tests/AlcanciaCoreTests/DataExporterTests.swift`

**Interfaces:**
- Produces: `DataExportFormat`, `DataExporter.export(data:format:calendar:) -> Data`.
- Consumes: `AlcanciaData`, Task 1 balance and month models.

- [ ] Write failing tests for quoted CSV, ISO-8601 JSON round-trip, ZIP/XLSX signatures, required worksheet names, formulas and non-ASCII text.
- [ ] Verify RED with `swift test --filter DataExporterTests`.
- [ ] Implement CSV and JSON encoders plus a minimal uncompressed OOXML ZIP writer with CRC32.
- [ ] Generate a sample workbook in a temporary directory and verify its four sheets with `openpyxl`.
- [ ] Run focused tests and full suite to GREEN.

### Task 4: Onboarding, balance and budget settings, recovery, and export UI

**Files:**
- Create: `Sources/Alcancia/OnboardingView.swift`
- Create: `Sources/Alcancia/ExportController.swift`
- Modify: `Sources/Alcancia/AlcanciaAppMain.swift`
- Modify: `Sources/Alcancia/MenuBarView.swift`
- Modify: `Sources/Alcancia/SettingsView.swift`
- Modify: `Sources/Alcancia/MonthHeaderView.swift`

**Interfaces:**
- Consumes: Tasks 1–3 store, status and exporter APIs.
- Produces: first-run flow, adjustment editor, per-month budget editor, recovery banner and save-panel export.

- [ ] Add state-level tests where logic can be extracted into Core; verify they fail first.
- [ ] Implement onboarding with optional deferral and today-balance anchor.
- [ ] Show the visible month's closing balance, allow adjustment, edit that month's budget, and surface save/recovery errors.
- [ ] Add CSV/JSON/XLSX save panels and success/error feedback.
- [ ] Build and run the full test suite.

### Task 5: Edit, undo, search, filters, and safe USD capture

**Files:**
- Create: `Sources/Alcancia/EntryEditorView.swift`
- Create: `Sources/AlcanciaCore/EntryFilter.swift`
- Modify: `Sources/Alcancia/HistoryView.swift`
- Modify: `Sources/Alcancia/QuickAddView.swift`
- Modify: `Sources/Alcancia/QuickCaptureView.swift`
- Modify: `Sources/Alcancia/MenuBarView.swift`
- Test: `Tests/AlcanciaCoreTests/EntryFilterTests.swift`

**Interfaces:**
- Consumes: transactional `updateEntry`, delete/add APIs and `MoneyParser`.
- Produces: filtered history, inline editor, session undo, immutable USD submission snapshot.

- [ ] Write failing filter and mutation tests, then verify RED.
- [ ] Implement pure filtering and store undo snapshots.
- [ ] Implement inline editing and compact filter controls without adding fields to the common quick-capture path.
- [ ] Freeze/disable capture state across exchange-rate awaits and use `MoneyParser` everywhere.
- [ ] Run focused tests and full suite to GREEN.

### Task 6: Hotkey configuration, recurrence UI, accessibility, and panel safety

**Files:**
- Create: `Sources/Alcancia/HotKeyShortcut.swift`
- Modify: `Sources/Alcancia/HotKeyManager.swift`
- Modify: `Sources/Alcancia/SettingsView.swift`
- Modify: `Sources/Alcancia/MenuBarView.swift`
- Modify: `Sources/Alcancia/CategoryRowView.swift`
- Modify: `Sources/Alcancia/SpendingTrendView.swift`
- Modify: `Sources/Alcancia/DesktopPanelController.swift`
- Modify: `Sources/Alcancia/DesktopPanelView.swift`
- Modify: `Sources/Alcancia/QuickCaptureView.swift`

**Interfaces:**
- Consumes: stable recurring period APIs from Task 1.
- Produces: preset global shortcuts with registration status, register/skip recurrence actions, semantic accessibility and visible-screen panel restoration.

- [ ] Add pure shortcut mapping tests and verify RED.
- [ ] Return and display Carbon registration errors; persist the chosen preset.
- [ ] Add recurrence skip/register actions for the current month.
- [ ] Add accessible labels/values/hints and replace tap-only panel behavior with a semantic button.
- [ ] Clamp restored panel origins to a visible screen.
- [ ] Run full tests plus debug, release and strict-concurrency builds.

### Task 7: Documentation and final verification

**Files:**
- Modify: `README.md`
- Modify: `Resources/guia-instalacion/INSTALL.md`

**Interfaces:**
- Consumes: all completed behavior.
- Produces: accurate user and developer documentation.

- [ ] Document onboarding, balance semantics, recovery, editing, filters and all export formats.
- [ ] Replace the stale fixed test count with a command-based statement.
- [ ] Run `swift test --parallel`, `swift build -c release`, strict-concurrency build, and independently open a generated XLSX.
- [ ] Confirm `git diff --check` and inspect the final diff for accidental personal data or unrelated files.

