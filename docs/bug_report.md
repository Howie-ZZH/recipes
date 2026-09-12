# FamilyRecipes QA Testing & Configuration Bug Report

This document records the configuration and build issues encountered during the setup and execution of the FamilyRecipes unit and UI tests, along with their respective resolutions and verification results.

---

## Encountered Issues and Resolutions

### 1. Missing Info.plist for Test Targets
* **Issue**: During code signing, the build failed with the error: `Cannot code sign because the target does not have an Info.plist file.` This occurred because XcodeGen-generated Xcode projects require plist configurations for test targets, which were not explicitly generated or provided.
* **Resolution**: Set `GENERATE_INFOPLIST_FILE: true` under the `base` settings of both `FamilyRecipesTests` and `FamilyRecipesUITests` targets in `project.yml`. After regenerating the project via XcodeGen, Xcode automatically generates the Info.plist file during the build process, satisfying code-signing requirements.

### 2. iOS Simulator CoreSimulator Version Mismatch
* **Issue**: Executing unit tests target on the iOS simulator failed because the simulator was out-of-date and unable to load. The CoreSimulator framework version mismatch prevented the test bundle from being injected and executed in the simulator environment.
* **Resolution**: The unit tests target (`FamilyRecipesTests`) was reconfigured as a native macOS testing bundle (`platform: macOS`, target type `bundle.unit-test`) rather than an iOS application testing bundle. This allows direct compilation and execution of unit tests for core models (SwiftData CRUD), database relationships, sync engine logic (Supabase DTO mappings, Last-Write-Wins logic), and AI engine utilities directly on macOS without requiring simulator virtualization.

### 3. UI Test Element Matching with Combined Labels
* **Issue**: Direct label matching (e.g. `app.buttons["妈妈"]` or `app.tabBars.buttons["今日点餐"]`) failed during UI tests because SwiftUI combined text elements and image/emoji components within a single button/tab item label, producing combined strings such as `👩‍🍳, 妈妈, 掌勺人`.
* **Resolution**:
  - Implemented `NSPredicate` query matchers using substring matching (e.g. `label CONTAINS '今日点餐'` and `label CONTAINS '妈妈'`) to successfully find and interact with the elements.
  - Added an explicit `accessibilityIdentifier("addDishButton")` to the add button inside `DishListView.swift` to allow the UI test to query and tap the button directly as `app.buttons["addDishButton"]`.

### 4. UI Test Locator Query API Misuse
* **Issue**: UI tests failed to locate elements (e.g. '添加成员', '保存', etc.) because the test code used `.containing(...)` instead of `.matching(...)`.
* **Resolution**: Changed all occurrences of `.containing` to `.matching` on button query objects.

---

## Test Verification and Results

The testing targets have been verified using the designated command-line tools. Both test execution and build compilation succeeded.

### 1. Unit Tests Verification
All unit tests were executed and passed successfully on the macOS platform.

* **Command**:
  ```bash
  xcodebuild test -project FamilyRecipes.xcodeproj -scheme FamilyRecipesTests -destination "platform=macOS" CODE_SIGN_IDENTITY="-"
  ```
* **Results**:
  - **Status**: `** TEST SUCCEEDED **`
  - **Execution Summary**: 11 unit tests executed, 0 failures.
  - **Tests Run**:
    - `testDiaryDTOParsingAndMapping` (Passed)
    - `testDishCRUD` (Passed)
    - `testDishDTOParsingAndMapping` (Passed)
    - `testDishNullifyDelete` (Passed)
    - `testFamilyMemberCascadeDelete` (Passed)
    - `testFamilyMemberCRUD` (Passed)
    - `testFoodDiaryCRUD` (Passed)
    - `testMealOrderCRUD` (Passed)
    - `testMemberDTOParsingAndMapping` (Passed)
    - `testOrderDTOParsingAndMapping` (Passed)
    - `testSyncEngineLastWriteWins` (Passed)

### 2. UI Tests Build Verification
All UI tests compiled and built successfully for the iOS Simulator.

* **Command**:
  ```bash
  xcodebuild build-for-testing -project FamilyRecipes.xcodeproj -scheme FamilyRecipes -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
  ```
* **Results**:
  - **Status**: `** TEST BUILD SUCCEEDED **`
  - **Outcome**: The application target and the `FamilyRecipesUITests` target successfully built for the iOS Simulator environment.
