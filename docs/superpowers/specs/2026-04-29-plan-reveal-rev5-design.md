# Plan Reveal Rev 5 — Design Spec (2026-04-29)

Self-contained design spec for the rev 5 redesign of the plan-reveal page (`OnboardingPersonalSolutionView`). Captures locked decisions from the rev 5 brainstorming session. The implementation plan lives in a sibling document.

## Why rev 5 exists

Rev 4 shipped a 75% reclaim reframe + new stakes/plan-beat layout. On-device review surfaced six problems:

1. The plan beat scrolled — content overflowed one screen.
2. The "Memo's plan" card itself looked unchanged from earlier revs (boring vertical list).
3. User asked whether the count-up number was actually their real Screen Time data (it is — but invisibly).
4. The cut moment was unreadable: when 51,000 → 38,000, the user couldn't tell whether 38k was what Memo *saved* or what was *left*.
5. The "HOW IT WORKS" copy was weak.
6. The plan beat lacked any anti-corporate framing — the brand's defining posture wasn't on the page that's supposed to deliver the kill shot before paywall.

Rev 5 splits the post-cut moment into **two beats** so each idea lands on its own canvas, redesigns the plan card visually, makes the cut moment unambiguous, and surfaces the corporate-attack framing the brand voice doc has been pushing for since v1.4.

## Goal in one sentence

Land the cut as a clear "you get 4Y 132D back," then dwell on "big tech is colonizing your attention" with the user, then reveal "brain training is how Memo gives it back" — without scrolling.

## What's locked

| # | Decision | Source |
|---|---|---|
| 1 | **Two-beat sequence** after the cut. Beat 1 = reclaim + corporate punch + CTA. Beat 2 = plan card + brand-voice bridge + CTA. | Q1 = B |
| 2 | **Plan card style:** tactical color-coded stack — each step is its own row card with a 3pt colored leading bar (coral/violet/blue/amber). No outer container box. | Q2 = 2 |
| 3 | **Cut moment fix:** keep the single big number, but flip the eyebrow from "With Memo" to **RECLAIMED** with subtitle "hours back in your life" the moment the slash hits. | Q3 = A |
| 4 | **Beat 1 corporate punch:** *"Big tech is colonizing your attention."* / *"Memo fights back."* (italic, accent color on the second line). | Q4 = B |
| 5 | **Beat 2 hero:** "Brain training that pays you in time." Plan rows reorder to **Train → Earn → Block → Compete**. Bridge: "Take your brain back. Big tech won't give it back voluntarily." No 25% number on this beat. | Q5 = X |
| 6 | **Beat 1 → Beat 2 transition:** user-tap CTA "See the plan →". No auto-advance. | Q6 = A |
| 7 | **Screen Time data trust:** small pill on the stakes count-up — `from your Screen Time` (measured) or `estimated from your input` (fallback) — driven by existing `projectionIsEstimate`. | Q7 = A |

## What carries forward from rev 4 (DO NOT re-litigate)

- **Direction:** "The Siege" backdrop — drift / pulse / recoil / depth-banded apps. Carries through all three states.
- **Reduction math:** 75% via `memoReductionFraction = 0.75` static. Single source of truth across this view AND the comparison page.
- **Stakes layout:** clean — headline + animated number + HOURS caption + climbing breakdown subtitle. No bar on stakes (bar lives on Beat 1).
- **Count-up pacing:** 209 × 24ms (≈5.0s) easing-out. Light haptic tick every 24 steps (~7 ticks).
- **Backdrop opacity tuning:** stakes peak 0.40, plan peak ~0.08 via `planOpacityMul = 0.20`.
- **Slash sweep + recoil mechanics:** drives the cut. Slash is brand-blue capsule scaling left-to-right, fading after sweep; tile recoil is the same outward push under `recoilProgress`.
- **2-color LifeBar:** blue 75% + coral 25% residual, draws in via `planBarProgress`. Lives on Beat 1, not stakes.
- **Comparison page math:** `hrs * 0.75` ("back in play" row) — already shipped.

## State model

The view's `revealBeat` enum gets one new case and one rename:

```swift
private enum RevealBeat {
    case stakes    // count-up of projected hours
    case reclaim   // Beat 1: post-cut hero + corporate punch + CTA  (was .withMemo)
    case plan      // Beat 2: plan card + bridge + CTA
}
```

The cut animation transitions `.stakes → .reclaim`. The Beat 1 CTA transitions `.reclaim → .plan`. The Beat 2 CTA fires `onContinue()` to advance the funnel into the existing comparison page.

