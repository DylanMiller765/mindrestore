# Plan Reveal — "The Siege" Design Spec (2026-04-28)

## Goal

Upgrade the `OnboardingPersonalSolutionView` plan reveal page from "static backdrop + spring number swap" to a brand-driven, dramatic visualization where the apps are antagonists and Memo is the agent of change. Page intent: emotional drama (A) + brand voice (D).

The current page reads as a polite stat reveal. After this change it should read as: "the apps are pulling at you in real time. Memo cuts the damage in half. The apps recoil."

## Locked decisions

- Direction: **"The Siege"** (drift + pulse + recoil), not "The Exhibit" (strikethrough cinema) or "The Takedown" (mascot pushes apps off-screen). User picked Siege for brand-voice emphasis without new asset cost.
- Apps stay logos in the backdrop tile grid (TikTok / Instagram / YouTube / Snap / Reddit / X) — no new asset work.
- No new mascot animation choreography — `mascot-unlocked` continues to appear during the `withMemo` beat as it does today.
- Numbers stay `targetProjectionHours` (without) → `targetProjectionHours / 2` (with) — no new data calculation.
- Page navigation, text labels, plan card section all unchanged.

## Five behaviors to add

### 1. Backdrop drift (during stakes)

Each tile gets a deterministic-random per-tile drift offset that animates back and forth on a long loop (~5–7s, autoreverse, ease-in-out). Range: ±4pt horizontal, ±3pt vertical. Each tile's seed comes from its `(row, column)` index so adjacent tiles drift in different directions, breaking the wallpaper-grid feel. Reads as: "the algorithm is always-on, always pulling."

Implementation: derive an `(x, y)` offset per tile via `sin/cos` of a timeline value, with phase offset by index.

### 2. Logo pulse synced to count-up (during stakes)

Tile opacity pulses with the count tempo. Base opacity stays around `0.42`, but during each count step opacity flares to `~0.55` for ~120ms then settles back. Reads as: "every hour you waste, the apps get a little stronger."

Implementation: a `@State var pulseTrigger: Bool` toggled inside the `countProjection()` task at the same step cadence. Tiles read this and animate.

### 3. Number color deepens (during stakes)

The "Without Memo" number starts at `AppColors.coral` and deepens to a `coralDeep` (darker red) as the count climbs. Color interpolates from coral → coralDeep based on `animatedProjectionHours / target` ratio.

`coralDeep` definition: `Color(red: 0.78, green: 0.22, blue: 0.20)` — same hue family, ~30% darker. Add as a private static property on the view (not a global `AppColors` addition — too narrow a use case).

### 4. Slash animation at the cut (transition to withMemo)

When the cut fires, a brand-blue line sweeps across the projected number from left to right over 0.6s, then the number halves and rises into place.

Implementation:
- `@State var slashProgress: CGFloat = 0` — animated 0 → 1 in 0.6s with `.easeOut`
- A `Capsule().fill(AppColors.accent).scaleEffect(x: slashProgress, anchor: .leading).frame(height: 8)` overlaid on the number
- After slash completes, fade the slash out over 0.3s while the new "with Memo" number cross-fades in

### 5. Apps recoil at the cut (transition to withMemo)

When `revealBeat` flips to `.withMemo`, all backdrop tiles get an additional offset pushing them away from center (radial outward), tile opacity drops from `0.42` → `0.18`, and saturation drops to `0.55`. Reads as: "the apps got pushed back."

Implementation: in the per-tile offset calculation, add a `withMemo` component that pushes each tile outward from center by ~30pt × normalized distance. Tile opacity and saturation are tied to the `revealBeat` state with a 0.7s spring transition concurrent with the slash.

## Density bump

Backdrop tile grid: **5 rows × 4 columns = 20 tiles → 7 rows × 5 columns = 35 tiles**. Tile size shrinks from 42pt → 36pt to fit. User explicitly asked for more icons — this is the simplest way to deliver that without restructuring the layout.

## Pacing adjustments (on top of the existing slowdown)

| Beat | Current | New |
|---|---|---|
| Count-up duration | ~2.0s (84 steps × 24ms) | **~2.5s** (105 steps × 24ms) — slower so each tick lands |
| Hold after count-up | 900ms | **1100ms** — let the climb settle |
| Stakes → withMemo spring response | 1.05s | **1.2s** — slow enough for the slash to read |
| Slash sweep duration | n/a | **0.6s easeOut** |
| Hold on halved number | 2000ms | **2000ms** (unchanged) |

Total stakes → withMemo time: ~5.4s now (was ~3.6s before this round).

## Implementation scope

All changes confined to `OnboardingPersonalSolutionView` in `MindRestore/Views/Onboarding/OnboardingNewScreens.swift`.

New private types/properties added inside the view:
- `coralDeep: Color` (private static)
- `pulseTrigger: Bool` (@State)
- `slashProgress: CGFloat` (@State)
- `tileOffset(for:)`, `tileOpacity(for:)`, `tileSaturation(for:)` helpers — replace the inline backdrop logic
- A new `PlanRevealBackdrop` private struct extracted from `revealBackdrop(size:)` so the per-tile animation logic has a tight home rather than ballooning the parent function

The existing `revealBackdrop(size:)` function gets thinner — it just instantiates `PlanRevealBackdrop` with the right beat/pulse/density inputs. The per-tile drift / pulse / recoil math lives in the new struct.

## Out of scope

- Sound design / haptics on the count tempo (could land in a follow-up — the spec calls out where they'd hook in if/when added)
- Mascot animation choreography changes
- Plan card section changes
- Backdrop visible past the plan beat (when `revealBeat == .plan`, behavior is unchanged: tiles fade further to ~0.18 opacity, no drift)
- Adding new logo assets — uses the six already in `Assets.xcassets`

## Testing

Visual verification on device per project standards. Build + install via the standard `xcodebuild` + `xcrun devicectl device install app` flow. No unit tests — this is a visual animation change with no testable logic boundary.

## Decisions locked

- Direction 1 ("The Siege"), not 2 or 3
- 7×5 tile grid (35 tiles), 36pt per tile
- 6 logo cycle: tiktok, instagram, youtube, snapchat, reddit, x
- Drift range: ±4pt horizontal / ±3pt vertical, 5–7s loop, autoreverse
- Pulse: 0.42 base → 0.55 peak, 120ms pulse duration, synced to count steps
- Color: coral → coralDeep (#C73835) over count progress
- Slash: AppColors.accent capsule, 0.6s easeOut, leading-anchor scale
- Recoil: 30pt × normalized-distance-from-center, 0.7s spring, opacity 0.42 → 0.18, saturation 0.55
- Pacing as in table above
- All changes confined to OnboardingPersonalSolutionView (no global asset/color additions)
