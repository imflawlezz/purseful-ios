# ADR 004: Budget rollover processing

**Status:** Accepted  
**Date:** 2026-06

## Context

Budgets have a `rollover` toggle and `rolloverAmount`, but originally nothing updated carryover when periods changed.

## Decision

Implement period rollover in `BudgetService.processRollovers`:

1. Track `rolloverPeriodStart` per budget.
2. On each processing run, for each elapsed period:
   - If rollover on: `rolloverAmount = max(0, effectiveLimit - spent)`
   - If rollover off: `rolloverAmount = 0`
3. Advance `rolloverPeriodStart` to current period start.
4. Skip `BudgetPeriod.custom` budgets.

**When processing runs:**

- App bootstrap (`AppBootstrapUseCase`)
- Dashboard pull-to-refresh (`DashboardRefreshUseCase`)
- App foreground (`WidgetSyncObserver`)

**Effective limit:** `amount + rolloverAmount` when rollover enabled.

## Consequences

**Positive**

- Envelope-style “remaining + rolled over” matches user expectation.
- Exported/imported via JSON including `rolloverPeriodStart`.

**Negative**

- Rollover only advances when app runs (not server-side).
- Overspending does not reduce next period (carryover floors at 0).

## Tests

`BudgetServiceTests` — carryover, overspend, disabled rollover, custom period skip.
