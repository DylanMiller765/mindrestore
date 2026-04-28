# Industry Scare redesign + onboarding eyebrow sweep

**Date:** 2026-04-28
**Author:** brainstormed with Claude
**Status:** Approved — ready for implementation plan

## Context

Industry Scare is page 3 of the v2.0 onboarding flow (currentPage index `3` in `OnboardingView.swift`'s TabView). Lives in `MindRestore/Views/Onboarding/FocusOnboardingPages.swift` as `struct FocusOnboardIndustryScare`. It sits between Pain Cards (page 2 — confessional receipt slips) and Empathy (page 4 — sunglasses Memo against social-media wall).

The current implementation gets a $57B industry-spend message across, but it doesn't land:

- 7 stacked elements compete for attention (eyebrow, count-up, two-tier caption, quote callout, mascot, defiance headline, subline).
- 5 different font styles fragment the visual hierarchy.
- The count-up animation is the only motion and it isn't dramatic enough.
- Voice reads more like a PSA than Memo.
- Per user direct feedback: "could be a bit more scary tbh."

The redesign keeps the message ($57B / industry-as-enemy) and the page's role in the emotional arc, but rebuilds it as a sequel to Pain Cards' "memo found the receipts" metaphor — turning a generic stat page into a narrative payoff.

## Design direction: The Lineup

Crime-scene / case-file aesthetic. Pain Cards = your receipts (confessions). Industry Scare = their receipts (crimes). Same metaphor extended, different target. The page presents the four major attention-economy platforms as named suspects in a case file, with the $57B aggregate R&D figure as the evidence at the bottom.

Why this fits the existing onboarding (vs. two alternatives considered — "The Dossier" surveillance-file aesthetic and "The Number That Eats You" pure-typography scale):

- **Continuity with Pain Cards.** The "memo found the suspects" headline is a direct sequel to "memo found the receipts." Setup → payoff.
- **Continuity with the established logo language.** Welcome uses logos as a queue Memo bounces. Empathy uses logos as the wall behind sunglasses Memo. Notif Priming uses TikTok's logo on the bait card. Industry Scare using logos as suspects fits — same actors, different framing per page.
- **Saves pure-number drama for Plan Reveal.** Plan Reveal is the climax (44k → 22k count-up). A pure-number Industry Scare would steal Plan Reveal's punch.
- **Mono digits + dashed dividers + evidence framing already exist in Pain Cards.** Extending the aesthetic instead of inventing a new one.

## Visual layout

Top to bottom on a dark `OB.bg` (#0A0A0F) page:

1. **Case-file slug** (replaces the old blue eyebrow): `CASE FILE · 04 OF 04`. Mono 10pt, tracking 1.6px, opacity 0.45. Top-left, 24pt horizontal padding, 12pt below the progress bar.
2. **Headline:** `memo found\nthe suspects.` Brand font, 26pt weight 800, line-height 1.05, letter-spacing −0.5px. Default `OB.fg` color, two lines, 16pt below the slug.
3. **Caution-tape divider.** Diagonal stripes (45deg) in `OB.amber` (#FFC247) and `OB.bg` (#0A0A0F), 9px stripe width, 16px repeat. Full-bleed horizontally (extends past the 24pt page padding by negative margins). 10pt height. 14pt below the headline.
4. **Suspect lineup — 4 rows.** Each row: 40×40pt logo tile (rounded 9pt) + meta column (suspect name 13pt weight 700 in `OB.fg`, parent company 9pt mono opacity 0.5 with 0.8px tracking) + role label (9pt mono, `OB.coral`, right-aligned, 0.8px tracking). 1pt dashed `Color.white.opacity(0.10)` divider between rows; no divider after the last row. The four rows:

   | Logo | Suspect | Parent | Role |
   |---|---|---|---|
   | `logo-tiktok` | TikTok | `BYTEDANCE` | `FEED` |
   | `logo-instagram` | Instagram | `META` | `REELS` |
   | `logo-youtube` | YouTube | `GOOGLE` | `SHORTS` |
   | `logo-snapchat` | Snap | `SNAP INC` | `SPOTLIGHT` |

   No per-company dollar figures. Specific R&D claims per platform invite fact-checks the app can't win. The aggregate $57B figure (below) is the defensible number.
5. **Top divider** (1.5pt solid `Color.white.opacity(0.18)`) above the totals block. Visually separates the case (suspects) from the evidence (total spend).
6. **Total label:** `COMBINED R&D · ANNUAL`. Mono 9pt, opacity 0.45, 1.6px tracking. Above the number.
7. **The $57B hammer.** `$57B` rendered in `.system(size: 56, weight: .black, design: .monospaced)` with `.monospacedDigit()`, letter-spacing −3px, line-height 1.0, full `OB.fg` opacity. Counted from `0 → 57` over ~1.2s. Mono `B` suffix is part of the same Text run.
8. **Caption under the number:** `spent every year engineering\nyour feed against you.` Brand 12pt, opacity 0.65, 6pt above the caption.
9. **Detective Memo (mascot).** Bottom-right corner, ~52pt, `accessibilityHidden(true)`. Uses a new `mascot-detective` asset (Memo with a fedora + magnifying glass — the user is producing the asset). Falls back to the existing `mascot-lookout` if the new asset isn't yet in the catalog. Soft `OB.accent` glow behind the mascot. Below the mascot: tiny `MEMO · DETECTIVE` mono caps label, 8pt, opacity 0.5, right-aligned.
10. **CTA at the bottom.** `i'm in. fight back.` rendered in the existing `FOContinueButton` shape (white text on `FO.accent` solid fill, 14pt corner radius, 17pt weight 700, 17pt vertical padding). Lowercase to match the brand voice already locked in by Pain Cards' `caught me` / `not me` and Welcome's lowercase headlines. Sits in `safeAreaInset(edge: .bottom)`.

## Animation choreography

Total entrance ~3.0s. Beats fire from `startSequence()` on `.onAppear`:

| Time | Beat | Animation | Haptic |
|---|---|---|---|
| 0.10s | Case-file slug + headline fade up | opacity 0→1, y 8→0, 0.40s easeOut | — |
| 0.55s | Caution tape rolls in left → right | `clipShape` width 0→100%, 0.50s easeOut | — |
| 1.05s | Suspect rows appear sequentially | per-row opacity 0→1 + y 8→0, 0.10s stagger, 0.30s easeOut each | light @ each row (4 ticks) |
| 1.55s | Top divider settles | opacity 0→1, 0.30s easeOut | — |
| 1.70s | $57B count-up starts | timer-driven 0 → 57 over 1.2s | light tick every other increment |
| 2.95s | Caption + mascot + CTA fade up | opacity 0→1, y 8→0, 0.40s easeOut | medium on $57B settle |

## Reduce Motion fallback

`@Environment(\.accessibilityReduceMotion)` binding. When `true`:
- Skip the count-up timer; set `displayedNumber = 57` immediately.
- All entrance opacity/offset animations collapse to a single `withAnimation(.easeOut(duration: 0.18))` block that flips every visibility boolean simultaneously.
- Caution tape appears at full width (no roll-in clip animation).
- Suspect-row stagger collapses to 0.0 — they appear together.
- A single `light` haptic fires at +0.30s after appear so the cinematic moment still has a tactile beat.

## Voice notes

- Headline lowercase per established brand voice (Pain Cards `caught me`, Welcome lowercase headlines).
- `BYTEDANCE / META / GOOGLE / SNAP INC` parent-company labels in mono caps — clinical-feeling labels are appropriate here because the page IS a case file. The clinical tone is the joke.
- Role labels (`FEED / REELS / SHORTS / SPOTLIGHT`) are real product names. Naming them by their attention-economy product feature (rather than abstract terms like `THE LOOP`) is what makes it specific and damning.
- Caption `spent every year engineering your feed against you.` — direct, plural-singular ("your feed"), active voice, "against you" is the punch.
- CTA `i'm in. fight back.` — active commitment, replaces the passive `Continue`. Lowercase. Pairs with the page's defiance.

## Eyebrow sweep — secondary task

User feedback: drop the small blue uppercase "marketing eyebrow" text from the pages that currently have it; align with the rest of the onboarding which mostly doesn't.

Pages affected:
- **Industry Scare:** Was `WHAT YOU'RE UP AGAINST` (blue, brand 13pt bold tracking 1.0, `FO.accent`). Replace with `CASE FILE · 04 OF 04` (mono 10pt, opacity 0.45, `OB.fg3`). This is conceptually NOT an eyebrow — it's a case-file slug that's part of the new design language. Different style entirely.
- **Pain Cards:** Was `MEMO FOUND THE RECEIPTS` (blue eyebrow). Replace with `CASE FILE · 03 OF 04` (mono small caps, same style as the Industry Scare slug). Establishes the case-file slug as a recurring micro-element across the two "evidence" pages.

Pages NOT affected:
- Other onboarding pages that already lack eyebrows stay as they are.
- The Goals / Plan Reveal eyebrows added in the reverted GSD work are gone (reverted) — staying gone, no need to add them back.
- Notif Priming has `TWO KINDS OF NUDGES` — keep as-is unless the user explicitly flags it. That eyebrow is integral to its layout (sets up the two-card comparison below it).

## Asset requirements

- **`mascot-detective`** (new) — produced by the user via image gen. PNG 1024×1024+, transparent bg, Memo with fedora + magnifying glass. Saved to `Assets.xcassets/mascot-detective.imageset/` as 1x/2x/3x.
- **Existing assets reused:** `logo-tiktok`, `logo-instagram`, `logo-youtube`, `logo-snapchat`. Verify all four exist in `Assets.xcassets`. If any are missing, fall back to the colored `logo-tile` placeholders (matching the existing `BouncerApp` / `DemoApp` pattern in `FocusOnboardingPages.swift`).
- **Fallback:** if `mascot-detective` isn't yet in the catalog at build time, render `mascot-lookout` instead so the page doesn't break. Asset substitution is a runtime concern handled by SwiftUI's `Image(_:)` initializer — if the named image is missing, SwiftUI logs a warning and renders nothing, so an explicit fallback path inside the View body is needed.

## Technical structure

The page lives in `FocusOnboardIndustryScare` (`FocusOnboardingPages.swift:66`). Implementation is a body rewrite-in-place per the established anti-pattern (no struct rename, no replacement). New private state needed:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

@State private var slugVisible = false
@State private var headlineVisible = false
@State private var tapeVisible = false
@State private var rowsVisible: [Bool] = Array(repeating: false, count: 4)
@State private var dividerVisible = false
@State private var displayedNumber: Int = 0
@State private var captionVisible = false
@State private var ctaVisible = false
@State private var sequenceTask: Task<Void, Never>?
```

The `startSequence()` function becomes a Swift `Task` that awaits the timeline beats sequentially (matches the pattern used in Plan Reveal's `revealTask`). Cancelled in `.onDisappear` to avoid retain cycles when the user navigates back.

A new private `SuspectRow` struct encapsulates a single row (`logoAsset: String, suspect: String, parent: String, role: String, visible: Bool`).

## Out of scope

- The "atmosphere blends behind the progress bar" pattern (the 3-act atmosphere idea from earlier in the session) is **not part of this plan**. That's a separate sweep across all 16 pages; revisit after Industry Scare lands.
- The full `BRAND.md` / brand-voice rewrite of all onboarding copy is out of scope. This plan touches only Industry Scare (full rebuild) and Pain Cards (eyebrow swap only).
- Phase 3 BRAND-05 rename (`Memori` → `Memo`) is unaffected. No `Memori` user-facing strings are introduced or removed by this plan.

## Verification

- `xcodebuild` succeeds on device target `00008130-000A214E11E2001C`.
- Visible on device: case-file slug + headline + caution tape + 4 suspect rows + divider + $57B + caption + detective Memo + CTA — in that vertical order.
- Reduce Motion ON → entrance is 0.18s opacity-only fades; $57B shows immediately as `57`; light haptic fires once at +0.30s.
- Pain Cards' previous `MEMO FOUND THE RECEIPTS` eyebrow is replaced with `CASE FILE · 03 OF 04` mono slug; Pain Cards otherwise unchanged.
- No fake per-company R&D dollar figures appear anywhere in the rendered page.
- VoiceOver reads, in order: `Case file four of four`, `memo found the suspects`, `TikTok by ByteDance`, `Instagram by Meta`, `YouTube by Google`, `Snap by Snap Inc`, `Combined R and D annual fifty-seven billion dollars`, `spent every year engineering your feed against you`, `i'm in, fight back, button`.

## Success criteria

- Industry Scare lands as a sequel to Pain Cards (the user reads the page and recognizes "oh, same case-file metaphor").
- Element count drops from 7 to 5 (case slug, headline, suspect lineup as one block, $57B + caption, mascot/CTA region).
- Font choices drop from 5 to 2 (brand sans + monospace).
- The $57B figure dominates the lower half of the screen at 56pt mono.
- Pain Cards eyebrow swept; no other onboarding pages are touched.
- New `mascot-detective` asset (or `mascot-lookout` fallback) renders without clipping at 52pt in the bottom-right.
