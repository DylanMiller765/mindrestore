# Focus Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Focus Mode (screen time blocking with brain game unlock) and Ultra subscription tier to Memori.

**Architecture:** FocusModeService manages all FamilyControls/ManagedSettings state. Extensions (DeviceActivityMonitor, ShieldConfiguration, ShieldAction) communicate with the main app via App Group UserDefaults. QuickGameView wraps existing game ViewModels with shortened parameters. StoreService gains Ultra product IDs and `isUltraUser` check.

**Tech Stack:** SwiftUI, FamilyControls, ManagedSettings, DeviceActivity, StoreKit 2, App Groups

---

## Phase 1: Foundation (no Xcode extension targets needed)

### Task 1: FocusModeService — Core Service

**Files:**
- Create: `MindRestore/Services/FocusModeService.swift`

- [ ] **Step 1: Create FocusModeService with shared state**

```swift
import SwiftUI
import FamilyControls
import ManagedSettings

@MainActor
@Observable
final class FocusModeService {
    // MARK: - Shared State (App Group)

    private let sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared")!

    var isEnabled: Bool {
        get { sharedDefaults.bool(forKey: "focus_mode_enabled") }
        set { sharedDefaults.set(newValue, forKey: "focus_mode_enabled") }
    }

    var unlockDurationMinutes: Int {
        get {
            let val = sharedDefaults.integer(forKey: "focus_unlock_duration")
            return val > 0 ? val : 15
        }
        set { sharedDefaults.set(newValue, forKey: "focus_unlock_duration") }
    }

    var unlockUntil: Date? {
        get { sharedDefaults.object(forKey: "focus_unlock_until") as? Date }
        set { sharedDefaults.set(newValue, forKey: "focus_unlock_until") }
    }

    var cooldownUntil: Date? {
        get { sharedDefaults.object(forKey: "focus_cooldown_until") as? Date }
        set { sharedDefaults.set(newValue, forKey: "focus_cooldown_until") }
    }

    var scheduleEnabled: Bool {
        get { sharedDefaults.bool(forKey: "focus_schedule_enabled") }
        set { sharedDefaults.set(newValue, forKey: "focus_schedule_enabled") }
    }

    var scheduleStart: Date {
        get { sharedDefaults.object(forKey: "focus_schedule_start") as? Date ?? Calendar.current.date(from: DateComponents(hour: 9))! }
        set { sharedDefaults.set(newValue, forKey: "focus_schedule_start") }
    }

    var scheduleEnd: Date {
        get { sharedDefaults.object(forKey: "focus_schedule_end") as? Date ?? Calendar.current.date(from: DateComponents(hour: 17))! }
        set { sharedDefaults.set(newValue, forKey: "focus_schedule_end") }
    }

    var dailyAttemptCount: Int {
        get {
            let savedDate = sharedDefaults.object(forKey: "focus_daily_attempt_date") as? Date
            if let savedDate, Calendar.current.isDateInToday(savedDate) {
                return sharedDefaults.integer(forKey: "focus_daily_attempt_count")
            }
            return 0
        }
        set {
            sharedDefaults.set(newValue, forKey: "focus_daily_attempt_count")
            sharedDefaults.set(Date.now, forKey: "focus_daily_attempt_date")
        }
    }

    // MARK: - FamilyControls

    var activitySelection = FamilyActivitySelection()
    private let store = ManagedSettingsStore()

    var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    // MARK: - Shield Management

    func applyShields() {
        let apps = activitySelection.applicationTokens
        let categories = activitySelection.categoryTokens
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        isEnabled = true
    }

    func removeShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    func temporaryUnlock() {
        unlockUntil = Date.now.addingTimeInterval(TimeInterval(unlockDurationMinutes * 60))
        removeShields()

        // Schedule re-lock
        Task {
            try? await Task.sleep(for: .seconds(unlockDurationMinutes * 60))
            if let until = unlockUntil, Date.now >= until {
                applyShields()
                unlockUntil = nil
            }
        }
    }

    var isCurrentlyUnlocked: Bool {
        if let until = unlockUntil, Date.now < until {
            return true
        }
        return false
    }

    // MARK: - Disable with Cooldown

    func initiateDisable() {
        cooldownUntil = Date.now.addingTimeInterval(600) // 10 minutes
        Task {
            try? await Task.sleep(for: .seconds(600))
            if cooldownUntil != nil {
                removeShields()
                isEnabled = false
                cooldownUntil = nil
                activitySelection = FamilyActivitySelection()
            }
        }
    }

    func cancelDisable() {
        cooldownUntil = nil
    }

    var isDisabling: Bool {
        if let until = cooldownUntil, Date.now < until {
            return true
        }
        return false
    }

    var disableTimeRemaining: TimeInterval {
        guard let until = cooldownUntil else { return 0 }
        return max(0, until.timeIntervalSince(Date.now))
    }

    // MARK: - Persistence

    private let selectionKey = "focus_activity_selection"

    func saveSelection() {
        if let data = try? JSONEncoder().encode(activitySelection) {
            sharedDefaults.set(data, forKey: selectionKey)
        }
    }

    func loadSelection() {
        if let data = sharedDefaults.data(forKey: selectionKey),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            activitySelection = selection
        }
    }

    // MARK: - Stats

    var todayShieldInteractions: Int {
        dailyAttemptCount
    }

    func recordShieldInteraction() {
        dailyAttemptCount += 1
    }

    var blockedAppCount: Int {
        activitySelection.applicationTokens.count + activitySelection.categoryTokens.count
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build 2>&1 | grep -E "(BUILD|error:)" | tail -5`
Expected: BUILD SUCCEEDED

