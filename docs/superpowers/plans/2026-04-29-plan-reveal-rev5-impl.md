# Plan Reveal Rev 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the rev 5 plan-reveal redesign — two-beat post-cut sequence (Beat 1 reclaim + corporate punch / Beat 2 brain-trainer hero + tactical color-coded plan card), unambiguous cut moment via `heroFormat` enum, no-scroll layouts, defeated backdrop on both beats, Screen Time provenance pill on stakes.

**Architecture:** Layered modifications to `OnboardingPersonalSolutionView` in `OnboardingNewScreens.swift`. Phase ordering produces a working app at each phase — refactor first, then cut moment, then Beat 1, then Beat 2. Each phase is a verifiable on-device checkpoint. No new files, no new assets, no `.xcodeproj` edits.

**Tech Stack:** Swift 5.x, SwiftUI (iOS 17+), `xcodebuild` CLI for compile/install, `xcrun devicectl` for device push.

**Spec:** `docs/superpowers/specs/2026-04-29-plan-reveal-rev5-design.md` (read all of it before starting).

**Verification model:** This codebase has no unit tests for SwiftUI visual code per CLAUDE.md ("verify-changes" is the loop). Each phase ends with `xcodebuild` + `xcrun devicectl install` + on-device visual check. Phase 5 additionally requires iPhone SE 3rd gen + iPhone 13 mini simulator runs.

---

## File Structure

Single file is touched: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` (lines 115–1011 for `OnboardingPersonalSolutionView` and `PlanRevealBackdrop`). All other changes are inside that file.

**Boundaries to preserve:**

| Region | Lines (current) | Owner |
|---|---|---|
| `OnboardingPersonalSolutionView` struct | 115–805 | Top-level page |
| `cinematicProjectionHero` view | 251–381 | Stakes + Beat 1 hero block (eyebrow + number + subtitle) |
| `ghostNumberStack` view | 383–397 | **DELETE** in Phase 2 |
| `planBeatLayout` view | 406–498 | **REWRITE** across Phase 4 + Phase 5 |
| `planCard` view + `planCardRow` helper | 507–545, ~548–600 | **REWRITE** in Phase 4 |
| `unlockPlanButton` view | 548–566 | Generic CTA, reused by Beat 1 + Beat 2 |
| `startRevealAnimation` async func | 683–771 | Heavily edited in Phase 2 + Phase 3 |
| `LifeBar` private struct | ~810–845 | Untouched |
| `PlanRevealBackdrop` private struct | ~870–end | Param rename + 3 internal references |

**Reference helpers already present (do not re-create):** `savedHoursTotal`, `savedBreakdownText`, `residualBreakdownText`, `reclaimedHoursText`, `lifeBreakdownText`, `projectionIsEstimate` (let), `projectedHoursText`, `animatedHoursText`, `feedTileLogos`, `revealPlanRows()`, `countProjection()`, `memoReductionFraction`.

---

## Phase 0: Pre-flight

### Task 0.1: Confirm clean baseline

- [ ] **Step 1: Verify branch + uncommitted state**

```bash
git status -s
git log --oneline -5
```
Expected: branch is `v2.0-focus-mode`, recent commits include `39b2dd6 docs(spec): plan reveal rev 5 — codex pass-2 nits`.

- [ ] **Step 2: Run baseline build to confirm rev 4 still compiles**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`. Pre-existing warnings (e.g., `'main actor-isolated static property'` in GameCenterService) are fine — unrelated.

- [ ] **Step 3: Confirm spec is at expected commit**

```bash
git log --oneline docs/superpowers/specs/2026-04-29-plan-reveal-rev5-design.md
```
Expected: latest commit is the codex pass-2 nits patch.

---

## Phase 1: Foundation refactor (no visual change)

**Goal:** Pure renames + scaffolding. Build succeeds. App looks identical to rev 4 on device.

### Task 1.1: Rename `RevealBeat.withMemo` → `RevealBeat.reclaim`

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — every `.withMemo` reference inside `OnboardingPersonalSolutionView`.

- [ ] **Step 1: Rename the enum case**

Locate the `RevealBeat` enum (currently lines 125–129) and rename:

```swift
private enum RevealBeat {
    case stakes
    case reclaim   // was .withMemo — Beat 1: post-cut hero + corporate punch + CTA
    case plan
}
```

- [ ] **Step 2: Replace all `withMemo` references**

Search the file for `withMemo` (case-sensitive). Expected hits (lines may shift):
- `cinematicProjectionHero` body — local `let withMemo = revealBeat == .withMemo` → `let isReclaim = revealBeat == .reclaim`. Update all `withMemo` reads in that scope to `isReclaim`.
- `if withMemo` branches — rewrite as `if isReclaim`.
- `revealBeat = .withMemo` inside `startRevealAnimation` → `revealBeat = .reclaim`.

Run `grep -n "withMemo" MindRestore/Views/Onboarding/OnboardingNewScreens.swift` after — expect zero hits.

- [ ] **Step 3: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
refactor(plan-reveal): rename RevealBeat.withMemo → .reclaim (rev 5 prep)

Pure rename. No behavior change. Sets up the rev 5 state-model split
where .reclaim owns Beat 1 (post-cut hero + corporate punch).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

### Task 1.2: Rename `PlanRevealBackdrop.isPlan` → `isDefeated` and update callsites

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — `PlanRevealBackdrop` struct (currently lines ~945–end) + `revealBackdrop(size:)` callsite (line ~241).