## Beat-by-beat layout

### Stakes (revealBeat == .stakes) — unchanged from rev 4 plus Screen Time pill

```
┌─────────────────────────────────────┐
│  [from your Screen Time] ← NEW pill │  ← tertiary text, 9pt mono, dot prefix
│                                     │
│  WITHOUT MEMO            (eyebrow)  │
│  You're giving social               │
│  media giants                       │
│                                     │
│  51,000   (animated count-up,      │  ← coral → coralDeep blend
│           coral, 92pt)              │     w/ slash overlay during cut
│                                     │
│  HOURS                              │
│  4 YEARS · 292 DAYS                 │  ← climbs in lockstep
└─────────────────────────────────────┘
```

The pill text:
- `projectionIsEstimate == false` → `● from your Screen Time`
- `projectionIsEstimate == true`  → `● estimated from your input`

Style: 9pt mono, tracking 0.8, white@40%, leading dot is `AppColors.accent`. Sits above the eyebrow with 8pt vertical gap.

### Cut moment (the .stakes → .reclaim transition)

The cut animation is the same choreography as rev 4 — slash sweep, tile recoil, number snap to `savedHoursTotal`. The new piece is **the eyebrow + subtitle change happens in the same beat as the number flip**, so when the user reads 38,000 there is already a "RECLAIMED" label and "hours back in your life" subtitle next to it.

`recoilProgress` and `revealBeat` are **decoupled** in rev 5 (rev 4 fired both in the same withAnimation block at slash-start). Recoil rides the slash; the layout-state change rides the number snap. This keeps the apps recoiling immediately — visual cause-and-effect of the slash — while the hero swap waits for the new number to land.

Sequence (relative t, slash-start = 0):

| t | Event |
|---|---|
| 0.00s | Slash sweep starts (0.5s easeOut). `recoilProgress` springs to 1.0 in its own withAnimation block. `revealBeat` still `.stakes`. |
| 0.80s | Number snaps to `savedHoursTotal` AND `revealBeat = .reclaim` in the same withAnimation block (0.5s spring). The hero block re-renders against the new state: eyebrow text crossfades coral "WITHOUT MEMO" → accent "RECLAIMED"; subtitle "hours back in your life" fades in below the number; the rev 4 stakes headline ("You're giving social media giants") fades out. |
| 1.10s | Slash capsule fades out (0.4s easeIn). |
| 1.10s | Beat 1's life bar + corporate punch + CTA enter. Implementation uses SwiftUI `.transition(.opacity.combined(with: .move(edge: .bottom)))` per element so the layout-state change drives the entrance — no extra reveal-progress state variable needed. Stagger via 100ms `.delay()` per element so they come in sequentially, not as a wall. |

What rev 4's `.withMemo` state did that rev 5 explicitly drops:
- The headline rewrite ("Memo cuts the damage in half.") — gone. Beat 1's headline IS the RECLAIMED hero.
- The ghost projected-number stack above the new number — gone.
- The `mascot-unlocked` placement below the number — gone (corporate punch is the emotional anchor on Beat 1, not the brain).
- The "Memo turns scrolling into reps" subtitle — gone.

### Beat 1 (revealBeat == .reclaim)

```
┌─────────────────────────────────────┐
│                                     │
│  RECLAIMED                          │  ← accent eyebrow, 11pt mono heavy
│  4 YR · 132 D     (savedBreakdown)  │  ← accent, 39pt heavy rounded
│  back in your life.                 │  ← white@70%, 17pt semibold
│                                     │
│  ▰▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱   ← 2-color bar │
│  TODAY              AGE 60          │  ← white@40%, 10pt mono
│                                     │
│  Big tech is colonizing             │  ← white@94%, 22pt heavy rounded
│  your attention.                    │
│  Memo fights back.                  │  ← accent, italic, 22pt heavy
│                                     │
│  [ See the plan → ]   (CTA, accent) │
└─────────────────────────────────────┘
```

The hero block (RECLAIMED + breakdown + "back in your life") is the same content the cut animation reveals — Beat 1 is just the surrounding frame for that hero. The bar + corporate punch + CTA are the new elements that fade in on the dwell.

The corporate punch sits in the visual middle of the screen, not bottom — it's the message, not a footer. CTA pins to the bottom via `safeAreaInset(edge: .bottom)`.

The mascot from rev 4 (`mascot-unlocked`) is **dropped from Beat 1**. The corporate-attack moment doesn't want a celebratory brain. If a mascot belongs anywhere, it belongs on Beat 2 (see below).

