# Features

Status for **v1.3.0**.

Legend: ✅ Done · ⚠️ Partial · ❌ Not implemented · 🚫 Deferred

---

## Core

| Feature | Status | Notes |
|---------|--------|-------|
| SwiftData models | ✅ | All spec models + `ShoppingListItem` |
| Account CRUD | ✅ | Settings → Accounts |
| Transaction CRUD | ✅ | Full form + quick add |
| Categories & subcategories | ✅ | Seed data + user categories |
| Dashboard | ✅ | Net worth, cash flow, budgets, payments, debts, goals |
| Tab navigation (5 tabs) | ✅ | |
| iCloud / CloudKit sync | 🚫 | Local App Group store only — [ADR 002](decisions/002-local-persistence-v1.md) |
| iCloud status in Settings | ❌ | Blocked on CloudKit |

---

## Transactions

| Feature | Status | Notes |
|---------|--------|-------|
| Group by day + daily total | ✅ | Day total converted to base currency |
| Search | ✅ | Title, note, category, amount |
| Filter account/category/type | ✅ | |
| Filter date range | ❌ | |
| Filter amount range | ❌ | |
| Sort options | ✅ | Date, amount, category |
| Quick add (3 taps) | ⚠️ | Account → amount → category (skips account if default set) |
| Transfer type | ✅ | |
| Split transaction | ✅ | |
| Swipe delete | ✅ | |
| Swipe duplicate | ❌ | |
| Batch delete | ✅ | Edit mode |
| Batch edit | ❌ | |
| Recurring toggle on transaction | ❌ | Use planned payments instead |
| Photo attachment (picker) | ❌ | Receipt scan stores JPEG |
| Receipt OCR | ✅ | Vision + Polish fiscal parser; merchant/title, attachment, low-confidence alert |

---

## Categories

| Feature | Status | Notes |
|---------|--------|-------|
| System categories | ✅ | `SeedDataService` |
| Hide system categories | ✅ | “Show Hidden” toggle |
| Merge | ✅ | Reassigns transactions, budgets, payments |
| Delete custom | ✅ | Orphans txs (category nil) |

---

## Budgets

| Feature | Status | Notes |
|---------|--------|-------|
| Per-category or all-spending | ✅ | |
| Weekly / monthly / custom | ✅ | |
| Progress bar + threshold colors | ✅ | |
| Rollover unused | ✅ | `BudgetService.processRollovers` |
| Budget history | ✅ | Last 3 months in detail |
| Push alerts at threshold | ⚠️ | Fires when app syncs, not true background — [notifications.md](notifications.md) |
| Global period selector on tab | ❌ | Per-budget period only |

---

## Planning

| Feature | Status | Notes |
|---------|--------|-------|
| Planned payments list | ✅ | |
| Calendar month grid | ✅ | Toolbar on Payments, Debts, and Goals |
| Mark as paid → transaction | ✅ | Via `PlannedPaymentUseCase.markPaid(from:)` |
| Auto-create on due date | ✅ | `RecurrenceProcessor` |
| Payment reminders | ✅ | Configurable days before |
| Overdue indicator | ✅ | |
| Debts | ✅ | Link txs, repayments, reminders |
| Goals | ✅ | Progress, contributions |
| Goal → transaction on completion | ✅ | Only if linked account set — [ADR 006](decisions/006-goal-transaction-on-completion.md) |
| Goal confetti | ❌ | Haptics only |
| Estimated completion date | ✅ | Goal detail |

---

## Reports

| Feature | Status | Notes |
|---------|--------|-------|
| Spending by category (chart) | ✅ | Swift Charts |
| Cash flow over time | ✅ | Day / week / month buckets by period length |
| Net worth trend | ✅ | Adaptive sampling + thinned axis labels |
| Spending vs prior period | ✅ | |
| Top payees | ✅ | |
| Daily average | ✅ | |
| Period selector | ✅ | 7D–12M + custom |
| Export PDF | ✅ | A4 portrait report with period stats and transaction ledger |
| Weekly summary sheet | ✅ | From notification / Settings preview |

