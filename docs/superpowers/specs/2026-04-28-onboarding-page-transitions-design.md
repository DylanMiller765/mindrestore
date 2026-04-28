# Onboarding page-to-page transitions

**Date:** 2026-04-28
**Author:** brainstormed with Claude
**Status:** Approved (verbal — user said "i trust you" after seeing the 3 visual directions) — ready for implementation plan

## Context

The v2.0 onboarding flow uses SwiftUI's `TabView` with `.tabViewStyle(.page(indexDisplayMode: .never))` and `.scrollDisabled(true)`. Page changes fire via `withAnimation { currentPage = N }` from each page's CTA. The default animation behavior is iOS's standard horizontal page-curl / slide — the same transition every Apple template uses, which feels generic against the rest of the polished v2.0 onboarding work (Welcome bouncer, Pain Cards receipt slips, Industry Scare case-file lineup, etc.).

Top onboarding flows (Cal AI, Headway, Reflectly, Stoic) ship custom transitions that elevate every page without drawing attention to themselves. The brand voice — defiant Gen Z, dark-pinned, mono-accented — leans toward something deliberate but not flashy. A polished dissolve, not a Lottie animation extravaganza.

## Direction: Refined Dissolve (Direction 2 from brainstorm)

The base transition for every page advance is a refined dissolve:

- **Outgoing page:** opacity 1 → 0 over 0.30s, easeIn.
- **Incoming page:** opacity 0 → 1 + scale 0.96 → 1.0 + offset y: 8 → 0 over 0.40s, easeOut.
- **Slight overlap** so the user always sees something during the transition (incoming starts fading in slightly before outgoing finishes fading out).
- **Forward and back are symmetric** — same transition both directions. Asymmetric forward/back was considered (Direction 3 — kinetic push) and rejected; symmetry reads as deliberate, asymmetry across 16 pages risks fatigue.

