# Changelog

All notable changes to Purseful are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.1] - 2026-07-23

### Added

- Accent-tinted page washes and Form/List surfaces (Liquid Glass unchanged)
- Tinted circular icons on Settings rows
- Payment calendar toolbar entry on Debts and Goals segments

### Fixed

- Polish fiscal receipt OCR: reading order, total vs VAT/tender, Pepco/VIVE-style NIP and merchants
- PDF report ledger omitted the parent remainder on split transactions
- Transaction multi-select checkbox no longer fades on toggle

## [1.1.0] - 2026-06-15

### Added

- A4 portrait PDF report export from Reports (period statistics, category breakdown with share percentages, paginated transaction ledger with split-line expansion)
- `ReportPDFExportTests` for summary builder and PDF generation

### Changed

- Clarified source-available `LICENSE` (personal local use, contribution terms) and aligned README license section
- Unified minimum deployment target to **iOS 26.0** across app, widgets, and test targets (was 26.2 on widgets/tests)
- Removed broken references to gitignored `prompt.md` from public docs; use `docs/features.md` as the living status matrix
- Added Keep a Changelog version comparison links at the bottom of `CHANGELOG.md`

## [1.0.0] - 2026-06-15

Initial public release. Local-first personal finance for iOS with no subscription or paywall.

### Added

#### Core app
- Five-tab navigation: Dashboard, Transactions, Budgets, Planning, Reports
- SwiftData persistence in a shared App Group store (`Purseful.store`)
- Accounts with types, currencies, colors, hide/include-in-total, and sort order
- Transactions: income, expense, transfer, split lines, search, filters, and batch delete
- Quick-add flow and full transaction form
- System and custom categories with subcategories, merge, and hide/show hidden
- Budgets: weekly, monthly, or custom periods, progress UI, alert thresholds, and rollover
- Planned payments with calendar view, mark-as-paid, auto-create on due date, and overdue state
- Debts with counterparty tracking, repayments, and linked transactions
- Savings goals with contributions, progress, optional target date, and linked account
- Reports: category spending, cash flow, net worth trend, top payees, daily average, period picker
- Multi-currency support with base currency and Frankfurter exchange rates (cached)
- Shopping list (parse-from-text helper and dashboard entry)

#### Data & import
- JSON export/import (format v2) with merge mode
- Purseful Web backup import
- Clear-all-data option in Settings

#### Widgets
- WidgetKit extension: account balance, budget progress, recent transactions, today’s spend
- App Group snapshot sync and `purseful://` deep links

#### Notifications
- Budget threshold and exceeded alerts (app-sync driven)
- Planned payment, debt, and goal reminders
- Optional weekly spending summary (Monday 9:00)

#### Receipt OCR
- On-device Vision document scan and receipt parsing (Polish + English)
- Pre-fill amount, date, merchant title, category; attach receipt JPEG

#### Platform
- Home Screen widgets and lock screen today-spend widget
- Spotlight indexing and deep links for transactions, accounts, and categories
- Privacy manifest (`PrivacyInfo.xcprivacy`)

#### Architecture
- Use-case layer with `DependencyContainer` for writes
- Unit tests for budgets, balances, import/export, debts, goals, receipts, and notifications

#### Documentation
- `README.md`, `docs/`, and architecture decision records (ADRs)

### Known limitations (v1.0.0)

- No iCloud / CloudKit sync — backup via JSON export
- No bank connection UI (Enable Banking scaffold only)
- No CSV export
- Budget alerts require the app to open and sync; not full background monitoring
- Widgets use the first visible account and first budget (no widget configuration UI)

### Deferred to later versions

- CloudKit multi-device sync
- Bank sync (Enable Banking)
- CSV import/export
- Additional transaction filters (date range, amount range, swipe duplicate)

[Unreleased]: https://github.com/imflawlezz/purseful-ios/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/imflawlezz/purseful-ios/releases/tag/v1.1.1
[1.1.0]: https://github.com/imflawlezz/purseful-ios/releases/tag/v1.1.0
[1.0.0]: https://github.com/imflawlezz/purseful-ios/releases/tag/v1.0.0
