# Plan Reveal Rev 4 — Handoff (2026-04-29)

Self-contained handoff for picking up the plan-reveal page redesign in a fresh session. Read top-to-bottom.

## Goal in one sentence

Reframe the plan-reveal page from "Memo halves your wasted time (still 3 years lost)" to "Memo reclaims 4 years 132 days — backed by behavioral science — want the last bit too?"

## Status

**Math helpers added. UI not yet rewired.** Project compiles. No user-facing changes shipped this session.

## What's locked (DO NOT re-litigate)

- **Direction:** "The Siege" — drift / pulse / recoil / slash / depth-banded backdrop. All carry forward from rev 2 + rev 3.
- **Reduction math:** 50% → **75%** Memo reduction. `memoReductionFraction = 0.75`. Single source of truth.
- **Stakes layout (clean):** headline + big number + HOURS caption + breakdown subtitle ("5 YEARS · 292 DAYS") that climbs in lockstep. **NO bar on stakes.** NO brand-voice line on stakes.
- **Plan beat layout (redesigned):** drop compactProjectionHeader, add RECLAIMED hero (saved years/days) + 2-color life bar (75% blue / 25% coral residual) + plan card + HOW IT WORKS explainer + residual footnote + "want it all back?" question + CTA.
- **Backdrop opacity tuning:** stakes max 0.55 → **0.40**. Plan max 0.45 → **0.08**.
- **Count-up:** 168 × 24ms (4.0s) → **209 × 24ms (5.016s)**.
- **HOW IT WORKS copy** (between plan card and residual footnote, 3 short lines):
  > Backed by behavioral science:
  > friction beats willpower. Memo bounces
  > 3 of 4 app opens — every unlock costs
  > 5 min of training.
- **Brand voice on plan beat:** `"want it all back?"` (italic, replaces "you good with that?")
- **Comparison page math:** `hrs / 2` → `hrs * 0.75` to stay aligned with the 75% claim. Line ~1823 in `OnboardingNewScreens.swift`.

## What's already done in code (across rev 2/3 + this session)

| Piece | Location | Status |
|---|---|---|
| `AppColors.coralDeep` token | `Utilities/DesignSystem.swift` | ✅ |
| `Color.interpolated(with:by:)` extension | `Utilities/DesignSystem.swift` | ✅ |
| coral → coralDeep number color blend | cinematicProjectionHero | ✅ |
| Slash capsule overlay (sweep + fade) | cinematicProjectionHero | ✅ |
| 11×7 logo grid + LinearCongruentialRNG permutation | `PlanRevealBackdrop` | ✅ |
| 12 brand logos (6 PNG + 6 SVG) | `Assets.xcassets/logo-*.imageset/` | ✅ |
| TimelineView drift + smooth-wave pulse + recoil | `PlanRevealBackdrop` | ✅ |
| `coralDeep` color | DesignSystem | ✅ |
| Haptics: light tick (every 24 steps) + medium on slash + soft success on first plan row | startRevealAnimation, countProjection, revealPlanRows | ✅ |
| `LifeBar` private view (single-color version) | OnboardingNewScreens.swift | ✅ (needs 2-color rewrite — see TODO) |
| Plan card title 22pt black + "Engineered to outlast the algorithm." subtitle + sequential row glow | planCard, revealPlanRows | ✅ |
| `memoReductionFraction = 0.75` static | OnboardingPersonalSolutionView | ✅ (this session) |
| `savedHoursTotal`, `residualHoursTotal` helpers | OnboardingPersonalSolutionView | ✅ (this session) |
| `savedBreakdownText`, `residualBreakdownText` helpers | OnboardingPersonalSolutionView | ✅ (this session) |

## What's remaining (DO THIS, IN ORDER)

### 1. Wire the new math through the cut animation

In `startRevealAnimation`, the cut block currently sets:
```swift
animatedReclaimedHours = targetProjectionHours / 2
```
Change to:
```swift
animatedReclaimedHours = savedHoursTotal
```

`reclaimedHoursText` and `finalReclaimedHoursText` are already updated to derive from `savedHoursTotal`.

### 2. Redesign the LifeBar to be 2-color

Current `LifeBar(progress:width:height:)` is single-color (coral → coralDeep gradient, fill width = progress).

New API:
```swift
struct LifeBar: View {
    let savedFraction: CGFloat   // 0.75 default
    let progress: CGFloat        // 0 → 1 animated draw-in
    let width: CGFloat
    let height: CGFloat
}
```

Body: ZStack with HStack of 2 colored sections clipped to a rounded rect. Saved (blue gradient) on the leading edge, residual (coral muted, opacity ~0.55) on the trailing edge. Both widths multiplied by `progress` for the draw-in animation.

```swift
HStack(spacing: 0) {
    LinearGradient(colors: [AppColors.accent.opacity(0.85), AppColors.accent], ...)
        .frame(width: width * savedFraction * progress)
    AppColors.coral.opacity(0.55)
        .frame(width: width * (1 - savedFraction) * progress)
    Spacer(minLength: 0)
}
.frame(width: width, height: height)
.background(RoundedRectangle(cornerRadius: height/2).fill(Color.white.opacity(0.10)))
.clipShape(RoundedRectangle(cornerRadius: height/2))
```

### 3. Simplify the stakes layout

