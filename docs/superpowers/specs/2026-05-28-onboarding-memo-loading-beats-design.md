# Onboarding Memo Loading Beats — Design Spec

**Date:** 2026-05-28
**Status:** Approved for planning
**Area:** `MindRestore/Views/Onboarding/`

## Summary

Replace the single pre-paywall personalization loader (`OnboardingPlanPersonalizingView`)
with a series of short, character-driven "building beats" distributed across onboarding.
After each data-collection milestone (goals → age → screen time), Memo appears, thinks
out loud in a speech bubble that reflects the answer just given, and snaps a new line
onto a persistent "YOUR PLAN" clipboard. The clipboard grows cumulatively across the
flow. A final beat right before the hard paywall flips Memo into a "presenting" pose,
holds up the now-complete clipboard, and opens the paywall pre-loaded with the same
personalized numbers.

The goal is conversion: the beats build investment (endowment / IKEA effect /
commitment-consistency / goal-gradient) and stage a problem-agitate-solve arc that peaks
loss aversion one beat before the offer.

## Goals

- Make the personalization feel like one cohesive thing that **grows throughout**
  onboarding, not three disconnected popups.
- Increase paywall conversion by building cumulative investment and peaking urgency
  immediately before the hard paywall.
- Keep each beat short and auto-advancing — no extra taps, minimal added friction.

## Non-Goals

- No change to the data we collect or the order of the existing collection screens
  (goals, age, screen time access, life-squares receipt).
- No change to the paywall's own layout beyond it continuing to receive the existing
  personalization inputs (age, screen-time hours, goal summary).
- Not introducing a new persistence model — beat state is derived from existing
  `@State` already held in `OnboardingView` (`selectedGoals`, `selectedAge`,
  `effectiveDailyScreenTimeHours`, `projectionIsEstimate`).

## Current State

`OnboardingView` (`MindRestore/Views/Onboarding/OnboardingView.swift`) drives a
9-page flow via an integer `currentPage` and a `pageContent` switch:

| Page | Screen |
|------|--------|
| 0 | welcome |
| 1 | goals |
| 2 | age |
| 3 | screenTimeAccess |
| 4 | lifeSquaresReceipt |
| 5 | memoPlan |
| 6 | planPersonalizing → fires `presentedCover = .paywall` |
| 7 | focusMode |
| 8 | notificationPriming |

The current `planPersonalizingPage` (page 6) renders `OnboardingPlanPersonalizingView`
(`OnboardingNewScreens.swift:3096`), which already does cumulative chip-lighting
(AGE / SCREEN TIME / GOAL / GAMES) behind a 0→100% bar, then calls `onComplete` →
paywall. This view is **removed** and its role is redistributed across the new beats.

## Design

### The building beat (reusable view)

A new view, `OnboardingPlanBuildBeat`, renders one beat. It is fully data-driven and
auto-advances:

