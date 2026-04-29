# Plan Reveal Rev 5 Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the rev 5 polish — fix Beat 2 content drift (CTA copy, top padding, Earn row value), center the stakes hero number vertically, and tighten Beat 1's hero block so the eyebrow + number + subtitle read as one labeled unit.

**Architecture:** All edits are in `MindRestore/Views/Onboarding/OnboardingNewScreens.swift`. Phase 1 is content-only (string + value + padding edits). Phase 2 splits `cinematicProjectionHero` into two views (`cinematicProjectionHero` keeps top-anchored content; new `heroNumberBlock` owns the number + caption stack), moves the conditional 122pt frame inside `heroNumber`, and restructures the body's `.stakes` and `.reclaim` branches with Spacer-based vertical centering.

**Tech Stack:** Swift 5.x, SwiftUI (iOS 17+), `xcodebuild` CLI for compile/install, `xcrun devicectl` for device push.

**Spec:** `docs/superpowers/specs/2026-04-29-plan-reveal-rev5-polish-design.md` (commit 63a6890).

**Verification model:** Each phase ends with `xcodebuild` + `xcrun devicectl install` + an on-device visual check by the user. No unit tests for SwiftUI visual code per CLAUDE.md.

---

## File Structure

Single file: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift`. All edits inside `OnboardingPersonalSolutionView` (struct definition starts at line 115).

**Current structure (post-rev-5 at HEAD `392b31a`):**

| Region | Approx lines | Owner |
|---|---|---|
| `body` property | 216–272 | Three-way switch on `revealBeat` |
| `cinematicProjectionHero` | 284–346 | Eyebrow + headline + Spacer + number + subtitle (split into stakes/reclaim via `isReclaim` flag) |
| `heroNumber(numberAccent:)` | 354–397 | Hours/breakdown form ZStack (callsite wraps with `.frame(height: 122)`) |
| `screenTimeSourcePill` | 402–415 | Stakes-only pill |
| `beat1Extras` | 418–462 | Bar + TODAY/AGE 60 markers + corporate punch |
| `beat1CTAButton` | 464–488 | Beat 1 "See the plan →" |
| `planBeatLayout` | 496–559 | Beat 2 hero + plan card + bridge + safeAreaInset CTA |
| `planCard` | 561–593 | Tactical color-coded stack (calls `planCardRow` × 4) |
| `unlockPlanButton` | 594–614 | Beat 2 CTA, currently titled "Show what changes" |
| `planCardRow(...)` | 898–937 | Single row (label + detail + value) |

**Post-polish structure:**

- `cinematicProjectionHero` shrinks to ONLY the top-anchored content: pill + eyebrow + headline. No more Spacer, no more number/caption.
- New `heroNumberBlock` owns the number + caption stack (was previously the lower half of `cinematicProjectionHero`).
- `heroNumber` internally owns its conditional frame height (122pt for hours form, intrinsic for breakdown form).
- `body`'s `.stakes` branch arranges `cinematicProjectionHero` (top) + Spacer + `heroNumberBlock` (centered) + Spacer.
- `body`'s `.reclaim` branch arranges Spacer + tight `cinematicProjectionHero + heroNumberBlock` block + Spacer + `beat1Extras`.
- `unlockPlanButton`'s title flips to "Take my brain back".
- `planBeatLayout`'s top padding flips to 12.
- `planCard`'s Earn-row value flips to "your call".

---

## Phase 0: Pre-flight

### Task 0.1: Confirm clean baseline

- [ ] **Step 1: Verify git state**

```bash
git status -s | head -10 && echo "---" && git log --oneline -5
```

Expected: branch `v2.0-focus-mode`, latest commits include `63a6890 docs(spec): plan reveal rev 5 polish` and `392b31a feat(plan-reveal): Beat 2 brain-trainer hero + bridge — rev 5 final layout`. Working tree may have uncommitted edits in OTHER files (FocusUnlocksReport, ContentView, etc.) — leave those alone.

- [ ] **Step 2: Confirm baseline rev 5 build works**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

Expected: `** BUILD SUCCEEDED **`.

---

## Phase 1: Beat 2 content drift (lowest risk)

**Goal:** Three small content/copy edits on Beat 2. No layout work. Self-contained, verifiable on device, low risk.

### Task 1.1: Beat 2 content fixes

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — three discrete edits inside `OnboardingPersonalSolutionView`.

- [ ] **Step 1: Change `unlockPlanButton`'s title**

Find the line containing `Text("Show what changes")` (currently line 597 inside `unlockPlanButton`). Replace the literal:

```swift
                Text("Show what changes")
