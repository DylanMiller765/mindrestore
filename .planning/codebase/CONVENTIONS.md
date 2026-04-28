# Coding Conventions

**Analysis Date:** 2026-04-27

## Naming Patterns

**Files:**
- Views: `{Feature}View.swift` (e.g. `ContentView.swift`, `OnboardingView.swift`, `FocusModeCard.swift`)
- Game views: `{ExerciseName}View.swift` under `MindRestore/Views/Exercises/` (e.g. `ReactionTimeView.swift`, `ColorMatchView.swift`)
- Services: `{Feature}Service.swift` under `MindRestore/Services/` (e.g. `StoreService.swift`, `AnalyticsService.swift`)
- Engines (algorithmic helpers): `{Feature}Engine.swift` (e.g. `AdaptiveDifficultyEngine.swift`, `WorkoutEngine.swift`)
- Models: singular noun, one `@Model` per file (e.g. `User.swift`, `Exercise.swift`, `DailySession.swift`)
- Tests: `{TypeUnderTest}Tests.swift` in `MindRestoreTests/` (e.g. `SeededGeneratorTests.swift`)

**Functions:** camelCase verb-first — `awardXP()`, `startGame()`, `loadProducts()`, `updateStreak(on:)`, `checkAndAwardStreakFreeze(on:)`. Use named argument labels (Swift idiomatic), e.g. `updateStreak(on date: Date = .now)`.

**Variables:** camelCase. Computed booleans prefer `is`/`has`/`should` prefixes (`isProUser`, `hasCompletedOnboarding`, `hasShared`). Storage-backed enum properties use `Raw` suffix paired with a computed property (`subscriptionStatusRaw` + `subscriptionStatus`, `focusGoalsRaw` + `focusGoals`) — pattern is forced by SwiftData's lack of native enum storage.

**Types:** PascalCase. Enums for state machines use a feature-prefixed short name (e.g. `RTPhase` for ReactionTime — `setup`, `waiting`, `ready`, `tooEarly`, `result`, `finished`). ViewModels are PascalCase + `ViewModel` suffix, declared `final class` (`ReactionTimeViewModel`).

**Constants:** Static product IDs and IDs use camelCase static lets on the owning service (`StoreService.weeklyProductID`, `StoreService.annualUltraProductID`).

## Code Style

**Formatting:** Xcode default (4-space indent, no trailing whitespace stripping enforced). No `.swiftformat` or `.editorconfig` checked in.

**Linting:** None. No `.swiftlint.yml` exists at repo root. Style is enforced by code review and by `xcodebuild` warnings only.

## Import Organization

**Order observed:** SwiftUI / SwiftData / Foundation first, then Apple frameworks (`StoreKit`, `GameKit`, `WidgetKit`, `UIKit`, `Charts`, `UserNotifications`, `CloudKit`, `FamilyControls`, `ManagedSettings`, `DeviceActivity`), then third-party SPM modules (`PostHog`, `RevenueCat`, `RiveRuntime`, `ConfettiSwiftUI`).

Example from `ReactionTimeView.swift`:
```swift
import SwiftUI
import SwiftData
import GameKit
```

**Path Aliases:** None — Swift module imports only. Internal types are accessed without imports because the entire app target is one module (`MindRestore`).

## Color Usage

**Pattern:** Use `AppColors.X` constants — NEVER raw `Color(red:green:blue:)` or `Color.blue` literals in feature code. Defined in `MindRestore/Utilities/DesignSystem.swift`.

**Source of truth:** `MindRestore/Utilities/DesignSystem.swift`
- Adaptive surfaces: `AppColors.pageBg`, `AppColors.cardSurface`, `AppColors.cardElevated`, `AppColors.cardBorder` (asset-catalog-backed for light/dark)
- Accent: `AppColors.accent` (`#4A7FE5`)
- Cognitive domain palette: `teal`, `indigo`, `coral`, `violet`, `sky`, `mint`, `rose`, `amber` (mapped to Memory/Speed/Attention/Flexibility/ProblemSolving via `CognitiveDomain` enum)
- Reaction phase colors: `reactionWait`, `reactionGo`, `reactionTooEarly`
- Gradients: `accentGradient`, `premiumGradient`, `neuralGradient`

