# Onboarding Demo Screen — Design Spec (2026-04-28)

## Goal

Insert a 6-second product demo immediately after the empathy page ("Memo fights back") so users *see* Memo's core loop — Instagram blocked → train → unlock — before continuing through the onboarding form. Same asset doubles as App Store preview video and screenshot source.

The empathy line ends with: *"Memo helps you take the controls back."* This screen literally shows that happening. It's the proof beat.

## Where it goes in the flow

Currently:
```
4 Empathy → 5 Goals → 6 Age → ...
```

After:
```
4 Empathy → 5 Demo (NEW) → 6 Goals → 7 Age → ...
```

All page indices in `OnboardingView.swift` from 5 onward shift +1. `goToPage(...)` call sites and `hiddenPages` set update accordingly. `pageContent` switch gets a new `case 5: demoPage`.

The progress header stays visible on this page (this is a transition beat, not a peak emotional moment like empathy or plan reveal).

## The recording

**Script (~6 seconds, recorded at 1x then sped to 2x in post = ~3 seconds of source becomes ~6 seconds of cinema):**

| Beat | Time | What's on screen |
|---|---|---|
| 1. Set the scene | 0–1s | Home screen. Finger taps **Instagram**. |
| 2. The bounce | 1–2s | Instagram launches for ~0.3s → Memo shield slams down. Headline: *"Train to unlock."* |
| 3. **Editorial cut** | — | Skip the notification → tap → app-launch chain. Cut straight to game playing. |
| 4. The earn | 2–4.5s | Reaction Time game: 3 flashes of color, three taps, score reveal: *"289ms · +3 min unlock."* |
| 5. The payoff | 4.5–6s | Cut back to Instagram, now opens. Hold ~1s on the feed. Loop. |

**Recording requirements:**
- Vertical (9:19.5, native iPhone aspect)
- Recorded on physical device (00008130-…) — UI is real, not simulated
- No screen overlay text inside the video — copy lives on the host screen
- Bundled in app as `onboarding_demo.mp4` under `MindRestore/Resources/Video/`
- Encoded H.264, ~1080×2340, target file size <2 MB (will compress further if needed for App Store binary size)

**Sound:** muted-by-default with a tap-to-unmute toggle in the corner of the video frame. Forcing audio in onboarding is a retention killer.

## The screen

```
┌─────────────────────────────┐
│  [progress header]          │
│                             │
│  Watch Memo take            │  ← headline: brand size 28pt, heavy
│  the controls back.         │     two-line, .textPrimary
│                             │
│      ┌─────────────┐        │
│      │             │        │
│      │  [phone     │        │  ← phone bezel frame
│      │   in phone  │        │     containing the loop
│      │   demo loop]│        │
│      │             │        │
│      │   [🔊 mute] │        │  ← bottom-right of bezel
│      └─────────────┘        │
│                             │
│  Instagram. Tap. Train.     │  ← optional sub-line, secondary text
│  Unlock. Repeat.            │
│                             │
│  ┌───────────────────────┐  │
│  │  Show me more →       │  │  ← gradient CTA
│  └───────────────────────┘  │
└─────────────────────────────┘
```

**Headline:** "Watch Memo take the controls back." (matches the empathy line callback)

**Sub-line (optional):** "Instagram. Tap. Train. Unlock. Repeat." — terse, mirrors the loop the video shows. Cut if it crowds the layout.

**Phone bezel:** SwiftUI-rendered iPhone frame (rounded corners + Dynamic Island notch placeholder). Aspect locked to the video. Subtle drop shadow for depth on the dark page. ~280pt wide × proportional height (fits comfortably with header + CTA).

**Video player:** `AVPlayer` + `AVPlayerLayer` wrapped in a `UIViewRepresentable`. Auto-loops via `AVPlayerLooper`. Muted on entry. Mute icon overlays bottom-right corner of the video (not the bezel — inside the screen area).

**CTA:** "Show me more →" — same gradient style as existing onboarding CTAs (`gradientButton()` modifier). Visible from frame 1, not skip-gated. Routes to goals page (now page 6).

**Animations on appear:**
- Headline fades + offsets up (existing onboarding pattern, ~0.34s after page transition)
- Phone bezel scales from 0.96 → 1.0 (~0.4s)
- Video starts playing immediately on appear; pauses on disappear (releases decoder)

## Auto-start prerequisite (ships first, separately)

Currently when the user taps the shield's "Train" button, they get a notification, tap it, and land on the exercise's setup screen. Two of those steps are friction.

The notification step **cannot be removed** — `ShieldActionExtension` runs in a sandboxed extension process and cannot launch the host app directly. This is an iOS platform constraint, not a Memori choice. Every app in the category (Opal, Brick, ScreenZen, Jomo) hits the same wall.

The setup-screen step **can be removed**. Two-line plan:

1. **`DeepLinkRouter`** — when the source is a Focus unlock, attach an `autoStart: true` flag to the routed exercise.
2. **Exercise view** (start with `ReactionTimeView` since the demo will use it) — when `autoStart` is true on `.onAppear`, transition setup → playing immediately, with a 1-second "3 · 2 · 1" countdown overlay so the user isn't surprised. Skip the "Tap to begin" affordance.

If this works for ReactionTime, generalize to other games later. For the demo, only ReactionTime needs to support it.

**Sequence:** ship the auto-start change → record the demo against the new flow → ship the demo screen. This avoids recording outdated friction.

## App Store reuse plan

Same `onboarding_demo.mp4` powers three placements:

1. **In-app demo screen** (this spec)
2. **App Store preview video** — App Store Connect accepts a 15–30s preview video per locale. The 6-second loop can be padded with two beats of "before" framing (Instagram doomscrolling) + a closing card ("Memo. Block apps. Train your brain.") to hit 15s. Locale: en-US first; localize copy cards if conversion lift justifies translation cost.
3. **App Store screenshots** — pull stills from the recording at the four most expressive frames: tap, shield, score, unlock. Add screenshot overlay text using existing ASO screenshot system (`AppStore/metadata.md` references). Defer screenshot redo until after the v2.0 metadata push to avoid two redos.

## Out of scope

- Localizing the demo video (en-US only at launch)
- A/B testing demo placement vs. no-demo (wait for baseline conversion data on v2.0)
- Interactive simulated demo as fallback (we have the FamilyControls dev entitlement; recording on real device is fine)
- Generalizing auto-start to all 10 games (only ReactionTime needed for the demo recording)
- Demo of any game other than ReactionTime (one game, one loop, one story)

## Decisions locked

- Real recording, not simulated UI
- Phone-in-phone bezel framing, not full-bleed
- Headline: "Watch Memo take the controls back."
- Editorial cut B (skip notification step in recording)
- Auto-start ships before recording
- ReactionTime is the demo game
- 6 seconds total runtime
- Muted by default, mute toggle present
- CTA visible from frame 1
- Page inserted at index 5; existing pages shift +1
