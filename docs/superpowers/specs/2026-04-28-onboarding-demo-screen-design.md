# Onboarding Demo Screen + Subscriber Review Prompt — Design Spec (2026-04-28)

## Goal

Two related onboarding upgrades:

1. **Welcome page demo:** integrate a 6-second product demo (real recording of the Instagram-block → train → unlock loop) into the welcome page, hand-off from the existing Memo-pushing-apps animation. Same asset doubles as App Store preview video and screenshot source.
2. **Subscriber review prompt:** call `AppStore.requestReview` for users who complete the onboarding paywall purchase. Highest-conversion star-rating moment available — they just paid.

Welcome thematic fit: the existing animation is the *metaphor* (Memo pushes apps away). The demo is the *receipts* (here it actually happens on a real iPhone). Animation hands off to bezel — the abstract becomes concrete in the same screen real estate.

## Where the demo goes

**Welcome page only.** No insertion between empathy and goals (earlier draft of this spec proposed that — superseded). One slot, one demo.

Welcome page choreography (option B — single focal point handoff):

| Beat | Time (approx) | What happens |
|---|---|---|
| 1. Headline appears | 0.0s | "Apps want you. Memo wants you back." (existing) |
| 2. Bouncer hero animates | 0.3s–2.5s | Existing `WelcomeBouncerHero` — Memo shoves apps off-screen |
| 3. Hero fades out | 2.5s–3.0s | `WelcomeBouncerHero` opacity 1 → 0, slight scale-down |
| 4. **Bezel materializes** | 3.0s–3.4s | Phone-in-phone bezel scales from 0.92 → 1.0 + fades in, occupying the area `WelcomeBouncerHero` just used |
| 5. Demo begins looping | 3.4s+ | `AVPlayerLooper` plays the 6s recording, muted by default |
| 6. Subline + CTA visible | already visible | "Block Apps. Train Your Brain." + "Let's go" CTA stay in place |

Existing welcome state vars (`welcomeAppsVisible`, `welcomeMemoVisible`, etc.) gate steps 1–2. Add new state vars `welcomeBezelVisible`, `welcomeBezelScale` for steps 3–5. The transition between hero and bezel is the cinema beat.

The headline + subline + CTA stay structurally where they are. Only the middle (`WelcomeBouncerHero` slot) changes from animation → bezel.

**No page-flow changes.** No new page index, no shifting of pages 1–15. This is purely additive on page 0.

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

**Sound:** muted-by-default with a tap-to-unmute toggle inside the bezel screen area. Forcing audio in onboarding is a retention killer.

## The bezel + video implementation

**Phone bezel:** SwiftUI-rendered iPhone frame — rounded rectangle, ~3pt black border, Dynamic Island placeholder at top, ~28pt corner radius. Aspect locked to the video. Subtle drop shadow for depth on the dark page. Sized to roughly match the height the `WelcomeBouncerHero` previously occupied (~330pt height, ~180–200pt width to keep iPhone aspect).

**Video player:** `AVPlayer` + `AVPlayerLayer` wrapped in a `UIViewRepresentable`. Auto-loops via `AVPlayerLooper` over an `AVQueuePlayer`. Muted on entry. Mute icon (`speaker.slash.fill` / `speaker.fill`) overlays bottom-right corner of the screen area inside the bezel. Tap toggles mute.

**Lifecycle:** Player starts loading on `welcomePage.onAppear`, begins playing when the bezel materializes (step 4 above). Pauses on `welcomePage.onDisappear`. AVPlayer instance is owned by a `@StateObject` view model so it survives view re-renders within the page.

## Auto-start prerequisite (ships first, separately)

Currently when the user taps the shield's "Train" button, they get a notification, tap it, and land on the exercise's setup screen. Two of those steps are friction.

The notification step **cannot be removed** — `ShieldActionExtension` runs in a sandboxed extension process and cannot launch the host app directly. This is an iOS platform constraint, not a Memori choice. Every app in the category (Opal, Brick, ScreenZen, Jomo) hits the same wall.

The setup-screen step **can be removed**. Two-line plan:

