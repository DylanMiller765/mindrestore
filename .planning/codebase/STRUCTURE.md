# Codebase Structure

**Analysis Date:** 2026-04-27

## Directory Layout

```
mindrestore/                                # Repo root
├── MindRestore/                            # Main app target source
│   ├── MindRestoreApp.swift                # @main App entry, AppDelegate
│   ├── ContentView.swift                   # Root TabView + TrainingView (~1534 lines)
│   ├── Configuration.storekit              # StoreKit Configuration for testing
│   ├── Info.plist
│   ├── MindRestore.entitlements            # FamilyControls, App Groups, GameKit
│   ├── memori (1).riv                      # Rive mascot animations
│   ├── Assets.xcassets/                    # App icon, mascot images, color sets
│   ├── Content/                            # Bundled training content (static data)
│   │   ├── ActiveRecallContent.swift
│   │   ├── EducationContent.swift
│   │   └── SpacedRepetitionContent.swift
│   ├── Extensions/                         # AppExtension SOURCE files (compiled into separate targets)
│   │   ├── DeviceActivityMonitorExtension.swift
│   │   ├── ShieldActionExtension.swift
│   │   └── ShieldConfigurationExtension.swift
│   ├── Models/                             # SwiftData @Model + value types
│   │   ├── Achievement.swift
│   │   ├── BrainScore.swift
│   │   ├── ChallengeLink.swift             # Codable value type for friend challenges
│   │   ├── DailySession.swift
│   │   ├── Enums.swift                     # ExerciseType, CognitiveDomain, SubscriptionStatus, etc.
│   │   ├── Exercise.swift
│   │   ├── LeaderboardEntry.swift
│   │   ├── PsychoEducationCard.swift
│   │   ├── SpacedRepetitionCard.swift
│   │   └── User.swift
│   ├── Resources/                          # Non-code bundles (fonts, .riv files)
│   │   └── Fonts/
│   ├── Services/                           # @Observable services + pure-logic engines
│   │   ├── AchievementService.swift
│   │   ├── ActiveRecallEngine.swift
│   │   ├── AdaptiveDifficultyEngine.swift
│   │   ├── AnalyticsService.swift          # enum Analytics (PostHog wrapper)
│   │   ├── DeepLinkRouter.swift
│   │   ├── DualNBackEngine.swift
│   │   ├── FocusModeService.swift
│   │   ├── GameCenterService.swift
│   │   ├── HapticService.swift             # enum
│   │   ├── LeaderboardService.swift
│   │   ├── NotificationService.swift       # singleton (.shared)
│   │   ├── PaywallTriggerService.swift
│   │   ├── ReferralService.swift
│   │   ├── ReviewPromptService.swift
│   │   ├── ScreenshotDataGenerator.swift   # MUST be #if DEBUG
│   │   ├── SeededGenerator.swift
│   │   ├── SoundService.swift              # enum
│   │   ├── SpacedRepetitionEngine.swift
│   │   ├── StoreService.swift
│   │   ├── StrategyTipService.swift
│   │   ├── TrainingSessionManager.swift
│   │   └── WorkoutEngine.swift
│   ├── Utilities/
│   │   ├── Constants.swift
│   │   ├── DesignSystem.swift              # AppColors, AppCardModifier, AppTheme
│   │   └── Extensions.swift
│   ├── ViewModels/                         # Cross-screen ViewModels (game VMs are inline in their View)
│   │   ├── ActiveRecallViewModel.swift
│   │   ├── BrainAssessmentViewModel.swift
│   │   ├── DailyChallengeViewModel.swift
│   │   ├── DualNBackViewModel.swift
│   │   ├── HomeViewModel.swift
│   │   ├── ProgressViewModel.swift
│   │   └── SpacedRepetitionViewModel.swift
│   ├── Views/                              # SwiftUI screens, grouped by feature
│   │   ├── Achievements/
│   │   ├── Assessment/                     # Brain Age assessment + reveal
│   │   ├── Components/                     # Reusable UI (BrainScoreCard, GameResultView, etc.)
│   │   ├── DailyChallenge/
│   │   ├── Education/
│   │   ├── Exercises/                      # 16 game files (10 active, 6 retired but in code)
│   │   ├── FocusMode/
│   │   ├── Home/
│   │   ├── Leaderboard/
│   │   ├── Onboarding/                     # OnboardingView (~2236), OnboardingNewScreens (~2375)
│   │   ├── Paywall/
│   │   ├── Profile/
│   │   ├── Progress/
│   │   ├── Settings/
│   │   └── Social/                         # Friend challenges (built but shelved)
│   └── Widget/                             # Widget SOURCE files (compiled into MemoriWidget target)
│       ├── MemoriWidgetBundle.swift
│       └── WidgetDataService.swift
├── MindRestore.xcodeproj                   # Xcode project (Claude CANNOT edit)
├── MindRestoreTests/                       # Unit tests
├── MemoriWidget/                           # Widget extension target wrapper
├── MemoriWidgetExtension.entitlements
├── MemoriShieldAction/                     # Shield action extension target wrapper
├── MemoriShieldConfig/                     # Shield config extension target wrapper
├── docs/                                   # Brand, onboarding briefs, marketing assets
├── marketing/                              # Marketing materials
├── AppStore/                               # App Store metadata + screenshots
├── screenshots-builder/                    # Screenshot generation tooling
├── mascot-integration-screenshots/
├── memori-mascots-no-background/
├── skills/                                 # GSD/skills definitions
├── build/                                  # Gitignored — xcodebuild output
├── build-sim/                              # Gitignored — simulator builds
├── FocusUnlocksReport/
├── memori_mascot.riv
├── memorimascots.riv
├── memorimascots 2.riv
├── ExportOptions.plist
├── project.yml                             # XcodeGen config (if used)
├── CLAUDE.md                               # Project instructions for Claude
├── AGENTS.md
└── skills-lock.json
```

