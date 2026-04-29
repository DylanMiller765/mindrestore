# Plan Reveal — "The Siege" Rev 3 Design Spec (2026-04-29)

## Goal

Make the plan reveal page actually land. The previous round (rev 2) added drift/pulse/recoil/slash but failed on three counts:

1. The number climbs too fast — 51,000 hours flashes by before the user reads it
2. The number is meaningless without context — "5.8 years" doesn't communicate "a chunk of your life"
3. The plan card after the climax feels weak — like a settings list after a movie scene

This rev adds a **life bar visualization**, a **years + days breakdown**, **slower pacing**, **denser/more-varied logo grid**, **brand-voice copy**, and **plan card elevation** in one cohesive pass.

Win condition: the user reads "you're giving social media giants 5 years and 292 days of your life — you good with that?" and feels a physical reaction. Then watches Memo cut the bar in half.

## Locked decisions (carrying forward from rev 2)

- Direction: **"The Siege"** — drift/pulse/recoil/slash all stay
- Single TimelineView drives all backdrop animation (no 35-state thrash)
- Slash is transitional, fades out (never permanent on final number)
- `AppColors.coralDeep` token (added in rev 2) — number color blends coral → coralDeep with count progress
- Haptics: light tick on count-step ramp, medium on slash, soft success on first plan row
- Plan card structure stays the same (no full redesign)

## New for rev 3

### 1. Layout (stakes beat)

```
┌──────────────────────────────────┐
│  YOUR PROJECTION                 │  ← eyebrow, mono, white@40%
│                                  │
│  You're giving social            │  ← headline, 28pt heavy rounded,
│  media giants                    │     white@90%
│                                  │
│  51,000                          │  ← number, JetBrains Mono, 96pt
│                                  │     coral → coralDeep blend
│  ┌──────────────────────┐        │  ← life bar
│  ████████████░░░░░░░░░░          │     280pt × 14pt
│  └──────────────────────┘        │
│  TODAY              AGE 60       │  ← bar markers, mono 10pt, white@40%
│                                  │
│  5 YEARS · 292 DAYS              │  ← breakdown, mono caps, 14pt accent
│  of your life.                   │  ← brand-voice line, 17pt rounded
│  you good with that?             │     italic-ish (use .italic), white@70%
│                                  │
└──────────────────────────────────┘
```

Backdrop: existing 11×7 logo grid (recoiling on cut), unchanged from rev 2 mechanics.

### 2. Pacing — slow + dramatic

| Phase | Duration | Behavior |
|---|---|---|
| Count climb | **4.0s** (168 steps × 24ms, was 2.5s) | Number, bar fill, years/days subtitle ALL animate in lockstep. Color deepens. Light haptic every 24 steps (~7 ticks). |
| Hold post-climb | 600ms (unchanged) | Color settles. Drift continues. |
| Cut sequence | **1.4s** (was 0.9s) | Slash sweeps 0.5s, halve cross-fade at 0.8s, slash fade 0.4s, all concurrent with apps recoiling on a 1.2s spring. |
| Hold post-halve | **1500ms** (was 1100ms) | mascot-unlocked enters, brand-blue glow settles. |
| Plan beat | 0.74s spring + plan rows | Plan rows reveal with sequential brand-blue accent pulse. |

**Total:** ~7.5s stakes → plan transition (was ~4.3s in rev 2). Slow on purpose — drama lives in the breathing room.

### 3. Life bar visualization

A horizontal bar representing the user's remaining life from current age → 60.

**Geometry:**
- Width: 280pt
- Height: 14pt
- Corner radius: 7pt
- Background track: `Color.white.opacity(0.10)`
- Fill gradient: `LinearGradient(colors: [AppColors.coral, AppColors.coralDeep], startPoint: .leading, endPoint: .trailing)`
- Fill width: `barWidth × countProgress` (climbs in lockstep with the number)
- Subtle inner shadow on fill for depth (`.shadow(color: .black.opacity(0.3), radius: 2, y: 1)`)

**Markers** (below bar):
- Left: "TODAY" — mono 10pt, white@40%
- Right: "AGE 60" — mono 10pt, white@40%

**At cut:**
- Bar fill width scales from `barWidth × 1.0` → `barWidth × 0.5` with the same 1.2s spring as the number halve
- Color transitions on the fill: gradient stays coral but **opacity drops to 0.65** to signal the reduction (not a separate "with Memo" bar — the existing bar visually halves)
- The slash capsule sweeps across the FULL number width but doesn't intersect the bar (separate visual layer)

### 4. Years + days math

```swift
let totalDays = projectedHours / 24                  // floor
let years = totalDays / 365                          // integer years
let remainingDays = totalDays - (years * 365)        // days remainder
// Format: "X YEARS · Y DAYS" — uppercase, mono, accent color
```

Note: ignores leap years for simplicity. 0.07% off, not visible at this scale.

Updates in lockstep with the count-up by deriving from `animatedProjectionHours` (not from a separate animated state).

### 5. Logo grid — denser + permuted

Two changes from rev 2:

**Density bump:** 7×5 (35 tiles) → **11×7 (77 tiles)**. Tile size shrinks 36pt → 28pt to fit.

**Deterministic permutation, not modulo:** Replace `logos[(row * cols + col) % logos.count]` with a deterministic shuffle. For each tile index `i`, look up `logos[shuffledIndices[i % shuffledIndices.count]]` where `shuffledIndices` is a one-time generated permutation of `0..<logos.count` repeated to fill 77 slots. Result: same logo can appear adjacent (intentional — feed wall feel), but no visible row/column patterns. Reads as varied even with only 6 unique logos.

**Implementation note:** if user adds new logos to assets later (Facebook / Pinterest / Threads / Twitch / BeReal / Discord), `feedTileLogos` array gets extended. No other code changes needed.

### 6. Copy

| Slot | Content | Style |
|---|---|---|
| Eyebrow | "YOUR PROJECTION" (existing) | mono, 11pt heavy, white@40% |
| Headline (stakes) | "You're giving social media giants" | rounded, 28pt heavy, white@90% |
| Number | (animated `51,000`) | mono, 96pt black, coral→coralDeep |
| Bar | (visual, no text) | — |
| Markers | "TODAY" / "AGE 60" | mono, 10pt heavy, white@40% |
| Breakdown | "5 YEARS · 292 DAYS" | mono caps, 14pt heavy, AppColors.coral |
| Brand-voice 1 | "of your life." | rounded, 17pt semibold, white@70% |
| Brand-voice 2 | "you good with that?" | rounded, 17pt heavy italic, white@70% |
| Headline (with Memo) | "Memo cuts the damage in half." (existing) | rounded, 28pt heavy, white@90% |
| Subtitle (with Memo) | "Memo turns scrolling into reps: train first, unlock after." (existing) | rounded, 17pt semibold, white@65% |

The "you good with that?" line is the punch. **Italic feel** for that line specifically — separates it from the matter-of-fact "of your life." line above it. Read as: matter-of-fact statement, then a confrontational question.

**Headline animates out** when transitioning to .withMemo — fade out + 8pt offset, then "Memo cuts the damage in half." fades in.

### 7. Plan card elevation (minimal)

Three small touches so the climax doesn't deflate:

1. **Bigger title:** "Memo's plan" header bumps from 17pt heavy → **22pt black**. Heavier visual weight after the cinematic moment.
2. **Subtitle line:** under the header, add **"Engineered to outlast the algorithm."** — brand voice carry-over. Mono, 11pt heavy, white@40%, tracking 1.2.
3. **Sequential row glow:** when plan rows reveal, each "01" / "02" / "03" / "04" leading number gets a brief brand-blue **glow pulse** as it appears (radial blur ~6pt, 250ms). Makes the rows feel "unsealed" rather than "printed."

Bigger plan card redesign stays out of scope. Separate spec when ready.

### 8. Implementation scope

Confined to:
- `MindRestore/Views/Onboarding/OnboardingNewScreens.swift`
  - `OnboardingPersonalSolutionView` — copy changes, life bar, years/days, pacing, plan card touches
  - `PlanRevealBackdrop` — density bump (11×7), tile size shrink, permutation logic
- `MindRestore/Utilities/DesignSystem.swift` — no new tokens (`coralDeep` already added in rev 2)

New private helpers in OnboardingPersonalSolutionView:
- `lifeBarFillProgress: CGFloat` — derived from `countProgress` × pre-cut multiplier or post-cut 0.5
- `yearsRemaining: Int`, `daysRemaining: Int` — computed from `animatedProjectionHours`
- `LifeBar` private view — encapsulates the bar + markers
- `permutedLogoIndex(for tileIndex: Int) -> Int` — deterministic shuffle helper on PlanRevealBackdrop

## Out of scope

- Adding new logo assets (Facebook, Pinterest, Threads, etc.) — flagged as non-blocking follow-up
- Sound design / audio
- Mascot animation choreography changes
- Plan card cards-as-stack redesign
- compactProjectionHeader (post-cut compact display) restyle
- Audio/music

## Decisions locked (rev 3)

- Direction 1 ("The Siege"), all rev 2 mechanics + new rev 3 layer
- 11×7 grid (77 tiles), 28pt nominal size, deterministic permutation across 6 logos
- Life bar: 280pt × 14pt, white@10% track, coral→coralDeep gradient fill, halves to 50% on cut with 1.2s spring
- Years + days math from `animatedProjectionHours` (no leap-year correction)
- Headline: "You're giving social media giants" → "Memo cuts the damage in half." on transition
- Brand-voice line: "of your life." (matter-of-fact) + "you good with that?" (italic, confrontational)
- Pacing: 4.0s count, 600ms hold, 1.4s cut, 1500ms hold, plan reveal — total ~7.5s
- Plan card: title 22pt black, subtitle "Engineered to outlast the algorithm.", sequential row glow pulse
- All animation logic in `OnboardingPersonalSolutionView` + extended `PlanRevealBackdrop` private struct
- No new global tokens, no new asset additions in this work
