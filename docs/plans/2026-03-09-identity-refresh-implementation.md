# Identity Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform Memori from a clinical wellness brain-training app into a competitive memory game with a Monkeytype/NYT Games aesthetic — monochrome dark base, electric cyan accent, solid flat cards, monospace numbers, no glassmorphism.

**Architecture:** Nearly all visual changes cascade from `DesignSystem.swift` — update colors, modifiers, and components there first. Then fix the ~15 files with hardcoded colors/styles that bypass the design system. Exercise views follow a batch pattern and can be processed together.

**Tech Stack:** SwiftUI, SF Pro + SF Mono system fonts, no external dependencies.

**Design doc:** `docs/plans/2026-03-09-identity-refresh-design.md`

---

### Task 1: Update DesignSystem.swift — Colors

**Files:**
- Modify: `MindRestore/Utilities/DesignSystem.swift:36-98`

**Step 1: Replace the color palette**

Replace the entire `AppColors` enum with the new monochrome + cyan system:

```swift
enum AppColors {
    // Monochrome base
    static let pageBg = Color(red: 0.039, green: 0.039, blue: 0.059)       // #0A0A0F
    static let cardSurface = Color(red: 0.078, green: 0.078, blue: 0.122)   // #14141F
    static let cardElevated = Color(red: 0.098, green: 0.098, blue: 0.145)  // #191925
    static let cardBorder = Color(red: 0.118, green: 0.118, blue: 0.180)    // #1E1E2E
    static let cardBorderDark = cardBorder

    // Text
    static let textPrimary = Color(red: 0.941, green: 0.941, blue: 0.941)   // #F0F0F0
    static let textSecondary = Color(red: 0.420, green: 0.420, blue: 0.502)  // #6B6B80
    static let textTertiary = Color(red: 0.30, green: 0.30, blue: 0.38)

    // Accent — electric cyan
    static let accent = Color(red: 0.0, green: 0.831, blue: 1.0)            // #00D4FF

    // Functional
    static let error = Color(red: 0.94, green: 0.33, blue: 0.31)
    static let warning = Color(red: 1.0, green: 0.65, blue: 0.15)
    static let chartBlue = Color(red: 0.35, green: 0.55, blue: 0.85)

    // Per-game colors (secondary — tiles and results only)
    static let teal = Color(red: 0.0, green: 0.73, blue: 0.68)
    static let indigo = Color(red: 0.35, green: 0.34, blue: 0.84)
    static let coral = Color(red: 0.98, green: 0.42, blue: 0.35)
    static let violet = Color(red: 0.58, green: 0.34, blue: 0.92)
    static let sky = Color(red: 0.25, green: 0.61, blue: 0.98)
    static let mint = Color(red: 0.0, green: 0.82, blue: 0.62)
    static let rose = Color(red: 0.92, green: 0.30, blue: 0.55)
    static let amber = Color(red: 1.0, green: 0.76, blue: 0.28)

    // Gradients — simplified, accent only
    static let accentGradient = LinearGradient(
        colors: [accent, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Keep these as aliases so call sites don't break, but they're all just accent now
    static let premiumGradient = LinearGradient(
        colors: [accent, Color(red: 0.0, green: 0.65, blue: 0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGradient = accentGradient
    static let coolGradient = accentGradient

    static let neuralGradient = LinearGradient(
        colors: [accent, accent.opacity(0.7)],
        startPoint: .leading,
        endPoint: .trailing
    )
}
```

**Step 2: Verify build compiles**

Run: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD"`

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add MindRestore/Utilities/DesignSystem.swift
git commit -m "refactor: update color palette to monochrome + cyan"
```

---

### Task 2: Update DesignSystem.swift — Card Modifiers

**Files:**
- Modify: `MindRestore/Utilities/DesignSystem.swift:100-173`

**Step 1: Replace card modifiers with flat solid style**

Replace `AppCardModifier`, `GlowingCardModifier`, and `HeroCardModifier`:

```swift
struct AppCardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardSurface)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
    }
}