## Directory Purposes

**`MindRestore/`:** Main app target. Everything else under it is the iOS app source. Top of the file tree for all feature work.

**`MindRestore/Models/`:** SwiftData persistent types (`@Model`) + companion `Codable` enums/structs. New persisted data types go here. Keys in `User`, `Exercise`, `BrainScoreResult`, `Achievement`, `DailySession`, `SpacedRepetitionCard` are wired into `MindRestoreApp.swift:60-62` `ModelContainer`.

**`MindRestore/Services/`:** All `@Observable @MainActor final class` services and pure-logic engines. New cross-screen state or external-API integration goes here. **Inject the new service in `ContentView.swift` via `@State` + `.environment(...)`.**

**`MindRestore/Views/`:** SwiftUI views, organized by feature subfolder. Game ViewModels live inline at the top of each `Views/Exercises/*.swift`.

**`MindRestore/ViewModels/`:** Used only for non-game screens that have enough logic to warrant extraction (Home, Progress, Brain Assessment, Daily Challenge, plus 3 retired-feature VMs).

**`MindRestore/Utilities/`:** `DesignSystem.swift` is the design token file. `Extensions.swift` for SwiftUI/Foundation conveniences. `Constants.swift` for bundled string/number constants.

**`MindRestore/Content/`:** Static training content (active recall prompts, education feed cards, spaced-repetition decks). Plain Swift files exporting arrays.

**`MindRestore/Widget/`:** Source files for the WidgetKit extension. Reads from app-group `UserDefaults` via `WidgetDataService`. Sibling target `MemoriWidget/` provides the extension wrapper.

**`MindRestore/Extensions/`:** Source files for the three Family Controls extensions (DeviceActivityMonitor, ShieldAction, ShieldConfiguration). Sibling targets `MemoriShieldAction/` + `MemoriShieldConfig/` provide the extension wrappers.

**`MindRestore/Resources/`:** Bundled non-code assets (fonts, Rive files used at runtime).

**`MindRestore/Assets.xcassets/`:** Image assets — app icon, mascot images, social logos, color sets (`PageBg`, `CardSurface`, `CardElevated`, `CardBorder`, `CardBorderDark`, `AccentColor`).

**`MindRestoreTests/`:** XCTest target. Run with `xcodebuild test -scheme MindRestoreTests`.

**`docs/`:** Brand book (`docs/BRAND.md` is canonical), onboarding redesign briefs, marketing copy assets.

**`build/` + `build-sim/`:** Gitignored xcodebuild output. Safe to delete for clean builds.

**`AppStore/`:** App Store Connect metadata, listing copy, screenshots.

**`screenshots-builder/`:** Tooling that generates marketing screenshots.

## Key File Locations

**Entry Points:**
- `MindRestore/MindRestoreApp.swift` — `@main App`. Configures Analytics, RevenueCat, ModelContainer, tab-bar appearance.
- `MindRestore/ContentView.swift` — Root view, owns service @State, TabView, inline TrainingView/TrainingTile, global overlays.

