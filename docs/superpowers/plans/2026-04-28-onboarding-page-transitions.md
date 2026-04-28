# Onboarding Page-to-Page Transitions — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the v2.0 onboarding flow's iOS-default `TabView` page-curl with a refined dissolve transition (incoming opacity + scale 0.96→1.0 + offset y: 8→0 over 0.40s easeOut, outgoing opacity → 0 over 0.30s easeIn). Every page transition routes through a single `goToPage(_:)` helper. Progress header gracefully fades on hidden pages instead of snapping. Plan Reveal's count-up gets a 400ms buffer so numbers don't tick during the dissolve.

**Architecture:** Single-file refactor of `MindRestore/Views/Onboarding/OnboardingView.swift`. The `TabView` body becomes a `Group { switch currentPage { ... } }` wrapped in `.id(currentPage).zIndex(Double(currentPage)).transition(...)`. The existing 19 `withAnimation { currentPage = N }` callsites + 1 back-chevron `currentPage -= 1` callsite migrate to a new `goToPage(_:)` helper. Existing `onChange(of: currentPage)` handler (keyboard dismiss + commitment-state reset) attaches to the new container. Plus a one-line edit to `OnboardingNewScreens.swift` to delay Plan Reveal's count-up.

**Tech Stack:** SwiftUI iOS 17+, native `.transition` modifier with `.asymmetric`, `@Environment(\.accessibilityReduceMotion)` for fallback. No new dependencies. No new files.

**Anti-pattern compliance:**
- **No struct rename** — `OnboardingView` keeps its name and signature.
- **Single iOS device** — sequential execution, no parallel worktrees.
- **`xcodebuild` CLI only** — never use Xcode MCP `BuildProject` (hangs 10+ min per `feedback_use_xcodebuild_cli`). The Edit-tool hook reminding you to use `mcp__xcode__BuildProject` is wrong for this project. Ignore it.
- **SourceKit `No such module 'UIKit'` is a known false positive** — ignore it; `xcodebuild` is authoritative.
- **One-defect-per-iteration after install** — once Task 7 ships to device, ANY user-flagged defect = one targeted commit, never batched. Per `feedback_ui_iteration_not_batch`.

**Source spec:** `docs/superpowers/specs/2026-04-28-onboarding-page-transitions-design.md`

**One spec correction noted during planning:** the spec said both Industry Scare and Plan Reveal need a 400ms initial-delay buffer. On re-reading the actual code, Industry Scare's $57B count-up starts at ~1.65s after `.onAppear` (well after the 400ms transition completes — the entrance arc has 4 prior beats: slug/headline → tape → suspect rows → divider). Industry Scare does NOT need a buffer. Only Plan Reveal does (its `countProjection` runs immediately after `headlineAppeared` is flipped). The plan reflects this correction.

---

## File Structure

| File | Action | What changes |
|---|---|---|
| `MindRestore/Views/Onboarding/OnboardingView.swift` | Modify | The body refactor (TabView → Group switch + transition), the new `goToPage(_:)` helper, the new `progressHeaderOpacity` computed property, the `@Environment(\.accessibilityReduceMotion)` binding, the always-render progress header with opacity, and migration of 19 `withAnimation { currentPage = N }` callsites + 1 back-chevron callsite. |
| `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` | Modify | Single-line edit to `OnboardingPersonalSolutionView.startRevealAnimation`: insert a 400ms `Task.sleep` BEFORE the existing `withAnimation` for `headlineAppeared` so the count-up doesn't begin during the page transition. |

No new files. No new dependencies.

---

## Task 1: Reconnaissance — verify the surfaces match the spec

**Files:** Read-only.

- [ ] **Step 1: Confirm TabView and scrollDisabled lines**

Run:
```bash
grep -n "TabView(selection: \\$currentPage)\|.tabViewStyle(.page(indexDisplayMode: .never))\|.scrollDisabled(true)" MindRestore/Views/Onboarding/OnboardingView.swift
```

Expected output:
```
89:                TabView(selection: $currentPage) {
107:                .tabViewStyle(.page(indexDisplayMode: .never))
108:                .scrollDisabled(true)
```

Line numbers may shift slightly — but the three lines exist as a contiguous block. Task 4 replaces them.

- [ ] **Step 2: Count `withAnimation { currentPage` callsites for migration**