### Beat 2 (revealBeat == .plan)

```
┌─────────────────────────────────────┐
│  MEMO'S PLAYBOOK   (eyebrow, mono)  │  ← white@40%, 11pt
│  Brain training                     │  ← white@94%, 26pt heavy rounded
│  that pays you in time.             │  ← accent, 26pt heavy rounded
│                                     │
│  Beat a brain game. Earn back       │  ← white@55%, 13pt
│  screen time. The only blocker      │
│  that trains your brain while       │
│  it locks the noise.                │
│                                     │
│  ┌────────────────────────────────┐ │
│  ▍ Train       brain games · 5min  │ │  ← violet leading bar (3pt)
│  └────────────────────────────────┘ │     violet@10% bg fill
│  ┌────────────────────────────────┐ │
│  ▍ Earn        15 min unlocked/win │ │  ← accent leading bar
│  └────────────────────────────────┘ │
│  ┌────────────────────────────────┐ │
│  ▍ Block       apps stay shielded  │ │  ← coral leading bar
│  └────────────────────────────────┘ │
│  ┌────────────────────────────────┐ │
│  ▍ Compete     leaderboards · live │ │  ← amber leading bar
│  └────────────────────────────────┘ │
│                                     │
│  Take your brain back.              │  ← white@94%, 17pt heavy
│  Big tech won't give it back        │  ← white@55%, 13pt semibold
│  voluntarily.                       │
│                                     │
│  [ Show what changes → ]    (CTA)   │
└─────────────────────────────────────┘
```

**Plan card row spec** (replaces existing `planCard` + `planCardRow`):

| Element | Spec |
|---|---|
| Container | `RoundedRectangle(cornerRadius: 14)` filled with `<rowColor>.opacity(0.10)`. No outer card box wrapping all four. |
| Leading bar | 3pt-wide colored bar, full row height, `<rowColor>` solid. Inset 0pt from row's leading edge. |
| Label | 13pt heavy rounded, `AppColors.textPrimary`. |
| Detail | 10pt semibold rounded, `AppColors.textPrimary.opacity(0.55)`. |
| Value | 11pt heavy monospaced, `<rowColor>`. Aligned to trailing edge. |
| Row gap | 7pt between rows. |
| Row vertical padding | 11pt top/bottom. |

**Row palette** (uses existing `AppColors`):

| # | Row | Color | Token |
|---|---|---|---|
| 01 | Train | Violet | `AppColors.violet` |
| 02 | Earn | Accent (brand blue) | `AppColors.accent` |
| 03 | Block | Coral | `AppColors.coral` |
| 04 | Compete | Amber | `AppColors.amber` |

**Row copy** (verbatim):

| # | Label | Detail | Value |
|---|---|---|---|
| 01 | Train | brain games · 5 min a day | `5 min/day` |
| 02 | Earn | 15 min unlocked per win | `15 min` |
| 03 | Block | apps stay shielded until you train | `pick yours` |
| 04 | Compete | leaderboards · live now | `live` |

The order matters: Train → Earn → Block → Compete tells the brand's story (training is the mechanism; blocking is enforcement; competing is the long game). Reversing this would re-frame Memo as a blocker that happens to have games, which is the inversion of the USP.

**Rev 4's "HOW IT WORKS" block is removed.** The plan rows self-explain; the "trains your brain while it locks the noise" subhead carries the defensibility claim.

**Reveal animation:** rows fade + slide-up sequentially as `revealBeat` enters `.plan` (existing `cardsAppeared` array works — 4 rows, 86ms stagger). Soft success haptic on first row.

## Cut-moment text crossfade — implementation note