**Light/Dark mode:** Always pull from `AppColors.*`. When a value must branch on appearance, use `@Environment(\.colorScheme)` and inspect `colorScheme == .dark` (see `AppCardModifier` in `DesignSystem.swift`). Never hardcode `.black` / `.white`.

## Error Handling

**Patterns:**
- `do/try/catch` for `StoreKit`, `Product.products(for:)`, transaction verification, and `JSONDecoder` paths.
- Errors that surface to the UI are stored on `@Observable` services as `purchaseError: String?` (see `StoreService`) — the view reads the optional and renders a banner.
- Background failures (CloudKit, GameKit) are swallowed with a `print("[Service] …: \(error.localizedDescription)")` log — see `ReferralService.swift` and `GameCenterService.swift`.
- Optional chaining + `guard let` early returns dominate in ViewModels (`guard let start = startTime else { return 0 }`).
- `@discardableResult` is used when the return is informational (e.g. `User.updateStreak(on:)` returns a `StreakFreezeEvent` callers can ignore).

**Anti-pattern:** Force-unwraps (`!`) appear in tests deliberately (`link.vercelURL!`) but are avoided in production code.

## Logging

**Framework:** `print(...)` with a bracketed service tag — no `os.Logger` / `os_log` adoption in the app target. Examples:
- `print("[GameCenterService] Authentication error: \(error.localizedDescription)")`
- `print("[GameCenterService] Submitting score \(score) to \(ids)")`
- `print("CloudKit save error: \(error.localizedDescription)")` (untagged in `ReferralService.swift`)

**Recommendation when adding new logs:** Match the `[ServiceName]` prefix pattern. Do not introduce `os.Logger` in isolation — the codebase has not standardized on it.

## Comments

**When to Comment:**
- WHY-not-WHAT: explain non-obvious business decisions (see `StoreService.weeklyProductID` block explaining the legacy/canonical SKU split for the v2.0 single-tier pivot — ~10 lines of context above the constants).
- `// NOTE:` prefix for known-stale-but-kept code (e.g. `User.subscriptionStatus` flagged as unused for SwiftData schema compatibility).
- `// MARK: -` section headers in every multi-section file (`// MARK: - Game Phase`, `// MARK: - ViewModel`, `// MARK: - Product IDs`).

**Doc comments:** `///` triple-slash doc comments on non-trivial public methods (e.g. `User.updateStreak(on:)`). Property-level doc comments only when the type alone is misleading.

## Function Design

**Size:** Most ViewModel functions stay under 30 lines. `User.updateStreak(on:)` is one of the longer ones (~40 lines) and is acceptable because the streak/freeze rules are inherently branchy. `ContentView.swift` is the codebase's known large file (~900 lines per `CLAUDE.md`) — do not extend the pattern; extract new tabs into separate files.

**Parameters:** Named argument labels with sensible defaults — `updateStreak(on date: Date = .now)`. Use trailing closures for SwiftUI view builders. Prefer a small struct return over multiple out-params (`StreakFreezeEvent`).

**Return Values:** Computed properties for derived state (`averageMs`, `bestMs`, `score`, `ratingText` on `ReactionTimeViewModel`). Tagged with `@discardableResult` only when the caller may legitimately ignore the value.

## SwiftUI-Specific Conventions

**View composition:** Prefer separate `View` structs over deeply nested computed `body` properties when a section has its own state, animation, or is reused. Stateless decorative chunks may be computed properties on the parent view (e.g. `private var headerLabel: some View`).