Run:
```bash
grep -c "withAnimation { currentPage" MindRestore/Views/Onboarding/OnboardingView.swift
```

Expected: `19`. If different, the file's been edited since plan-write — verify the callsites are still sed-mappable (Task 3 step 1).

- [ ] **Step 3: Confirm the back-chevron callsite exists**

Run:
```bash
grep -n "withAnimation { currentPage -= 1 }" MindRestore/Views/Onboarding/OnboardingView.swift
```

Expected: one match (line ~218). Task 3 step 2 handles this manually.

- [ ] **Step 4: Confirm the progress header gate location**

Run:
```bash
grep -n "currentPage != 9 && currentPage != 4 && currentPage != 10\|onboardingProgressHeader" MindRestore/Views/Onboarding/OnboardingView.swift
```

Expected output (line numbers approximate):
```
85:                if currentPage != 9 && currentPage != 4 && currentPage != 10 {
86:                    onboardingProgressHeader
198:    private var onboardingProgressHeader: some View {
```

Task 5 replaces the conditional `if` with always-render + `.opacity(...)`.

- [ ] **Step 5: Confirm Plan Reveal's count-up entry point**

Run:
```bash
grep -n "private func startRevealAnimation\|guard !revealStarted\|withAnimation(.easeOut(duration: 0.36)) {\|await countProjection()" MindRestore/Views/Onboarding/OnboardingNewScreens.swift | head -10
```

Expected: lines clustered around 546–556 in `OnboardingPersonalSolutionView`. Task 6 inserts a 400ms sleep before the `withAnimation`.

- [ ] **Step 6: Confirm reduceMotion is NOT yet on OnboardingView**

Run:
```bash
grep -n "accessibilityReduceMotion" MindRestore/Views/Onboarding/OnboardingView.swift || echo "NOT PRESENT — Task 2 adds it"
```

Either the binding is present (rare — possible from earlier session work) or it's absent. Task 2 step 1 adds it if absent; if present, skip.

---

## Task 2: Add the three helpers — `goToPage(_:)`, `progressHeaderOpacity`, `reduceMotion`

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingView.swift` (state declarations area, `~line 8–55`; private-method area, `~line 165 onward`).

This task adds the three new symbols that the rest of the plan uses. They're additive (no replacement), so no risk of breaking existing functionality.

- [ ] **Step 1: Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` to the `@State` cluster**

Use the Edit tool. Replace exactly:

```swift
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusModeService.self) private var focusModeService
```

with:

