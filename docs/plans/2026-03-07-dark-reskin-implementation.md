# Dark Reskin + Viral Brain Age Reveal — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reskin the app to a dark premium aesthetic and build a dramatic Brain Age reveal for TikTok virality.

**Architecture:** DesignSystem.swift centralizes colors and card modifiers — changing it propagates app-wide. The Brain Age reveal is a new full-screen view inserted into the existing assessment flow. Share card already exists dark-themed (use as reference).

**Tech Stack:** SwiftUI, SwiftData, iOS 17+

---

### Task 1: Dark Surface Colors in DesignSystem

**Files:**
- Modify: `MindRestore/Utilities/DesignSystem.swift`

**Step 1: Replace surface color definitions**

Replace `AppColors` surface colors:
```swift
// Dark canvas — near-black with slight blue tint
static let pageBg = Color(red: 0.04, green: 0.04, blue: 0.055)
static let cardSurface = Color(red: 0.086, green: 0.086, blue: 0.11)
static let cardElevated = Color(red: 0.11, green: 0.11, blue: 0.14)
static let cardBorder = Color.white.opacity(0.06)
// Remove cardBorderDark — no longer needed, always dark
```

**Step 2: Replace text color helpers**

Add text color constants to AppColors:
```swift
static let textPrimary = Color.white.opacity(0.92)
static let textSecondary = Color.white.opacity(0.55)
static let textTertiary = Color.white.opacity(0.35)
```

**Step 3: Update AppCardModifier**

Remove `@Environment(\.colorScheme)` — always dark now:
```swift
struct AppCardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.cardSurface)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 0.75)
            )
    }
}
```

**Step 4: Update GlowingCardModifier**

```swift
struct GlowingCardModifier: ViewModifier {
    let color: Color
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.cardSurface)
                    .shadow(color: color.opacity(intensity * 0.6), radius: 8, y: 2)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 0.75)
            )
    }
}
```

**Step 5: Update HeroCardModifier**

```swift
struct HeroCardModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.cardElevated)
                    .shadow(color: color.opacity(0.12), radius: 12, y: 4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.cardBorder, lineWidth: 0.75)
            )
    }
}
```

**Step 6: Update pageBackground()**

```swift
func pageBackground() -> some View {
    self.background(AppColors.pageBg.ignoresSafeArea())
}
```

**Step 7: Update BrainScoreRing**

Make the ring thicker (12pt) and add outer glow:
- Change `lineWidth` from 10 to 12
- Add `.shadow(color: ringColor.opacity(0.4), radius: 8)` on the progress arc

**Step 8: Update StreakWeekView colors**

Replace `Color(.tertiarySystemFill)` → `Color.white.opacity(0.08)`
Replace `Color(.systemFill)` → `Color.white.opacity(0.12)`

**Step 9: Build and verify**

Run: `xcodebuild -scheme MindRestore -destination 'id=00008130-000A214E11E2001C' build`
Expected: BUILD SUCCEEDED

**Step 10: Commit**

```
feat: dark canvas foundation — surface colors, card modifiers, ring glow
```

---

### Task 2: Dark Theme in ContentView (TrainingTile + Training Tab)

**Files:**
- Modify: `MindRestore/ContentView.swift`

**Step 1: Update TrainingTile**

Remove `@Environment(\.colorScheme)` and `isDark` logic. Use dark colors directly:
```swift
.background {
    RoundedRectangle(cornerRadius: 18)
        .fill(AppColors.cardSurface)
}
.overlay(
    RoundedRectangle(cornerRadius: 18)
        .stroke(AppColors.cardBorder, lineWidth: 0.75)
)
```

**Step 2: Fix any hard-coded system colors**

Replace any remaining `Color(.systemBackground)`, `Color(.secondarySystemGroupedBackground)` with `AppColors.cardSurface` or `AppColors.pageBg`.

Replace `.secondary` foreground styles with `AppColors.textSecondary` where they appear on card surfaces (system `.secondary` may not contrast well on custom dark).

**Step 3: Build and verify**

**Step 4: Commit**

```
feat: dark theme TrainingTile and training tab
```

---

### Task 3: Dark Theme in HomeView

**Files:**
- Modify: `MindRestore/Views/Home/HomeView.swift`

**Step 1: Update greeting and header text colors**

The greeting `.title2.weight(.bold)` should remain `.primary` (system adapts). But verify all `.secondary` labels read well.

