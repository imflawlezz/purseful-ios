# ADR 005: Notification sync model

**Status:** Accepted  
**Date:** 2026-06

## Context

Notifications mix immediate delivery (budget alerts) and scheduled triggers (payments, debts, goals, weekly summary). Budget alerts originally only fired during explicit sync.

## Decision

**Orchestrator:** `NotificationScheduler.syncAll`

| Type | Delivery | Rescheduled on sync |
|------|----------|---------------------|
| Budget threshold / exceeded | Immediate (`trigger: nil`) | Dedup per period via UserDefaults |
| Planned payment | Calendar trigger | Yes — cancel + re-add |
| Debt due | Calendar trigger | Yes |
| Goal target | Calendar trigger | Yes |
| Weekly summary | Next Mon 9:00 | Yes — spend for prior Mon–Sun week |

**Sync triggers:** bootstrap, foreground, pull-to-refresh, `syncAfterSave` after data changes.

## Consequences

**Positive**

- Payment/debt/goal reminders work without app open once scheduled.
- Weekly summary amount refreshes as transactions sync during the week.

**Negative**

- Budget alerts still require app to run sync near threshold — not true background monitoring.
- Fixing budget background alerts would need BGAppRefreshTask or Notification Service Extension (out of v1 scope).

## Related

See [notifications.md](../notifications.md).
