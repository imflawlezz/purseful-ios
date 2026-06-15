# Purseful documentation

This folder describes **how the app is built today**, not only what was originally planned.

| If you want to… | Read |
|-----------------|------|
| Set up the project | [../README.md](../README.md) |
| Understand code layout & data flow | [architecture.md](architecture.md) |
| Learn SwiftData models | [data-model.md](data-model.md) |
| See what's done vs planned | [features.md](features.md) |
| Debug notifications | [notifications.md](notifications.md) |
| Backup/restore JSON | [import-export.md](import-export.md) |
| Work on widgets | [widgets.md](widgets.md) |
| Run or add tests | [testing.md](testing.md) |
| Understand a design choice | [decisions/](decisions/) |
| License terms | [../LICENSE](../LICENSE) |

## Maintenance

Update these docs when you change:

- **architecture.md** — new use cases, DI patterns, startup hooks
- **data-model.md** — SwiftData schema or export format version
- **features.md** — ship or defer a feature
- **notifications.md** — alert logic, triggers, dedup keys
- **decisions/** — any non-obvious tradeoff (add a new ADR)

Use **features.md** as the living status matrix when the implementation diverges from earlier planning notes.
