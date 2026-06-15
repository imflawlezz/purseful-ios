# ADR 003: Planned payments instead of recurring transactions

**Status:** Accepted  
**Date:** 2026-06

## Context

The spec mentions recurring transactions and a `isRecurring` flag on `Transaction`. The app also has `PlannedPayment` for bills with due dates, calendar UI, and auto-create.

Maintaining both paths duplicated logic and confused UX.

## Decision

- **Recurring bills/subscriptions** → `PlannedPayment` + optional `RecurringRule`.
- **`RecurrenceProcessor`** creates transactions when `autoCategorize` is on and due date ≤ today.
- **No UI** for standalone recurring transactions; `Transaction.isRecurring` retained for import compatibility only.

Mark-as-paid and calendar flows operate on planned payments.

## Consequences

**Positive**

- Single mental model for “things that happen on a schedule.”
- Notifications tied to `nextDueDate` and `reminderDaysBefore`.

**Negative**

- Spec item “recurring toggle on transaction form” not implemented.
- Imported recurring flags are stored but not edited in UI.