**Step 2: Update brain score card**

- Opacity-based backgrounds (`accent.opacity(0.08)`, `accent.opacity(0.12)`) → bump to `accent.opacity(0.15)` minimum for visibility on dark
- Avatar circle background: `accent.opacity(0.12)` → `accent.opacity(0.18)`
- Brain type capsule: `accent.opacity(0.1)` → `accent.opacity(0.18)`

**Step 3: Update stat numbers**

Make stat numbers bigger and bolder:
- Streak, sessions, brain age numbers → `.title.weight(.bold)` or `.system(size: 32, weight: .bold, design: .rounded)`
- Labels below → `.caption2` with `AppColors.textSecondary`

**Step 4: Update all card sections**

Walk through each card (streak, today's session, daily challenge, achievements, etc.) and ensure no hard-coded light colors remain. Key patterns:
- `Color(.tertiarySystemFill)` → `Color.white.opacity(0.08)`
- `Color(.systemBackground)` → `AppColors.pageBg`
- `Color(.secondarySystemBackground)` → `AppColors.cardSurface`

**Step 5: Build and verify**

**Step 6: Commit**

```
feat: dark theme HomeView — bigger stats, dark surfaces
```

---

### Task 4: Dark Theme Across Remaining Views

**Files:**
- Modify: `MindRestore/Views/Settings/SettingsView.swift`
- Modify: `MindRestore/Views/Progress/ProgressDashboardView.swift`
- Modify: `MindRestore/Views/Leaderboard/LeaderboardView.swift`
- Modify: `MindRestore/Views/Paywall/PaywallView.swift`
- Modify: `MindRestore/Views/Onboarding/OnboardingView.swift`
- Modify: `MindRestore/Views/DailyChallenge/DailyChallengeView.swift`
- Modify: `MindRestore/Views/Achievements/AchievementsView.swift`

**Step 1: Batch replace system colors in all views**

In each file, replace:
- `Color(.systemBackground)` → `AppColors.pageBg`
- `Color(.secondarySystemGroupedBackground)` → `AppColors.cardSurface`
- `Color(.secondarySystemBackground)` → `AppColors.cardSurface`
- `Color(.tertiarySystemFill)` → `Color.white.opacity(0.08)`
- `Color(.systemFill)` → `Color.white.opacity(0.12)`
- `Color(.systemGray6)` → `AppColors.cardSurface`
- `Color(.systemGray5)` → `Color.white.opacity(0.1)`

**Step 2: Fix text colors that won't auto-adapt**

Any hard-coded `.primary` that means "dark text" won't work. Check each view for text that assumes light background. SwiftUI `.primary` and `.secondary` should auto-adapt to dark mode, but verify.

**Step 3: Fix opacity-based overlays**

Any `color.opacity(0.08)` or `color.opacity(0.10)` backgrounds → bump to `0.15-0.20` for dark visibility.

**Step 4: Leaderboard podium cards**

Replace `.ultraThinMaterial` with `AppColors.cardElevated`. Medal colors (gold, silver, bronze) already work on dark.

**Step 5: Build and verify**

**Step 6: Install on phone and visual check all tabs**

**Step 7: Commit**

```
feat: dark theme across all views
```

---

### Task 5: Force Dark Mode App-Wide

**Files:**
- Modify: `MindRestore/MindRestoreApp.swift`
- Modify: `MindRestore/Views/Settings/SettingsView.swift`

**Step 1: Force dark color scheme on the root view**

In MindRestoreApp.swift, add `.preferredColorScheme(.dark)` to the root ContentView. This ensures the app is always dark regardless of system setting.

**Step 2: Remove theme picker from Settings**

Remove the Appearance card (light/dark/system toggle) from SettingsView — the app is now always dark. Remove `@AppStorage("appTheme")` and `AppTheme` references.

**Step 3: Build and verify**

**Step 4: Commit**

```
feat: force dark mode app-wide, remove theme picker
```

---

### Task 6: Dramatic Brain Age Reveal

**Files:**
- Modify: `MindRestore/Views/Assessment/ScoreRevealView.swift`

**Step 1: Add brain age color function**

```swift
private func brainAgeColor(for age: Int) -> Color {
    switch age {
    case ...25: return Color(red: 0, green: 0.82, blue: 0.62)   // green #00D19E
    case 26...40: return Color(red: 0.25, green: 0.61, blue: 0.98) // sky #3F9CFA
    case 41...55: return Color(red: 1.0, green: 0.76, blue: 0.28)  // amber #FFC247
    default: return Color(red: 0.98, green: 0.42, blue: 0.35)      // coral #FA6B59
    }
}
```

**Step 2: Add count-up animation state**

```swift
@State private var displayedBrainAge: Int = 18
@State private var isCountingUp = false
@State private var countUpFinished = false
@State private var showSubtitle = false
@State private var showPercentile = false
@State private var showShareButton = false
```

**Step 3: Build the full-screen brain age reveal phase**

After the existing reveal sequence, add a dedicated brain age phase:
- Full black screen
- "Your Brain Age" fades in (small, white 0.5 opacity)
- Number counts from 18 to actual brain age over ~3 seconds
- Color shifts in real-time based on current displayed number
- Pulse glow behind final number
- Snarky subtitle slides in: "You have the brain of a [age]-year-old"
- Percentile fades in
- Share button appears

**Step 4: Implement count-up timer**

```swift
private func startBrainAgeCountUp(target: Int) {
    displayedBrainAge = 18
    isCountingUp = true
    let totalSteps = target - 18
    let interval = 3.0 / Double(max(totalSteps, 1))

    Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
        if displayedBrainAge >= target {
            timer.invalidate()
            countUpFinished = true
            withAnimation(.easeOut(duration: 0.5)) {
                showSubtitle = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showPercentile = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(1.2)) {
                showShareButton = true
            }
        } else {
            displayedBrainAge += 1
        }
    }
}
```

**Step 5: Build the reveal view body**

Full-screen ZStack on black background with:
- Centered brain age number (96pt, rounded, black weight)
- Color from `brainAgeColor(for: displayedBrainAge)`
- Radial glow behind number when `countUpFinished`
- Subtitle, percentile, share button with staggered fade-in

**Step 6: Build and verify**

**Step 7: Commit**

```
feat: dramatic brain age reveal with count-up animation
```

---

### Task 7: Upgraded Share Card

**Files:**
- Modify: `MindRestore/Views/Assessment/ShareCardView.swift`

**Step 1: Update share card design**

The share card is already dark-themed. Enhance it:
- Brain Age number: make it 120pt, colored by `brainAgeColor`
- Add user's actual age group to percentile: "Sharper than X% of 20-year-olds"
- Add faint neural dot pattern in background at `white.opacity(0.03)`
- Ensure "Memori" watermark is present at bottom

**Step 2: Verify share card renders correctly**

Test the share card image generation to ensure it looks right for social media.

**Step 3: Build and verify**

**Step 4: Commit**

```
feat: enhanced dark share card with brain age prominence
```

---

### Task 8: Exercise Views Dark Cleanup

**Files:**
- Modify: All files in `MindRestore/Views/Exercises/`
- Modify: All files in `MindRestore/Views/Components/`

**Step 1: Scan all exercise views for system colors**

Replace the same patterns as Task 4:
- System background colors → AppColors equivalents
- System fill colors → white opacity equivalents
- Low-opacity overlays → bumped opacity values

**Step 2: Check exercise gameplay backgrounds**

Some exercises (Reaction Time, Dual N-Back) have intentional colored backgrounds for gameplay. These should remain — they're functional, not decorative.

**Step 3: Update component views**

HeatmapCalendar, ProgressRing, StreakBadge, ExerciseCard, etc. — ensure they use the design system colors.

**Step 4: Build and verify**

**Step 5: Install on phone, test each exercise visually**

**Step 6: Commit**

```
feat: dark theme cleanup across exercises and components
```

---

### Task 9: Final Polish and Build

**Files:**
- All modified files

**Step 1: Full build**

Run: `xcodebuild -scheme MindRestore -destination 'id=00008130-000A214E11E2001C' build`

**Step 2: Install on phone**

Run: `xcrun devicectl device install app --device 00008130-000A214E11E2001C [app path]`

**Step 3: Visual audit all screens**

Walk through every tab and screen:
- Home → brain score, streak, daily challenge
- Train → exercise grid, each exercise
- Compete → leaderboard, podium
- Insights → progress dashboard
- Profile → settings, about
- Brain Assessment → full flow → reveal → share card

**Step 4: Fix any visual issues found**

**Step 5: Commit**

```
feat: dark reskin polish and final fixes
```