The eyebrow + subtitle changes need to land *as the slash hits*, not after. SwiftUI `.contentTransition(.opacity)` on the eyebrow Text — driven by `revealBeat` — gives a clean cross-fade. Same for the subtitle (which just appears, doesn't change content).

In code: hoist the eyebrow and subtitle out of the existing `if withMemo` branch into a single block whose content is computed from `revealBeat`. When `revealBeat` flips to `.reclaim` inside the same `withAnimation` block as the number snap, the cross-fade rides the same spring. No new state needed.

## Backdrop behavior

| State | Effect |
|---|---|
| `.stakes` | Full drift + pulse + saturated tiles. Peak opacity 0.40. |
| `.reclaim` | Recoiled, dim, drift muted. `recoilProgress = 1.0`. Same opacity multiplier as `.plan` was rev-4 (planOpacityMul ≈ 0.20). |
| `.plan` | Same as `.reclaim`. The grid is defeated; doesn't change between beats. |

Effectively `recoilProgress` and the `planOpacityMul` get triggered by `(revealBeat != .stakes)` instead of `isPlan`, so both Beats 1 and 2 share the dim/recoiled backdrop. Rev 4's `isPlan` path becomes `isStakes` inverted.

## CTA copy

| Beat | CTA | Action |
|---|---|---|
| Beat 1 | `See the plan →` | `revealBeat = .plan`, animate plan-bar draw-in, reveal rows |
| Beat 2 | `Show what changes →` | `onContinue()` (existing) — advances funnel to comparison page |

Beat 2 keeps the existing copy because the next page IS the comparison page ("X hrs leaks → Y hrs back in play"), and "Show what changes" is the literal contract. Renaming it would require renaming the comparison page's premise too.

## Animation choreography (full sequence, absolute t from page enter)

```
t=0.00s  Page enters. Pill + headline fade in (rev 4's existing 0.36s easeOut).
t=0.40s  countProjection() starts. 209 steps × 24ms.
t=5.42s  countProjection() ends. countProgress=1, full coralDeep.
t=6.02s  600ms hold ends. Medium impact haptic.
         Slash sweeps (0.5s easeOut). recoilProgress springs to 1.0 (1.2s spring).
t=6.82s  Number snap (0.5s spring) AND revealBeat = .reclaim in same block.
         Hero re-renders: eyebrow "WITHOUT MEMO"→"RECLAIMED" cross-fade,
                          color coral→accent,
                          subtitle "hours back in your life" fades in,
                          stakes headline fades out.
t=7.32s  Slash fades out (0.4s easeIn).
t=7.32s  Beat 1 elements enter via SwiftUI transitions (triggered by .reclaim):
           +0ms     life bar (planBarProgress 0→1, 0.6s easeOut)
           +100ms   corporate punch (opacity + slide-up, 0.5s spring)
           +200ms   CTA (opacity, 0.5s)
t=8.02s  Beat 1 fully revealed. User dwell.
t=∞     User taps "See the plan →".
         revealBeat = .plan via 0.74s spring.
         Plan rows reveal sequentially (4 × 86ms stagger via cardsAppeared).
         Soft success haptic on row 01.
```

≈8s from page-enter to "user can tap." The count-up earns it — drama, payoff, message — and Beat 1 dwells deliberately so the corporate punch lands instead of getting auto-advanced past.

## Files affected

| File | Change |
|---|---|
| `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` | Primary. Adds `.reclaim` state, splits plan-beat layout, redesigns plan card, adds Screen Time pill, hoists eyebrow/subtitle out of cut moment. |
| `MindRestore/Utilities/DesignSystem.swift` | No new tokens needed (`coral`, `violet`, `accent`, `amber` all exist). |
| `MindRestore/Assets.xcassets/` | No new assets. |

No `.xcodeproj` changes (per CLAUDE.md). No new SPM packages.

## Out of scope

- Comparison page changes — already shipped in rev 4 with the 75% claim.
- Paywall changes — Beat 2 still flows into the existing comparison page → paywall sequence.
- Any onboarding pages outside `OnboardingPersonalSolutionView`.
- Animation speed tuning of count-up (already tuned in rev 4).
- The 25% residual stat — explicitly removed from this view's surface.
- Mascot inclusion on Beat 2. We can add `mascot-unlocked` or `mascot-thinking` if Beat 2 feels empty on device, but spec ships without one — the corporate antagonist is the emotional anchor, not the mascot.

## Project rules (carry forward)

- Always `xcodebuild` CLI. Never Xcode MCP `BuildProject` (hangs 10+ min).
- SourceKit "Cannot find X in scope" errors are false positives — only trust xcodebuild output.
- Use `AppColors` constants — never raw `Color(red:)`.
- Device target: `00008130-000A214E11E2001C`.
- Verify on-device after build via `xcrun devicectl device install app`.

## Spec history

- `2026-04-28-plan-reveal-siege-design.md` — original Siege spec (rev 2)
- `2026-04-29-plan-reveal-siege-rev3-design.md` — rev 3 (life bar, 4s count, 11×7 grid)
- `2026-04-29-plan-reveal-rev4-handoff.md` — rev 4 mid-implementation (75% reframe, layout v1)
- **This file (rev 5 design)** — two-beat split, tactical plan card, brand-voice corporate punch, brain-trainer USP

Rev 4's mechanics (slash, recoil, count-up timing, 75% math, life bar) all carry forward. Rev 5 is layered on top, not a rewrite.
