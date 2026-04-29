# Plan Reveal — "The Siege" Design Spec (2026-04-28, rev 2)

## Goal

Upgrade the `OnboardingPersonalSolutionView` plan reveal page from "static backdrop + spring number swap" to a brand-driven, dramatic visualization where the apps are antagonists and Memo is the agent of change. Page intent: emotional drama (A) + brand voice (D).

The current page reads as a polite stat reveal. After this change it should read as: "the apps are pulling at you in real time. Memo cuts the damage in half. The apps recoil."

Win condition: not "more animation" — it's that the feed feels alive, Memo cuts it down, and the user feels the plan is a counterattack.

## Locked decisions

- Direction: **"The Siege"** (drift + pulse + recoil), not "The Exhibit" (strikethrough cinema) or "The Takedown" (mascot pushes apps off-screen).
- Apps stay logos in the backdrop tile grid (TikTok / Instagram / YouTube / Snap / Reddit / X) — no new asset work.
- No new mascot animation choreography — `mascot-unlocked` continues to appear during the `withMemo` beat.
- Numbers stay `targetProjectionHours` (without) → `targetProjectionHours / 2` (with).
- Page navigation, text labels, plan card structure all unchanged.

## Five behaviors to add

### 1. Backdrop drift (during stakes)

Each tile gets a deterministic-random per-tile drift via a single `TimelineView` driving all 35 tile offsets. One timeline value, derive `(x, y)` per tile from `sin(t × ω + phase_i)` and `cos(t × ω + phase_i)` where `phase_i` is the tile's grid index. **No 35 independent state animations** — that would thrash. One timeline, deterministic offsets.

Range: **±4pt horizontal, ±3pt vertical**. Period: ~6 seconds per cycle. Reads as: "the algorithm is always-on, always pulling."

### 2. Logo pulse — smooth wave, not per-tick toggle (during stakes)