In `cinematicProjectionHero`, the `else` (stakes) branch currently has bar + markers + breakdown + brand-voice lines. **Remove all of it except the breakdown subtitle text.** Keep:
- Headline ("You're giving social media giants")
- Big number (animatedHoursText)
- HOURS caption (small, mono, white@40%)
- Breakdown subtitle (lifeBreakdownText, climbs with count)

Drop:
- LifeBar (it moves to plan beat)
- TODAY / AGE 60 markers
- "of your life. you good with that?" lines (these move to plan beat)

### 4. Reorganize the plan beat layout

In the body, the `if revealBeat == .plan` branch currently shows:
- compactProjectionHeader
- planCard
- solutionSummary text
- Spacer
- unlockPlanButton

Replace with:
```
[ "RECLAIMED" eyebrow ]
[ savedBreakdownText hero — 39pt heavy rounded, AppColors.accent ]
[ "back in your life." — 17pt semibold, white@70% ]

[ LifeBar(savedFraction: 0.75, progress: animated 0→1) ]
[ TODAY ............... AGE 60 ]

[ planCard (existing, with rev3 elevations) ]

[ "HOW IT WORKS" eyebrow ]
[ 3-line explainer (see locked copy above) ]

[ "still: \(residualBreakdownText) on the table." — small, white@50% ]
[ "want it all back?" — italic, 17pt heavy, white@70% ]

(safeAreaInset bottom: existing unlockPlanButton)
```

Add a new `@State var planBarProgress: CGFloat = 0` to drive the bar's draw-in animation. In `startRevealAnimation`, after `revealBeat = .plan`, animate `withAnimation(.easeOut(duration: 0.6)) { planBarProgress = 1 }`. Reset to 0 in the start-of-function reset block.

### 5. Update comparison page math

In `OnboardingComparisonView` (`OnboardingNewScreens.swift` line ~1823):
```swift
let halved = max(hrs / 2, 0.5)
```
Change to:
```swift
let saved = max(hrs * 0.75, 0.5)
```
And update the row text from `"\(formatHrs(halved)) back in play"` → `"\(formatHrs(saved)) back in play"`.

### 6. Bump count-up to 5.0s

In `countProjection`:
```swift
let steps = 168
```
Change to:
```swift
let steps = 209
```
Tick frequency check: `step % 24 == 0` already gives ~7 ticks across 209 steps. Good.

### 7. Backdrop opacity tuning

In `PlanRevealBackdrop.tile(...)`:
- The `baseOpacity` is currently `0.55 - normDist * 0.37` (range 0.55 → 0.18).
- Change peak: `0.40 - normDist * 0.27` (range 0.40 → 0.13). Stakes max drops to 0.40.
- The `planOpacityMul = isPlan ? 0.45 : 1.0` → change `0.45` to `0.20`. Plan max becomes ~0.40 × 0.20 = 0.08.

### 8. Build + install on device

```bash
cd /Users/dylanmiller/Desktop/mindrestore && \
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head && \
xcrun devicectl device install app --device 00008130-000A214E11E2001C \
  build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

### 9. Verify on device

Reset onboarding via the Profile debug toggle. Step to plan reveal. Confirm:
- Stakes: clean — number breathes, just headline + number + HOURS + breakdown subtitle
- Cut: slash + recoil reads cleanly without bar competing
- Plan beat: RECLAIMED hero is the focal point. Bar is 2-color (blue 75% / coral 25%). Explainer is readable. Brand-voice question lands as the punch.
- Comparison page (next page): the "X hrs leaks → Y hrs back in play" rows match the 75% claim.

## Files modified across all revs

- `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — primary
- `MindRestore/Utilities/DesignSystem.swift` — `coralDeep` + `Color.interpolated`
- `MindRestore/Assets.xcassets/logo-{bluesky,discord,facebook,pinterest,threads,twitch}.imageset/` — 6 SVG logo additions

## Project rules to remember

- **Always `xcodebuild` CLI**, never Xcode MCP (per CLAUDE.md + feedback memory — MCP hangs 10+ min)
- **SourceKit `Cannot find X in scope` errors are FALSE POSITIVES** — only trust xcodebuild output
- **Device:** `00008130-000A214E11E2001C`
- **Use AppColors constants**, never raw `Color(red:)` (project rule)
- **No GSD commands** (per `feedback_no_gsd.md`)
- **UI iteration: one change → build → show user → iterate.** Don't batch large visual changes without user check-ins (per `feedback_ui_iteration_not_batch.md`)

## Spec history

- `2026-04-28-plan-reveal-siege-design.md` — original Siege spec (rev 2 in conversation)
- `2026-04-29-plan-reveal-siege-rev3-design.md` — rev 3 with life bar + 4s count + 11×7 grid
- **This file (rev 4 handoff)** — captures the 75% reframe + plan beat redesign deltas

The rev 3 spec is mostly still valid. The rev 4 deltas overlaid on top:
- 50% → 75% reduction
- Stakes layout: drop bar (it moves to plan beat)
- Plan beat: full redesign with RECLAIMED hero + 2-color bar + explainer + new question copy
- Comparison page math sync
- Count-up bump 4.0s → 5.0s
- Backdrop opacity drops (0.40 stakes / 0.08 plan)

## How a fresh session should start

1. Read this handoff in full
2. Read `2026-04-29-plan-reveal-siege-rev3-design.md` for context on rev 3 mechanics
3. Skim recent commits: `git log --oneline -20`
4. `git diff HEAD~1 -- MindRestore/Views/Onboarding/OnboardingNewScreens.swift` to see the helper additions from this session
5. Begin "What's remaining" step 1