---

## Settings & data

| Feature | Status | Notes |
|---------|--------|-------|
| Appearance (accent) | ✅ | Page wash + solid Form/List surfaces; glass effects untinted |
| App icon picker | ❌ | |
| Currency & base currency | ✅ | Invalidates + refreshes rates on change |
| Notifications settings | ✅ | Permission + weekly summary + preview |
| App language | ✅ | Opens iOS Settings (per-app language) |
| Donate / Buy Me a Coffee | ✅ | About → external BMC link |
| Localization (String Catalogs) | ✅ | en + pl, ru, uk, de, es, fr |
| JSON export/import | ✅ | Format v2, merge mode; ISO-8601 export detection |
| Purseful Web backup import | ✅ | Extra |
| CSV export/import | 🚫 | |
| Clear all data | ✅ | |
| Bank connections UI | 🚫 | Model + service stub only |
| Minimum iOS | ✅ | **iOS 18.0**; Liquid Glass on 26+ |

---

## Multi-currency

| Feature | Status | Notes |
|---------|--------|-------|
| Per-account currency | ✅ | |
| Base currency totals | ✅ | Dashboard, reports, day headers |
| Frankfurter exchange rates | ✅ | Launch, foreground, base-currency change; cache by base |
| Manual rates UI | ❌ | API exists |
| Transaction foreign currency UI | ❌ | Model + import support |
| Stored rate in calculations | ✅ | When `exchangeRate` set |

---

## Widgets

| Feature | Status | Notes |
|---------|--------|-------|
| Balances (small/medium) | ✅ | Primary + 4 secondary accounts; medium adds spent today + upcoming payments |
| Budget (medium) | ✅ | Configurable; remaining + ring |
| Recent transactions (large) | ✅ | Last 6 + spent today + next due |
| Lock Screen — spent today | ✅ | Inline / rectangular (no circular) |
| Widget configuration | ✅ | Account (Balances), budget |
| Deep links | ✅ | `purseful://` |

See [widgets.md](widgets.md).

---

## Notifications

| Feature | Status | Notes |
|---------|--------|-------|
| Budget threshold / exceeded | ⚠️ | App-driven sync |
| Payment reminders | ✅ | Scheduled |
| Debt due reminders | ✅ | |
| Goal target date | ✅ | Not in Settings UI |
| Weekly summary | ✅ | Mon 9:00 → opens weekly summary sheet; Settings preview |

See [notifications.md](notifications.md).

---

## Other

| Feature | Status | Notes |
|---------|--------|-------|
| Spotlight search | ⚠️ | Index on Settings appear; stale between visits |
| VoiceOver / accessibility pass | ⚠️ | Partial labels |
| iPad keyboard shortcuts | ❌ | Defined, not wired |
| Shopping list | ✅ | Extra feature |
| Bank sync (Enable Banking) | 🚫 | [BankSyncService](../purseful-ios/Services/BankSync/BankSyncService.swift) stub |
| Privacy manifest | ✅ | `PrivacyInfo.xcprivacy` |

---

## Test coverage map

| Area | Test file |
|------|-----------|
| Budget math & rollover | `BudgetServiceTests` |
| Balances & conversion | `BalanceCalculatorTests` (incl. day net cash flow) |
| Import/export v2 | `ImportExportTests` |
| Receipt parsing | `ReceiptParserTests` |
| Debts | `DebtServiceTests` |
| Goals | `GoalUseCaseTests` |
| Notifications helpers | `NotificationHelpersTests` |
| Web import | `PursefulWebImportTests` |
| Bank dedup | `BankTransactionDedupTests` |
| Shopping list parser | `ShoppingListParserTests` |
| Daily spend | `DailySpendCalculatorTests` |
| PDF report export | `ReportPDFExportTests` |

Full list: [testing.md](testing.md).