```

with:

```swift
                Text("Take my brain back")
```

Don't change anything else in `unlockPlanButton` — the arrow image, font, padding, background, shadow all stay identical.

- [ ] **Step 2: Reduce `planBeatLayout` top padding**

Find `.padding(.top, 28)` inside `planBeatLayout` (currently line 539). Change to:

```swift
        .padding(.top, 12)
```

- [ ] **Step 3: Change Earn row value**

Find the four `planCardRow(...)` calls inside `planCard` (lines 561–593). The second call configures the Earn row. Change:

```swift
            planCardRow(
                color: AppColors.accent,
                label: "Earn",
                detail: "15 min unlocked per win",
                value: "15 min",
                index: 1
            )
```

to:

```swift
            planCardRow(
                color: AppColors.accent,
                label: "Earn",
                detail: "15 min unlocked per win",
                value: "your call",
                index: 1
            )
```

Don't touch the `detail:` string — the spec only changes the trailing `value:`. The detail keeps "15 min" because that's the default behavior, not the user-set value being labeled.

- [ ] **Step 4: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

Expected: `** BUILD SUCCEEDED **`. Pre-existing warnings in unrelated files are fine.

- [ ] **Step 5: Install on device**

```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C \
  build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

Report the last 3 lines.

- [ ] **Step 6: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
fix(plan-reveal): Beat 2 content polish — CTA copy, top padding, Earn row

Three on-device polish fixes for Beat 2:

  - CTA "Show what changes →" → "Take my brain back →" so the button
    commits to the plan instead of describing the next page (which IS
    the comparison — "Same phone. Different rules.").
  - planBeatLayout padding(.top, 28) → padding(.top, 12). Eyebrow now
    sits ~71pt from the top of screen on iPhone Pro models — tight
    breathing room without crowding the status bar.
  - Earn row value "15 min" → "your call". The unlock-minutes setting
    is user-configurable in Memo's settings; the placeholder mirrors
    the Block row's "pick yours" so the two configurable rows share
    visual symmetry.

Per spec decisions Q3a-A, Q3b-A, Q3c-A.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: User on-device verification gate**

After committing, the user verifies on device. Expected:

- Beat 2 starts higher up the screen (less white space above MEMO'S PLAYBOOK eyebrow).
- Earn row's trailing value reads "your call" in accent blue.
- Beat 2 CTA reads "Take my brain back →".
- Tapping the CTA still advances to the comparison page (`OnboardingComparisonView`) — no flow break.

**Stop here. Wait for user sign-off before starting Phase 2.**

---

## Phase 2: Stakes hero centering + Beat 1 hero density

**Goal:** Restructure `cinematicProjectionHero` to split top-anchored content from the centered hero block, then update the body's `.stakes` and `.reclaim` branches to use vertical centering. After this phase, the stakes count-up sits at vertical center (not bottom-stuck), and Beat 1's RECLAIMED + breakdown + subtitle read as one tight labeled unit.

### Task 2.1: Refactor — split `cinematicProjectionHero`, move `heroNumber` frame

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — refactor three regions: `cinematicProjectionHero` (lines 284–346), `heroNumber` (lines 354–397), and body's `.stakes` + `.reclaim` branches (lines 222–255).

This task does the full restructure as one atomic change because the three pieces are interdependent — the body's branches must reference the new view names introduced by the refactor for the file to compile.

- [ ] **Step 1: Rewrite `cinematicProjectionHero` (top-anchored content only)**

Replace the entire `private var cinematicProjectionHero: some View { ... }` body (lines 284–346) with this slimmer version:

```swift
    /// Top-anchored content for the stakes/reclaim states. Pill +
    /// eyebrow + headline. The number + caption block lives in
    /// `heroNumberBlock`, which the parent positions independently
    /// (centered for stakes, tight under this view for reclaim).
    private var cinematicProjectionHero: some View {
        let isReclaim = revealBeat == .reclaim
        let eyebrowAccent = isReclaim ? AppColors.accent : AppColors.coral

        return VStack(alignment: .leading, spacing: 10) {
            // Screen Time provenance pill — only on stakes
            if !isReclaim {
                screenTimeSourcePill
                    .transition(.opacity)
            }

            // Eyebrow
            Text(isReclaim ? "RECLAIMED" : "WITHOUT MEMO")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(eyebrowAccent)
                .contentTransition(.opacity)

            // Stakes-only headline ("You're giving social media giants").
            // Fades out at the cut.
            if !isReclaim {
                Text("You're giving social\nmedia giants")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.92))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
```

This view keeps the eyebrow's `.contentTransition(.opacity)` so the rev-5 cut animation (eyebrow flips coral "WITHOUT MEMO" → accent "RECLAIMED") still works. The Spacer, the number, the subtitle, and the HOURS caption are all GONE — they move to `heroNumberBlock` next.

- [ ] **Step 2: Add new `heroNumberBlock` view immediately after `cinematicProjectionHero`**

Insert this view directly below the rewritten `cinematicProjectionHero`:

```swift
    /// The hero number + caption stack. On stakes: animated count-up
    /// in coral with HOURS + climbing breakdown subtitle. On reclaim
    /// + .hours: snapped reclaimedHoursText with "hours back in your
    /// life" subtitle. On reclaim + .breakdown: savedBreakdownText
    /// with the same subtitle. The parent body chooses where this
    /// view sits relative to `cinematicProjectionHero` — vertically
    /// centered for stakes, tight under the eyebrow for reclaim.
    private var heroNumberBlock: some View {
        let isReclaim = revealBeat == .reclaim
        let numberAccent: Color = isReclaim
            ? AppColors.accent
            : AppColors.coral.interpolated(with: AppColors.coralDeep, by: countProgress)

        return VStack(alignment: .leading, spacing: 6) {
            heroNumber(numberAccent: numberAccent)

            if isReclaim {
                Text("hours back in your life")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                    .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HOURS")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))

                    Text(lifeBreakdownText)
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(AppColors.coral)
                        .contentTransition(.numericText(value: Double(animatedProjectionHours)))
                }
            }
        }
    }
```

This is the lower half of the previous `cinematicProjectionHero`, lifted into its own view with the spacing tightened. Note `spacing: 6` between the `heroNumber` and the subtitle (so on Beat 1, "4 YEARS · 132 DAYS" → "hours back in your life" reads as one unit). The stakes HOURS/breakdown caption now uses `spacing: 6` too so it reads tight (was 10 in the old code).

- [ ] **Step 3: Move `heroNumber`'s frame logic inside the function**

Replace the entire `heroNumber(numberAccent:)` function (lines 354–397) with this version that owns its own frame height conditionally:

```swift
    /// The hero number block with the slash overlay. Two visual states:
    /// - hours form (during stakes count-up AND immediately post-cut):
    ///   shows `animatedHoursText` while .stakes, `reclaimedHoursText`
    ///   while .reclaim + .hours. Frame height locks to 122pt so the
    ///   slash overlay has consistent room across the cut animation.
    /// - breakdown form (post-dwell): shows `savedBreakdownText`. No
    ///   slash. Height is intrinsic so the subtitle sits directly
    ///   under the number — no residual 80pt of empty space.
    @ViewBuilder
    private func heroNumber(numberAccent: Color) -> some View {
        let useHoursForm = heroFormat == .hours || revealBeat == .stakes

        ZStack(alignment: .leading) {
            if useHoursForm {
                let displayText = revealBeat == .stakes ? animatedHoursText : reclaimedHoursText
                let numericValue = revealBeat == .stakes
                    ? Double(animatedProjectionHours)
                    : Double(savedHoursTotal)

                Text(displayText)
                    .font(.system(size: 92, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(numberAccent)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: numericValue))
                    .shadow(
                        color: (revealBeat == .stakes ? AppColors.coral : AppColors.accent).opacity(0.28),
                        radius: 18, y: 8
                    )
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(AppColors.accent)
                                .frame(width: proxy.size.width, height: 8)
                                .scaleEffect(x: slashProgress, y: 1, anchor: .leading)
                                .offset(y: proxy.size.height / 2 - 4)
                                .opacity(slashOpacity)
                                .shadow(color: AppColors.accent.opacity(0.55), radius: 10, y: 0)
                        }
                        .allowsHitTesting(false)
                    }
                    .transition(.opacity)
            } else {
                // .reclaim + .breakdown — drop the slash, show breakdown text.
                Text(savedBreakdownText)
                    .font(.system(size: 39, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .shadow(color: AppColors.accent.opacity(0.32), radius: 16, y: 8)
                    .transition(.opacity)
            }
        }
        .frame(height: useHoursForm ? 122 : nil, alignment: .leading)
    }
```

Differences from the rev-5 implementation:
- Adds `let useHoursForm = ...` for the same condition the inner `if` uses (DRY).
- Moves the `.frame(height: 122)` from the OUTER callsite (was on `heroNumber(...).frame(height: 122)` inside the old `cinematicProjectionHero`) INTO the function body, conditional on `useHoursForm`. For breakdown form the height is `nil` (intrinsic — the 39pt text decides its own height).

- [ ] **Step 4: Update body's `.stakes` and `.reclaim` branches**

Replace the body's `Group { switch revealBeat { ... } }` block (lines 221–259) with this version that wires `cinematicProjectionHero` and `heroNumberBlock` independently per branch:

```swift
                Group {
                    switch revealBeat {
                    case .stakes:
                        VStack(alignment: .leading, spacing: 0) {
                            cinematicProjectionHero
                                .padding(.top, 38)
                                .opacity(headlineAppeared ? 1 : 0)
                                .offset(y: headlineAppeared ? 0 : 10)

                            Spacer(minLength: 24)

                            heroNumberBlock
                                .opacity(headlineAppeared ? 1 : 0)

                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 28)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    case .reclaim:
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer(minLength: 0)

                            VStack(alignment: .leading, spacing: 4) {
                                cinematicProjectionHero
                                heroNumberBlock
                            }

                            Spacer(minLength: 24)

                            beat1Extras
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 38)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .safeAreaInset(edge: .bottom) {
                            beat1CTAButton
                                .padding(.horizontal, 32)
                                .padding(.bottom, 16)
                                .padding(.top, 8)
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.pageBg.opacity(0), AppColors.pageBg.opacity(0.85), AppColors.pageBg],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .ignoresSafeArea(edges: .bottom)
                                )
                        }
                        .transition(.opacity)
                    case .plan:
                        planBeatLayout
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
```

Key changes vs rev-5:
- **Stakes branch:** `cinematicProjectionHero` + `Spacer` + `heroNumberBlock` + `Spacer` — the two Spacers around `heroNumberBlock` are equal-flexible, so the number block is vertically centered in the space below the top-anchored content (per spec Q1=B). The number block also fades in alongside the headline via `headlineAppeared`.
- **Reclaim branch:** outer Spacer (top) → tight `VStack(spacing: 4) { cinematicProjectionHero + heroNumberBlock }` → outer Spacer (middle, 24pt min) → `beat1Extras`. The hero block is centered in the space above `beat1Extras` (per spec Q2=Y). The eyebrow + breakdown number + subtitle render with 4pt + 6pt internal gaps so they're a tight labeled unit.
- The CTA's `safeAreaInset` wrapper, `.transition(.opacity)`, and `.padding(.top, 38)` all stay identical.

- [ ] **Step 5: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

Expected: `** BUILD SUCCEEDED **`. If errors mention `heroNumberBlock` not found, double-check Step 2's view was saved into the file. If errors mention `Spacer(minLength:)` or layout mismatches, re-read Step 4 carefully.

- [ ] **Step 6: Install on device**

```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C \
  build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

Report last 3 lines.

- [ ] **Step 7: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
fix(plan-reveal): center stakes hero, tighten Beat 1 hero density

Splits cinematicProjectionHero into two views so the parent body can
position them independently per beat:

  - cinematicProjectionHero now owns ONLY the top-anchored content
    (pill + eyebrow + headline). No Spacer, no number.
  - New heroNumberBlock owns the number + caption stack with tight
    6pt internal spacing.
  - heroNumber's 122pt frame moves inside the function, conditional
    on hours form. Breakdown form is intrinsic-height — no residual
    80pt of empty space above the subtitle.

Body's .stakes branch arranges top + Spacer + number-block + Spacer
so the number is vertically centered (no longer bottom-stuck). Body's
.reclaim branch arranges Spacer + tight 4pt-gap eyebrow/number/subtitle
block + Spacer + beat1Extras so the hero reads as one labeled unit.

Per spec decisions Q1=B (stakes centered) and Q2=Y (Beat 1 dense
centered hero).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: User on-device verification gate**

Reset onboarding via the Profile debug toggle. Step to plan reveal. Expected:

**Stakes:**
- Pill + WITHOUT MEMO eyebrow + "You're giving social media giants" headline anchored at the top.
- Empty breathing room above the count-up number (intentional — the number is centered).
- Big coral count-up number sits in the vertical middle of the screen.
- HOURS caption + climbing "X YEARS · Y DAYS" subtitle directly under the number with tight 6pt gaps.
- Number does NOT touch the bottom edge.

**Cut:**
- Slash hits, recoil happens, number snaps to ~38,000.
- Eyebrow flips coral "WITHOUT MEMO" → accent "RECLAIMED".
- Stakes headline + HOURS caption + breakdown subtitle fade out.
- "hours back in your life" subtitle fades in directly under the number.
- ~700ms post-snap, the 38,000 cross-fades to "4 YEARS · 132 DAYS".

**Beat 1 (post-cut, settled):**
- RECLAIMED eyebrow + "4 YEARS · 132 DAYS" + "hours back in your life" stack as ONE tight visual block (4pt + 6pt internal gaps). The subtitle clearly labels the number above.
- Block is centered in the upper portion of the screen — no longer huge empty upper half.
- Bar + corporate punch + CTA in the lower portion.
- Tapping "See the plan →" advances to Beat 2 (Phase 1's polish should be visible: top padding tighter, "your call" Earn row, "Take my brain back →" CTA).

If anything looks broken, report what looks wrong — fix before declaring complete.

---

## Self-review checklist

After completing all phases, verify against the spec:

| Spec requirement | Implemented in |
|---|---|
| Q1 — Stakes centered hero | Phase 2 Task 2.1 Step 4 (.stakes branch with Spacer-Spacer wrapping heroNumberBlock) |
| Q2 — Beat 1 dense centered hero | Phase 2 Task 2.1 Step 4 (.reclaim branch with tight 4pt VStack containing heroNumberBlock) |
| Q3a — CTA "Take my brain back →" | Phase 1 Task 1.1 Step 1 |
| Q3b — Beat 2 padding(.top, 12) | Phase 1 Task 1.1 Step 2 |
| Q3c — Earn row "your call" | Phase 1 Task 1.1 Step 3 |
| heroNumber frame conditional on hours form | Phase 2 Task 2.1 Step 3 |
| cinematicProjectionHero/heroNumberBlock split | Phase 2 Task 2.1 Steps 1 + 2 |
| No regression in Beat 1 → Beat 2 transition | Phase 2 Task 2.1 Step 8 (verify advanceToPlan() still fires from Beat 1 CTA, and Beat 2 → comparison page still flows) |

If any line is missing an implementation reference, add the task in the relevant phase before declaring complete.