Note: Need to add `import FamilyControls` and `import ManagedSettings` — these frameworks must be added to the main target in Xcode. The user may need to add them via Build Phases → Link Binary With Libraries.

- [ ] **Step 3: Commit**

```bash
git add MindRestore/Services/FocusModeService.swift
git commit -m "feat: add FocusModeService — FamilyControls, shield management, shared state"
```

### Task 2: Ultra Subscription Tier in StoreService

**Files:**
- Modify: `MindRestore/Services/StoreService.swift`

- [ ] **Step 1: Add Ultra product IDs and isUltraUser**

Add after the existing product ID constants:
```swift
static let weeklyUltraProductID = "com.memori.ultra.weekly"
static let monthlyUltraProductID = "com.memori.ultra.monthly"
static let annualUltraProductID = "com.memori.ultra.annual"
```

Update `loadProducts()` to include Ultra products in the fetch array.

Add a new property:
```swift
var isUltraUser = false
```

Update `updateSubscriptionStatus()` to check for Ultra product IDs and set `isUltraUser`. Both Pro and Ultra should set `isProUser = true` (Ultra is a superset of Pro).

Add computed properties:
```swift
var weeklyUltraProduct: Product? { products.first { $0.id == Self.weeklyUltraProductID } }
var monthlyUltraProduct: Product? { products.first { $0.id == Self.monthlyUltraProductID } }
var annualUltraProduct: Product? { products.first { $0.id == Self.annualUltraProductID } }
```

- [ ] **Step 2: Build and verify**
- [ ] **Step 3: Commit**

```bash
git add MindRestore/Services/StoreService.swift
git commit -m "feat: add Ultra subscription tier to StoreService"
```

### Task 3: DeepLinkRouter — Focus Unlock URL

**Files:**
- Modify: `MindRestore/Services/DeepLinkRouter.swift`

- [ ] **Step 1: Add focusUnlock destination**

Add to `DeepLinkDestination` enum:
```swift
case focusUnlock
```

Add to the `switch url.host` in `handle(_:)`:
```swift
case "focus-unlock": pendingDestination = .focusUnlock
```

- [ ] **Step 2: Build and verify**
- [ ] **Step 3: Commit**

### Task 4: QuickGameView — Shortened Game Wrapper

**Files:**
- Create: `MindRestore/Views/FocusMode/QuickGameView.swift`

- [ ] **Step 1: Create QuickGameView**

This view picks a random game, presents a shortened version, and calls `onComplete` when done. It wraps existing game ViewModels with reduced parameters (fewer rounds, shorter time limits).

The view should:
- Pick a random ExerciseType from the 10 active games
- Show a brief "Get ready!" countdown (3, 2, 1)
- Present the game with shortened params
- On completion, call the `onComplete` closure (which triggers `temporaryUnlock()`)
- NOT save exercise results or count toward daily limits (this is a focus unlock, not a training session)