- [ ] **Step 1: Rename the struct property**

In `PlanRevealBackdrop`, change:

```swift
let isStakes: Bool
let isPlan: Bool
```

to:

```swift
let isStakes: Bool
let isDefeated: Bool   // true when revealBeat != .stakes — apps recoiled, dim grid
```

- [ ] **Step 2: Update internal references inside the struct**

There are exactly two places inside `PlanRevealBackdrop` that read `isPlan`:

a. The halo opacity (currently around line 997):

```swift
.fill(accent.opacity(isPlan ? 0.14 : 0.24))
```
→
```swift
.fill(accent.opacity(isDefeated ? 0.14 : 0.24))
```

b. The grid opacity multiplier (currently around line 1008):

```swift
.opacity(isPlan ? 0.45 : 1)
```
→
```swift
.opacity(isDefeated ? 0.45 : 1)
```

c. The `tile(...)` helper's local `planOpacityMul` (currently line ~1057, in body of `tile`). This reads `isPlan`. Rename:

```swift
let planOpacityMul = isPlan ? 0.20 : 1.0
```
→
```swift
let planOpacityMul = isDefeated ? 0.20 : 1.0
```

(Variable name `planOpacityMul` is fine to keep — rev 4 baggage, scoped local.)

Run `grep -n "isPlan" MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — expect zero hits after.

- [ ] **Step 3: Update the callsite in `revealBackdrop(size:)`**

Currently:

```swift
PlanRevealBackdrop(
    isStakes: revealBeat == .stakes,
    isPlan: revealBeat == .plan,
    recoilProgress: recoilProgress,
    size: size,
    logos: feedTileLogos
)
```

Change to:

```swift
PlanRevealBackdrop(
    isStakes: revealBeat == .stakes,
    isDefeated: revealBeat != .stakes,   // Beat 1 + Beat 2 share defeated grid
    recoilProgress: recoilProgress,
    size: size,
    logos: feedTileLogos
)
```

- [ ] **Step 4: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
refactor(plan-reveal): rename PlanRevealBackdrop.isPlan → isDefeated

Beat 1 and Beat 2 will both want the defeated/recoiled grid behavior.
Parent now passes (revealBeat != .stakes) so the dim path activates on
.reclaim AND .plan instead of just .plan.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

### Task 1.3: Add `HeroFormat` enum + `heroFormat` state (unused yet)

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — add to `OnboardingPersonalSolutionView`'s state declarations.

- [ ] **Step 1: Add the enum and the state property**

Below the `RevealBeat` enum and alongside other `@State` declarations (around line 158, just after `cardGlowing`):

```swift
/// Drives the Beat 1 hero number's format. The cut snaps to .hours so
/// the user reads continuity with the count-up; ~700ms later we flip
/// to .breakdown ("4 YEARS · 132 DAYS") so the emotional weight lands.
private enum HeroFormat {
    case hours
    case breakdown
}
@State private var heroFormat: HeroFormat = .hours
```

- [ ] **Step 2: Reset heroFormat in `startRevealAnimation`**

In the reset block at the top of `startRevealAnimation` (currently around lines 687–693), add the reset:

```swift
recoilProgress = 0
slashProgress = 0
slashOpacity = 0
countProgress = 0
planBarProgress = 0
heroFormat = .hours    // NEW
cardGlowing = [false, false, false, false]
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|warning: 'heroFormat'|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`. SourceKit may flag `heroFormat` as unused — that's expected (Phase 2 wires it up). Don't suppress; it'll resolve on its own.

- [ ] **Step 4: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
feat(plan-reveal): add HeroFormat enum + heroFormat state (unused)

Scaffolding for the rev 5 cut-moment fix. The hero number snaps to
.hours (continuity with count-up) then flips to .breakdown after a
700ms dwell. Wired in Phase 2.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

### Task 1.4: Add unwired `advanceToPlan()` method

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — new method on `OnboardingPersonalSolutionView`.

- [ ] **Step 1: Add the method**

Add `advanceToPlan()` immediately above `revealPlanRows()` (currently line ~782 — find the existing `private func revealPlanRows() async {` and insert above it):

```swift
/// Beat 1 → Beat 2 transition, fired by Beat 1's "See the plan →" CTA.
/// Wired in Phase 3. Defined here in Phase 1 to keep the diff in
/// each phase tight.
@MainActor
private func advanceToPlan() {
    guard revealBeat == .reclaim else { return }
    withAnimation(.spring(response: 0.74, dampingFraction: 0.86)) {
        revealBeat = .plan
    }
    revealTask?.cancel()
    revealTask = Task { @MainActor in
        await revealPlanRows()
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`. SourceKit may flag `advanceToPlan` as unused — expected (Phase 3 wires it).

- [ ] **Step 3: Install + on-device smoke check**

```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C \
  build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

Open onboarding (Profile debug toggle to reset). Page through to the plan-reveal page. Expected: identical to pre-Phase-1 rev 4 — count-up climbs, slash hits, number halves to ~38k, page transitions to plan-card layout. **No visual regression.**

- [ ] **Step 4: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
feat(plan-reveal): add unwired advanceToPlan() for Beat 1 CTA (rev 5 prep)

Stub method that wraps the .reclaim → .plan transition + plan-row
reveal. Wired into the Beat 1 CTA in Phase 3 once that view exists.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 2: Cut moment + stakes pill (visual change #1)

**Goal:** Strip rev 4 `.withMemo` cosmetics. Hoist eyebrow + subtitle so they read from `revealBeat`. Decouple `recoilProgress` from `revealBeat` in the cut sequence. Add the Screen Time provenance pill. After this phase, the cut animation looks cleaner and the stakes page has a small pill above the eyebrow.

### Task 2.1: Strip rev 4 `.withMemo` cosmetic treatments from `cinematicProjectionHero`

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — `cinematicProjectionHero` body (currently lines 251–381) + `ghostNumberStack` (lines 383–397).

- [ ] **Step 1: Delete the `ghostNumberStack` view**

Currently around lines 383–397. Delete the entire `private var ghostNumberStack: some View { … }` block.

- [ ] **Step 2: Replace `cinematicProjectionHero` with the rev 5 unified hero**

Replace the entire `cinematicProjectionHero` body (lines 251–381) with:

```swift
private var cinematicProjectionHero: some View {
    let isReclaim = revealBeat == .reclaim
    let eyebrowAccent = isReclaim ? AppColors.accent : AppColors.coral
    let numberAccent: Color = isReclaim
        ? AppColors.accent
        : AppColors.coral.interpolated(with: AppColors.coralDeep, by: countProgress)

    return VStack(alignment: .leading, spacing: 16) {
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

        Spacer(minLength: isReclaim ? 4 : 30)

        // The hero number. Same screen position across stakes → reclaim.
        // During stakes: animatedHoursText (climbs).
        // During .reclaim + .hours: reclaimedHoursText (snapped, e.g. "38,000").
        // During .reclaim + .breakdown: savedBreakdownText (e.g. "4 YEARS · 132 DAYS").
        heroNumber(numberAccent: numberAccent)
            .frame(height: 122, alignment: .leading)

        // Subtitle stack
        if isReclaim {
            Text("hours back in your life")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                .transition(.opacity)
        } else {
            VStack(alignment: .leading, spacing: 10) {
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

- [ ] **Step 3: Add the `heroNumber(numberAccent:)` helper view**

Add directly below `cinematicProjectionHero`:

```swift
/// The hero number block with the slash overlay. Two visual states:
/// - hours form (during stakes count-up AND immediately post-cut):
///   shows `animatedHoursText` while .stakes, `reclaimedHoursText` while
///   .reclaim + .hours.
/// - breakdown form (post-dwell): shows `savedBreakdownText`.
@ViewBuilder
private func heroNumber(numberAccent: Color) -> some View {
    ZStack(alignment: .leading) {
        if heroFormat == .hours || revealBeat == .stakes {
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
}
```

- [ ] **Step 4: Add the `screenTimeSourcePill` view**

Add directly below `heroNumber`:

```swift
/// Small "● from your Screen Time" / "● estimated from your input"
/// pill above the stakes eyebrow. Builds trust at the count-up moment.
/// Driven by the existing `projectionIsEstimate` input.
private var screenTimeSourcePill: some View {
    HStack(spacing: 6) {
        Circle()
            .fill(AppColors.accent)
            .frame(width: 5, height: 5)
        Text(projectionIsEstimate ? "estimated from your input" : "from your Screen Time")
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(AppColors.textPrimary.opacity(0.4))
    }
}
```

- [ ] **Step 5: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`. If errors mention `ghostNumberStack` or removed cosmetics, search for stale references and remove.

- [ ] **Step 6: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
refactor(plan-reveal): unify cinematicProjectionHero, drop withMemo cosmetics

Hero is now one block whose content reads from revealBeat + heroFormat.
Drops the rev 4 .withMemo treatments per spec: ghost number stack,
"Memo cuts the damage in half" headline, "Memo turns scrolling into
reps" subtitle, mascot-unlocked. Adds the screenTimeSourcePill on
stakes for data provenance.

Hero number still in .hours form post-cut — Task 2.2 wires the
revealBeat decoupling and Task 2.3 wires the heroFormat flip.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

### Task 2.2: Decouple `revealBeat` from `recoilProgress` in the cut sequence

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — `startRevealAnimation` body, the cut-sequence section (currently lines 716–770).

- [ ] **Step 1: Edit the cut sequence**

Locate the cut sequence inside `startRevealAnimation` (look for `// The cut.` comment around line 716). Replace the block from `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` through the end of the function with this rev 5 sequence (delete the rev 4 trailing `revealBeat = .plan` block too — it goes away in this same edit):

```swift
            // The cut. Rev 5 sequence:
            // (1) recoil + slash sweep at slash-start (concurrent, no revealBeat change yet)
            // (2) at +0.8s, number snaps AND revealBeat flips to .reclaim in same withAnimation block
            // (3) at +1.10s, slash fades + planBarProgress draws in + Beat 1 elements enter
            // (4) at +1.50s, heroFormat flips to .breakdown
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // Slash + recoil — independent of revealBeat. Apps recoil while the
            // hero block is still showing the stakes count.
            withAnimation(.easeOut(duration: 0.5)) {
                slashProgress = 1.0
                slashOpacity = 1.0
            }
            withAnimation(.spring(response: 1.2, dampingFraction: 0.86)) {
                recoilProgress = 1.0
            }

            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }

            // Number snap + layout swap to .reclaim in the SAME withAnimation
            // block — the eyebrow / subtitle / headline crossfades all ride
            // this spring. heroFormat stays .hours so the snapped number
            // renders as `38,000` (continuity with the count-up).
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                animatedReclaimedHours = savedHoursTotal
                revealBeat = .reclaim
            }

            // 300ms breath, then slash fades + Beat 1 elements draw in
            // (lifeBar via planBarProgress). See spec animation table at
            // t=7.12s relative to page-enter.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                slashOpacity = 0
            }
            withAnimation(.easeOut(duration: 0.6)) {
                planBarProgress = 1
            }

            // 400ms more — slash fade is finishing — then flip the hero
            // number from .hours to .breakdown. Total post-snap dwell = 700ms.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.4)) {
                heroFormat = .breakdown
            }

            // startRevealAnimation EXITS here — Beat 1 dwells until user
            // taps "See the plan →", which calls advanceToPlan().
        }
    }
```

This deletes the entire trailing block that did `revealBeat = .plan` + `planBarProgress = 1` + `revealPlanRows()` auto-advance.

- [ ] **Step 2: Verify the auto-advance is gone**

```bash
grep -n "revealBeat = .plan" MindRestore/Views/Onboarding/OnboardingNewScreens.swift
```
Expected: only one hit, inside `advanceToPlan()` (added in Task 1.4). If `startRevealAnimation` still has `revealBeat = .plan`, delete that block.

- [ ] **Step 3: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Install + on-device check**

```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C \
  build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

Reset onboarding (Profile debug toggle), step to plan reveal. Expected:
- Stakes shows the new pill above "WITHOUT MEMO" eyebrow.
- Count-up climbs to 51,000 in coral.
- Slash hits, apps recoil. Number snaps to 38,000 (still hours form). Eyebrow flips to "RECLAIMED" in accent color, subtitle "hours back in your life" appears.
- ~700ms later, the 38,000 cross-fades to "4 YEARS · 132 DAYS".
- **The page does NOT auto-advance to the plan layout.** It dwells on the .reclaim hero (no bar, no corporate punch yet — Phase 3 adds those).

If the page tries to auto-advance, the `revealBeat = .plan` block is still in `startRevealAnimation`. Find and delete it.

- [ ] **Step 5: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
feat(plan-reveal): decouple recoil/snap, end startRevealAnimation at .reclaim

Slash + recoil now ride their own withAnimation block at slash-start.
revealBeat = .reclaim fires in the same block as the number snap, 800ms
later. heroFormat flips to .breakdown ~700ms after the snap, when the
slash fade completes. The auto-advance to .plan is removed —
startRevealAnimation exits at Beat 1, and the Beat 1 CTA (Phase 3)
will own the .reclaim → .plan transition via advanceToPlan().

Per spec implementation notes 1, 2, 6.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 3: Beat 1 layout (visual change #2)

**Goal:** Build the rest of Beat 1 — 2-color life bar, corporate punch, CTA. Wire the CTA to `advanceToPlan()`. After this phase, Beat 1 is fully functional: the cut lands on a finished page where the user can tap "See the plan →" to advance.

### Task 3.1: Add `beat1Extras` view + `beat1CTAButton` view

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — add new views.

- [ ] **Step 1: Add `beat1Extras` view**

Add directly below `screenTimeSourcePill`:

```swift
/// Beat 1 elements that enter under the hero after the cut: the 2-color
/// life bar with TODAY/AGE 60 markers, and the corporate-attack
/// punchline. Each element uses a SwiftUI transition with a small
/// per-element delay so they enter sequentially, not as a wall.
private var beat1Extras: some View {
    let lifeBarWidth: CGFloat = 280

    return VStack(alignment: .leading, spacing: 22) {
        // 2-color life bar
        VStack(alignment: .leading, spacing: 8) {
            LifeBar(
                savedFraction: CGFloat(Self.memoReductionFraction),
                progress: planBarProgress,
                width: lifeBarWidth,
                height: 14
            )

            HStack {
                Text("TODAY")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                Spacer()
                Text("AGE 60")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))
            }
            .frame(width: lifeBarWidth)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))

        // Corporate punch — the brand-voice rev 5 anchor.
        VStack(alignment: .leading, spacing: 4) {
            Text("Big tech is colonizing\nyour attention.")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColors.textPrimary.opacity(0.94))
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
            Text("Memo fights back.")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .italic()
                .foregroundStyle(AppColors.accent)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.10), value: revealBeat)
    }
}
```

- [ ] **Step 2: Add `beat1CTAButton`**

Add below `beat1Extras`:

```swift
/// Beat 1's "See the plan →" — fires advanceToPlan() (Phase 1 stub).
private var beat1CTAButton: some View {
    Button(action: advanceToPlan) {
        HStack(spacing: 8) {
            Text("See the plan")
            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .heavy))
        }
        .font(.system(size: 18, weight: .heavy, design: .rounded))
        .foregroundStyle(AppColors.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.textPrimary.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: AppColors.accent.opacity(0.34), radius: 22, y: 10)
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`. Warnings about unused `beat1Extras` / `beat1CTAButton` are fine — Task 3.2 wires them.

### Task 3.2: Wire Beat 1 into the body

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — `body` property of `OnboardingPersonalSolutionView` (currently lines 207–238).

- [ ] **Step 1: Replace the body's view branching**

Find the `var body: some View { GeometryReader { proxy in ZStack { ... } } }` block (currently around lines 207–238). Replace the inner `Group { if revealBeat == .plan { ... } else { ... } }` with three-way branching:

```swift
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                revealBackdrop(size: proxy.size)

                Group {
                    switch revealBeat {
                    case .stakes:
                        VStack(spacing: 0) {
                            cinematicProjectionHero
                                .padding(.horizontal, 28)
                                .padding(.top, 38)
                                .opacity(headlineAppeared ? 1 : 0)
                                .offset(y: headlineAppeared ? 0 : 10)
                            Spacer(minLength: 22)
                        }
                    case .reclaim:
                        VStack(alignment: .leading, spacing: 26) {
                            cinematicProjectionHero
                            beat1Extras
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 38)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
            }
        }
        .animation(.spring(response: 0.68, dampingFraction: 0.86), value: revealBeat)
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: headlineAppeared)
        .onAppear {
            startRevealAnimation()
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Install + on-device check**

```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C \
  build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

Reset onboarding, step to plan reveal. Expected:
- Cut animation lands cleanly. Number snaps to 38,000 (hours), then crossfades to "4 YEARS · 132 DAYS".
- 2-color life bar fades in below the hero (75% blue / 25% coral). TODAY · AGE 60 markers visible.
- Corporate punch fades in below the bar: "Big tech is colonizing your attention." + italic accent "Memo fights back."
- "See the plan →" CTA pinned to the bottom.
- Tapping "See the plan →" advances to the plan beat (rev 4 plan card layout — will be redesigned in Phase 4).
- Plan rows reveal sequentially with the soft success haptic on row 01 (existing).

If the rev 4 plan-beat layout still scrolls, that's expected — Phase 4 fixes it.

- [ ] **Step 4: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
feat(plan-reveal): Beat 1 layout — life bar + corporate punch + CTA

Splits the body into stakes / reclaim / plan branches. Beat 1
(.reclaim) shows the unified hero + the new 2-color life bar +
corporate punch ("Big tech is colonizing your attention. Memo fights
back.") + "See the plan →" CTA pinned via safeAreaInset. The CTA fires
advanceToPlan() to advance to Beat 2.

Per spec sections "Beat 1 layout" and implementation notes 3, 5.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 4: Beat 2 plan card redesign (visual change #3)

**Goal:** Replace the rev 4 `planCard` (vertical numbered list with outer container) with the tactical color-coded stack — 4 standalone row-cards, no outer container, each with a colored leading bar. Reorder rows to Train → Earn → Block → Compete with new copy. Drop the rev 4 ScrollView, "HOW IT WORKS" section, residual line, and "want it all back?" question. After this phase, Beat 2's plan card looks fresh, but the surrounding messaging is still rev 4 (Phase 5 swaps that).

### Task 4.1: Replace `planCard` and `planCardRow` with the tactical stack

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — `planCard` (currently around lines 507–545) and `planCardRow` (around 548–600). Replace both.

- [ ] **Step 1: Replace `planCard`**

Find the existing `private var planCard: some View { ... }` and replace with:

```swift
/// Rev 5 tactical color-coded plan stack. No outer container box; each
/// row is its own RoundedRectangle with a 3pt colored leading bar.
/// Order encodes the brand story: Train (mechanism) → Earn (payoff) →
/// Block (enforcement) → Compete (long game).
private var planCard: some View {
    VStack(alignment: .leading, spacing: 7) {
        planCardRow(
            color: AppColors.violet,
            label: "Train",
            detail: "brain games · 5 min a day",
            value: "5 min/day",
            index: 0
        )
        planCardRow(
            color: AppColors.accent,
            label: "Earn",
            detail: "15 min unlocked per win",
            value: "15 min",
            index: 1
        )
        planCardRow(
            color: AppColors.coral,
            label: "Block",
            detail: "apps stay shielded until you train",
            value: "pick yours",
            index: 2
        )
        planCardRow(
            color: AppColors.amber,
            label: "Compete",
            detail: "leaderboards · live now",
            value: "live",
            index: 3
        )
    }
}
```

- [ ] **Step 2: Replace `planCardRow`**

Find the existing `private func planCardRow(...)` and replace with:

```swift
/// Single row card. Row-color@10% background, 3pt leading bar in
/// row-color, label + detail stack on the leading edge, mono value
/// trailing. Reuses cardsAppeared[index] for the entry animation.
@ViewBuilder
private func planCardRow(
    color: Color,
    label: String,
    detail: String,
    value: String,
    index: Int
) -> some View {
    let appeared = index < cardsAppeared.count ? cardsAppeared[index] : true

    HStack(spacing: 12) {
        Rectangle()
            .fill(color)
            .frame(width: 3)

        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text(detail)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 11)

        Spacer(minLength: 8)

        Text(value)
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.trailing, 12)
    }
    .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(color.opacity(0.10))
    )
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .opacity(appeared ? 1 : 0)
    .offset(y: appeared ? 0 : 12)
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`. The old `cardGlowing` references inside `planCardRow` are gone — if SourceKit complains about unused `cardGlowing`, that's a Phase 7 cleanup item; don't address now.

### Task 4.2: Strip `planBeatLayout` to bare-minimum (plan card only, no scroll)

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — `planBeatLayout` view (currently around lines 406–498).

- [ ] **Step 1: Replace `planBeatLayout`**

Find `private var planBeatLayout: some View { ... }` and replace with this stripped-down Phase 4 version (Beat 2 hero + bridge come in Phase 5):

```swift
/// Beat 2 — the plan card. No ScrollView per spec implementation note 4;
/// fixed VStack + safeAreaInset(.bottom) for the CTA. Hero + bridge
/// added in Phase 5.
private var planBeatLayout: some View {
    VStack(alignment: .leading, spacing: 16) {
        Text("MEMO'S PLAYBOOK")
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(AppColors.textPrimary.opacity(0.4))

        planCard

        Spacer(minLength: 0)
    }
    .padding(.horizontal, 24)
    .padding(.top, 38)
    .frame(maxWidth: .infinity, alignment: .leading)
    .safeAreaInset(edge: .bottom) {
        unlockPlanButton
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
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Install + on-device check**

```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C \
  build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

Reset onboarding, step to plan reveal, tap "See the plan →" on Beat 1. Expected on Beat 2:
- "MEMO'S PLAYBOOK" eyebrow at top.
- Four standalone row cards, no outer container:
  - Violet leading bar, "Train" + "brain games · 5 min a day" + violet "5 min/day"
  - Accent (blue) leading bar, "Earn" + "15 min unlocked per win" + accent "15 min"
  - Coral leading bar, "Block" + "apps stay shielded until you train" + coral "pick yours"
  - Amber leading bar, "Compete" + "leaderboards · live now" + amber "live"
- "Show what changes →" CTA pinned to the bottom (existing `unlockPlanButton`).
- **No vertical scrolling.** If the page scrolls, ScrollView is still in `planBeatLayout` — re-check Step 1.

- [ ] **Step 4: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
feat(plan-reveal): tactical color-coded plan card + drop ScrollView

Replaces the rev 4 numbered-list plan card with the rev 5 tactical
stack: 4 standalone row-cards (no outer container), each with a 3pt
colored leading bar (violet/accent/coral/amber) and a row-color@10%
background. Row order is Train → Earn → Block → Compete with new
copy per spec.

planBeatLayout is now a fixed VStack — no ScrollView (per spec
implementation note 4). The HOW IT WORKS section, residual line,
and "want it all back?" question are removed; Phase 5 adds the
brain-trainer hero + bridge in their place.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 5: Beat 2 hero + bridge + small-device verification (visual change #4)

**Goal:** Add the brain-trainer hero ("Brain training that pays you in time."), supporting subhead, and the bridge ("Take your brain back. Big tech won't give it back voluntarily."). Then verify no-scroll on iPhone SE 3rd gen and iPhone 13 mini simulators (mandatory per spec).

### Task 5.1: Add hero + bridge to `planBeatLayout`

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — `planBeatLayout` body.

- [ ] **Step 1: Update `planBeatLayout`**

Replace the body of `planBeatLayout` (just written in Task 4.2) with the full rev 5 layout:

```swift
private var planBeatLayout: some View {
    VStack(alignment: .leading, spacing: 18) {
        // Eyebrow
        Text("MEMO'S PLAYBOOK")
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(AppColors.textPrimary.opacity(0.4))

        // Hero — brain-trainer USP
        VStack(alignment: .leading, spacing: 0) {
            Text("Brain training")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColors.textPrimary.opacity(0.94))
            Text("that pays you in time.")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColors.accent)
        }

        // Supporting subhead
        Text("Beat a brain game. Earn back screen time. The only blocker that trains your brain while it locks the noise.")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColors.textPrimary.opacity(0.55))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)

        // Plan card
        planCard

        Spacer(minLength: 0)

        // Bridge — carries the corporate antagonist into Beat 2
        VStack(alignment: .leading, spacing: 4) {
            Text("Take your brain back.")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColors.textPrimary.opacity(0.94))
            Text("Big tech won't give it back voluntarily.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(cardsAppeared[3] ? 1 : 0)
    }
    .padding(.horizontal, 24)
    .padding(.top, 28)
    .frame(maxWidth: .infinity, alignment: .leading)
    .safeAreaInset(edge: .bottom) {
        unlockPlanButton
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
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Install + on-device check (iPhone 16 Pro, the dev device)**

```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C \
  build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

Reset onboarding, step through to Beat 2. Expected layout (top → bottom):
- "MEMO'S PLAYBOOK" eyebrow
- "Brain training" / accent "that pays you in time."
- Subhead "Beat a brain game. Earn back screen time…" (3 lines)
- Tactical color-coded plan card (4 rows)
- "Take your brain back." / muted "Big tech won't give it back voluntarily."
- "Show what changes →" CTA
- **No scrolling on iPhone 16 Pro.** If it scrolls, tighten `padding(.top, 28)` to `padding(.top, 16)` and reduce row spacing to `spacing: 14`.

### Task 5.2: Verify no-scroll on small-device simulators (mandatory)

- [ ] **Step 1: Boot iPhone SE (3rd generation) simulator**

```bash
xcrun simctl list devices available | grep -i "SE (3rd"
```
If "iPhone SE (3rd generation)" exists in the list, boot it:

```bash
xcrun simctl boot "iPhone SE (3rd generation)" 2>&1 | tail -3
open -a Simulator
```

If it's not in the list, create it:

```bash
xcrun simctl create "iPhone SE (3rd generation)" "iPhone SE (3rd generation)" \
  $(xcrun simctl list runtimes | grep "iOS 17" | tail -1 | sed 's/.*\(com\.apple.*\)/\1/')
xcrun simctl boot "iPhone SE (3rd generation)"
```

- [ ] **Step 2: Build for the simulator**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Install + launch on the simulator**

```bash
xcrun simctl install "iPhone SE (3rd generation)" \
  build/Build/Products/Debug-iphonesimulator/MindRestore.app
xcrun simctl launch "iPhone SE (3rd generation)" com.memori.brain
```

(If `com.memori.brain` is wrong, find the bundle ID:
```bash
plutil -extract CFBundleIdentifier raw \
  build/Build/Products/Debug-iphonesimulator/MindRestore.app/Info.plist
```
and re-launch with the correct value.)

- [ ] **Step 4: Step through to Beat 2 and screenshot**

Use the Profile debug toggle to reset onboarding inside the simulator, navigate to the plan reveal, tap "See the plan →".

```bash
mkdir -p /tmp/rev5-verify
xcrun simctl io "iPhone SE (3rd generation)" screenshot /tmp/rev5-verify/iphone-se-beat2.png
```

Open `/tmp/rev5-verify/iphone-se-beat2.png`. Expected:
- All Beat 2 elements visible: eyebrow, hero (2-line), subhead (3 lines), 4-row plan card, bridge (2-line), CTA.
- **No scrolling indicator visible. The CTA is fully on-screen.**

If overflow is visible:
1. Reduce `padding(.top, 28)` to `padding(.top, 12)`.
2. Reduce VStack `spacing: 18` to `spacing: 14`.
3. Reduce hero font from `26pt` to `24pt`.
4. Drop the subhead's last sentence ("…while it locks the noise.") so it fits in 2 lines instead of 3.
5. Reduce plan-card row spacing from `7` to `5`.

Apply fixes one at a time, rebuild, re-screenshot. Re-iterate until no overflow.

- [ ] **Step 5: Repeat verification on iPhone 13 mini simulator**

```bash
xcrun simctl boot "iPhone 13 mini" 2>&1 | tail -3
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 13 mini' \
  -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
xcrun simctl install "iPhone 13 mini" \
  build/Build/Products/Debug-iphonesimulator/MindRestore.app
xcrun simctl launch "iPhone 13 mini" com.memori.brain
# step to Beat 2 manually...
xcrun simctl io "iPhone 13 mini" screenshot /tmp/rev5-verify/iphone-13-mini-beat2.png
```

Open `/tmp/rev5-verify/iphone-13-mini-beat2.png`. Same no-overflow check. Apply tightening fixes if needed (will likely be a non-issue if iPhone SE passed — 13 mini is taller).

- [ ] **Step 6: Verify Beat 1 also fits on iPhone SE**

Reset onboarding on the SE simulator. Wait for the cut animation to land on Beat 1.

```bash
xcrun simctl io "iPhone SE (3rd generation)" screenshot /tmp/rev5-verify/iphone-se-beat1.png
```

Expected: hero + life bar + corporate punch + CTA all visible without scroll. If overflow, tighten `VStack(alignment: .leading, spacing: 26)` in body's `.reclaim` branch (Task 3.2 — currently `26`) down to `20` or `18`.

- [ ] **Step 7: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
feat(plan-reveal): Beat 2 brain-trainer hero + bridge — rev 5 final layout

Adds "Brain training that pays you in time." hero + supporting subhead
above the plan card. Bridge below the card carries the corporate
antagonist into Beat 2: "Take your brain back. Big tech won't give it
back voluntarily."

Verified no-scroll on iPhone 16 Pro (dev device), iPhone SE 3rd gen,
and iPhone 13 mini simulators.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 6: End-to-end verification + cleanup

**Goal:** Smoke test the full sequence on the dev device. Sweep for residual rev 4 references. Verify the comparison page (next page in the funnel) still works with the rev-4-shipped 75% math.

### Task 6.1: Spec-compliance sweep

- [ ] **Step 1: Confirm no `withMemo` or `isPlan` references remain**

```bash
grep -n "withMemo\|isPlan" MindRestore/Views/Onboarding/OnboardingNewScreens.swift
```
Expected: zero hits inside `OnboardingPersonalSolutionView` or `PlanRevealBackdrop`. (One `isPlan` may remain in unrelated code — confirm any hit is OUTSIDE those two structs.)

- [ ] **Step 2: Confirm `ScrollView` is gone from `planBeatLayout`**

```bash
grep -n "ScrollView" MindRestore/Views/Onboarding/OnboardingNewScreens.swift
```
Expected: zero hits. If there's a hit, it's a leftover from rev 4 — delete it.

- [ ] **Step 3: Confirm `startRevealAnimation` no longer auto-advances**

```bash
grep -n "revealBeat = .plan" MindRestore/Views/Onboarding/OnboardingNewScreens.swift
```
Expected: exactly one hit, inside `advanceToPlan()`. Two hits means the auto-advance still exists in `startRevealAnimation` — delete it.

- [ ] **Step 4: Confirm rev 4 visual artifacts are gone**

```bash
grep -n "ghostNumberStack\|mascot-unlocked\|cuts the damage in half\|Memo turns scrolling into reps\|HOW IT WORKS\|on the table\|want it all back" MindRestore/Views/Onboarding/OnboardingNewScreens.swift
```
Expected: zero hits.

- [ ] **Step 5: Confirm `cardGlowing` is no longer referenced (optional cleanup)**

```bash
grep -n "cardGlowing" MindRestore/Views/Onboarding/OnboardingNewScreens.swift
```
If only the `@State` declaration remains and no reads, delete the declaration as dead state. If reads remain (in `revealPlanRows`), leave it — that's existing functionality.

### Task 6.2: Full on-device end-to-end test

- [ ] **Step 1: Build + install fresh**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
xcrun devicectl device install app --device 00008130-000A214E11E2001C \
  build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **` and successful install.

- [ ] **Step 2: Walk through the full sequence**

Reset onboarding on device. Step to plan reveal. Verify the full rev 5 sequence:

1. **Stakes** — Screen Time pill above eyebrow ("● from your Screen Time" or "● estimated from your input"), "WITHOUT MEMO" eyebrow, "You're giving social media giants" headline, count-up climbs from 0 to ~51,000 in coral over ~5 seconds with light haptic ticks, HOURS caption + climbing breakdown subtitle.
2. **Cut** — slash sweeps left-to-right in brand blue. Apps recoil outward immediately. Number snaps to ~38,000. Eyebrow crossfades coral "WITHOUT MEMO" → accent "RECLAIMED". Subtitle "hours back in your life" appears. Stakes headline fades out.
3. **Hero format swap** — ~700ms after the snap, "38,000" cross-fades to "4 YEARS · 132 DAYS".
4. **Beat 1 elements** — 2-color life bar fades in (75% blue, 25% coral). TODAY · AGE 60 markers. Corporate punch "Big tech is colonizing your attention." + italic accent "Memo fights back." "See the plan →" CTA pinned at the bottom. **Page does not auto-advance.**
5. **Beat 1 → Beat 2** — Tap "See the plan →". Page transitions to Beat 2.
6. **Beat 2** — "MEMO'S PLAYBOOK" eyebrow, "Brain training" / "that pays you in time." hero, subhead, 4-row tactical plan card (Train violet → Earn accent → Block coral → Compete amber), bridge "Take your brain back. Big tech won't give it back voluntarily.", "Show what changes →" CTA.
7. **Beat 2 → comparison page** — Tap "Show what changes →". Comparison page should appear with rows showing "[hrs] leaks into the feed" → "[hrs × 0.75] back in play". The 75% math from rev 4 should be intact.

- [ ] **Step 3: Take a screenshot for the commit**

```bash
mkdir -p /tmp/rev5-verify
# screenshot Beat 1, Beat 2 manually via the simulator/device tool
```

If this works, the implementation is complete.

### Task 6.3: Final commit

- [ ] **Step 1: Confirm clean working tree**

```bash
git status -s
```
Expected: clean (or only `?? /tmp/rev5-verify/` artifacts which are outside the repo).

- [ ] **Step 2: Final summary commit (if any cleanup happened in Task 6.1)**

If Task 6.1 found and deleted dead code (e.g., unreferenced `cardGlowing` state), commit it:

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
chore(plan-reveal): remove dead state from rev 4

Cleanup pass after rev 5 verification — drop @State variables that
no longer have any consumers.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

If no cleanup needed, skip.

- [ ] **Step 3: Push if desired**

`git push` is at the user's discretion. Do not push automatically.

---

## Self-review checklist (run before handing off)

After completing all phases, verify against the spec:

| Spec requirement | Implemented in |
|---|---|
| Two-beat sequence after the cut (Q1 = B) | Phase 3 (Beat 1 wired) + Phase 4 (Beat 2 plan card) + Phase 5 (Beat 2 hero/bridge) |
| Tactical color-coded plan card, violet/accent/coral/amber (Q2 = 2) | Task 4.1 |
| Cut moment fix — eyebrow flips at the cut (Q3 = A) | Task 2.1 (hero unification) + Task 2.2 (revealBeat in snap block) |
| Beat 1 corporate punch — "Big tech is colonizing your attention. / Memo fights back." (Q4 = B) | Task 3.1 (`beat1Extras`) |
| Beat 2 hero + bridge (Q5 = X) | Task 5.1 |
| User-tap CTA, no auto-advance (Q6 = A) | Task 1.4 (`advanceToPlan` stub) + Task 2.2 (delete auto-advance) + Task 3.2 (wire CTA) |
| Screen Time provenance pill (Q7 = A) | Task 2.1 (`screenTimeSourcePill`) |
| `.withMemo` → `.reclaim` rename | Task 1.1 |
| `isPlan` → `isDefeated` rename | Task 1.2 |
| `HeroFormat` enum + state | Task 1.3 |
| `advanceToPlan()` method | Task 1.4 + Task 3.1 wires it |
| Remove auto-advance from `startRevealAnimation` | Task 2.2 |
| `planBarProgress = 1` at slash-fade time, not concurrent with snap | Task 2.2 |
| `heroFormat = .breakdown` 700ms post-snap | Task 2.2 |
| ScrollView removed from Beat 2 | Task 4.2 (and confirmed Task 6.1 step 2) |
| Verify no-scroll on iPhone SE 3rd gen + iPhone 13 mini | Task 5.2 |
| Tactical plan card with row palette + copy verbatim | Task 4.1 |
| Drop rev 4 cosmetics (ghost stack, "cuts in half", mascot-unlocked) | Task 2.1 |
| Stagger Beat 1 elements via `.animation(.delay(...))` | Task 3.1 (`beat1Extras` — corporate punch has `.delay(0.10)`) |
| Comparison page next-page flow (75% math) | Verified end-to-end Task 6.2 step 2 (untouched in this plan) |

**If any line is missing an implementation reference, add a task back in the relevant phase before declaring complete.**