- **Top label:** `MEMO IS BUILDING YOUR PLAN` (small mono, tracked).
- **Memo:** looping idle video (Runway-generated MP4, dark-matched background) played
  via the existing `LoopingVideoPlayer` (already in `OnboardingView.swift`). Two assets:
  a **thinking/working** loop (beats 1–3) and a **presenting** loop (final beat).
  If an asset is missing, fall back to a static Memo image so the screen never breaks
  (mirror the welcome bezel's "only animate if asset is bundled" pattern).
- **Speech bubble:** the beat's line, typed/faded in. Uses existing onboarding bubble
  styling conventions.
- **Clipboard ("YOUR PLAN"):** a card listing the line items earned **so far** (see
  cumulative rule below). The newest line animates in with a green tick after the
  bubble appears.
- **Auto-advance:** after the bubble + new line have settled (~2.5s total; honor
  `reduceMotion` by shortening to a fade), the beat advances to the next onboarding
  screen on its own. No CTA button.

### The four beats

| Beat | Fires after | Memo bubble | Clipboard line added |
|------|-------------|-------------|----------------------|
| 1 | goals (page 1) | "Hours back. That's the mission." | ✓ Goal: {goalSummary} |
| 2 | age (page 2) | "{age}? You've got ~{80 − age} years of phone ahead." | ✓ Age: {age} · ~{80 − age} yrs ahead |
| 3 | screen time (after life-squares receipt) | "{hours}h a day… that's ~{days} days a year gone." | ✓ Screen time: {hours}h/day |
| Final | memoPlan (pre-paywall) | "Your counterattack's ready." (presenting pose) | — all 3 already shown; card stamped "Personalized for you" |

**Copy is data-driven:**
- `goalSummary` reuses the existing `onboardingPlanGoalSummary` mapping
  (e.g. `.screenTimeFrying` → "hours back").
- Years ahead reuses the existing `80 - age` heuristic from
  `OnboardingPlanPersonalizingView`.
- Days/year gone = `dailyScreenTimeHours * 365 / 24`, rounded. (e.g. 4.2h → ~64 days.)
  When screen time is an estimate and ≥8h, present as "8h+".

**Tone arc (problem-agitate-solve):** Beat 1 warm/commitment → Beat 2 mild stakes →
Beat 3 the loss-aversion gut-punch → Final beat resolves into agency + the plan. The
agitation peaks one screen before the offer; the final beat hands back control so users
hit the paywall motivated, not hopeless.

### Cumulative clipboard rule

The clipboard always renders **every line earned up to and including the current beat**.
Because beats are separated by real onboarding screens, the card visually re-enters each
beat but re-shows prior lines (they're derived from persisted `@State`, so progress is
never lost). The newest line is the one that animates in. The final beat shows all three
lines pre-filled and adds the "Personalized for you" stamp + presenting pose as the
payoff.

### Flow integration

Three new beat screens are inserted and the old personalization page is replaced. New
logical order:

```
welcome → goals → [BEAT 1] → age → [BEAT 2] → screenTimeAccess → lifeSquaresReceipt
→ [BEAT 3] → memoPlan → [FINAL BEAT] → (paywall cover) → focusMode → notificationPriming
```

Implementation notes:
- The `pageContent` switch and `totalPages` (currently 9) grow to accommodate the new
  beats. All hard-coded `goToPage(n)` targets, `progressHeaderOpacity` hidden-page set
  (currently `[6]`), back-button behavior, and the paywall trigger move accordingly.
  **Beat screens hide the progress header** (full-bleed cinematic), matching how page 6
  is treated today.
- The final beat owns the `presentedCover = .paywall` trigger that
  `planPersonalizingPage` currently fires (`OnboardingView.swift:1134`).
- `handleCoverDismiss` routing (brain-age reveal → personalizing; paywall → focusMode)
  updates to the new page indices.
- **Back navigation:** beats are transient/auto-advancing. Pressing back from the screen
  *after* a beat should return to the data screen, not re-trigger the beat. Simplest:
  beats are skipped when navigating backward (back button on age returns to goals, not
  Beat 1). Confirm during planning.

### Analytics

- Keep firing `trackOnboardingStepViewed` / `trackOnboardingStepCompleted` for each beat
  with distinct step names (e.g. `planBeatGoals`, `planBeatAge`, `planBeatScreenTime`,
  `planBeatFinal`).
- `Analytics.onboardingStepName(for:)` updates to map the new page indices.
- Preserve the existing final-beat completion property
  `paywall_trigger: "onboarding_personalized_plan"` so paywall attribution is unchanged.
- Drop-off tracking (`onDisappear`) continues to work via the updated step-name mapping.

## Assets

Two Memo loops, generated in Runway Animate Keyframes (same image as first + last frame
for seamless loop), exported as dark-bg MP4 to match `OB.bg` (~`#0E1014`):

1. **Thinking/working** — Memo with clipboard + pencil, subtle bob + scribble + blink.
2. **Presenting** — Memo holding the completed clipboard up, soft "ta-da" + blink.

Add to the asset catalog / bundle. Wrap playback in an availability check so a missing
asset falls back to a static image (no broken screen).

## Testing

- **Build:** device build per CLAUDE.md (`00008130-000A214E11E2001C`) must succeed and
  install; simulator-only is not sufficient.
- **Visual:** `/verify-changes` screenshots of each beat in both light and dark (onboarding
  is dark-pinned, but verify no cream bleed).
- **Flow trace:** walk goals→beat1→age→beat2→screenTime→receipt→beat3→memoPlan→finalBeat
  →paywall; confirm each beat auto-advances, the clipboard shows the correct cumulative
  lines, copy interpolates real values, and the paywall still receives age / hours / goal.
- **Edge cases:** screen-time estimate path (≥8h → "8h+"), `reduceMotion` on (fades, no
  long holds), missing Memo video asset (static fallback), back-navigation does not
  re-trigger a beat.
- **Drop-off analytics:** verify new step names appear and paywall attribution unchanged.

## Open Questions

- Exact auto-advance duration per beat (start ~2.5s, tune on device).
- Whether back navigation skips beats entirely vs. replays them (lean: skip).