For v2.0 MVP: start with just Reaction Time (3 rounds) as the quick game. We can add the other 9 games as quick variants in follow-up tasks — getting the flow working end-to-end is more important.

- [ ] **Step 2: Build and verify**
- [ ] **Step 3: Commit**

### Task 5: FocusModeSetupView — 4-Step Setup Flow

**Files:**
- Create: `MindRestore/Views/FocusMode/FocusModeSetupView.swift`

- [ ] **Step 1: Create setup flow**

4-step TabView with scroll disabled:
1. Intro screen — mascot-goal image, "Block distracting apps, train your brain instead", Continue button
2. App picker — FamilyActivityPicker embedded, with note for free users ("Pick 1 app — unlock more with Ultra")
3. Schedule — toggle for "Always on" vs schedule picker with start/end time
4. Duration + permission — picker for unlock duration (5/15/30/60 min), button to request FamilyControls permission, "You're set!" confirmation

Each step has Continue/Back navigation. Final step calls `focusModeService.applyShields()` and dismisses.

- [ ] **Step 2: Build and verify**
- [ ] **Step 3: Commit**

### Task 6: FocusModeCard — Home Tab Integration

**Files:**
- Create: `MindRestore/Views/FocusMode/FocusModeCard.swift`
- Modify: `MindRestore/Views/Home/HomeView.swift`

- [ ] **Step 1: Create FocusModeCard**

A compact card showing:
- Focus Mode toggle (on/off)
- "X apps blocked" count
- "Tap to manage" hint
- If currently unlocked: "Unlocked for X min remaining"
- If cooldown active: "Disabling in X min..."

Tapping opens FocusModeSettingsView as a sheet.

- [ ] **Step 2: Add to HomeView between mascot and workout card**

Insert `FocusModeCard()` after `mascotHeroSection` and before the workout card.

- [ ] **Step 3: Build and verify**
- [ ] **Step 4: Commit**

### Task 7: FocusModeSettingsView — Management Screen

**Files:**
- Create: `MindRestore/Views/FocusMode/FocusModeSettingsView.swift`

- [ ] **Step 1: Create settings view**

Full management screen accessible from FocusModeCard:
- Toggle Focus Mode on/off
- "Edit blocked apps" → re-opens FamilyActivityPicker
- Schedule management (toggle + time pickers)
- Unlock duration picker
- "Turn off Focus Mode" button with 10-min cooldown confirmation
- Stats: today's shield interactions, current unlock status

- [ ] **Step 2: Build and verify**
- [ ] **Step 3: Commit**

### Task 8: Wire Up Focus Unlock Flow in ContentView

**Files:**
- Modify: `MindRestore/ContentView.swift`

- [ ] **Step 1: Add FocusModeService as environment object**

Add to ContentView's state:
```swift
@State private var focusModeService = FocusModeService()
```

Add to environment chain:
```swift
.environment(focusModeService)
```

- [ ] **Step 2: Handle focusUnlock deep link**

In the `.onChange(of: deepLinkRouter.pendingDestination)` handler, add:
```swift
case .focusUnlock:
    showQuickGame = true
    deepLinkRouter.pendingDestination = nil
```

Add state and sheet:
```swift
@State private var showQuickGame = false

.fullScreenCover(isPresented: $showQuickGame) {
    QuickGameView {
        focusModeService.temporaryUnlock()
        showQuickGame = false
    }
}
```

- [ ] **Step 3: Build and verify**
- [ ] **Step 4: Commit**

### Task 9: Onboarding Integration

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Add Focus Mode onboarding screen**

Insert a new page before the final "You're ready!" page (before `privacyPage`):
- Show mascot-goal image
- "One more thing — want to block distracting apps?"
- "Replace screen time with brain training"
- "Set up Focus Mode" button → presents FocusModeSetupView as sheet
- Prominent "Not now" skip button

Update `totalPages` count and adjust page indices.

- [ ] **Step 2: Build and verify**
- [ ] **Step 3: Commit**

### Task 10: Analytics Events

**Files:**
- Modify: `MindRestore/Services/AnalyticsService.swift` (or wherever Analytics is defined)

- [ ] **Step 1: Add Focus Mode analytics events**

