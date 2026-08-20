# Architecture

Purseful uses a **pragmatic clean architecture**: SwiftUI + SwiftData for UI and persistence, use cases for writes, and service enums for pure logic.

---

## Layer overview

```mermaid
flowchart TB
    subgraph presentation ["Presentation"]
        Views["SwiftUI Views - Query reads"]
        AppState["AppState - rates and navigation"]
    end

    subgraph domain ["Domain"]
        UC["Use Cases"]
    end

    subgraph services ["Services"]
        SVC["BudgetService, ExportService, etc."]
    end

    subgraph persistence ["Persistence"]
        Repo["SwiftDataRepository"]
        SD[("SwiftData App Group store")]
    end

    subgraph extensions ["Extensions"]
        Widgets["PursefulWidgets"]
        AG["App Group UserDefaults snapshot"]
    end

    Notif["NotificationScheduler"]

    Views -->|writes| UC
    Views -->|reads| SD
    UC --> Repo
    UC --> SVC
    Repo --> SD
    SVC --> SD
    UC -->|syncAfterSave| Notif
    Views --> AppState
    SD --> AG
    AG --> Widgets
```

---

## App entry & dependency injection

**File:** `purseful-ios/purseful_iosApp.swift`

1. Creates `ModelContainer` via `ModelContainerProvider`.
2. Builds `DependencyContainer(context: mainContext)`.
3. Injects into SwiftUI:
   - `.environment(appState)` — `@Observable AppState`
   - `.environment(dependencies)` — `@Observable DependencyContainer`
4. Runs `appBootstrap.runStartupTasks()` on launch.
5. Attaches `WidgetSyncObserver(dependencies:appState:)` for foreground sync (explicit params — no `@Environment` from `.background`).

### DependencyContainer

**File:** `purseful-ios/App/Composition/DependencyContainer.swift`

| Use case | Responsibility |
|----------|----------------|
| `AppBootstrapUseCase` | Seed data, sort orders, budget rollover, recurrence, notifications |
| `TransactionUseCase` | Save/delete transactions, split children, category resolution |
| `BudgetUseCase` | Save/delete budgets, process rollovers |
| `PlannedPaymentUseCase` | CRUD, mark paid (builds transaction), category resolution |
| `DebtUseCase` | Debt CRUD via `DebtService` (opening tx sync on save) |
| `GoalUseCase` | Goals; completion transaction when linked account set |
| `CategoryUseCase` | Categories; merge reassigns tx/budgets/payments |
| `AccountUseCase` | Account CRUD, reorder, clear default on delete |
| `ImportExportUseCase` | JSON import/export, clear data, widget sync trigger |
| `DashboardRefreshUseCase` | Pull-to-refresh + exchange-rate refresh pipeline |
| `ShoppingListUseCase` | Shopping list CRUD |

### Reading dependencies in views

```swift
@Environment(DependencyContainer.self) private var dependencies

try? dependencies.transactions.save(transaction: tx, isNew: true, splitLines: [])
```

Previews use `PreviewDependencies.withPreviewDependencies()`.

---

## Read vs write paths

| Operation | Pattern |
|-----------|---------|
| List transactions, budgets, etc. | `@Query` in the view |
| Create/update/delete | Use case → `repository.save()` |
| Calculations (spent, net worth, day totals) | `BudgetService`, `BalanceCalculator` (called from views with `@Query` data) |
| Export JSON | `ImportExportUseCase` → `ExportService` |

Views should **not** call `modelContext` / `repository.context` for writes. Acceptable presentation helpers:

- `AccountPreferences.visibleAccounts` / `preferredAccount` (pure filtering)
- `DebtService` read helpers (`debtsDue`, `openingTransaction`, `isDebtLinkedTransaction`)
- `NotificationScheduler.syncAll` from Settings after permission / toggle changes

Known leak: `PursefulWebImportView` still uses `modelContext` directly (legacy import path).

---

## Concurrency

App target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Pure parsers and calculators that must run off the main actor (or be passed as function values) are marked `nonisolated` (e.g. `ReceiptParser`). UI and use cases stay on the main actor.

---

## Persistence