struct GlowingCardModifier: ViewModifier {
    let color: Color
    let intensity: Double

    func body(content: Content) -> some View {
        // No glow — same as appCard but with subtle accent border
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardSurface)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
    }
}

struct HeroCardModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardElevated)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            )
    }
}
```

**Step 2: Verify build**

**Step 3: Commit**

```bash
git add MindRestore/Utilities/DesignSystem.swift
git commit -m "refactor: flatten card modifiers — no glass, no glow, 12pt radius"
```

---

### Task 3: Update DesignSystem.swift — Buttons & Typography

**Files:**
- Modify: `MindRestore/Utilities/DesignSystem.swift:175-227` (buttons)
- Modify: `MindRestore/Utilities/DesignSystem.swift:283-340` (BrainScoreRing)
- Modify: `MindRestore/Utilities/DesignSystem.swift:344-483` (StreakWeekView, rings, bars)

**Step 1: Update button modifiers**

Replace `AccentButtonStyle` and `GradientButtonStyle`:

```swift
struct AccentButtonStyle: ViewModifier {
    var color: Color = AppColors.accent

    func body(content: Content) -> some View {
        content
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.black)
    }
}

struct GradientButtonStyle: ViewModifier {
    var gradient: LinearGradient = AppColors.accentGradient

    func body(content: Content) -> some View {
        content
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.black)
    }
}
```

Key changes:
- Button text is now **black** on cyan (not white on blue)
- Corner radius 10pt (not 14pt)
- `.semibold` not `.bold`
- `gradientButton` ignores the gradient param, just uses solid accent

**Step 2: Update SectionHeader to new typography**

```swift
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.textSecondary)
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

**Step 3: Update BrainScoreRing — monospace number, remove .rounded**

In `BrainScoreRing`, replace the score Text:
```swift
// Old:
Text("\(score)")
    .font(.system(size: size * 0.36, weight: .black, design: .rounded))

// New:
Text("\(score)")
    .font(.system(size: size * 0.34, weight: .bold, design: .monospaced))
```

Remove the `.shadow(color: ringColor.opacity(0.4), radius: 8)` from the score arc.

**Step 4: Update StreakWeekView — remove .rounded**

Replace:
```swift
.font(.system(size: 11, weight: .medium, design: .rounded))
```
With:
```swift
.font(.system(size: 11, weight: .medium))
```

**Step 5: Update StreakRingView — monospace, remove .rounded**

Replace:
```swift
.font(.system(size: size * 0.3, weight: .black, design: .rounded))
```
With:
```swift
.font(.system(size: size * 0.3, weight: .bold, design: .monospaced))
```

**Step 6: Update CognitiveDomainBar — remove .rounded**

Replace:
```swift
.font(.system(size: 9, weight: .bold, design: .rounded))
```
With:
```swift
.font(.system(size: 9, weight: .bold, design: .monospaced))
```

**Step 7: Verify build, commit**

```bash
git add MindRestore/Utilities/DesignSystem.swift
git commit -m "refactor: flat buttons, monospace scores, clean section headers"
```

---

### Task 4: Update HomeView.swift

**Files:**
- Modify: `MindRestore/Views/Home/HomeView.swift`

**Changes needed:**
- Remove all `.shadow(color:` calls (replace with no shadow or remove entirely)
- Replace any `design: .rounded` with `design: .monospaced` for score numbers, or just remove `.rounded` for labels
- Replace any hardcoded `cornerRadius` of 16/20 with 12
- Replace any `.ultraThinMaterial` with `AppColors.cardSurface`
- Scores/numbers should use `.design(.monospaced)`
- Section headers should be ALL CAPS + tracked if they aren't using `SectionHeader` already
- Keep layout structure, just update visual treatment

**Step 1:** Read the full file, identify all instances
**Step 2:** Make replacements
**Step 3:** Build and verify
**Step 4:** Commit

