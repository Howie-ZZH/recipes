# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FamilyRecipes is a SwiftUI iOS app (iOS 17+) for managing family meal planning — members, shared dish recipes, meal orders, and food diaries. It is built on an **offline-first, multi-tier sync architecture**: local data lives in SwiftData and synchronizes with a remote PostgREST (PostgreSQL) or Supabase backend with delta sync, soft deletes, an offline outbox queue, network reachability awareness, and adaptive WebSocket/polling channels.

The UI is in Chinese; user-facing strings (tab labels, buttons, accessibility labels) are Chinese literals that UI tests match against.

## Build & Test Commands

The Xcode project is **generated from `project.yml` via XcodeGen** — do not hand-edit `FamilyRecipes.xcodeproj`. After changing `project.yml` (or adding/removing source files), regenerate:

```bash
xcodegen generate
```

Build the app for the iOS Simulator:

```bash
xcodebuild build -project FamilyRecipes.xcodeproj -scheme FamilyRecipes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

**Unit tests run on macOS** (not iOS — see Test Target Quirks below):

```bash
xcodebuild test -project FamilyRecipes.xcodeproj -scheme FamilyRecipesTests \
  -destination "platform=macOS" CODE_SIGN_IDENTITY="-"
```

Build UI tests for the simulator (UI tests are compiled but not executed in CI):

```bash
xcodebuild build-for-testing -project FamilyRecipes.xcodeproj -scheme FamilyRecipes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Run a single unit test:

```bash
xcodebuild test -project FamilyRecipes.xcodeproj -scheme FamilyRecipesTests \
  -destination "platform=macOS" CODE_SIGN_IDENTITY="-" \
  -only-testing:FamilyRecipesTests/FamilyRecipesTests/testDishCRUD
```

Success is `** TEST SUCCEEDED **` (unit, 32/32 tests passing) / `** TEST BUILD SUCCEEDED **` (UI build).

## Architecture

### Data flow: offline-first delta sync & multi-channel collaboration

```text
[ SwiftUI Views ]
       │
       ▼
[ SwiftData (@Model) ]  ←──(Last-Write-Wins / Delta)──→  [ SyncEngine ]
                                                               │
                     ┌───────────────────┬─────────────────────┼────────────────────┐
                     ▼                   ▼                     ▼                    ▼
             [ RealtimeManager ]  [ SyncOutbox ]       [ NetworkMonitor ]   [ SupabaseManager ]
             (WebSocket 广播)     (离线突变队列)        (NWPathMonitor)     (HTTP / PostgREST)
                     │                   │                                          │
                     └───────────────────┴──────────────────────────────────────────┘
                                                 │
                                                 ▼
                                     [ Remote PostgreSQL ]
```

Core models in `FamilyRecipes/Models/`:

- **`Models.swift`** — SwiftData `@Model` classes: `FamilyMember`, `Dish`, `MealOrder`, `FoodDiary`. Relationships carry delete rules:
  - `FamilyMember` → `.cascade` its orders and diaries (deleting a member deletes them).
  - `Dish` → `.nullify` its orders and diaries (deleting a dish leaves them but sets `dish` to nil).
  - All entities have a UUID `id` (`.unique`) and an `updatedAt: Date` used for conflict resolution.
- **`DTOs.swift`** — Codable DTOs (`MemberDTO`, `DishDTO`, `OrderDTO`, `DiaryDTO`) plus `dto` / `update(from:)` extensions on each model. CodingKeys map to **snake_case** PostgREST columns (`updated_at`, `deleted_at`, `dish_description`, `member_id`, etc.). Images sync as `image_base64` strings, not binary.
- **`SupabaseManager.swift`** — Singleton HTTP client targeting PostgREST / Supabase. Supports delta queries via `since: Date?` parameter (`updated_at=gt.<ISO8601>`). Soft delete APIs update `deleted_at = NOW()`; physical DELETE APIs issue `?id=eq.<uuid>`.
- **`SyncEngine.swift`** — `@MainActor` singleton coordinator.
  - **Delta Sync**: If `appState.lastSyncTimestamp` exists, fetches only records updated since that timestamp. Inserts/updates newer records via LWW and deletes records where `deleted_at != nil`.
  - **Full Snapshot Sync**: When forced or on cursor reset, fetches full table and prunes local records absent on the server.
  - **Concurrency Deduplication**: Merges overlapping `syncDown` calls into a single in-flight `Task`.
  - **Adaptive Poller**: 15s timer when `scenePhase == .active`.
- **`SyncOutbox.swift`** — Local persistent FIFO queue (`OutboxMutation`) stored in `UserDefaults`. When mutations fail due to offline/network drop, they are enqueued and automatically flushed in sequential order once connectivity is restored.
- **`NetworkMonitor.swift`** — `NWPathMonitor` wrapper tracking `.satisfied` / `.cellular` / `.unsatisfied` states and firing `onStatusChange`.
- **`RealtimeManager.swift`** — WebSocket client. Connects to `supabase.co` real-time channels or custom `ws://` endpoints. Silently skips pure PostgREST HTTP instances and relies on adaptive polling.

### App state & config

- **`AppState.swift`** — `@Observable @MainActor` singleton injected via `.environment(appState)`. Holds `activeMemberId` (which member is "logged in"), `lastSyncTimestamp` (delta sync cursor), `pendingOutboxCount`, `isRealtimeConnected`, cloud sync URL/key, and sync UI state. Persists configuration to `UserDefaults`. **Default sync URL is `http://47.79.236.127:3000`**.
- **`FamilyRecipesApp.swift`** — builds the `ModelContainer` for all four models. If SwiftData migration fails, it resets the store (`default.store*` in Application Support) and recreates it.
- `ContentView` manages `scenePhase` transitions, starting/stopping realtime and poller lifecycle, and routing between `ProfileSelectionView` and `MainTabView`.

### PostgREST table contract

Backend tables: `family_members`, `dishes`, `meal_orders`, `food_diaries`.
Each table requires `updated_at TIMESTAMPTZ DEFAULT NOW()` and `deleted_at TIMESTAMPTZ`.

## Testing

### Mock injection (network-free unit tests)

`SupabaseManager.shared` exposes `mockMembers`/`mockDishes`/`mockOrders`/`mockDiaries` optionals. When set, `fetch*` returns them directly and skips the network. All 32 unit tests run against an in-memory `ModelContainer` and cleanup mocks afterwards.

### Test Target Quirks (from `project.yml`)

- **Unit tests (`FamilyRecipesTests`) are a macOS target**, not iOS — they run directly on the host without a simulator in under 0.1s.
- The test target compiles specific model source files directly (listed under `sources:` in `project.yml`).
- **When adding any new model/network file that tests need, add its path to `FamilyRecipesTests.sources` in `project.yml` and re-run `xcodegen generate`.**

## Known configuration facts

- **ATS is fully open**: `Info.plist` sets `NSAllowsArbitraryLoads: true` (also in `project.yml`) so the app can reach the HTTP PostgREST backend.
- `AIEngine.swift` generates dish photos by hitting `https://image.pollinations.ai/...` (external, no key).
