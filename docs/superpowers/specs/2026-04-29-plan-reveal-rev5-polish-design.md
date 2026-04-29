# Plan Reveal Rev 5 — Polish Spec (2026-04-29)

Self-contained polish spec, layered on top of the rev 5 design at `docs/superpowers/specs/2026-04-29-plan-reveal-rev5-design.md` and the implementation at HEAD (`392b31a`). Addresses three on-device issues surfaced after rev 5 Phase 5.

## Why this exists

Rev 5 Phases 1–5 shipped the two-beat split + tactical plan card. On-device review surfaced layout fluff and one content drift:

1. **Stakes hero number is bottom-stuck.** A flexible `Spacer(minLength: 30)` between the headline and the count-up number expands to fill all available space, slamming the number against the lower edge. The headline reads as orphaned; the number reads as crammed.
2. **Beat 1 has an empty upper half AND a disconnect between the breakdown number and its subtitle.** Same `Spacer(minLength: 4)` pattern + a residual `.frame(height: 122)` on the heroNumber view (sized for the 92pt stakes number, oversized for the 39pt breakdown text) leaves ~80pt of dead space above the subtitle. The subtitle reads as a separate thought instead of labeling the number above it.
3. **Beat 2 has multiple drift items:** the CTA copy ("Show what changes →") describes the next page (the comparison view) instead of committing to the plan; the top padding leaves too much vertical fluff above the eyebrow; and the Earn row hard-codes "15 min" when that value is user-configurable.

## Goal in one sentence

Tighten stakes + Beat 1 vertical layout so the hero number sits where the eye lands, retitle Beat 2's CTA into a commitment line, and stop misrepresenting user-configurable values.

## What's locked

| # | Decision | Source |
|---|---|---|
| 1 | **Stakes hero positioning:** centered hero pattern. Pill + eyebrow + headline anchored at top; the big animated number + HOURS caption + breakdown subtitle vertically centered in the remaining space. The expanding Spacer between headline and number is removed; vertical centering is achieved via parent layout. | Q1 = B |
| 2 | **Beat 1 hero density:** centered, denser stack. RECLAIMED eyebrow + breakdown number + "hours back in your life" subtitle render as a tight 3-line block (4–6pt internal spacing) vertically centered above the bar/punch/CTA. The `heroNumber` view drops the fixed 122pt frame; height is intrinsic to the rendered text in each format. | Q2 = Y |
| 3a | **Beat 2 CTA copy:** `Take my brain back →` (replaces `Show what changes →`). Mirrors the bridge line above ("Take your brain back."), so the CTA is the user saying yes to the bridge. Existing `unlockPlanButton` still renders the button; only the title and arrow string change. | Q3a = A |
| 3b | **Beat 2 top padding:** `padding(.top, 12)` (replaces `padding(.top, 28)`). Eyebrow lands ~71pt from the top of the screen on iPhone Pro models — tight but not crammed against the status bar. | Q3b = A |
| 3c | **Beat 2 Earn row value:** `"your call"` (replaces hardcoded `"15 min"`). Mirrors `"pick yours"` on the Block row — two configurable rows now share visual symmetry. The unlock-minutes setting is user-configurable in Memo's settings; rendering a fixed value misrepresents. The placeholder is brand-voiced ("your call" = gen-z, agency-forward) and avoids plumbing a settings value through onboarding state. | Q3c = A |

## What carries forward (DO NOT re-litigate)

Everything from rev 5 design + implementation that isn't called out above. In particular:
- Two-beat sequence after the cut.
- `RevealBeat` enum (`.stakes`, `.reclaim`, `.plan`).
- Tactical color-coded plan card (violet/accent/coral/amber, Train → Earn → Block → Compete order).
- Cut-moment mechanics (slash, recoil, eyebrow flip, heroFormat hours→breakdown swap at +700ms post-snap).
- `advanceToPlan()` Beat 1 → Beat 2 transition.
- `PlanRevealBackdrop`'s `isDefeated` parameter.
- Screen Time provenance pill on stakes.
- Brain-trainer hero + bridge on Beat 2 (only the CTA copy changes; hero, subhead, and bridge stay).
- 75% reduction math, 5s count-up pacing, comparison page contents.

## Layout deltas

### Stakes (`revealBeat == .stakes`) — center the number

Current rev 5 flow:
```
[pill]
WITHOUT MEMO
You're giving social
media giants
                          ← Spacer(minLength: 30) expands here
[46,650] HOURS
5 YEARS · 118 DAYS
```
Polish flow:
```
[pill]
WITHOUT MEMO
You're giving social
media giants
                          ← intentional centering space (no expanding Spacer)
[46,650]                  ← centered vertically in remaining space
HOURS
5 YEARS · 118 DAYS
                          ← apps grid backdrop continues below
```

Implementation strategy: the stakes content above the centered number stays in the top of `cinematicProjectionHero`. The number + caption block becomes its own subview that the parent stakes container vertically centers using a `VStack { topGroup; Spacer(); centeredGroup; Spacer() }` pattern (or similar). The previous `Spacer(minLength: 30)` is removed.

The count-up animation timing is unchanged (209 steps × 24ms ≈ 5s). Only the visual position changes.