1. **`DeepLinkRouter`** — when the source is a Focus unlock, attach an `autoStart: true` flag to the routed exercise.
2. **`ReactionTimeView`** — when `autoStart` is true on `.onAppear`, transition setup → playing immediately, with a 1-second "3 · 2 · 1" countdown overlay so the user isn't surprised. Skip the "Tap to begin" affordance.

If this works for ReactionTime, generalize to other games later. For the demo, only ReactionTime needs to support it.

**Sequence:** ship the auto-start change → record the demo against the new flow → ship the welcome demo screen.

## Subscriber review prompt

**When:** immediately after the user successfully purchases via the onboarding paywall, ~2 seconds after the success state has rendered (give the success animation room to land first, then prompt).

**Why post-paywall:** they paid. That's the highest-commitment positive interaction we can give Apple's `requestReview` API — and Apple's docs explicitly endorse this timing. Cal AI, Rise, RoutineFlow, and most modern subscription apps do this. Reviews from this cohort skew 4.7+ stars.

**Implementation:**

```swift
// Services/ReviewPromptService.swift — new method
@MainActor
static func requestForNewSubscriber() {
    let defaults = UserDefaults.standard
    let lastPrompt = defaults.double(forKey: "lastReviewPromptDate")
    let daysSincePrompt = (Date.now.timeIntervalSince1970 - lastPrompt) / 86400
    guard daysSincePrompt > 90 else { return }   // respect the 90-day cooldown shared with the engagement-based prompt
    
    defaults.set(Date.now.timeIntervalSince1970, forKey: "lastReviewPromptDate")
    if let scene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
        AppStore.requestReview(in: scene)
    }
}
```

Trigger site: in `PaywallView` (or wherever `StoreService.purchase()` resolves with success) — schedule with `DispatchQueue.main.asyncAfter(deadline: .now() + 2.0)`. Only fire on first-time purchase, not restore (`isRestore` flag).

**Why guarded by the same 90-day cooldown:** prevents users who subscribe, churn, then re-subscribe within 90 days from getting double-prompted. Apple's 3-per-365-day limit would catch it anyway, but our cooldown is friendlier.

**No new gate beyond cooldown.** Don't gate on "completed first exercise" or anything else — the user already cleared the highest possible bar by paying. Adding more gates wastes the moment.

## App Store reuse plan

Same `onboarding_demo.mp4` powers three placements:

1. **In-app welcome demo** (this spec)
2. **App Store preview video** — App Store Connect accepts a 15–30s preview video per locale. The 6-second loop can be padded with two beats of "before" framing (Instagram doomscrolling) + a closing card ("Memo. Block apps. Train your brain.") to hit 15s. Locale: en-US first; localize copy cards if conversion lift justifies translation cost.
3. **App Store screenshots** — pull stills from the recording at the four most expressive frames: tap, shield, score, unlock. Add screenshot overlay text using existing ASO screenshot system (`AppStore/metadata.md` references). Defer screenshot redo until after the v2.0 metadata push to avoid two redos.

## Out of scope

- Localizing the demo video (en-US only at launch)
- A/B testing demo placement vs. no-demo (wait for baseline conversion data on v2.0)
- Interactive simulated demo as fallback (we have the FamilyControls dev entitlement; recording on real device is fine)
- Generalizing auto-start to all 10 games (only ReactionTime needed for the demo recording)
- Demo of any game other than ReactionTime (one game, one loop, one story)
- Lowering the engagement-based prompt threshold (5+ exercises / 2+ streak stays as-is)
- Prompting non-paying users at end of onboarding (only paying users — wasted Apple-budget otherwise)

## Decisions locked

- Real recording, not simulated UI
- Phone-in-phone bezel framing, not full-bleed
- **Demo lives on welcome page (page 0), not as a new inserted page**
- Welcome page choreography: option B — animation hands off to bezel in the same screen area
- Existing welcome headline ("Apps want you. Memo wants you back.") stays — no new headline needed; the metaphor + receipts pairing makes the demo self-explanatory
- Editorial cut B (skip notification step in recording)
- Auto-start ships before recording
- ReactionTime is the demo game
- 6 seconds total runtime
- Muted by default, mute toggle inside bezel screen area
- Existing "Let's go" CTA stays
- **Subscriber review prompt fires ~2s post-paywall-success, gated only by the existing 90-day cooldown**
- First-time purchase only, not restores
