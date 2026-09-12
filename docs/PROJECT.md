# Project: FamilyRecipes Sync Architecture & Evolution

## Architecture
The application is a SwiftUI iOS application targeting iOS 17.0+ (with unit test runtime on macOS 14.0+). It employs an enterprise-grade **Offline-First Multi-Tier Synchronization Architecture** with SwiftData, PostgREST / PostgreSQL, and optional Supabase Realtime channels.

Data Flow & Layers:
- **Local Persistence**: SwiftData (`@Model`) manages local entity storage, cascade/nullify rules, and fast in-memory query rendering.
- **Sync Coordinator**: `SyncEngine.swift` manages Delta Sync cursors, conflict resolution via Last-Write-Wins (LWW), concurrent request deduplication, and active foreground polling.
- **Outbox Queue**: `SyncOutbox.swift` guarantees that all offline and failed mutations are persistently stored and automatically retried in strict FIFO sequence upon network recovery.
- **Network Reachability**: `NetworkMonitor.swift` observes real-time connectivity via Apple's Network framework (`NWPathMonitor`).
- **Realtime Channels**: `RealtimeManager.swift` handles WebSocket long-lived connections for Supabase or falls back seamlessly to adaptive polling on standalone PostgREST backends.
- **REST Network Client**: `SupabaseManager.swift` handles HTTP PostgREST requests with fractional-second ISO8601 date parsing and delta query filters (`updated_at=gt.<cursor>`).

## Architectural Evolution Milestones

| # | Milestone Name | Scope & Highlights | Status |
|---|---|---|---|
| **M1** | Backend Migration to PostgREST | HTTP unencrypted ATS configuration, stripped `/rest/v1` path requirement, and direct REST access to self-hosted PostgREST at `http://47.79.236.127:3000`. | **COMPLETED** |
| **M2** | Foreground Poller & Concurrency Deduplication (Phase 1) | 15s intelligent foreground timer on `.active`, concurrent `syncDown` task deduplication, silent background error suppression, and Cook dashboard `.refreshable` UI. | **COMPLETED** |
| **M3** | Delta Sync & Tombstone Soft Deletes (Phase 2) | Persistent timestamp cursors (`lastSyncTimestamp`), `deleted_at` tombstone column across all 4 tables/DTOs, delta merge logic, manual cursor reset button, and schema migration. | **COMPLETED** |
| **M4** | Realtime Collaboration, Offline Outbox & Reachability (Phase 3) | Native WebSocket client (`RealtimeManager`), local persistent mutation queue (`SyncOutbox`), `NWPathMonitor` connectivity tracker (`NetworkMonitor`), and fallback physical delete protection. | **COMPLETED** |
| **M5** | Comprehensive Test Suite & Schema Hardening | 32 automated unit tests covering CRUD, delta sync, relationships, soft deletes, outbox mutations, and network failure modes with 100% scenario coverage. | **COMPLETED** |

## Backend Table Schema Contracts
All PostgreSQL tables (`family_members`, `dishes`, `meal_orders`, `food_diaries`) adhere to the following standard schema contracts:
- `id UUID PRIMARY KEY`
- `created_at TIMESTAMPTZ DEFAULT NOW()`
- `updated_at TIMESTAMPTZ DEFAULT NOW()`
- `deleted_at TIMESTAMPTZ` (NULL for active records, timestamp for soft-deleted records)

## Code Layout
- Project: `FamilyRecipes.xcodeproj` (generated via XcodeGen)
- App Entry: `FamilyRecipes/FamilyRecipesApp.swift`
- Plist Settings: `FamilyRecipes/Info.plist`
- Models: `FamilyRecipes/Models/`
  - `AppState.swift`
  - `Models.swift`
  - `DTOs.swift`
  - `SupabaseManager.swift`
  - `SyncEngine.swift`
  - `SyncOutbox.swift`
  - `NetworkMonitor.swift`
  - `RealtimeManager.swift`
  - `AIEngine.swift`
  - `ImageUtils.swift`
  - `SampleData.swift`
- Views: `FamilyRecipes/Views/`
  - `Cook/`
  - `Dishes/`
  - `Diary/`
  - `Wheel/`
  - `Profile/CloudSettingsView.swift`
- Tests:
  - `FamilyRecipesTests/FamilyRecipesTests.swift` (32 unit tests on macOS)
  - `FamilyRecipesUITests/FamilyRecipesUITests.swift` (iOS UI tests)