Tile opacity pulses on a smooth sine wave tied to the same `TimelineView`. Base opacity per tile (varies by depth band — see #6 below) modulates by ±0.08 on a ~250ms breath cycle. Phase per tile shifts by index so the pulse rolls across the grid like a wave instead of all tiles flashing in sync.

**Critical:** this is NOT toggled per count step. A 24ms toggle reads as a strobe. The smooth wave reads as a breath.

### 3. Number color deepens (during stakes)

The "Without Memo" number starts at `AppColors.coral` and deepens to `AppColors.coralDeep` as the count climbs. Color interpolates linearly via `Color.blend()` (or equivalent) from coral → coralDeep based on `animatedProjectionHours / target` ratio.

**`coralDeep` is added to `Utilities/DesignSystem.swift`** as a proper semantic token (not inlined as a private raw color). Project rule: use `AppColors`, never raw `Color(red:)`. Since this is a brand-meaningful "danger escalation" color, it earns its name.

### 4. Slash animation at the cut — transitional, fades out

When the cut fires, an `AppColors.accent` capsule sweeps across the projected number from left to right, the number halves, then the slash fades out. **The slash NEVER sits on the final number** — the user previously rejected a permanent red strikethrough; this is a Memo cut-beam that comes and goes.

Phases:
- **Sweep in:** 0.4s `.easeOut`, capsule scales from 0 → 1 along x-axis, leading anchor
- **Number halves:** at 0.6s mark, projected number cross-fades to halved number (0.2s fade) while slash is still visible
- **Slash fades:** 0.3s `.easeIn` opacity 1 → 0
- **Total slash visible:** ~0.9s

Visual: `Capsule().fill(AppColors.accent).frame(height: 8)` overlaid on the number's frame.

### 5. Apps recoil at the cut (transition to withMemo)

When `revealBeat` flips to `.withMemo`, all backdrop tiles get an additional offset pushing them away from center (radial outward), tile opacity drops by ~50%, saturation drops to 0.55. Reads as: "the apps got pushed back."

Implementation: in the per-tile offset calculation, add a `withMemo` component that pushes each tile outward from center by `30pt × normalizedDistanceFromCenter`. Tile opacity, saturation, and blur all transition together with a 0.7s spring concurrent with the slash.

## Backdrop density + variety

Backdrop grid: **5×4 = 20 tiles → 7×5 = 35 tiles**. But uniform opacity across 35 tiles would read as cheap wallpaper. Tiles split into three depth bands by `distanceFromCenter`:

| Band | Tile count | Opacity | Blur | Scale | Role |
|---|---|---|---|---|---|
| Front | ~5 (innermost) | 0.55 | 0pt | 1.00 | Readable, the user can recognize them |
| Mid | ~15 | 0.32 | 0.8pt | 0.92 | Atmospheric — present but not demanding |
| Back | ~15 (edges) | 0.18 | 2.2pt | 0.85 | Feed wall in fog |

The pulse wave (#2) modulates each band's base opacity by the same ±0.08 — front band breathes between 0.47 ↔ 0.63, mid 0.24 ↔ 0.40, back 0.10 ↔ 0.26. Tile size: 36pt regardless of band (scale handles visual size).

## Pacing — every beat does something, no dead time

| Beat | Duration | What's happening |
|---|---|---|
| Count climb | ~2.5s (105 × 24ms) | Number ticks up, color deepens, drift+pulse continuous |
| Hold after climb | 600ms (was 1100ms) | Color settles to full coralDeep; drift continues |
| Cut moment | 0.9s | Slash sweeps in, number halves, slash fades — concurrent with apps recoiling 0.7s |
| Hold on halved | 1100ms (was 2000ms) | mascot-unlocked enters, brand-blue glow settles around number |
| Plan beat | 0.74s spring + plan rows | First row appears 180ms after halved number settles, accent matches the slash blue |

**Total stakes → plan transition: ~4.3s** (was ~5.4s, was originally ~3.6s before this round of work). Still cinematic, no static frames.

## Haptics

| Trigger | Haptic | Frequency |
|---|---|---|
| Count climbing | Light impact (intensity 0.4) | Every 15 count steps (~7 ticks total across the climb) |
| Slash fires | Medium impact | Once, at slash start |
| First plan row | Soft success notification | Once |

Implementation: `UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator` from existing patterns in `OnboardingView.swift`.

## Plan card carry-over (small, not a redesign)

Plan card structure stays. **Two minimal touches** so the climax doesn't deflate into a settings table:

1. The first plan row's accent number/glyph uses **`AppColors.accent`** (the same brand-blue that just slashed the number) instead of whatever it currently is.
2. The first plan row appears **180ms after** the halved number settles (no awkward gap). Currently it's gated on a separate state machine — needs to be tied directly to the end of the halved-number animation.

A real plan card redesign (cards-as-card-stack, large numerals, Memo-as-author header, etc.) goes in a separate spec when you're ready. **Out of scope for this work.**

## Implementation scope

All changes confined to:
- `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — `OnboardingPersonalSolutionView` and one new private struct `PlanRevealBackdrop`
- `MindRestore/Utilities/DesignSystem.swift` — adds `AppColors.coralDeep`

New private types/properties added inside the view:
- `slashProgress: CGFloat` (@State) — 0 → 1 across the slash sweep
- `slashOpacity: CGFloat` (@State) — 1 → 0 during fade
- A new `PlanRevealBackdrop` private struct extracted from `revealBackdrop(size:)`. Wraps the `TimelineView`, depth-band logic, and per-tile drift/pulse/recoil math. Existing `revealBackdrop(size:)` becomes a thin wrapper.

## Out of scope

- Sound design (haptics yes, audio no)
- Mascot animation choreography changes
- Plan card section redesign (only the two minimal touches called out above)
- Adding new logo assets — uses the six already in `Assets.xcassets`
- Reduce-Motion alternative — defer until QA tests with Reduce Motion enabled. (Likely fix: skip drift/pulse, keep color deepen + slash + recoil at minimum opacity changes.)

## Testing

Visual verification on device. Build + install via standard `xcodebuild` + `xcrun devicectl device install app`. No unit tests — visual animation change with no testable logic boundary.

## Decisions locked (rev 2)

- Direction 1 ("The Siege"), all five behaviors
- 7×5 tile grid (35 tiles), 36pt nominal size, three depth bands (5 / 15 / 15 split by distance from center)
- 6 logo cycle: tiktok, instagram, youtube, snapchat, reddit, x
- Drift: ±4pt H / ±3pt V, ~6s period, single TimelineView driving deterministic per-tile sin/cos
- Pulse: smooth sine wave, ±0.08 modulation around per-band base opacity, ~250ms cycle, phase shifted per tile
- Color: `AppColors.coral` → new `AppColors.coralDeep` token, linear blend tied to count progress
- Slash: AppColors.accent capsule, transitional (sweep in 0.4s → halve at 0.6s → fade 0.3s), never permanent
- Recoil: 30pt × normalized-distance-from-center, 0.7s spring, opacity halved, saturation 0.55, blur step
- Haptics: light ticks every 15 count steps, medium on slash, soft success on first plan row
- Pacing: ~4.3s total stakes → plan, no static holds
- `coralDeep` added to `AppColors` (DesignSystem.swift), not inlined
- All animation logic confined to OnboardingPersonalSolutionView + a new private PlanRevealBackdrop struct
- Plan card stays; only first row accent + timing tweaks
