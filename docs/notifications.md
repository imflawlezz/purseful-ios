# Notifications

Local notifications via `UserNotifications`. Orchestrated by `NotificationScheduler`; delivery logic in `NotificationService`.

Authorization is requested from Settings → Notifications. All scheduling no-ops if not `.authorized`.

---

## Sync entry points

`NotificationScheduler.syncAll(context:transactions:exchangeRates:)` runs:

1. Budget alert evaluation (immediate)
2. Reschedule payment reminders
3. Reschedule debt reminders
4. Reschedule goal reminders
5. Reschedule weekly summary

**When sync runs:**

| Trigger | Location |
|---------|----------|
| App bootstrap | `AppBootstrapUseCase` |
| After saves | `NotificationScheduler.syncAfterSave` (transactions, goals, import, etc.) |
| Dashboard pull-to-refresh | `DashboardRefreshUseCase` |
| App foreground | `WidgetSyncObserver` |
| Recurrence auto-pay | `RecurrenceProcessor` after save |

---

## Budget alerts

**Immediate delivery** (`trigger: nil`) when `evaluateBudgetAlerts` runs during sync.

| Condition | Level | Message |
|-----------|-------|---------|
| `progress >= alertThreshold` | `threshold` | “{name} is at N% of your limit.” |
| `progress >= 1.0` | `exceeded` | “{name} has exceeded your limit.” |

- **Limit:** `BudgetService.effectiveLimit` (includes rollover when enabled).
- **Spent:** `BudgetService.spentAmount` for current period.
- **Dedup:** UserDefaults key `budgetAlert.{budgetID}.{periodStartDay}.{level}` — one alert per level per budget period.

### Limitation

Budget alerts require the app to run sync while the user is near/over threshold. They are **not** background-scheduled threshold watchers. See [decisions/005-notification-sync-model.md](decisions/005-notification-sync-model.md).

Clear dedup state when deleting a budget: `NotificationService.clearBudgetAlertState(for:)`.

---

## Planned payment reminders

**Scheduled** with `UNCalendarNotificationTrigger`.

| Setting | Source |
|---------|--------|
| Fire date | `nextDueDate - reminderDaysBefore` (start of day) |
| Identifier | `payment-{uuid}` |
| Skipped if | Inactive, one-time already paid, reminder date in past |

Title: payment name. Body includes amount and due date.

---

## Debt reminders

**Scheduled** for `dueDate - 1 day` at 9:00 (when due date set).

| Identifier | `debt-{uuid}` |
| Skipped if | No due date, remaining ≤ 0, fire date in past |

---

## Goal reminders

**Scheduled** for `targetDate - 3 days` at 9:00.

| Identifier | `goal-{uuid}` |
| Skipped if | No target date, completed, fire date in past |

Not exposed in Settings UI (always on when authorized).

---

## Weekly summary

**Scheduled** for next **Monday 9:00** (one-shot, rescheduled each sync).

| Setting | `AppSettings.weeklySummaryEnabled` |
| Body | “Last week you spent {amount}.” |
| Period | Monday 00:00 – Sunday 23:59:59 **before** the fire Monday |
| Identifier | `weekly-summary` |

Spend is recomputed from transactions on each sync so the body stays fresh as the week progresses. If the app is not opened between Sunday night and Monday 9:00, the last synced amount is delivered.

Helper: `NotificationHelpers.nextMondayMorning()`.

---

## User settings

**Settings → Notifications**

- Request permission / show status
- Toggle weekly summary (`AppSettings.weeklySummaryEnabled`)

Per-budget threshold is on each budget form (`alertThreshold` slider).  
Per-payment reminder lead time is on each planned payment form (`reminderDaysBefore` stepper).

---

## Code map

| File | Role |
|------|------|
| `Services/NotificationScheduler.swift` | Orchestrator |
| `Services/NotificationService.swift` | UNCenter APIs |
| `NotificationHelpers` | Dedup keys, next Monday |
| `BudgetService` | Spent/limit for budget alerts |

---

## Testing

`NotificationHelpersTests` — dedup key format, next Monday calculation.

Manual QA checklist:

1. Enable notifications → grant permission.
2. Create budget at 80% threshold → spend until alert (with app open after save).
3. Create payment due in 2 days, reminder 1 day → verify pending notification.
4. Enable weekly summary → verify pending Monday notification in Settings → Notifications (system).