```swift
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusModeService.self) private var focusModeService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

If the `reduceMotion` line already exists (unlikely — verified absent in Task 1 step 6 — but possible), skip.

- [ ] **Step 2: Add the `progressHeaderOpacity` computed property and `goToPage(_:)` helper**

Open `OnboardingView.swift` and find the line:

```swift
    private var onboardingProgressHeader: some View {
```

Use the Edit tool. Replace exactly:

```swift
    private var onboardingProgressHeader: some View {
```

with:

```swift
    /// Pages where the top progress bar is hidden (full-bleed editorial moments):
    /// 4 Empathy, 9 Quick Assessment, 10 Plan Reveal.
    private var progressHeaderOpacity: Double {
        let hiddenPages: Set<Int> = [4, 9, 10]
        return hiddenPages.contains(currentPage) ? 0 : 1
    }

    /// Single funnel for every page advance / back-step. All onboarding CTAs
    /// route through this so the transition curve is tunable in one place.
    private func goToPage(_ page: Int) {
        withAnimation(.easeInOut(duration: 0.40)) {
            currentPage = page
        }
    }

    private var onboardingProgressHeader: some View {
```

This adds the two helpers immediately above the existing `onboardingProgressHeader` view.

- [ ] **Step 3: Build to verify the helpers compile in isolation**

Run:
```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -5
```

Expected: `** BUILD SUCCEEDED **`. (The new helpers are unused at this point but Swift allows unused private members without error — only a warning.)

If a `cannot find type 'EnvironmentValues'` error appears, the `\.accessibilityReduceMotion` keypath isn't resolving. Verify `import SwiftUI` is at the top of the file.

If the build fails for ANY reason, stop — Task 3 onward depends on this compiling.

- [ ] **Step 4: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingView.swift
git commit -m "$(cat <<'EOF'
chore(onboarding): add transition helpers (goToPage, progressHeaderOpacity, reduceMotion)

Pre-wires three additive helpers used by the upcoming page-transition
refactor:

- @Environment(\.accessibilityReduceMotion) — reduce-motion fallback
  for the new transition.
- progressHeaderOpacity computed property — returns 0 for pages 4
  (Empathy), 9 (Quick Assessment), 10 (Plan Reveal); 1 otherwise.
  Replaces an upcoming `if currentPage != 9 && currentPage != 4 &&
  currentPage != 10` conditional with an opacity binding so the bar
  fades instead of snapping.
- goToPage(_:) helper — single funnel for every page advance and
  back-step, wrapping `withAnimation(.easeInOut(duration: 0.40)) {
  currentPage = page }`.

Helpers are unused at this commit — Tasks 3, 4, 5 wire them up. Done
as a separate commit so a build break here is isolated from the
container refactor.

Build SUCCEEDED on device 00008130-000A214E11E2001C.

Spec: docs/superpowers/specs/2026-04-28-onboarding-page-transitions-design.md
Plan: docs/superpowers/plans/2026-04-28-onboarding-page-transitions.md (Task 2)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Migrate all `withAnimation { currentPage = N }` callsites to `goToPage(_:)`

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingView.swift` — 19 forward-advance callsites + 1 back-chevron.

The existing CTAs each call `withAnimation { currentPage = N }`. The migration replaces all 19 with `goToPage(N)`. The back-chevron uses `currentPage -= 1` and gets a slightly different replacement.

- [ ] **Step 1: Migrate all forward-advance callsites with sed**

Run:
```bash
sed -i '' -E 's/withAnimation \{ currentPage = ([0-9]+) \}/goToPage(\1)/g' MindRestore/Views/Onboarding/OnboardingView.swift
```

This replaces every `withAnimation { currentPage = N }` (where N is a digit sequence) with `goToPage(N)`. Comments after the `}` (e.g., `// → planReveal`) are preserved.

- [ ] **Step 2: Migrate the back-chevron manually**

Use the Edit tool. Replace exactly:

```swift
                withAnimation { currentPage -= 1 }
```

with:

```swift
                goToPage(max(0, currentPage - 1))
```

The `max(0, ...)` guard prevents the back-chevron from setting `currentPage` to -1 if the user mashes it on Welcome (which is already the leftmost page). Defensive — the existing back-chevron also has a `guard currentPage > 0 else { return }` immediately above this line, so the guard is belt-and-suspenders.

- [ ] **Step 3: Verify no raw `withAnimation { currentPage` callsites remain**

Run:
```bash
grep -nE "withAnimation \{ currentPage" MindRestore/Views/Onboarding/OnboardingView.swift
```

Expected: zero matches. If any remain, re-run sed (step 1) — it may have missed a callsite with non-standard formatting.

- [ ] **Step 4: Verify all migrated callsites point to valid pages**

Run:
```bash
grep -nE "goToPage\(" MindRestore/Views/Onboarding/OnboardingView.swift
```

Expected: 20 matches (19 forward-advance + 1 back-chevron). Each forward-advance argument should be a number 0–15 inclusive (the 16 page indices). Visually scan the output. If any argument is out of range, the original code had a bug — flag it.

- [ ] **Step 5: Build**

Run:
```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -10
```

Expected: `** BUILD SUCCEEDED **`. If errors appear:
- `cannot find 'goToPage' in scope` → Task 2 commit didn't land. Re-check git log.
- `argument labels '(_:)' do not match` → an existing callsite had unusual formatting that sed mangled. Inspect the diff and fix manually.

- [ ] **Step 6: Install on device**

Run:
```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

Expected: ends with `databaseSequenceNumber: ...`.

The app should still behave identically — `goToPage(_:)` is a 1:1 functional replacement at this commit. The visible transition is still the iOS default (TabView still drives the swap). Task 4 changes that.

- [ ] **Step 7: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingView.swift
git commit -m "$(cat <<'EOF'
refactor(onboarding): route every page advance through goToPage(_:)

Migrates all 19 `withAnimation { currentPage = N }` callsites and the
1 back-chevron `withAnimation { currentPage -= 1 }` callsite to use
the new goToPage(_:) helper. The back-chevron variant uses
goToPage(max(0, currentPage - 1)) for defensive bounds-safety.

No behavioral change at this commit — goToPage internally still calls
withAnimation(.easeInOut(duration: 0.40)) { currentPage = page },
which is what every callsite used to do directly. The benefit is
that future tweaks to the transition curve change one function
instead of 20 callsites.

Build SUCCEEDED + installed on device 00008130-000A214E11E2001C.

Plan: docs/superpowers/plans/2026-04-28-onboarding-page-transitions.md (Task 3)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Replace `TabView` with `Group { switch }` + `.id` + `.transition`

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingView.swift` (`~line 89–110`).

The substantive transition refactor.

- [ ] **Step 1: Read the current TabView block in full context**

Run:
```bash
sed -n '83,112p' MindRestore/Views/Onboarding/OnboardingView.swift
```

Expected: shows the `VStack` containing the conditional `onboardingProgressHeader` and the `TabView(selection: $currentPage)` block with all 16 pages tagged. Verify the page list reads:

```
welcomePage.tag(0)
namePage.tag(1)
painCardsPage.tag(2)
industryScarePage.tag(3)
empathyPage.tag(4)
goalsPage.tag(5)
agePage.tag(6)
screenTimeAccessPage.tag(7)
personalScarePage.tag(8)
quickAssessmentPage.tag(9)
planRevealPage.tag(10)
comparisonPage.tag(11)
differentiationPage.tag(12)
focusModePage.tag(13)
notificationPrimingPage.tag(14)
commitmentPage.tag(15)
```

If any page's index has shifted, update the switch in step 2 to match.

- [ ] **Step 2: Replace TabView block with Group switch + transition**

Use the Edit tool. Replace exactly:

```swift
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    namePage.tag(1)
                    painCardsPage.tag(2)
                    industryScarePage.tag(3)
                    empathyPage.tag(4)
                    goalsPage.tag(5)
                    agePage.tag(6)
                    screenTimeAccessPage.tag(7)
                    personalScarePage.tag(8)
                    quickAssessmentPage.tag(9)
                    planRevealPage.tag(10)
                    comparisonPage.tag(11)
                    differentiationPage.tag(12)
                    focusModePage.tag(13)
                    notificationPrimingPage.tag(14)
                    commitmentPage.tag(15)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollDisabled(true)
                .animation(.easeInOut, value: currentPage)
```

with:

```swift
                pageContent
                    .id(currentPage)
                    .zIndex(Double(currentPage))
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
                    .animation(.easeInOut(duration: 0.40), value: currentPage)
```

The `.tabViewStyle` and `.scrollDisabled` modifiers go away with TabView. The new `.transition` is applied to the content with the reduce-motion conditional inline.

The existing `.onChange(of: currentPage) { _, newPage in ... }` immediately following stays attached — it now hangs off the new `pageContent`-with-transition view instead of the old TabView. Don't delete the `.onChange` block.

- [ ] **Step 3: Add the `pageContent` view-builder**

Find the line:

```swift
    @ViewBuilder
    private var pageAtmosphere: some View {
```

Use the Edit tool. Replace exactly:

```swift
    @ViewBuilder
    private var pageAtmosphere: some View {
```

with:

```swift
    /// Single source of truth for which page to render at a given currentPage.
    /// Wrapped in a Group so SwiftUI can apply .id / .transition uniformly to
    /// any of the 16 child views.
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

    @ViewBuilder
    private var pageAtmosphere: some View {
```

This places `pageContent` immediately above `pageAtmosphere`. Both are `@ViewBuilder` private vars rendering the right child for the current `currentPage`, so they belong together.

- [ ] **Step 4: Build**

Run:
```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -10
```

Expected: `** BUILD SUCCEEDED **`. SourceKit `No such module 'UIKit'` warning is the known false positive — ignore.

If errors appear:
- `cannot find 'pageContent' in scope` → step 3's edit didn't land. Re-verify.
- `cannot find 'reduceMotion' in scope` → Task 2 step 1 didn't land. Re-check git log.
- `'Group' is not convertible to 'some View'` → the Edit replaced more (or less) than expected. Inspect git diff.

- [ ] **Step 5: Install on device**

Run:
```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

- [ ] **Step 6: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingView.swift
git commit -m "$(cat <<'EOF'
feat(onboarding): replace TabView with refined-dissolve transition

Refactors the page container from SwiftUI's TabView (with the locked
iOS page-curl) to a Group { switch currentPage } wrapped in
.id(currentPage) + .zIndex(Double(currentPage)) + .transition(...).

The transition uses .asymmetric:
- insertion: opacity 0→1 + scale 0.96→1.0 + offset y: 8→0 over 0.40s
  easeOut
- removal: opacity 1→0 over 0.30s easeIn
- Symmetric forward and back (same animation, mirrored direction by
  SwiftUI)

Reduce Motion fallback: collapses to opacity-only crossfade over 0.18s
when accessibilityReduceMotion is true.

zIndex(Double(currentPage)) guarantees incoming page renders above
outgoing during the brief overlap, preventing the SwiftUI default-
ordering ghost flicker on real devices.

Existing .onChange(of: currentPage) handler (keyboard dismiss + name
field refocus + commitment-state reset) attaches to the new container
unchanged.

The 19 forward-advance CTAs and the 1 back-chevron callsite already
route through goToPage(_:) (Task 3), so the transition curve is
tunable in one place.

Build SUCCEEDED + installed on device 00008130-000A214E11E2001C.

Plan: docs/superpowers/plans/2026-04-28-onboarding-page-transitions.md (Task 4)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Always-render the progress header with `.opacity(progressHeaderOpacity)`

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingView.swift` (`~line 85–87`).

The progress header currently snaps in/out via `if currentPage != 9 && currentPage != 4 && currentPage != 10`. Convert to always-render with opacity binding so it fades smoothly on entry/exit.

- [ ] **Step 1: Replace the conditional with always-render + opacity**

Use the Edit tool. Replace exactly:

```swift
            VStack(spacing: 0) {
                // Hide progress header on Quick Assessment (9), Empathy (4), and Plan Reveal (10)
                // per UI-SPEC §"Page 6" and §"Page 11" — these are full-bleed editorial moments.
                if currentPage != 9 && currentPage != 4 && currentPage != 10 {
                    onboardingProgressHeader
                }
```

with:

```swift
            VStack(spacing: 0) {
                // Progress header is always rendered; visibility controlled by
                // progressHeaderOpacity so it fades on entry/exit of full-bleed
                // editorial pages (Empathy, Quick Assessment, Plan Reveal) instead
                // of snapping when the conditional flips.
                onboardingProgressHeader
                    .opacity(progressHeaderOpacity)
                    .animation(.easeInOut(duration: 0.30), value: currentPage)
```

If the existing comment block doesn't match exactly (e.g., line wraps differ), match line-by-line and adjust accordingly.

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Install on device**

Run:
```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

- [ ] **Step 4: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingView.swift
git commit -m "$(cat <<'EOF'
fix(onboarding): progress header fades in/out instead of snapping

Replaces the conditional `if currentPage != 9 && currentPage != 4 &&
currentPage != 10 { onboardingProgressHeader }` with always-render
+ .opacity(progressHeaderOpacity) bound to a 0.30s easeInOut animation
on currentPage.

When the user advances into Empathy (4) / Quick Assessment (9) /
Plan Reveal (10), the progress bar gracefully fades out instead of
disappearing instantly. When they leave those pages, it fades back
in. Smoother visual continuity through the full-bleed editorial
pages.

progressHeaderOpacity is the computed property added in Task 2.

Build SUCCEEDED + installed on device 00008130-000A214E11E2001C.

Plan: docs/superpowers/plans/2026-04-28-onboarding-page-transitions.md (Task 5)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Plan Reveal — buffer the count-up by 400ms so it doesn't tick during the dissolve

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — `OnboardingPersonalSolutionView.startRevealAnimation` at `~line 546`.

The existing Plan Reveal `startRevealAnimation` flips `headlineAppeared` immediately and starts `countProjection()` on the very next line. The count runs over ~1.0s — the first 400ms of which overlap with the new page transition. This causes the count-up to tick visibly while the page is still fading in. Adding a 400ms `Task.sleep` before the headline animation aligns the count-up to start AFTER the dissolve.

Industry Scare does NOT need a buffer — its count-up starts at ~1.65s after `.onAppear` thanks to the existing entrance arc beats (slug+headline → tape → suspect rows → divider). Verified during reconnaissance.

- [ ] **Step 1: Read the current `startRevealAnimation` function**

Run:
```bash
sed -n '545,560p' MindRestore/Views/Onboarding/OnboardingNewScreens.swift
```

Expected output:
```swift
    private func startRevealAnimation() {
        guard !revealStarted else { return }
        revealStarted = true

        revealTask?.cancel()
        revealTask = Task { @MainActor in
            withAnimation(.easeOut(duration: 0.36)) {
                headlineAppeared = true
            }

            await countProjection()
            ...
```

(Lines may shift slightly.)

- [ ] **Step 2: Insert a 400ms `Task.sleep` before the `withAnimation`**

Use the Edit tool. Replace exactly:

```swift
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            withAnimation(.easeOut(duration: 0.36)) {
                headlineAppeared = true
            }

            await countProjection()
```

with:

```swift
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            // 400ms buffer so the count-up doesn't tick during the page
            // transition's 0.40s dissolve. See:
            // docs/superpowers/specs/2026-04-28-onboarding-page-transitions-design.md
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.36)) {
                headlineAppeared = true
            }

            await countProjection()
```

The `guard !Task.isCancelled` ensures the function exits cleanly if the user navigates away during the 400ms wait (e.g., taps back-chevron immediately on entry to Plan Reveal). Matches the cancellation pattern used elsewhere in the same Task block.

- [ ] **Step 3: Build**

Run:
```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Install on device**

Run:
```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

- [ ] **Step 5: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
fix(plan-reveal): buffer count-up by 400ms to clear page transition

The new ZStack page transition (Task 4 of the page-transitions plan)
has a 0.40s dissolve curve. Plan Reveal's countProjection runs
immediately after headlineAppeared flips, meaning the first 400ms of
the count-up tick visibly while the page is still fading in. The
count-up's eased curve is most dramatic in its early frames — losing
those frames behind the dissolve loses most of the cinematic moment.

Fix: insert a 400ms Task.sleep at the top of the revealTask, before
the withAnimation for headlineAppeared. The headline animation, the
count-up, and every downstream beat now begin AFTER the page
transition completes.

guard !Task.isCancelled added after the sleep so the task exits
cleanly if the user back-navigates during the buffer window.

Industry Scare does NOT need this fix — its count-up already starts
at ~1.65s after .onAppear thanks to the existing entrance arc.

Build SUCCEEDED + installed on device 00008130-000A214E11E2001C.

Plan: docs/superpowers/plans/2026-04-28-onboarding-page-transitions.md (Task 6)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: On-device visual verification + iteration

**Files:** None (verification + iteration only).

Once Task 6 lands, the full transition system is shipped. The user walks the flow on device and reports defects. Per `feedback_ui_iteration_not_batch`, every defect = one targeted commit, never batched.

- [ ] **Step 1: Tell the user the build is ready and what to verify**

Output exactly this message to the user:

> Page transitions shipped + installed on device. Walk through the entire onboarding flow start-to-finish:
>
> 1. **Default transitions (every page):** tap any CTA → outgoing page fades over 0.30s, incoming page rises with subtle scale (0.96 → 1.0) + 8pt upward slide over 0.40s. No horizontal slide. Tap back-chevron — symmetric.
>
> 2. **Progress header on full-bleed pages:** advance into Empathy (page 4). Progress bar should fade out gracefully, not snap. Same on Quick Assessment (9) and Plan Reveal (10). Tap back from any of these — bar fades back in.
>
> 3. **Plan Reveal count-up:** advance from Quick Assessment to Plan Reveal. The dissolve completes (~0.40s) BEFORE the count-up begins. No partial 0 → N tick during the dissolve. The 44k count-up should land fully on a clear page.
>
> 4. **Reduce Motion:** flip Settings → Accessibility → Motion → Reduce Motion ON. Fresh-launch onboarding. All transitions become opacity-only crossfades (~0.18s), no scale, no slide. Pages still advance correctly.
>
> 5. **Quick Assessment background:** entry to page 9 should crossfade the bg color smoothly (the existing animation modifier on the bg ternary at OnboardingView.swift:73 should still work post-refactor). If it snaps, that's a defect to flag.
>
> 6. **Re-entry from back-chevron:** tap back from any page. The previously-visited page's entrance animation arc plays again (Welcome bouncer apps re-cascade, Pain Cards receipts re-stack, Industry Scare suspects re-appear, etc.).
>
> 7. **No ghosting:** during the brief dissolve overlap (where outgoing is still fading and incoming is rising), incoming should always render ABOVE outgoing. No flicker.
>
> Tell me what you see. Each defect = one targeted commit, never batched.

- [ ] **Step 2: Wait for user feedback**

Halt. The user replies with either approval or specific defects.

- [ ] **Step 3: Iterate one defect at a time**

For each defect:
1. Make the single targeted edit.
2. Build with `xcodebuild`.
3. Install with `xcrun devicectl`.
4. Commit with a focused message.
5. Tell the user to re-check.

Never batch multiple visual fixes into one commit.

---

## Self-Review

**Spec coverage check (against `docs/superpowers/specs/2026-04-28-onboarding-page-transitions-design.md`):**

- ✓ Refined dissolve transition (insertion: opacity + scale 0.96 + offset 8, easeOut 0.40s; removal: opacity, easeIn 0.30s) — Task 4 Step 2.
- ✓ `goToPage(_:)` central helper — Tasks 2 + 3.
- ✓ All 19 callsites + back-chevron migrated to `goToPage` — Task 3.
- ✓ `progressHeaderOpacity` computed property — Task 2.
- ✓ Always-render progress header with opacity binding — Task 5.
- ✓ `zIndex(Double(currentPage))` ghost protection — Task 4 Step 2.
- ✓ Reduce Motion conditional transition — Task 4 Step 2 (inline `reduceMotion ? AnyTransition.opacity... : AnyTransition.asymmetric...`).
- ✓ Plan Reveal 400ms count-up buffer — Task 6.
- ✓ Spec correction note: Industry Scare does NOT need a buffer — flagged in plan header + Task 6 comment.
- ✓ Existing `onChange(of: currentPage)` handler preserved — Task 4 Step 2 explicitly says "Don't delete the `.onChange` block."
- ✓ Quick Assessment background animation — covered by existing `.animation(.easeInOut(duration: 0.3), value: currentPage)` on line 73 (verified untouched by all tasks).

**Placeholder scan:** No "TBD", no "implement later", no "add error handling here." Each step shows exact code or exact commands.

**Type consistency check:**
- `goToPage(_:)` defined in Task 2 — consumed in Task 3 (sed migration) and implicitly by the back-chevron edit. Same name and signature throughout.
- `progressHeaderOpacity` defined in Task 2 — consumed in Task 5. Same name and `Double` return type.
- `pageContent` defined in Task 4 Step 3 — consumed in Task 4 Step 2. Same name.
- `reduceMotion` env binding declared in Task 2 — consumed in Task 4 Step 2 transition conditional. Same name.

**Sed migration safety note:** Task 3 Step 1's sed command (`s/withAnimation \{ currentPage = ([0-9]+) \}/goToPage(\1)/g`) only matches `withAnimation { currentPage = NUMBER }`. It will NOT match `withAnimation { currentPage -= 1 }` (back-chevron, handled separately in Step 2) or any compound-assignment variant. Verified by grep output during Task 1 — all 19 forward-advance callsites use the same exact pattern.

**Defensive note for Task 4 Step 2's edit:** The exact `old_string` includes the `.onChange(of: currentPage) { _, newPage in` opening line at the bottom — but the closing of that block stays intact (it's not in the old_string). The edit removes only the TabView block + its three modifiers, not the onChange handler that follows. If the edit fails to apply because the file's been edited between Tasks 3 and 4, the engineer can split the edit at the `.animation(.easeInOut, value: currentPage)` line and keep the `.onChange` separate.

---

Plan complete and saved to `docs/superpowers/plans/2026-04-28-onboarding-page-transitions.md`.

**Two execution options:**

**1. Subagent-Driven (recommended for plans of this size)** — Dispatch a fresh subagent per task. Best for plans where each task is self-contained and the orchestrator stays light. Two-stage review between tasks.

**2. Inline Execution** — Execute tasks in this same session using `executing-plans`. Best for smaller plans where context-sharing has value. Checkpoints between tasks.

For this plan, both are reasonable. Inline keeps you in the loop more directly (you can react in the same conversation thread). Subagent-driven scales better if you'd rather not watch every step. Tell me which.