### Beat 1 (`revealBeat == .reclaim`) — tight hero block, centered

Current rev 5 flow:
```
RECLAIMED
                          ← Spacer(minLength: 4) expands
                          ← + heroNumber.frame(height: 122) padding
4 YEARS · 133 DAYS        ← lands far below eyebrow
                          ← VStack spacing 16
hours back in your life
                          ← VStack spacing 26
[life bar][TODAY  AGE 60]
[corporate punch]
[CTA pinned]
```
Polish flow:
```
                          ← top half (above hero block) is breathing room
RECLAIMED
4 YEARS · 133 DAYS        ← directly under eyebrow, ~4pt gap
hours back in your life   ← directly under number, ~6pt gap
                          ← deliberate vertical centering of the 3-line block
[life bar][TODAY  AGE 60]
[corporate punch]
[CTA pinned]
```

Implementation strategy:

1. The `cinematicProjectionHero` body splits into two render paths via the `isReclaim` branch. The reclaim path is a tight `VStack(spacing: 4)` of eyebrow + breakdown text + subtitle, rendered without the slash overlay (slash applies only during stakes/cut).
2. The `heroNumber(numberAccent:)` helper drops the unconditional `.frame(height: 122)`. For the hours form (stakes + cut moment), height stays 122pt to give the slash overlay room. For the breakdown form, height is `nil` (intrinsic).
3. The parent body's `.reclaim` branch becomes a vertically centered layout: top spacer, hero block, bottom spacer (then bar + corporate punch above the safeAreaInset CTA). On the hero side, this is achieved by replacing `VStack(alignment: .leading, spacing: 26) { hero; beat1Extras; Spacer() }` with a structure that places the hero as a centered element above `beat1Extras`.

### Beat 2 (`revealBeat == .plan`) — three coordinated content fixes

| Element | Before (rev 5) | After (polish) |
|---|---|---|
| Top padding | `padding(.top, 28)` | `padding(.top, 12)` |
| CTA title | `unlockPlanButton` renders "Show what changes →" | `unlockPlanButton` renders "Take my brain back →" |
| Earn row value | `"15 min"` (hardcoded) | `"your call"` |

The `unlockPlanButton` view's title string is changed in the existing view (no view-shape change). The Earn row's `value:` parameter in the `planCardRow` call changes from `"15 min"` to `"your call"`.

Beat 2's other content (eyebrow, hero, subhead, plan card, bridge, gradient bottom fade) is unchanged.

## Files affected

| File | Change |
|---|---|
| `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` | Single primary file. Edits to `cinematicProjectionHero` (split branches, drop expanding Spacer, restructure for vertical centering), `heroNumber(numberAccent:)` (conditional frame height), `body` (centering wrapper for `.stakes` and `.reclaim` branches, padding(.top, 12) on `planBeatLayout`), `unlockPlanButton` (title string), `planCard` (Earn row value `"15 min"` → `"your call"`). |

No `.xcodeproj` edits, no new assets, no new SPM packages, no design-system token changes.

## Out of scope

- Comparison page (`OnboardingComparisonView`) — the next page after Beat 2. Already coherent: "Take my brain back →" → comparison page header "Same phone. / Different rules." → "Why Memo wins" CTA flows naturally; no changes needed.
- Dynamic earn-time setting plumbing. The "your call" placeholder defers this; if/when the unlock-minutes setting is exposed, the Earn row can swap to read the actual value, but the placeholder doesn't block that future change.
- Comparison page "back in play" math — already aligned with `memoReductionFraction = 0.75` from rev 4.
- Any rev 5 mechanics not explicitly modified above.

## Verification (per-phase, on-device)

The implementation plan should split the polish into phases that each end with a build + install + visual check on device:

1. **Beat 2 content fixes (lowest risk).** CTA copy + Earn row value + top padding. No layout restructuring.
2. **Stakes centering.** `cinematicProjectionHero` stakes branch + body's `.stakes` wrapper.
3. **Beat 1 hero density.** `cinematicProjectionHero` reclaim branch + heroNumber conditional frame + body's `.reclaim` wrapper.

This ordering surfaces the easiest wins first and keeps each visible diff small.

For each phase, verify on iPhone 16 Pro (dev device). The Beat 1 + Beat 2 fixes carry inherent small-device risk; if device-side checks pass, optionally rerun on iPhone SE 3rd gen + iPhone 13 mini simulators (already created during rev 5 Phase 5).

## Project rules (carry forward)

- `xcodebuild` CLI for compile + install. NEVER `mcp__xcode__BuildProject` (10+ min hang per `feedback_use_xcodebuild_cli.md`).
- Device target: `00008130-000A214E11E2001C`.
- `AppColors` constants only — never raw `Color(red:)`.
- SourceKit "Cannot find X in scope" diagnostics are FALSE POSITIVES.
- Touch only `MindRestore/Views/Onboarding/OnboardingNewScreens.swift`. The repo has uncommitted edits in unrelated files; leave them alone.

## Spec history

- `2026-04-29-plan-reveal-rev5-design.md` — rev 5 base design (two-beat split, tactical plan card, cut-moment fix).
- **This file (rev 5 polish)** — three on-device issues addressed: stakes centering, Beat 1 density, Beat 2 content drift.