**State management:**
- `@State` for view-local UI state.
- `@Binding` for parent-owned state passed into child views.
- `@Observable` (Swift 5.9 macro) for ViewModels and services — see `ReactionTimeViewModel`, `StoreService`. Do NOT use the older `ObservableObject` / `@Published` pattern; the codebase has migrated to `@Observable`.
- `@MainActor` on ViewModels and services that mutate UI-bound state (`@MainActor @Observable final class ReactionTimeViewModel`, `@MainActor @Observable final class StoreService`).
- Environment objects for cross-screen services: `StoreService`, `AchievementService`, `PaywallTriggerService`, `TrainingSessionManager`, `GameCenterService`, `DeepLinkRouter`. Inject via `.environment(...)` at the root in `MindRestoreApp.swift`.
- SwiftData models are accessed via `@Query` and `@Environment(\.modelContext)`.

**Modifier order:** Layout (frame/padding) → background/foreground → effects (shadow, blur) → gestures → animation. Use the `.appCard()` view modifier from `DesignSystem.swift` instead of recreating card chrome.

## Module Design

**Exports:** Default access (`internal`) is the norm — the app is a single module so explicit `public` is rarely needed. Use `private` for ViewModel storage that should not be set externally (`private var rng: SeededGenerator?`, `private var waitTimer: Timer?`, `private var updateListenerTask: Task<Void, Error>?`). `final class` for all reference types unless inheritance is needed (it usually isn't).

**Service singletons:** Services are `@Observable` `final class` instances created once in `MindRestoreApp.swift` and injected through `.environment()`. There are no `static let shared` singletons in the new services; older code may still have them but new services should follow the environment-injection pattern.

## Game Pattern (for Exercises)

**Standard flow:** `setup → playing → results` modeled as an enum (e.g. `RTPhase` in `ReactionTimeView.swift` — `setup, waiting, ready, tooEarly, result, finished`). The view switches on `viewModel.phase` to render each step.

**Share cards:** Every game produces a results card via `ExerciseShareCard` (the Memori-branded share image) plus a TikTok-style `TikTokShareCard` for social. NOTE: per recent commit `eef3ecb`, share buttons were removed from the in-game results screen but the card components remain in use elsewhere.

**Results screen:** Unified `GameResultView.swift` is used by all games — do not build per-game results screens.

**High scores:** `PersonalBestTracker` — every leaderboard-eligible game records best/avg into this tracker.

**Difficulty:** `AdaptiveDifficultyEngine` (`MindRestore/Services/AdaptiveDifficultyEngine.swift`) — feed user perf, get next-round parameters.

**Composite leaderboard scores (capped games):**
```swift
primaryScore * 1000 + max(0, 999 - durationSeconds)
```
Used by Game Center reporting in `GameCenterService.swift` so that ties on a capped score are broken by speed.

**Seeded RNG for friend challenges:** Games that participate in async challenges accept a `challengeSeed: Int?` and instantiate a `SeededGenerator` (`MindRestore/Services/SeededGenerator.swift`) so both players see identical sequences. See the pattern in `ReactionTimeViewModel.startGame()`.

## Project-specific Gotchas

- **SourceKit false positives:** "Cannot find X in scope" diagnostics inside Xcode/SourceKit are wrong — the entire app target is one module and types resolve at build time. Trust only `xcodebuild` output. (Documented in `CLAUDE.md`.)
- **`#if DEBUG` wrapping:** `MindRestore/Services/ScreenshotDataGenerator.swift` MUST be wrapped in `#if DEBUG ... #endif` or release archive builds fail.
- **Device family:** `TARGETED_DEVICE_FAMILY = 1` (iPhone only). Never set to `"1,2"`.
- **`build/` directory:** Gitignored. Safe to wipe for clean builds.
- **Builds:** Use `xcodebuild` CLI directly (per `CLAUDE.md`), not the Xcode MCP `BuildProject` tool — the MCP variant has been observed to hang for 10+ minutes on this codebase.

---
*Convention analysis: 2026-04-27*
