# Purseful

Native iOS personal finance app — SwiftUI, SwiftData, WidgetKit. Free, on-device first, no paywalls.

**Bundle ID:** `dev.imflawlezz.purseful-ios`  
**Version:** 1.1.0  
**Minimum deployment:** iOS 26.0  
**App Group:** `group.dev.imflawlezz.purseful-ios`

---

## Requirements

- Xcode 26+ (iOS 26 SDK)
- macOS with iOS Simulator or a physical device
- Apple Developer account (for App Group + widgets on device)

---

## Getting started

1. Clone the repository.
2. Open `purseful-ios.xcodeproj` in Xcode.
3. Select the **purseful-ios** scheme.
4. Run on a simulator or device (`⌘R`).

### Run tests

```bash
xcodebuild -scheme purseful-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

Or use **Product → Test** in Xcode (`⌘U`).

---

## Project structure

```
purseful-ios/                 # Main app target
├── App/                      # Entry, DI, settings, bootstrap
├── Core/
│   ├── Domain/UseCases/      # Write paths & orchestration
│   └── Persistence/          # SwiftData repository
├── Models/                   # SwiftData @Model types
│   └── Features/             # SwiftUI screens (by tab/feature)
├── Services/                 # Pure logic, calculators, I/O
└── Shared/                     # UI components, formatters, extensions

PursefulWidgets/              # WidgetKit extension
purseful-iosTests/            # Unit tests
docs/                         # Project documentation (start here)
LICENSE                       # Source-available license
CHANGELOG.md                  # Release history
```

Canonical UI code lives under `purseful-ios/Models/Features/`. Ignore any stale duplicate paths if they appear locally.

---

## Architecture (short)

- **Reads:** SwiftUI views use `@Query` against SwiftData.
- **Writes:** Views call **use cases** via `@Environment(DependencyContainer.self)`.
- **Services:** Stateless helpers (budget math, OCR, JSON/PDF export, notifications).
- **Persistence:** Single SwiftData store in the App Group container (shared with widgets).

See [docs/architecture.md](docs/architecture.md) for diagrams and data flows.

---

## Documentation

| Document | Description |
|----------|-------------|
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [docs/README.md](docs/README.md) | Documentation index |
| [docs/architecture.md](docs/architecture.md) | Layers, DI, startup, sync hooks |
| [docs/data-model.md](docs/data-model.md) | SwiftData entities & relationships |
| [docs/features.md](docs/features.md) | Feature matrix (implemented vs planned) |
| [docs/notifications.md](docs/notifications.md) | Alert types, scheduling, dedup |
| [docs/import-export.md](docs/import-export.md) | JSON backup format v2 |
| [docs/widgets.md](docs/widgets.md) | WidgetKit extension & snapshot sync |
| [docs/testing.md](docs/testing.md) | Test targets & coverage map |
| [docs/decisions/](docs/decisions/) | Architecture decision records (ADRs) |
| [LICENSE](LICENSE) | Source-available license terms |

---

## Key conventions

- Inject dependencies with `.environment(dependencies)` and read `@Environment(DependencyContainer.self)`.
- Pass `DependencyContainer` explicitly to background helpers (e.g. `WidgetSyncObserver`) that miss SwiftUI environment.
- Do not store secrets in SwiftData — use Keychain (`KeychainService`) for future bank tokens.
- Recurring bills use **Planned Payments** + `RecurrenceProcessor`, not standalone recurring transactions.

---

## Deferred

These are intentionally out of scope for the current release:

- CloudKit / iCloud sync
- Bank sync UI & Enable Banking production wiring
- CSV import/export

See [docs/features.md](docs/features.md) for the complete status table.

---

## License

Source-available — all rights reserved. See [LICENSE](LICENSE) for full terms.

You may view the code and build or run it locally for personal, non-commercial use. Commercial use, redistribution, and publishing derivative works are not permitted without written permission. Contributions via pull request are welcome under the terms in `LICENSE`.