Add static methods:
```swift
static func focusModeEnabled() { capture("focus_mode_enabled") }
static func focusModeDisabled() { capture("focus_mode_disabled") }
static func focusShieldShown(attemptCount: Int) { capture("focus_shield_shown", properties: ["attempt_count": attemptCount]) }
static func focusUnlockGameStarted(gameType: String) { capture("focus_unlock_game_started", properties: ["game_type": gameType]) }
static func focusUnlockGameCompleted(gameType: String, score: Int) { capture("focus_unlock_game_completed", properties: ["game_type": gameType, "score": score]) }
static func focusUnlockGranted(durationMinutes: Int) { capture("focus_unlock_granted", properties: ["duration_minutes": durationMinutes]) }
static func focusStayedFocused() { capture("focus_stayed_focused") }
static func focusSetupCompleted() { capture("focus_setup_completed") }
static func focusSetupSkipped() { capture("focus_setup_skipped") }
static func focusCooldownInitiated() { capture("focus_cooldown_initiated") }
```

- [ ] **Step 2: Wire analytics calls into FocusModeService and setup views**
- [ ] **Step 3: Commit**

## Phase 2: Xcode Extension Targets (requires manual user action)

### Task 11: User Creates Extension Targets in Xcode

**This task is for the USER to complete manually in Xcode.**

**Step-by-step instructions:**

1. Open `MindRestore.xcodeproj` in Xcode
2. File → New → Target
3. Search for "Device Activity Monitor Extension"
4. Name it `DeviceActivityMonitorExtension`
5. Team: Dylan Bryan Miller
6. Bundle ID: `com.dylanmiller.mindrestore.DeviceActivityMonitor`
7. Embed in: MindRestore
8. Activate scheme: No

Repeat for:
- "Shield Configuration Extension" → `ShieldConfigurationExtension` → `com.dylanmiller.mindrestore.ShieldConfiguration`
- "Shield Action Extension" → `ShieldActionExtension` → `com.dylanmiller.mindrestore.ShieldAction`

For ALL THREE extensions:
1. Select the extension target → Signing & Capabilities
2. Add "App Groups" capability → check `group.com.memori.shared`
3. Set deployment target to iOS 17.0
4. Make sure the extension is embedded in the main app target

### Task 12: DeviceActivityMonitor Extension Code

**Files:**
- Modify: `DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift`

Code for scheduled blocking — start/stop shields based on schedule.

### Task 13: ShieldConfiguration Extension Code

**Files:**
- Modify: `ShieldConfigurationExtension/ShieldConfigurationExtension.swift`

Custom shield UI with Memo mascot. Reads attempt count from App Group to rotate messages.

### Task 14: ShieldAction Extension Code

**Files:**
- Modify: `ShieldActionExtension/ShieldActionExtension.swift`

Handles "Play a game" button → opens `memori://focus-unlock`. Handles "Stay focused" → dismisses.

## Phase 3: Paywall Redesign

### Task 15: Paywall with Pro/Ultra Tier Selection

**Files:**
- Modify: `MindRestore/Views/Paywall/PaywallView.swift`

Add tier selector at top (Pro vs Ultra with feature comparison), then show duration options for the selected tier.

## Phase 4: StoreKit Configuration

### Task 16: Create Ultra Products in StoreKit Config

**This task is for the USER to complete in App Store Connect:**

1. Go to App Store Connect → Memori → Subscriptions
2. In the existing subscription group, add 3 new products:
   - `com.memori.ultra.weekly` — $3.99/week
   - `com.memori.ultra.monthly` — $6.99/month
   - `com.memori.ultra.annual` — $39.99/year
3. Set Ultra products as Level 2 (higher tier than Pro Level 1)
4. Update the local StoreKit configuration file if one exists

---

## Execution Order

**This session — Phase 1 (Tasks 1-10):** All Swift code in the main app target. No Xcode extension work needed. This gives us the complete Focus Mode service, setup flow, Home card, settings, quick game, deep link, onboarding, and analytics.

**Next session — Phase 2 (Tasks 11-14):** User creates extension targets in Xcode, then we write the extension code.

**Follow-up — Phase 3-4 (Tasks 15-16):** Paywall redesign and StoreKit products.
