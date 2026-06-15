# Testing

Unit tests live in **purseful-iosTests**. No UI test target currently.

---

## Running tests

### Xcode

Select **purseful-ios** scheme → `⌘U`.

### Command line

```bash
cd purseful-ios.xcodeproj/..
xcodebuild -scheme purseful-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

Run a single suite:

```bash
xcodebuild -scheme purseful-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:purseful-iosTests/BudgetServiceTests \
  test
```

Swift Testing (`@Test`) and XCTest (`XCTestCase`) are both used.

---

## Test inventory

| File | Framework | Covers |
|------|-----------|--------|
| `BudgetServiceTests` | XCTest | Progress, effective limit, **rollover processing** |
| `BalanceCalculatorTests` | XCTest | Currency conversion, split category totals, stored exchange rate |
| `ImportExportTests` | Swift Testing | JSON v2 round-trip, v1 backward compat |
| `ReceiptParserTests` | XCTest | Polish/English totals, dates, merchants |
| `DebtServiceTests` | Swift Testing | Opening/repayment txs, remaining balance |
| `GoalUseCaseTests` | Swift Testing | Completion transaction when linked account set |
| `NotificationHelpersTests` | XCTest | Budget dedup keys, next Monday |
| `PursefulWebImportTests` | Swift Testing | Web backup parsing/import |
| `BankTransactionDedupTests` | XCTest | Import dedup hash |
| `ShoppingListParserTests` | XCTest | List text parsing |
| `DailySpendCalculatorTests` | XCTest | Category-filtered daily spend |

---

## Test infrastructure

### In-memory SwiftData

```swift
let container = try ModelContainerProvider.makeContainer(inMemory: true)
let context = ModelContext(container)
```

Used across import, goal, and debt tests.

### Previews

`ModelContainerProvider.preview` — seeded in-memory container for SwiftUI previews.

`PreviewDependencies.withPreviewDependencies()` — injects `DependencyContainer` in previews.

---

## What to test when changing…

| Change | Add/update tests in |
|--------|---------------------|
| Budget spent/rollover | `BudgetServiceTests` |
| Currency conversion | `BalanceCalculatorTests` |
| Export schema | `ImportExportTests` |
| Receipt keywords | `ReceiptParserTests` |
| Notification date math | `NotificationHelpersTests` |
| Goal completion side effects | `GoalUseCaseTests` |
| Debt linking | `DebtServiceTests` |

---

## CI suggestion

Minimal GitHub Actions job:

```yaml
- name: Test
  run: |
    xcodebuild -scheme purseful-ios \
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
      test | xcpretty
```

Requires macOS runner with Xcode 26+.

---

## Known flaky test

`ReceiptParserTests.testParsesPolishTotalKeyword` — may be environment/locale sensitive; investigate if CI fails intermittently.
