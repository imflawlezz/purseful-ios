# Architecture decision records

Short documents explaining **why** the codebase looks the way it does.

| ADR | Title |
|-----|-------|
| [001](001-use-case-layer.md) | Use-case layer for writes |
| [002](002-local-persistence-v1.md) | Local persistence without CloudKit (v1) |
| [003](003-planned-payments-not-recurring-transactions.md) | Planned payments instead of recurring transactions |
| [004](004-budget-rollover.md) | Budget rollover processing |
| [005](005-notification-sync-model.md) | Notification sync model |
| [006](006-goal-transaction-on-completion.md) | Goal transaction on completion only |

## Adding a new ADR

1. Copy the template below to `00N-short-title.md`.
2. Link it from this index and from relevant docs (`architecture.md`, `features.md`).
3. Keep it to one screen.

### Template

```markdown
# ADR NNN: Title

**Status:** Proposed | Accepted | Superseded  
**Date:** YYYY-MM

## Context
What problem or choice?

## Decision
What we did.

## Consequences
Positive and negative outcomes.

## Alternatives considered
What we didn't do.
```