**Configuration:**
- `MindRestore/Info.plist` — Bundle config.
- `MindRestore/MindRestore.entitlements` — Family Controls, GameKit, App Groups, push.
- `MindRestore/Configuration.storekit` — Local StoreKit testing config.
- `ExportOptions.plist` (repo root) — App Store upload options.
- `/tmp/ExportOptions.plist` — Created on demand for archive uploads (teamID `73668242TN`).

**Core Logic:**
- `MindRestore/Services/StoreService.swift` — Subscription source of truth.
- `MindRestore/Services/AchievementService.swift` — Unlock criteria walker.
- `MindRestore/Services/FocusModeService.swift` — Family Controls / shields / weekly-blocked-minutes.
- `MindRestore/Services/NotificationService.swift` — All 8 notification types.
- `MindRestore/Services/WorkoutEngine.swift` — 3-game daily workout builder.
- `MindRestore/Services/AdaptiveDifficultyEngine.swift` — Per-game difficulty selection.
- `MindRestore/Models/User.swift` — Streak, freezes, XP/level, focus goals.
- `MindRestore/Utilities/DesignSystem.swift` — Color tokens, card modifiers.

**Testing:**
- `MindRestoreTests/` — Unit tests (sparse coverage; QA primarily on-device per `CLAUDE.md`).

**Build Output:**
- `build/Build/Products/Debug-iphoneos/MindRestore.app` — Device debug build.
- `build-sim/` — Simulator builds.

## Naming Conventions

**Files:**
- Views: `XxxView.swift` (`HomeView`, `LeaderboardView`, `ReactionTimeView`).
- Services (stateful): `XxxService.swift` (`StoreService`, `FocusModeService`).
- Services (logic-only): `XxxEngine.swift` (`WorkoutEngine`, `AdaptiveDifficultyEngine`).
- ViewModels (extracted): `XxxViewModel.swift` (`HomeViewModel`).
- ViewModels (game-local): defined inline at top of `XxxView.swift` as `@Observable final class XxxViewModel`.
- Models: noun (`User.swift`, `Exercise.swift`, `Achievement.swift`).
- Components: descriptive noun (`BrainScoreCard.swift`, `GameResultView.swift`, `RiveMascotView.swift`).

**Directories:**
- Top-level layer (`Services/`, `Models/`, `Views/`, `Utilities/`, `Content/`, `ViewModels/`, `Resources/`, `Widget/`, `Extensions/`).
- Feature subfolder under `Views/` (`Views/Onboarding/`, `Views/FocusMode/`, `Views/Exercises/`).

**Types:**
- Services: `final class XxxService` with `@MainActor @Observable`.
- Models: `final class Xxx` with `@Model`.
- View enums: `XxxPhase` for game state machines (e.g. `RTPhase` in `ReactionTimeView.swift`).
- Static namespaces: `enum Xxx { static func ... }` (`Analytics`, `HapticService`, `SoundService`, `AppColors`, `Constants`).

**Identifiers:**
- StoreKit product IDs: `com.memori.{tier}.{interval}` — see `MindRestore/Services/StoreService.swift:33-39`.
- UserDefaults keys: prefixed by feature (`focus_*`, `referral_*`, `trainingSeconds_*`).
- App-group key namespaces: defined as `private enum FocusKey { ... }` inside the owning service.

## Where to Add New Code

**New Game (Exercise):**
- Primary code: `MindRestore/Views/Exercises/{Name}View.swift`. Include inline `@Observable final class {Name}ViewModel` at the top.
- Add `case {name}` to `ExerciseType` in `MindRestore/Models/Enums.swift` (set `displayName`, `icon`, `description`, `cognitiveDomain`).
- Wire into `TrainingView` tile list inside `MindRestore/ContentView.swift`.
- Add to GameCenter leaderboard ID list in `MindRestore/Services/GameCenterService.swift`.
- Use `ExerciseShareCard` / `GameResultView` (`MindRestore/Views/Components/`) for the results screen.
- Optional: extend `AdaptiveDifficultyEngine` for difficulty rules, `WorkoutEngine` for inclusion in daily workouts.
- Tests: `MindRestoreTests/` (current coverage is sparse).

