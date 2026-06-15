# Features

Status matrix comparing [prompt.md](../prompt.md) to the **current codebase** (v1.0.0).

Legend: ✅ Done · ⚠️ Partial · ❌ Not implemented · 🚫 Deferred by choice

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
| Group by day + daily total | ✅ | |
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
| Receipt OCR | ⚠️ | Vision + parser; merchant/title, attachment, low-confidence alert |

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
| Calendar month grid | ✅ | |
| Mark as paid → transaction | ✅ | |
| Auto-create on due date | ✅ | `RecurrenceProcessor` |
| Payment reminders | ✅ | Configurable days before |
| Overdue indicator | ✅ | |
| Debts | ✅ | Link txs, repayments, reminders |
| Goals | ✅ | Progress, contributions |
| Goal → transaction on completion | ✅ | Only if linked account set — [ADR 003](decisions/003-goal-transaction-on-completion.md) |
| Goal confetti | ❌ | Haptics only |
| Estimated completion date | ✅ | Goal detail |

---

## Reports

| Feature | Status | Notes |
|---------|--------|-------|
| Spending by category (chart) | ✅ | Swift Charts |
| Cash flow over time | ⚠️ | Weekly buckets only |
| Net worth trend | ✅ | |
| Spending vs prior period | ✅ | |
| Top payees | ✅ | |
| Daily average | ✅ | |
| Period selector | ✅ | 7D–12M + custom |
| Export PDF | 🚫 | Share partial image only |
| Export report image | ⚠️ | Subset of report |

---

## Settings & data

| Feature | Status | Notes |
|---------|--------|-------|
| Appearance (accent) | ✅ | |
| App icon picker | ❌ | |
| Currency & base currency | ✅ | |
| Notifications settings | ✅ | Permission + weekly summary |
| JSON export/import | ✅ | Format v2, merge mode |
| Purseful Web backup import | ✅ | Extra |
| CSV export/import | 🚫 | |
| Clear all data | ✅ | |
| Bank connections UI | 🚫 | Model + service stub only |

---

## Multi-currency

| Feature | Status | Notes |
|---------|--------|-------|
| Per-account currency | ✅ | |
| Base currency totals | ✅ | |
| Frankfurter exchange rates | ✅ | Cached |
| Manual rates UI | ❌ | API exists |
| Transaction foreign currency UI | ❌ | Model + import support |
| Stored rate in calculations | ✅ | When `exchangeRate` set |

---

## Widgets

| Feature | Status | Notes |
|---------|--------|-------|
| Small — account balance | ✅ | First visible account |
| Medium — budget progress | ✅ | First budget by name sort |
| Large — recent transactions | ✅ | |
| Lock screen — today spend | ✅ | |
| Widget configuration (pick account) | ❌ | |
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
| Weekly summary | ✅ | Mon 9:00, previous calendar week |

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
| Balances & conversion | `BalanceCalculatorTests` |
| Import/export v2 | `ImportExportTests` |
| Receipt parsing | `ReceiptParserTests` |
| Debts | `DebtServiceTests` |
| Goals | `GoalUseCaseTests` |
| Notifications helpers | `NotificationHelpersTests` |
| Web import | `PursefulWebImportTests` |
| Bank dedup | `BankTransactionDedupTests` |
| Shopping list parser | `ShoppingListParserTests` |
| Daily spend | `DailySpendCalculatorTests` |

Full list: [testing.md](testing.md).