**File:** `purseful-ios/App/ModelContainerProvider.swift`

- Store path: App Group `Purseful.store`
- **Not** using CloudKit in v1 (local only)
- On corruption, store files are deleted and recreated (data loss — document for users)

**Repository:** `SwiftDataRepository` implements `DataRepositoryProtocol` (fetch, insert, delete, save, `context`).

---

## Startup sequence

`AppBootstrapUseCase.runStartupTasks()`:

1. `SeedDataService.seedIfNeeded` — system categories
2. `AccountPreferences.ensureSortOrders`
3. `BudgetUseCase.processRollovers` — advance budget periods
4. `RecurrenceProcessor.processDueItems` — auto-create due planned payments
5. `NotificationScheduler.syncAll`

---

## Foreground & refresh sync

| Trigger | Actions |
|---------|---------|
| App launch | Bootstrap (above); `MainTabView.task` refreshes exchange rates |
| Scene becomes active | `WidgetSyncObserver`: exchange rates → rollover → widget snapshot → `NotificationScheduler.syncAll` |
| Dashboard pull-to-refresh | `DashboardRefreshUseCase.refresh` |
| Base currency change | Invalidate rate cache → `DashboardRefreshUseCase.refreshExchangeRates` |
| After most saves | `NotificationScheduler.syncAfterSave` (async) |

---

## AppState

**File:** `purseful-ios/App/AppState.swift`

- In-memory exchange rates + `ExchangeRateCache` (UserDefaults, keyed by base)
- Tab selection, planning section, Spotlight pending IDs, weekly-summary sheet flag
- `refreshExchangeRates()` → `ExchangeRateService` (Frankfurter); does not return stale rates for a different base

---

## Services vs use cases

**Use cases** — orchestrate persistence + side effects (notifications, widget sync hooks).

**Services** — pure or side-effecting utilities:

| Service | Role |
|---------|------|
| `BudgetService` | Period ranges, spent amount, rollover processing |
| `BalanceCalculator` | Balances, net worth, currency conversion, day net cash flow |
| `CategoryService` | Resolve “Other” category, debt-only categories |
| `DebtService` | Debt categories, repayments, linked transactions |
| `RecurrenceProcessor` | Auto transactions from planned payments |
| `ExportService` / `ImportService` | JSON v2 (ISO-8601 dates for export detection) |
| `ReportSummaryBuilder` / `ReportPDFExportService` | Reports PDF export |
| `NotificationService` / `NotificationScheduler` | Local notifications |
| `ReceiptScanner` / `ReceiptParser` | On-device OCR (PL fiscal heuristics) |
| `AccentTheme` | Accent page wash and solid list/form surfaces |
| `SpotlightService` | Core Spotlight indexing |
| `WidgetDataSync` | App Group JSON snapshot for WidgetKit |
| `PursefulWebImportService` | Import from web app backup |
| `BankSyncService` / `EnableBankingService` | Prepared, disabled in v1 |

---

## Navigation

**File:** `purseful-ios/App/MainTabView.swift`

| Tab | View |
|-----|------|
| 0 Dashboard | `DashboardView` |
| 1 Transactions | `TransactionsView` |
| 2 Budgets | `BudgetsView` |
| 3 Planned | `PlanningView` |
| 4 Reports | `ReportsView` |

Settings is reached from the Dashboard toolbar. Deep links: URL scheme `purseful://`, widget links, Spotlight via `AppState.handleSpotlightIdentifier`, weekly summary via `purseful://weekly-summary`.

User-facing copy lives in String Catalogs — see [i18n.md](i18n.md).

---

## Multi-target layout

| Target | Purpose |
|--------|---------|
| `purseful-ios` | Main app |
| `PursefulWidgets` | WidgetKit extension (reads App Group snapshot) |
| `purseful-iosTests` | Unit tests |

Shared constants: `AppConstants.appGroupIdentifier`.

---

## Related ADRs

- [001 — Use-case layer](decisions/001-use-case-layer.md)
- [002 — Local persistence without CloudKit](decisions/002-local-persistence-v1.md)
- [003 — Planned payments instead of recurring transactions](decisions/003-planned-payments-not-recurring-transactions.md)