The transition is uniform across all 16 pages. No per-page customization. The page contents themselves (which already have their own staggered entrance arcs implemented in each page's `.onAppear`) carry the per-page personality after the transition completes. The transition is connective tissue, not a feature.

## What gets shared between pages (continuity)

Three elements visually carry across page transitions:

1. **Background.** `OB.bg` (#0A0A0F) is the same on every page, so the dark stays continuous across the transition. Light-mode iOS leak is already prevented by the parent's `.preferredColorScheme(.dark)` + `.environment(\.colorScheme, .dark)` pin.
2. **Progress bar.** The progress capsule + back-chevron sit OUTSIDE the page-content container, so they don't transition out — they stay anchored and animate their fill width via `withAnimation` on `onboardingProgress`. This already works; no change needed.
3. **`pageAtmosphere`.** The atmosphere blur layer (currently `welcomeAtmosphere` for page 0, `EmptyView()` for the rest) sits outside the page-content container. It's shared infrastructure that survives the transition.

Mascot continuity (e.g., Memo flowing from Pain Cards → Industry Scare → Empathy via `matchedGeometryEffect`) was considered as a sprinkle of Direction 1 (Cinematic Morph). **Deferred to a follow-up iteration.** Reasons:

- It requires renaming each page's mascot Image to share a single `matchedGeometryEffect` id + parent namespace, which crosses page boundaries that today are isolated.
- It only earns its place where mascot positions across consecutive pages create a clear continuity narrative. Most page pairs don't.
- The base refined dissolve is a clear upgrade on its own. Adding mascot morph is a separable enhancement — easier to evaluate after the base transition lands.

## Architecture

Replace the `TabView` with a `ZStack`-anchored single-page container that uses SwiftUI's `.transition` modifier driven by `.id(currentPage)`:

**Before** (`OnboardingView.swift:89`):
```swift
TabView(selection: $currentPage) {
    welcomePage.tag(0)
    namePage.tag(1)
    painCardsPage.tag(2)
    // ... 13 more pages
}
.tabViewStyle(.page(indexDisplayMode: .never))
.scrollDisabled(true)
.animation(.easeInOut, value: currentPage)
.onChange(of: currentPage) { _, newPage in /* keyboard dismiss + bullets reset */ }
```

**After:**
```swift
ZStack {
    pageContent
        .id(currentPage)
        .transition(.asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.96, anchor: .center))
                .combined(with: .offset(y: 8))
                .animation(.easeOut(duration: 0.40)),
            removal: .opacity
                .animation(.easeIn(duration: 0.30))
        ))
}
.animation(.easeInOut, value: currentPage)  // drives the .transition
.onChange(of: currentPage) { _, newPage in /* keyboard dismiss + bullets reset */ }
```

Where `pageContent` is a `Group` with a switch:

```swift
@ViewBuilder
private var pageContent: some View {
    switch currentPage {
    case 0: welcomePage
    case 1: namePage
    case 2: painCardsPage
    case 3: industryScarePage
    case 4: empathyPage
    case 5: goalsPage
    case 6: agePage
    case 7: screenTimeAccessPage
    case 8: personalScarePage
    case 9: quickAssessmentPage
    case 10: planRevealPage
    case 11: comparisonPage
    case 12: differentiationPage
    case 13: focusModePage
    case 14: notificationPrimingPage
    case 15: commitmentPage
    default: EmptyView()
    }
}
```

The `.id(currentPage)` modifier tells SwiftUI to treat each page-index as a distinct view identity. When `currentPage` changes, SwiftUI tears down the outgoing view and builds the incoming view, applying the `.transition` on each.

## Why this approach over alternatives

- **TabView with custom animation override** — rejected. iOS 17's `TabView.tabViewStyle(.page)` hard-codes its transition; you cannot override it via `.transition` or `.animation`. Confirmed via testing the existing `.animation(.easeInOut, value: currentPage)` line, which only modifies the curve speed, not the visual style. Stays a horizontal slide.
- **Custom `UIPageViewController` wrapped in `UIViewControllerRepresentable`** — overkill. The whole reason to use SwiftUI is to avoid this. We don't need swipe-to-advance (currently disabled anyway via `.scrollDisabled(true)`).
- **Imperative animation on `currentPage` change with manual opacity state** — possible but more code. Loses SwiftUI's automatic transition orchestration.

`Group { switch ... }` + `.id` + `.transition` is the canonical SwiftUI pattern for "pick one of N views and animate the swap." It's what TabView would be doing under the hood if it weren't locked.

## State management considerations

The existing `@State private var currentPage = 0` and the existing CTA actions that fire `withAnimation { currentPage = N }` ALL CONTINUE TO WORK UNCHANGED. The only thing changing is the container that consumes `currentPage`.

The existing `onChange(of: currentPage)` handler that:
- Dismisses the keyboard
- Refocuses the name field on `newPage == 1`
- Resets the commitment entrance state booleans on `newPage != 15`

— stays intact. Attached to the new `ZStack` instead of `TabView`.

The `.scrollDisabled(true)` modifier disappears (TabView is gone, swipe-to-advance is no longer in scope). Not a regression — swipe-to-advance was already disabled in the current implementation.

## Per-page entrance animations

Each page already has `.onAppear` blocks that stagger the page's internal elements (e.g., welcome bouncer's app-pile cascade, Pain Cards' receipt-slip stack, Industry Scare's caution-tape roll-in, Plan Reveal's count-up). These remain untouched.

The new container transition fires FIRST (~0.40s), then the page's `.onAppear` triggers and the page's internal entrance arc plays. There's a slight perceptual sequencing — the page slides into existence, THEN its contents animate in. This is intentional and matches Cal AI / Headway / Stoic's pattern.

## Failure modes considered

- **Stutter on slow devices.** A 0.96 → 1.0 scale combined with opacity is cheap; runs at 60fps on every iPhone Apple still supports. No GPU concern.
- **Reduce Motion.** Page transitions should be lighter under Reduce Motion. The `.transition` modifier respects `accessibilityReduceMotion` automatically only when using `.transition(.opacity)` alone. Custom transitions don't auto-reduce. Add explicit handling: when `reduceMotion == true`, replace the transition with `.transition(.opacity.animation(.easeInOut(duration: 0.18)))` — strip the scale + offset.
- **Memory.** SwiftUI's `.id(currentPage)` causes the outgoing page to deallocate. The pages each carry their own `@State` (entrance booleans, etc.). Not a concern; in fact this is a memory improvement over TabView, which keeps all 16 pages allocated.
- **Re-entry from back swipe.** Each page's `.onAppear` already resets its entrance state and re-fires its animation arc. Going back to a previously-visited page will re-play its entrance animation. Verified pattern in `welcomePage`'s `startWelcomeEntrance()`.

## Reduce Motion fallback

Add an environment binding (already declared on `OnboardingView` for the goalsPage / commitmentPage / etc. iterations earlier in this session). Wrap the transition in a conditional:

```swift
.transition(reduceMotion
    ? AnyTransition.opacity.animation(.easeInOut(duration: 0.18))
    : AnyTransition.asymmetric(
        insertion: .opacity
            .combined(with: .scale(scale: 0.96, anchor: .center))
            .combined(with: .offset(y: 8))
            .animation(.easeOut(duration: 0.40)),
        removal: .opacity
            .animation(.easeIn(duration: 0.30))
    )
)
```

Reduce Motion users get a clean opacity-only crossfade. Same intent (deliberate, polished), no scale/offset motion.

## What this is NOT

- NOT a replacement for the per-page entrance animations. Each page keeps its existing `.onAppear` choreography.
- NOT adding mascot continuity via `matchedGeometryEffect` (deferred — see "What gets shared" above).
- NOT changing background hue per phase (would require a new `phaseAtmosphere` system; out of scope).
- NOT adding a pre-tap CTA pulse haptic (Direction 3 sprinkle — out of scope).
- NOT changing forward vs back behavior (both use the same symmetric transition).

## Verification

- `xcodebuild` succeeds on device target `00008130-000A214E11E2001C`.
- Visible on device: tap any page's CTA → outgoing page fades + the new page rises with a subtle scale + slight upward offset, ~0.40s, no horizontal slide. Tapping the back-chevron is symmetric.
- Reduce Motion ON → opacity-only crossfade with no scale/offset, ~0.18s.
- All 16 pages still render (each via the switch). No page is silently broken by the container swap.
- Existing in-page animations (welcome bouncer, Pain Cards receipts, Industry Scare suspect lineup, Plan Reveal count-up, etc.) continue to play correctly on `.onAppear`.
- Keyboard dismiss + bullet reset behavior preserved (the `onChange` handler moves to the new ZStack).
- Re-entry from back-chevron replays each page's entrance animation arc.

## Success criteria

- The transition reads as deliberate and polished. Not a stock iOS slide.
- It feels uniform across all 16 pages — no page surprises with a different transition.
- It doesn't fight the per-page entrance animations; the page transition COMPLETES before the in-page animations begin.
- Reduce Motion respected.
- The codebase loses one TabView and gains a Group switch — net code is roughly the same volume, but reads more explicitly (each page indexed in one place).
