# ADR 001: Use-case layer for writes

**Status:** Accepted  
**Date:** 2026-06

## Context

The app grew from views calling SwiftData `modelContext` directly. That made side effects (notifications, widget sync) easy to forget and hard to test.

## Decision

Introduce **use cases** behind `DependencyContainer`:

- Views keep `@Query` for reads.
- All mutations go through use cases (`TransactionUseCase`, `BudgetUseCase`, …).
- Use cases use `DataRepositoryProtocol` and call `NotificationScheduler` after saves where needed.

Services remain for **stateless logic** (calculators, parsers, export encoding).

## Consequences

**Positive**

- Centralized write paths and side effects.
- Testable domain behavior (`GoalUseCaseTests`, etc.).
- Clear place for new features to hook in.
- Category resolution and mark-paid transaction creation live in use cases.

**Negative**

- Not fully enforced — `PursefulWebImportView` still touches `modelContext`; Settings still calls `NotificationScheduler.syncAll` with repository context after toggles.
- Presentation helpers (`AccountPreferences.visibleAccounts`, `DebtService` read APIs) remain callable from views by design.
- No ViewModel layer; large views (`PlanningView`, `SettingsView`) remain.

## Alternatives considered

- Full ports & adapters with duplicate domain entities — rejected as over-engineering for v1.
- MVVM everywhere — deferred; use cases chosen as lighter middle ground.