```bash
git commit -m "refactor: update HomeView to new identity"
```

---

### Task 5: Update ProgressDashboardView.swift

**Files:**
- Modify: `MindRestore/Views/Progress/ProgressDashboardView.swift`

**Changes needed:**
- Same pattern as HomeView: remove shadows, remove .rounded, update corner radii
- 8 glowingCard usages — these will auto-update from DesignSystem changes but verify
- Scores/stats → monospace
- Remove any radial gradient glows around icons

**Step 1-4:** Read, replace, build, commit

```bash
git commit -m "refactor: update ProgressDashboard to new identity"
```

---

### Task 6: Update Assessment Views (3 files)

**Files:**
- Modify: `MindRestore/Views/Assessment/BrainAssessmentView.swift`
- Modify: `MindRestore/Views/Assessment/ScoreRevealView.swift`
- Modify: `MindRestore/Views/Assessment/ShareCardView.swift`

**Changes needed:**
- ScoreRevealView has large score displays — convert to monospace
- ShareCardView has 10 `.rounded` fonts — all scores should be monospace
- Remove radial gradient glows around score circles
- Remove shadows
- Update corner radii to 12

**Step 1-4:** Read each, replace, build, commit

```bash
git commit -m "refactor: update assessment views to new identity"
```

---

### Task 7: Update Onboarding & Paywall Views

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingView.swift`
- Modify: `MindRestore/Views/Onboarding/OnboardingAssessmentView.swift`
- Modify: `MindRestore/Views/Paywall/PaywallView.swift`

**Changes needed:**
- Onboarding: `.ultraThinMaterial` → solid surface, remove .rounded fonts, update radii
- Paywall: remove premium gradient hero, simplify to clean accent treatment, remove shadows
- The paywall should feel confident and minimal, not flashy

**Step 1-4:** Read, replace, build, commit

```bash
git commit -m "refactor: update onboarding and paywall to new identity"
```

---

### Task 8: Update Achievements Views

**Files:**
- Modify: `MindRestore/Views/Achievements/AchievementsView.swift`
- Modify: `MindRestore/Views/Achievements/AchievementDetailView.swift`
- Modify: `MindRestore/Views/Components/AchievementToast.swift`
- Modify: `MindRestore/Models/Achievement.swift` (50+ gradient arrays)

**Changes needed:**
- Achievement.swift has per-achievement gradient arrays — simplify to single colors
- Achievement toast: remove shadows, clean flat style with accent left-border stripe
- Achievement views: remove glows, use flat cards
- Corner radii to 12

**Step 1-4:** Read, replace, build, commit

```bash
git commit -m "refactor: update achievements to new identity"
```

---

### Task 9: Batch Update Exercise Views (13 files)

**Files:**
- Modify: `MindRestore/Views/Exercises/ActiveRecallView.swift`
- Modify: `MindRestore/Views/Exercises/ChunkingTrainingView.swift`
- Modify: `MindRestore/Views/Exercises/ColorMatchView.swift`
- Modify: `MindRestore/Views/Exercises/DualNBackView.swift`
- Modify: `MindRestore/Views/Exercises/MathSpeedView.swift`
- Modify: `MindRestore/Views/Exercises/MemoryPalaceView.swift`
- Modify: `MindRestore/Views/Exercises/MixedTrainingView.swift`
- Modify: `MindRestore/Views/Exercises/ProspectiveMemoryView.swift`
- Modify: `MindRestore/Views/Exercises/ReactionTimeView.swift`
- Modify: `MindRestore/Views/Exercises/SequentialMemoryView.swift`
- Modify: `MindRestore/Views/Exercises/SpacedRepetitionView.swift`
- Modify: `MindRestore/Views/Exercises/SpeedMatchView.swift`
- Modify: `MindRestore/Views/Exercises/VisualMemoryView.swift`

**Pattern (same for all):**
- Remove `design: .rounded` → use default or `.monospaced` for scores
- Remove `.shadow(color:` calls
- Replace hardcoded `cornerRadius` 14/16/20 → 12
- Replace `RadialGradient` icon glows with simple solid circles or remove
- Score numbers → `.design(.monospaced)`
- `.ultraThinMaterial` → `AppColors.cardSurface`
- Custom colored button backgrounds: reduce opacity, remove gradient fills

These files follow an identical pattern — process as a batch.

**Step 1-4:** Read each, apply pattern, build, commit

```bash
git commit -m "refactor: update all exercise views to new identity"
```

---

### Task 10: Update Components (11 files)

**Files:**
- Modify: `MindRestore/Views/Components/ExerciseCard.swift`
- Modify: `MindRestore/Views/Components/ProgressRing.swift`
- Modify: `MindRestore/Views/Components/StreakBadge.swift`
- Modify: `MindRestore/Views/Components/HeatmapCalendar.swift`
- Modify: `MindRestore/Views/Components/BrainScoreChart.swift`
- Modify: `MindRestore/Views/Components/ShareableCard.swift`
- Modify: `MindRestore/Views/Components/TikTokShareCard.swift` (23 shadows!)
- Modify: `MindRestore/Views/Components/TrainingLimitBanner.swift`
- Modify: `MindRestore/Views/Components/AchievementToast.swift` (if not done in Task 8)

**Critical: TikTokShareCard.swift**
- Has 23 shadow effects — remove all colored shadows
- Replace with clean flat design — the share card should look premium and minimal
- Solid backgrounds, accent borders, monospace stats

**Step 1-4:** Read each, apply changes, build, commit

```bash
git commit -m "refactor: update components to new identity"
```

---

### Task 11: Update Remaining Views

**Files:**
- Modify: `MindRestore/ContentView.swift` (TrainingView, TrainingTile)
- Modify: `MindRestore/Views/Settings/SettingsView.swift`
- Modify: `MindRestore/Views/Leaderboard/LeaderboardView.swift`
- Modify: `MindRestore/Views/DailyChallenge/DailyChallengeView.swift`
- Modify: `MindRestore/Views/Social/ChallengeView.swift`
- Modify: `MindRestore/Views/Social/DuelView.swift`

**ContentView — TrainingTile:**
- Update tile corner radius to 12
- Remove `.fill(AppColors.cardSurface)` → stays but radius changes
- Icon circle radius: 12 (down from 14)

**Step 1-4:** Read each, apply pattern, build, commit

```bash
git commit -m "refactor: update remaining views to new identity"
```

---

### Task 12: Update DESIGN.md

**Files:**
- Modify: `docs/DESIGN.md`

Update the design doc to reflect the new identity:
- New brand positioning
- New color palette table
- New typography rules
- New component specs
- Remove references to glassmorphism, Elevate, wellness direction
- Add references to Monkeytype, NYT Games, competitive gaming

**Step 1:** Rewrite relevant sections
**Step 2:** Commit

```bash
git commit -m "docs: update DESIGN.md for identity refresh"
```

---

### Task 13: Final Build & Install

**Step 1:** Full clean build
```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -destination 'generic/platform=iOS' clean build 2>&1 | grep -E "error:|BUILD"
```

**Step 2:** Install on device
```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C <path-to-app>
```

**Step 3:** Visual QA on device — check every tab, every game, every screen for:
- Any remaining glassmorphism/material
- Any remaining colored shadows
- Any .rounded fonts
- Any corner radius > 12 (except iOS system components)
- Accent color consistency (should all be #00D4FF)
- Button text should be black on cyan

---

## Execution Notes

- **DesignSystem.swift is the linchpin** — Tasks 1-3 cascade changes to ~70% of the app automatically through the modifier system
- **Tasks 4-11 handle the remaining ~30%** — hardcoded styles that bypass the design system
- **Logo/app icon is separate** — needs to be designed externally and dropped in, not part of this code plan
- **Total estimated scope:** ~45 files, but most changes are mechanical find-and-replace patterns