**New Onboarding Page:**
- Add a new step view to `MindRestore/Views/Onboarding/` — IDEALLY in a new `Steps/{Name}Step.swift` instead of bloating the existing mega-files.
- Wire into the page list in `OnboardingView.swift` or `OnboardingNewScreens.swift` and increment the total-steps count.
- If it captures user data, persist on the `User` model (`MindRestore/Models/User.swift`).

**New Service:**
- Create `MindRestore/Services/{Name}Service.swift` with `@MainActor @Observable final class`.
- Instantiate as `@State` in `MindRestore/ContentView.swift` and inject via `.environment(...)`.
- Consume in views with `@Environment({Name}Service.self)`.
- Persist any cross-launch state in UserDefaults or via SwiftData; do NOT add singletons unless necessary (precedent: only `NotificationService.shared`).

**New SwiftData Model:**
- Create `MindRestore/Models/{Name}.swift` with `@Model final class`.
- Register in the `ModelContainer` declaration in `MindRestore/MindRestoreApp.swift:58-63`.
- All properties need defaults (see `User.swift` for the pattern) for SwiftData migration safety.
- For shared enums/value types, place them in `MindRestore/Models/Enums.swift` or a new file alongside.

**New Reusable UI Component:**
- `MindRestore/Views/Components/{Name}.swift`.
- Use `AppColors` tokens; never raw `Color(red:green:blue:)`.
- Include `#Preview` blocks (light + dark mode if visual-mode-sensitive).

**New Color/Design Token:**
- Add to `enum AppColors` in `MindRestore/Utilities/DesignSystem.swift`.
- For light/dark adaptive colors, add a `.colorset` to `MindRestore/Assets.xcassets/` and reference via `Color("name")`.

**New Notification Type:**
- Add a method to `NotificationService` in `MindRestore/Services/NotificationService.swift`.
- Schedule from `ContentView.onAppear` if launch-driven.
- Set `userInfo["deepLink"]` so the tap handler in `AppDelegate` routes correctly.
- Add a matching `case` in `DeepLinkRouter` if it opens a new destination.

**New Deep Link Destination:**
- Extend `DeepLinkRouter.Destination` enum in `MindRestore/Services/DeepLinkRouter.swift`.
- Handle in `MindRestore/ContentView.swift` `.onChange(of: deepLinkRouter.pendingDestination)`.

**New Analytics Event:**
- Add a static method to `enum Analytics` in `MindRestore/Services/AnalyticsService.swift` wrapping `PostHogSDK.shared.capture(...)`.
- Use snake_case event names (`game.completed`, `paywall.shown`).

**New Achievement:**
- Add a case to `AchievementType` in `MindRestore/Models/Achievement.swift`.
- Add unlock logic to `AchievementService.checkAchievements(...)` in `MindRestore/Services/AchievementService.swift`.

**New Widget:**
- Add view + entry struct in `MindRestore/Widget/`. Add to `MemoriWidgetBundle` body. Read data via `WidgetDataService.currentSnapshot()`.

**Static Training Content (recall prompts, edu cards):**
- Append arrays in `MindRestore/Content/{ActiveRecallContent,EducationContent,SpacedRepetitionContent}.swift`.

## Special Directories

**`build/`:** Purpose: xcodebuild output. Generated: Y. Committed: N. Safe to delete.

**`build-sim/`:** Purpose: simulator-build output. Generated: Y. Committed: N.

**`MindRestore/Assets.xcassets/`:** Purpose: image + color assets. Generated: N. Committed: Y. Edits via Xcode (or direct JSON edits to `Contents.json`, but prefer Xcode UI).

**`MindRestore/Resources/`:** Purpose: bundled fonts + Rive files. Generated: N. Committed: Y.

**`MindRestore.xcodeproj/`:** Purpose: Xcode project. Generated: maintained by Xcode. Committed: Y. **Claude CANNOT edit** — flag any change here as a manual user step.

**`AppStore/`:** Purpose: App Store metadata + ASO assets. Committed: Y.

**`docs/`:** Purpose: brand + design briefs (`docs/BRAND.md` canonical). Committed: Y.

**`MemoriWidget/` + `MemoriShieldAction/` + `MemoriShieldConfig/`:** Purpose: thin wrapper directories for extension targets. Their actual source lives under `MindRestore/Widget/` and `MindRestore/Extensions/`. Committed: Y.

**`skills/`:** Purpose: GSD skills definitions. Committed: Y.

**`.planning/`:** Purpose: GSD planning artifacts (this directory). Committed per project convention.

---
*Structure analysis: 2026-04-27*
