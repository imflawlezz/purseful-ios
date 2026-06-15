# ADR 002: Local persistence without CloudKit (v1)

**Status:** Accepted  
**Date:** 2026-06

## Context

The original product spec described SwiftData + CloudKit sync across devices. v1 focused on core features, widgets, and import/export.

## Decision

Ship v1 with a **local SwiftData store** in the App Group:

- Path: `{AppGroup}/Purseful.store`
- No `cloudKitDatabase` configuration
- No CloudKit entitlements
- Backup via **JSON export** instead of iCloud

## Consequences

**Positive**

- Simpler debugging and offline-first behavior.
- Widget extension shares store via App Group without sync conflicts.
- No CloudKit container setup for development.

**Negative**

- No automatic multi-device sync.
- Users must export/import to move data.
- Settings cannot show iCloud status until implemented.

## Future work

Enable CloudKit in `ModelContainerProvider`, add entitlements, migration plan for existing local stores, and Settings sync indicator.
