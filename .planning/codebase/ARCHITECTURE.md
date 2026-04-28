<!-- refreshed: 2026-04-27 -->
# Architecture

**Analysis Date:** 2026-04-27

## System Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│  ENTRY                                                                 │
│  `MindRestore/MindRestoreApp.swift` — @main App + AppDelegate          │
│   - configures Analytics (PostHog), RevenueCat, ModelContainer         │
│   - injects WindowGroup → ContentView                                  │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│  ROOT VIEW                                                             │
│  `MindRestore/ContentView.swift` (~1534 lines)                         │
│   - Owns @State for ALL services (StoreService, AchievementService,    │
│     PaywallTriggerService, TrainingSessionManager, GameCenterService,  │
│     DeepLinkRouter, ReferralService, FocusModeService)                 │
│   - .environment(...) injects each into the SwiftUI hierarchy          │
│   - TabView (Home / Train / Compete / Insights / Profile)              │
│   - Hosts global overlays: XP toast, achievement toast, milestone      │
│     full-screen covers, paywall sheet, deep-link routing               │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   ▼
┌─────────────────────────────┬─────────────────────────────────────────┐
│  FEATURE VIEWS              │  SHARED COMPONENTS                       │
│  Views/Home, Views/Exercises│  Views/Components/* — BrainScoreCard,    │
│  Views/Onboarding,          │  GameResultView, RiveMascotView,         │
│  Views/Leaderboard, Profile │  AchievementToast, ConfettiView, etc.    │
│  Views/FocusMode            │                                          │
└──────────────────┬──────────┴────────────────┬────────────────────────┘
                   ▼                            ▼
┌────────────────────────────────┐  ┌──────────────────────────────────┐
│  SERVICES (@MainActor          │  │  MODELS (SwiftData @Model)        │
│  @Observable, no protocols)    │  │  `Models/User.swift`              │
│  `Services/StoreService.swift` │  │  `Models/Exercise.swift`          │
│  `AchievementService.swift`    │  │  `Models/DailySession.swift`      │
│  `FocusModeService.swift`      │  │  `Models/BrainScore.swift`        │
│  `NotificationService.swift`   │  │  `Models/Achievement.swift`       │
│  `GameCenterService.swift`     │  │  `Models/SpacedRepetitionCard`    │
│  `AnalyticsService.swift`      │  │  Plus value types: ChallengeLink, │
│  `TrainingSessionManager.swift`│  │  Enums (ExerciseType, etc.)       │
│  `PaywallTriggerService.swift` │  └──────────────────────────────────┘
│  `DeepLinkRouter.swift`        │
│  `ReferralService.swift`       │  ┌──────────────────────────────────┐
│  `WorkoutEngine.swift`         │  │  ENGINES (logic-only services)    │
│  `HapticService.swift` (enum)  │  │  AdaptiveDifficultyEngine,        │
│  `SoundService.swift` (enum)   │  │  WorkoutEngine, DualNBackEngine,  │
└────────────────────────────────┘  │  SpacedRepetitionEngine,          │
                                     │  ActiveRecallEngine, SeededGen.   │
                                     └──────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│  EXTENSIONS (separate targets, share UserDefaults app group)           │
│  `MindRestore/Widget/MemoriWidgetBundle.swift` — home-screen widget    │
│  `MindRestore/Extensions/DeviceActivityMonitorExtension.swift`         │
│  `MindRestore/Extensions/ShieldActionExtension.swift`                  │
│  `MindRestore/Extensions/ShieldConfigurationExtension.swift`           │
│  Top-level targets: MemoriShieldAction/, MemoriShieldConfig/,          │
│  MemoriWidget/, MemoriShieldConfig/                                    │
└────────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `MindRestoreApp` | App entry, ModelContainer, RevenueCat config, PostHog init, tab-bar appearance | `MindRestore/MindRestoreApp.swift` |
| `AppDelegate` | UNUserNotificationCenter delegate, deep-link from notification taps | `MindRestore/MindRestoreApp.swift` |
| `ContentView` | Root TabView, owns service @State, global overlays, deep-link routing, achievement/streak/decay reactions | `MindRestore/ContentView.swift` |
| `StoreService` | StoreKit 2 transactions, single Pro entitlement (legacy + new SKUs), referral trial | `MindRestore/Services/StoreService.swift` |
| `AchievementService` | Walks all unlock criteria (streak, count, brain-score, etc.) on demand | `MindRestore/Services/AchievementService.swift` |
| `PaywallTriggerService` | Centralizes paywall context + `shouldShowPaywall` flag | `MindRestore/Services/PaywallTriggerService.swift` |
| `TrainingSessionManager` | Tracks today's training seconds, daily 20-min limit, sweet-spot UI | `MindRestore/Services/TrainingSessionManager.swift` |
| `FocusModeService` | FamilyControls authorization, ManagedSettings shields, schedule, weekly-blocked-minutes leaderboard metric | `MindRestore/Services/FocusModeService.swift` |
| `NotificationService` | All 8 local-notification types (streak risk, comeback, weekly report, brain-fact, etc.) | `MindRestore/Services/NotificationService.swift` |
| `GameCenterService` | GameKit auth, leaderboard score reporting (composite scores for capped games) | `MindRestore/Services/GameCenterService.swift` |
| `DeepLinkRouter` | Parses URL scheme into `pendingDestination` + `pendingChallenge` | `MindRestore/Services/DeepLinkRouter.swift` |
| `Analytics` (enum) | Static PostHog wrappers for every tracked event | `MindRestore/Services/AnalyticsService.swift` |
| `WorkoutEngine` | Builds the 3-game daily workout from cognitive-domain rotation | `MindRestore/Services/WorkoutEngine.swift` |
| `AdaptiveDifficultyEngine` | Per-game difficulty selection from recent scores | `MindRestore/Services/AdaptiveDifficultyEngine.swift` |
| `User` (@Model) | Streak, freezes, XP/level, dailyGoal, focusGoals, subscription mirror | `MindRestore/Models/User.swift` |
| `Exercise` (@Model) | One completed game session record | `MindRestore/Models/Exercise.swift` |
| `BrainScoreResult` (@Model) | Daily computed brain score + brain age | `MindRestore/Models/BrainScore.swift` |
| `Achievement` (@Model) | Unlocked-state row per `AchievementType` | `MindRestore/Models/Achievement.swift` |
| `WidgetDataService` | App-group UserDefaults bridge to widget | `MindRestore/Widget/WidgetDataService.swift` |
| Shield extensions | Render shielded-app UI + enforce blocking | `MindRestore/Extensions/Shield*.swift` |

## Pattern Overview

**Overall:** Hybrid **MV + MVVM**. SwiftUI-first, with `@Observable` services injected via `.environment(...)` and SwiftData `@Model`s queried directly from views via `@Query`. Most feature views are MV (no ViewModel). **Exercise/game views and a few cross-cutting screens (Home, ProgressDashboard, Assessment, DualNBack, ActiveRecall, SpacedRepetition, DailyChallenge) DO use ViewModels** — they live in `MindRestore/ViewModels/` and are co-located with the View when game-specific (e.g. `ReactionTimeViewModel` lives inside `MindRestore/Views/Exercises/ReactionTimeView.swift`).

**Key Characteristics:**
- iOS 17+ Observation framework (`@Observable`, `@Bindable`) — no Combine/`ObservableObject`.
- All services declared `@MainActor @Observable final class`. No protocols. No DI container.
- SwiftData (`@Model`, `@Query`, `ModelContext`) — no Core Data, no manual repositories.
- StoreKit 2 (not SK1, no RevenueCat as source of truth — RevenueCat is configured but `StoreService.isProUser` is the source of truth via `Transaction.currentEntitlements`).
- Strict iPhone-only (`TARGETED_DEVICE_FAMILY = 1`).
- No Coordinator/Router pattern: navigation is `selectedTab` + sheets/full-screen-covers + `DeepLinkRouter.pendingDestination`.

## Layers

**Presentation Layer (Views):**
- Purpose: SwiftUI screens + reusable components.
- Location: `MindRestore/Views/**` (subfolders: Home, Onboarding, Exercises, Components, FocusMode, Achievements, Assessment, DailyChallenge, Education, Leaderboard, Profile, Progress, Settings, Social, Paywall).
- Contains: Views, View-local enums (e.g. `RTPhase`), inline ViewModels for games.
- Depends on: Services (via `@Environment(...)`), Models (via `@Query`), DesignSystem.
- Used by: `ContentView` aggregates them; `MindRestoreApp` mounts the root.

**Service Layer:**
- Purpose: Mutable app state + side-effects (StoreKit, GameKit, FamilyControls, UserNotifications, PostHog, CloudKit-via-ReferralService).
- Location: `MindRestore/Services/**`.
- Contains: `@Observable` reference types (state-holding) and pure-logic helpers (engines).
- Depends on: Models, Apple frameworks. **No view dependencies.**
- Used by: `ContentView` instantiates and injects via environment.

**Model Layer:**
- Purpose: Persistent state.
- Location: `MindRestore/Models/**`.
- Contains: SwiftData `@Model` classes plus value-type `Codable` enums/structs (`ExerciseType`, `ChallengeLink`).
- Depends on: Foundation, SwiftData only.
- Used by: Views (`@Query`) and Services (passed `ModelContext`).

**ViewModels Layer (selective):**
- Purpose: Stateful logic for complex screens that exceed reasonable inline `@State`.
- Location: `MindRestore/ViewModels/**` plus inline ViewModels at the top of `Views/Exercises/*.swift`.
- Used by: Views that need them (`HomeView`, `ProgressDashboardView`, `BrainAssessmentView`, `DailyChallengeView`, all 16 exercises).

**Content Layer (static):**
- Purpose: Bundled training content (cards, education feed).
- Location: `MindRestore/Content/{ActiveRecallContent,EducationContent,SpacedRepetitionContent}.swift`.

**Utilities Layer:**
- `MindRestore/Utilities/DesignSystem.swift` — `AppColors`, `AppCardModifier`, `CognitiveDomain`.
- `MindRestore/Utilities/Constants.swift` — bundled string/number constants.
- `MindRestore/Utilities/Extensions.swift` — Foundation/SwiftUI conveniences (e.g. `Date.isToday`).

**Extension Targets:**
- Widget (`MindRestore/Widget/`) and three Family Controls extensions (`MindRestore/Extensions/`) compile into separate bundle targets and communicate with the app via App Group `UserDefaults`.

## Data Flow

### Primary Request Path — User completes a game

1. User taps a game tile in `TrainingView` (inline in `MindRestore/ContentView.swift:~600+`).
2. `NavigationLink`/`fullScreenCover` pushes the game view (e.g. `MindRestore/Views/Exercises/ReactionTimeView.swift`).
3. The game's local ViewModel (`@Observable final class ReactionTimeViewModel`) drives game phases and writes results.
4. On finish, the View calls `awardXP(...)` defined in `MindRestore/ContentView.swift` (TrainingView extension), which:
   - Inserts an `Exercise` via `modelContext.insert(...)`.
   - Calls `user.addXP(...)` and `user.updateStreak(...)` on the `User` `@Model`.
   - Triggers `AchievementService.checkAchievements(...)`.
   - Reports score to `GameCenterService.submitScore(...)`.
   - Posts `Notification.Name.workoutGameCompleted` for global listeners.
   - Calls `Analytics.gameCompleted(...)`.
5. SwiftUI re-renders subscribed views (Home, Profile, ContentView toasts) via `@Query` invalidation and `@Observable` change tracking.

### Onboarding Flow

1. `ContentView.body` checks `user?.hasCompletedOnboarding`.
2. If false, presents `MindRestore/Views/Onboarding/OnboardingView.swift` (~2236 lines) which orchestrates a multi-step page flow including `OnboardingNewScreens.swift` (~2375 lines), `FocusOnboardingPages.swift`, `QuickAssessmentView.swift`, `OnboardingPaywallView.swift`.
3. Final step writes `user.hasCompletedOnboarding = true` → root re-renders into `mainTabView`.

### Deep Link Flow

1. URL arrives at `MindRestoreApp` → `ContentView.onOpenURL` → `DeepLinkRouter.handle(url)` (`MindRestore/Services/DeepLinkRouter.swift`).
2. Router sets `pendingDestination` (`.home` / `.train` / `.game(_)` / `.challenge` / `.compete` / `.focusUnlock` / `.referral`) and optional `pendingChallenge`.
3. `ContentView.onChange(of: deepLinkRouter.pendingDestination)` switches `selectedTab` and presents the relevant sheet/cover.
4. Notification taps reach `AppDelegate.userNotificationCenter(_:didReceive:...)` which extracts `userInfo["deepLink"]` and calls `UIApplication.shared.open(url)` — back to step 1.

### Focus Mode Unlock Flow

1. User taps shielded app → `ShieldActionExtension` opens `memori://focus-unlock`.
2. `DeepLinkRouter` → `pendingDestination = .focusUnlock`.
3. `ContentView` selects a random game from the active 10, sets `focusUnlockExercise` and `focusUnlockPending = true`.
4. Game completes → `Notification.Name.workoutGameCompleted` posted.
5. `ContentView.onReceive(...)` calls `focusModeService.temporaryUnlock()` and shows the unlock toast.

**State Management:**
- **Persistent:** SwiftData `ModelContainer` declared in `MindRestoreApp.body` (`User`, `Exercise`, `SpacedRepetitionCard`, `DailySession`, `BrainScoreResult`, `Achievement`). `cloudKitDatabase: .none`.
- **Cross-screen mutable state:** Eight `@Observable` services held as `@State` in `ContentView` and re-injected via `.environment(...)`.
- **Lightweight settings:** `@AppStorage` (e.g. `appTheme`) and direct `UserDefaults` reads in services (Focus Mode, referral expiry, training seconds).
- **App-group bridge:** Widget reads via `WidgetDataService` (`MindRestore/Widget/WidgetDataService.swift`).
- **Cross-component events:** `NotificationCenter` for `streakMilestoneCelebration`, `brainScoreMilestoneCelebration`, `workoutGameCompleted`, `brainScoreImproved` (declared in `MindRestore/ContentView.swift:4-9`).

## Key Abstractions

**`@Observable` Service:** Stateful `@MainActor final class` injected via environment.
- Examples: `MindRestore/Services/StoreService.swift`, `MindRestore/Services/FocusModeService.swift`, `MindRestore/Services/AchievementService.swift`.
- Pattern: Single source of truth per concern; no protocols/mocks. Tests use real instances (or skip).

**SwiftData `@Model`:** Persisted reference type with computed helpers + mutating methods.
- Examples: `MindRestore/Models/User.swift` (owns `updateStreak`, `addXP`, `xpForExercise`).
- Pattern: Models hold their own domain logic; services orchestrate across multiple models.

**Engine (logic-only helper):** Pure-ish helper (often a struct or `static`-method enum) consumed by views/services.
- Examples: `MindRestore/Services/WorkoutEngine.swift`, `MindRestore/Services/AdaptiveDifficultyEngine.swift`, `MindRestore/Services/SeededGenerator.swift`.
- Pattern: No `@Observable`, no shared state; deterministic given inputs.

**Static `enum` namespace:** Used for stateless service-like clusters.
- Examples: `Analytics` (`MindRestore/Services/AnalyticsService.swift`), `HapticService`, `SoundService`.
- Pattern: `enum Foo { static func bar() }`.

**`AppColors` / `AppCardModifier`:** DesignSystem tokens at `MindRestore/Utilities/DesignSystem.swift`.
- Pattern: Always reference these — never raw `Color(red:green:blue:)` in views.

**Game ViewModel (game-local):** `@Observable final class XxxViewModel` declared at the top of each `Views/Exercises/*.swift`.
- Pattern: setup → playing → results state machine; calls back to `awardXP` on completion.

## Entry Points

**App launch:** `MindRestore/MindRestoreApp.swift` (`@main struct MindRestoreApp: App`)
- Triggers: cold start.
- Responsibilities: configure PostHog (`Analytics.configure()`), RevenueCat, tab-bar appearance, mount `ModelContainer`, present `ContentView`.

**Notification tap:** `AppDelegate.userNotificationCenter(_:didReceive:...)` in `MindRestore/MindRestoreApp.swift:78-92`
- Triggers: user taps a local notification.
- Responsibilities: extract `userInfo["deepLink"]`, fire `Analytics.appOpenedFromNotification`, open URL → `onOpenURL` → `DeepLinkRouter`.

**URL scheme:** `ContentView.onOpenURL` in `MindRestore/ContentView.swift:78-80`
- Triggers: `memori://` deep link, including from `ShieldActionExtension`.
- Responsibilities: hand to `DeepLinkRouter.handle(url)`.

**Widget timeline:** `MemoriTimelineProvider.getTimeline` in `MindRestore/Widget/MemoriWidgetBundle.swift:40`
- Triggers: WidgetKit (~hourly + on `WidgetCenter.shared.reloadAllTimelines()`).
- Responsibilities: read `WidgetDataService.currentSnapshot()` from app-group UserDefaults.

**Family Controls events:** `DeviceActivityMonitorExtension`, `ShieldActionExtension`, `ShieldConfigurationExtension` in `MindRestore/Extensions/`.

## Architectural Constraints

- **Threading:** All services are `@MainActor`. SwiftData mutations occur on the main actor (matches `ModelContext` default). Detached `Task`s exist for `Transaction.updates` (`StoreService.listenForTransactions`) and widget snapshot syncing.
- **Global state:** Eight long-lived `@Observable` instances live as `@State` on `ContentView` for the entire app lifetime. They behave like singletons but are not declared `static`. `Analytics`, `HapticService`, `SoundService` are `enum` namespaces (true module-level statics). `NotificationService.shared` (`MindRestore/Services/NotificationService.swift`) IS a true singleton.
- **Circular imports:** None observed. Services depend on Models; Models stand alone; Views depend on both.
- **Cross-target sharing:** App ↔ Widget ↔ Shield extensions communicate exclusively through App Group `UserDefaults` (keys defined inline per file, e.g. `MindRestore/Services/FocusModeService.swift:9-25`).
- **No SPM additions from Claude:** Cannot edit `MindRestore.xcodeproj`. SPM packages currently used: ConfettiSwiftUI, PostHog, RiveRuntime, RevenueCat (manual user step required to add new packages).
- **Archive guard:** `ScreenshotDataGenerator` (`MindRestore/Services/ScreenshotDataGenerator.swift`) must remain `#if DEBUG`-wrapped — release archives otherwise fail.

## Anti-Patterns

### God-View `ContentView.swift`

**What happens:** `MindRestore/ContentView.swift` is ~1534 lines. It owns service instantiation, the entire TabView, the inline `TrainingView` + `TrainingTile`, all global overlays, deep-link routing logic, notification scheduling, brain-score-decay handling, focus-unlock orchestration, and `awardXP`.

**Why it's wrong:** Forces unrelated concerns into one file; impossible to navigate; merge conflicts on every feature; impossible to unit-test individual flows.

**Do this instead:** Split into `RootView`, `AppEnvironmentRoot` (service plumbing), `TrainingView.swift` (lift TrainingView+TrainingTile out), `RootOverlays.swift` (toasts), `RootNotificationsCoordinator.swift` (decay, comeback, weekly-report scheduling). Keep `ContentView` to <200 lines that wires children together.

### Mega-Onboarding files

**What happens:** `MindRestore/Views/Onboarding/OnboardingView.swift` (~2236 lines) and `OnboardingNewScreens.swift` (~2375 lines) hold dozens of step views in single files.

**Why it's wrong:** Same as above — search and editing become hostile; previews can't isolate steps cleanly.

**Do this instead:** One file per onboarding screen in `MindRestore/Views/Onboarding/Steps/`, with a thin `OnboardingFlow.swift` that drives transitions.

### Dead `User.subscriptionStatus` / `User.isProUser`

**What happens:** `MindRestore/Models/User.swift:43-58` declares `subscriptionStatus` and `isProUser` but a comment says "unused — `StoreService.isProUser` is the source of truth".

**Why it's wrong:** Two ways to ask "is the user paying?" — call sites can grab the wrong one.

**Do this instead:** Always read `StoreService.isProUser`. Leave the model fields only because removing them migrates SwiftData schema; mark them `@available(*, deprecated)` and audit any reads.

### Legacy "Ultra" SKU naming after single-tier pivot

**What happens:** `StoreService` keeps both `com.memori.pro.*` and `com.memori.ultra.*` product IDs (`MindRestore/Services/StoreService.swift:33-39`). The "ultra" name is permanent because renaming an active App Store SKU invalidates subscriptions.

**Why it's wrong:** Reads as if there's still an Ultra tier. Future devs will assume tiered logic exists.

**Do this instead:** Always grant the same Pro entitlement for either family (already done in `updateSubscriptionStatus`). Rename Swift constants to `legacyProAnnualID` / `currentProAnnualID` to decouple from the marketing name. Document at the top of every paywall view.

### Inline ViewModels for game files

**What happens:** Each `MindRestore/Views/Exercises/*.swift` declares the ViewModel at the top of the same file (~30+ lines before the View starts).

**Why it's wrong:** Fine in moderation, but forces previews to instantiate the ViewModel; bloats files >800 lines for some games.

**Do this instead:** Extract to `Views/Exercises/Engines/{Name}ViewModel.swift` once a file passes ~500 lines. (Acceptable as-is for short games.)

## Error Handling

**Strategy:** Best-effort, user-non-blocking. Errors are logged or displayed inline as `purchaseError` strings; few do-catch chains propagate to the UI.

**Patterns:**
- StoreKit: `do { try await ... } catch { purchaseError = "Purchase failed: \(error)" }` — `MindRestore/Services/StoreService.swift:71-93`.
- SwiftData: `try? modelContext.fetchCount(...)` — silently degrades to defaults (e.g. `ContentView.swift:89`).
- Notifications: `try? await UNUserNotificationCenter.current().add(request)` — silent if undelivered.
- Network/CloudKit (`ReferralService`): wrapped in `do-catch`, errors surfaced via `@Observable` flags, never thrown out of services.
- Force-unwraps appear in `MindRestore/MindRestoreApp.swift:59` (`try! ModelContainer(...)`) — acceptable at app launch (would crash anyway if container fails).

## Cross-Cutting Concerns

**Logging:** `print()` in DEBUG paths and PostHog `Analytics.*` calls everywhere user behavior matters. No OSLog/Logger usage observed.

**Validation:** Done inline in views (e.g. text-input pages of onboarding) and in model setters (e.g. `User.updateStreak` enforces same-day idempotency). No central validator layer.

**Authentication:**
- Game Center via `GameCenterService.authenticate()` (`MindRestore/Services/GameCenterService.swift`) — called once on `ContentView.onAppear`.
- Family Controls via `FocusModeService` `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
- StoreKit auto-uses signed-in Apple ID. No app-level account system.
- Referrals identify users via a per-user code stored in CloudKit public DB (`ReferralService`).

**Analytics:** `MindRestore/Services/AnalyticsService.swift` — `enum Analytics` with static methods wrapping `PostHogSDK.shared.capture(...)`. User identified once on launch with `is_pro_user`, `streak`, `brain_age`, `games_played` properties.

**Theming:** `@AppStorage("appTheme")` in `MindRestoreApp` toggles `.preferredColorScheme(...)`. Color tokens come exclusively from `MindRestore/Utilities/DesignSystem.swift::AppColors`.

---
*Architecture analysis: 2026-04-27*
