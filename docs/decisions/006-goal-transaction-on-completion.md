# ADR 006: Goal transaction on completion only

**Status:** Accepted  
**Date:** 2026-06

## Context

The spec suggests goal contributions create transactions to a linked account. Product decision: incremental contributions are **tracking only**; a ledger entry on every contribution would clutter accounts.

## Decision

- **Contributions** update `Goal.currentAmount` only — no transaction.
- **On completion** (contribute reaches target, mark complete, or edit current ≥ target):
  - If `linkedAccount` is set → create one **income** transaction:
    - Title: `Goal: {name}`
    - Amount: `targetAmount`
    - Category: default income (“Other Income”)
  - If no linked account → no transaction.

UI: Goal form includes optional **Credit to Account** picker.

## Consequences

**Positive**

- Account history reflects the goal achievement once, not N small deposits.
- Optional — users without linked account still use goals as progress trackers.

**Negative**

- Intermediate contributions are not reflected in account balances.
- Completion transaction uses `targetAmount`, not sum of incremental contributions (they should match at completion).

## Tests

`GoalUseCaseTests` — with/without linked account.
