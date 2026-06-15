# Import & export

Purseful supports **JSON backup** (format version 2) and **Purseful Web backup** import. CSV is not implemented.

---

## JSON export

**UI:** Settings → Export JSON  
**Code:** `ImportExportUseCase.exportJSON` → `ExportService.exportJSON`

### Payload structure

```json
{
  "formatVersion": 2,
  "exportedAt": "2026-06-11T12:00:00Z",
  "accounts": [],
  "categories": [],
  "transactions": [],
  "budgets": [],
  "goals": [],
  "plannedPayments": [],
  "debts": [],
  "recurringRules": [],
  "shoppingList": [],
  "settings": { }
}
```

### Format version 2 additions (vs v1)

| Section | Notes |
|---------|-------|
| `plannedPayments` | Bills & subscriptions |
| `debts` | With linked transaction IDs |
| `recurringRules` | Linked from payments |
| `shoppingList` | Shopping list items |
| `settings` | Base currency, accent, default account, daily spend prefs, weekly summary |

v1 files import with empty arrays for missing sections (`ImportService` + `ExportPayload` decoder defaults).

### Export details

- **Amounts** encoded as strings (Decimal precision).
- **Split transactions:** only parent rows exported (`!isSplitChild` filter).
- **Categories** referenced by name in some nested objects; IDs preserved on entities.
- **Settings** snapshot from `ExportAppSettings.current` unless overridden.

---

## JSON import

**UI:** Settings → Import JSON  
**Code:** `ImportExportUseCase.importJSON(data:merge:)`

| Mode | Behavior |
|------|----------|
| Replace | Clears existing data first (via merge flag false path) |
| Merge | Skips entities whose UUID already exists |

**Import order** (respects relationships):

1. Categories  
2. Accounts  
3. Recurring rules  
4. Budgets  
5. Goals  
6. Planned payments  
7. Debts  
8. Transactions  
9. Shopping list  
10. Apply settings if present  

After import: `NotificationScheduler.syncAll`.

**UI:** `JSONImportView` shows counts + skipped duplicates.

---

## Clear all data

**Settings → Clear All Data**

`ImportExportUseCase.clearAllData()` → `PursefulWebImportService.clearAllData` + empty widget snapshot.

---

## Purseful Web backup

**UI:** Settings → Import Purseful Web Backup  
**Code:** `PursefulWebImportService`

Separate format from native JSON export. Supports merge/replace and duplicate skipping. Uses `modelContext` directly (legacy path).

Tests: `PursefulWebImportTests`.

---

## Bank transaction import (future)

**Code:** `BankSyncService` / `EnableBankingService`

Stub pipeline: raw bank tx → dedup by hash → create `Transaction` with `importSourceID`. Not exposed in UI. Tests: `BankTransactionDedupTests`.

---

## File locations

| File | Role |
|------|------|
| `Services/ExportService.swift` | Encode v2 |
| `Services/ImportService.swift` | Decode + merge |
| `Core/Domain/UseCases/ImportExportUseCase.swift` | App-facing API |
| `Models/Features/Settings/JSONImportView.swift` | Import UI |

---

## Versioning policy

1. Bump `ExportService.formatVersion` for breaking schema changes.
2. Keep backward decoding in `ExportPayload.init(from:)` for older versions.
3. Document changes in this file and [data-model.md](data-model.md).
4. Add/adjust tests in `ImportExportTests`.

---

## Related tests

```bash
xcodebuild -scheme purseful-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:purseful-iosTests/ImportExportTests test
```
