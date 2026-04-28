# Memo Questions Redesign — Receipt Stack

**Status:** ready for user review  
**Target file:** `MindRestore/Views/Onboarding/OnboardingNewScreens.swift`  
**Target view:** `OnboardingPainCardsView`  
**Design direction:** playful confession, not interrogation

## Goal

Redesign the current `MEMO'S QUESTIONS` pain-card page so it feels like a playful, brand-native confession moment instead of a survey. The user should feel like Memo is collecting receipts on their feed loop, not judging them. Every positive answer should build sunk cost that later makes the plan reveal feel personalized and earned.

## Current Issues

- The cream paper card breaks the dark onboarding system.
- `Yep` / `Nah` feels generic and survey-like.
- `QUESTION 03/06` feels like cheap meta-label chrome.
- Memo is decorative instead of actively helping collect the evidence.
- `yepCount` currently affects no visible downstream screen, so the answers do not feel meaningfully used.

## Core Concept

Memo is gathering receipts from the user's feed loop.

The page shows a dark stack of narrow receipt slips. The front slip contains the current confession. Dimmed slips behind it imply previous evidence. When the user taps `Caught me`, the front slip gets a quick coral `CAUGHT` stamp and slides into the saved stack. When the user taps `Not me`, the slip flicks away and the next one rises in.

This keeps the mechanic fast, funny, and low-shame while making each answer feel like evidence that Memo will use to build the fight plan.

## Visual System

Use the existing OB dark onboarding tokens.

| Element | Treatment |
|---|---|
| Background | `OB.bg` / dark pinned onboarding background |
| Receipt surface | `OB.surface` |
| Active receipt border | `OB.accent.opacity(0.45...0.55)` |
| Saved receipt border | `Color.white.opacity(0.08...0.12)` |
| Stamp accent | `OB.coral` |
| Primary text | `OB.fg` |
| Secondary text | `OB.fg2` |
| Tertiary text | `OB.fg3` |
| Primary CTA | `OB.accent` |

Do not use a cream paper surface. The page must sit cleanly inside the current dark onboarding arc.

## Differentiation From The Existing Differentiation Receipt

The Differentiation page already uses a clean pricing receipt artifact with `PAID, NOT FARMED` and four line items. This page must not repeat that exact language.

Pain Cards receipt stack:

- Narrower, taller vertical slips, like torn feed receipts.
- Uneven stacked rotations.
- Perforated or dotted tear edge at the top or bottom.
- No neat line-item grid.
- No `PAID, NOT FARMED` style header.
- No checkmark list.
- One temporary handwritten-feeling `CAUGHT` stamp after positive tap only.
- Labels are warm and contextual: `current receipt`, `saved receipt`, `3 of 6`.

Differentiation receipt:

- Rectangular pricing receipt.
- Monospaced line items.
- Business-model proof.

The relationship should read as brand family, not duplicate motif:

- Pain Cards = evidence of the user's feed loop.
- Differentiation = proof of Memo's business model.

## Layout

### Header

Keep the existing progress header from parent onboarding.

Inside the page:

- Eyebrow: `MEMO FOUND THE RECEIPTS`
- Headline: `Which ones are yours?`
- Subcopy: `Tap what feels painfully familiar. Memo uses it to build your fight plan.`

Use wide headline spacing with no 4+ line wrap. The headline should fit in one line on modern iPhones and two lines on small devices.

### Receipt Stack

Middle hero zone:

- Three visible receipt slips.
- The visible stack grows with positive answers, capped at three saved/background slips to avoid clutter.
- If `receiptCount == 0`, show two ambient dim slips behind the active slip so the screen still has depth.
- If `receiptCount > 0`, replace ambient slips with saved slips, capped at three visible.
- Back slip 1: rotation `+5°`, y offset `18pt`, x offset `10pt`, opacity `0.54`, no blur.
- Back slip 2: rotation `-4°`, y offset `36pt`, x offset `-8pt`, opacity `0.34`, no blur.
- Back slip 3, only if needed: rotation `+8°`, y offset `54pt`, x offset `14pt`, opacity `0.22`, no blur.
- Front slip is full opacity with active border.
- Front slip contains:
  - Micro progress: `3 of 6`
  - Active label: `current receipt`
  - Big confession text
- Back slips may show short dimmed labels like `saved receipt`.

Receipt dimensions:

- Width: page width minus `48pt` horizontal margin.
- Min height: `210pt`.
- Corner radius: `16pt`.
- Padding: `18pt` horizontal, `18pt` vertical.
- Perforation: dotted tear line along the top edge, inset `16pt`, `Color.white.opacity(0.14)`, dash `[2, 5]`.

Receipt text should be the hero of the page. Avoid icons inside the receipt unless they serve the evidence metaphor. No generic SF Symbol badges.

### Mascot

Use bottom-left Memo placement.

Memo should peek from behind the bottom-left of the receipt stack, like he is physically pulling receipts from the feed. This makes Memo active instead of decorative.

Recommended asset:

- Start with `mascot-thinking` if no new pose is available.
- If a new pose is created later, use a detective/evidence-gathering pose that keeps Memo anatomy: blue brain body, purple outline, pink folds, glasses, two arms max.

Small-screen rule:

- Memo may tuck behind the stack and show only head/glasses/one hand.
- Memo must never cover the active confession text or buttons.

### Buttons

Replace the existing buttons:

- Secondary: `Not me`
- Primary: `Caught me`

`Caught me` is the conversion copy. It makes the user feel busted in a funny way rather than interrogated.

Button treatment:

- `Not me`: dark surface, white border at low opacity, secondary text.
- `Caught me`: brand blue fill, white text, subtle blue glow.

## Copy

Pain statements stay close to the current set, because they are specific and Gen-Z-readable:

1. `I check my phone before I check the time`
2. `I forget what I just read on a page`
3. `I uninstall TikTok, then redownload by Friday`
4. `I scroll until 2am even when I know better`
5. `I open the same 4 apps in a loop`
6. `I can't sit through a movie without my phone`

Potential copy tune:

- Keep the language specific and slightly funny.
- Avoid making the user sound broken or pathetic.
- Line 4 is intentionally rewritten away from literal self-hate language. Keep shame on the loop, not the user.

## Motion

Entrance:

| t | Action |
|---|---|
| `0.10s` | Header fades up: opacity `0 → 1`, y offset `8 → 0`, duration `0.38s`, easeOut |
| `0.32s` | Receipt stack rises in: opacity `0 → 1`, y offset `24 → 0`, spring response `0.50`, damping `0.82` |
| `0.48s` | Memo peeks in from bottom-left: opacity `0 → 1`, scale `0.90 → 1`, rotation `-7° → -4°`, spring response `0.46`, damping `0.80` |
| `0.78s` | Buttons fade up: opacity `0 → 1`, y offset `10 → 0`, duration `0.30s`, easeOut |

On `Caught me`:

1. Medium haptic.
2. Coral `CAUGHT` stamp pops onto the active slip.
3. Hold stamp for `0.18s`.
4. Active slip slides backward into saved stack with rotation `+5°`, scale `0.94`, opacity `0.54`.
5. Next slip rises into front position.

On `Not me`:

1. Light haptic.
2. Active slip tilts `-9°` and flicks left by `-340pt` while fading to `0`.
3. Next slip rises into front position.

Do not overdo the stamp aesthetic. One `CAUGHT` stamp on positive tap is enough.

### Stamp Visual

Use a diagonal rubber-stamp treatment:

- Text: `CAUGHT`
- Font: monospaced, heavy, `22pt`
- Tracking: `1.8`
- Color: `OB.coral`
- Border: rounded rectangle around the text, `OB.coral.opacity(0.72)`, `2pt`
- Rotation: `-8°`
- Placement: lower-right quadrant of the active slip, never over the main text baseline.
- Scale animation: `0.72 → 1.08 → 1.0` over `0.18s`.

## State And Behavior

Preserve the current one-at-a-time question mechanic:

- Tap-based, no swipe gesture required.
- Six total prompts.
- Advance automatically after the final prompt.
- Analytics still fires at completion.

Rename the state conceptually:

- Current `yepCount` becomes `receiptCount`.

Callback and parent plumbing:

- Change `OnboardingPainCardsView` from `let onContinue: () -> Void` to `let onContinue: (Int) -> Void`.
- On final prompt completion, call `onContinue(receiptCount)`.
- Add `@State private var receiptCount: Int = 0` to `OnboardingView`.
- In `painCardsPage`, assign the callback value to `receiptCount` before advancing to `currentPage = 3`.
- Add `receiptCount: receiptCount` to `OnboardingPersonalSolutionView`.
- Add `let receiptCount: Int` to `OnboardingPersonalSolutionView`.

## Downstream Handoff

Minimum viable handoff:

- Persist or pass `receiptCount` after the last question.
- Plan Reveal gets a small personalized line:
  - If `receiptCount > 0`: `You admitted to 4 feed loops. Memo goes after those first.`
  - If `receiptCount == 0`: `Memo still builds the plan around your picks.`

Do not add a folder transition in this pass. It is a good idea for later, but it adds animation scope without enough conversion upside right now.

## Accessibility

- Buttons must have clear labels: `Not me` and `Caught me`.
- The active receipt should be accessible as the current question.
- Stamp animation should not be the only indicator of selection; the question should advance as feedback.
- Respect Reduce Motion:
  - Disable card flick/slide transforms.
  - Use a `0.18s` opacity fade between receipts.
  - Keep haptics.
  - Show no scale punch on the `CAUGHT` stamp.

## Acceptance Criteria

1. Build succeeds on device.
2. Page stays dark and visually consistent with the rest of onboarding.
3. No cream paper card remains.
4. No `QUESTION 03/06` style label remains.
5. Buttons read `Not me` and `Caught me`.
6. `Caught me` increments `receiptCount`.
7. `Not me` does not increment `receiptCount`.
8. Final prompt advances to the next onboarding page.
9. Memo peeks from bottom-left and never covers active text.
10. Receipt stack visually differs from the Differentiation page's pricing receipt.
11. Plan Reveal can display the admitted receipt count.
12. Back stack grows with positive answers, capped at three visible saved slips.
13. Reduce Motion uses fade-only transitions.

## Out Of Scope

- No redesign of Differentiation.
- No new mascot asset required for the first implementation.
- No folder transition.
- No changes to the actual onboarding order.
- No changes to paywall.
