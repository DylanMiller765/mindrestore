# Onboarding Memo Loading Beats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single pre-paywall personalization loader with cumulative, character-driven "Memo building your plan" beats fired after goals/age/screen-time, converging into a final presenting beat right before the hard paywall.

**Architecture:** The 3 building beats are rendered as a **transient full-screen overlay** layered on `OnboardingView`'s root `ZStack`, driven by one `@State` enum — NOT as new entries in the integer `pageContent` switch. This leaves every existing `goToPage(n)` index, the `progressHeaderOpacity` set, back-navigation, and the `Analytics.onboardingStepNames` index array completely untouched. The **final beat** simply swaps the view rendered inside the existing page 6 (`planPersonalizingPage`). All beat copy/clipboard content comes from one pure, unit-tested model.

**Tech Stack:** SwiftUI, SwiftData, XCTest, existing `LoopingVideoPlayer` (AVPlayerLooper), `OB` design tokens.

> **⚠️ Divergence from spec:** The approved spec (`docs/superpowers/specs/2026-05-28-onboarding-memo-loading-beats-design.md`) described "inserting 3 new beat *pages* and renumbering all `goToPage` targets / analytics indices." During planning, the page indices proved to be fragile scattered magic numbers with stale comments. This plan delivers the identical UX via an **overlay** instead, which is materially lower-risk and requires zero renumbering. The user-facing behavior (4 beats, cumulative clipboard, auto-advance, final beat before paywall) is unchanged. Flag for user confirmation before executing.

---

## File Structure

- **Create:** `MindRestore/Views/Onboarding/PlanBuildBeatContent.swift` — pure model: given a beat + collected onboarding data, returns the Memo bubble string and the clipboard line items. No SwiftUI. Easy to unit-test. *(New file — requires adding to the Xcode/XcodeGen project; see Task 0.)*
- **Create:** `MindRestoreTests/PlanBuildBeatContentTests.swift` — unit tests for the model. *(New file — add to test target; see Task 0.)*
- **Modify:** `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — add `OnboardingPlanBuildBeatOverlay` (building beats) and `OnboardingPlanFinalBeatView` (final beat); delete `OnboardingPlanPersonalizingView`.
- **Modify:** `MindRestore/Views/Onboarding/OnboardingView.swift` — add `activeBeat` state + overlay layer + `advance(after:then:)` helper; wrap the 3 milestone advances; repoint `planPersonalizingPage` to the new final beat view.
- **Add (assets):** two Memo loop MP4s (`memo-building.mp4`, `memo-presenting.mp4`) into the app bundle — manual Xcode step (Task 5).

---

## Task 0: Add new source files to the project (MANUAL — user)

This project is iOS; Claude cannot edit `MindRestore.xcodeproj` or `project.yml` membership reliably. The two new files in this plan must be registered before they compile.

- [ ] **Step 1:** Determine project generation. If `project.yml` lists source folders by directory (XcodeGen), new files under `MindRestore/Views/Onboarding/` and `MindRestoreTests/` are picked up automatically on regenerate. If the repo commits `MindRestore.xcodeproj` directly, the files must be added via Xcode.

- [ ] **Step 2 (XcodeGen path):** Run `xcodegen generate` (or the repo's generate command) after the files are created in Tasks 1.

- [ ] **Step 3 (Xcode path):** In Xcode, right-click the `Onboarding` group → Add Files → select `PlanBuildBeatContent.swift`, target = MindRestore. Right-click `MindRestoreTests` → Add Files → `PlanBuildBeatContentTests.swift`, target = MindRestoreTests.

> **Note for the implementing engineer:** Create the file *contents* in Tasks 1 first, then have the user run this registration step before building. If unsure which path applies, ask the user.

---

## Task 1: Pure beat-content model (TDD)

**Files:**
- Create: `MindRestore/Views/Onboarding/PlanBuildBeatContent.swift`
- Test: `MindRestoreTests/PlanBuildBeatContentTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MindRestore

final class PlanBuildBeatContentTests: XCTestCase {

    func test_goalBeat_bubbleAndLine() {
        let c = PlanBuildBeatContent(
            beat: .goals,
            goals: [.screenTimeFrying],
            age: 24,
            dailyScreenTimeHours: 4.2,
            isEstimate: false
        )
        XCTAssertEqual(c.bubble, "Hours back. That's the mission.")
        XCTAssertEqual(c.newLine?.label, "Goal")
        XCTAssertEqual(c.newLine?.value, "hours back")
    }

    func test_ageBeat_interpolatesYearsAhead() {
        let c = PlanBuildBeatContent(
            beat: .age, goals: [], age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertEqual(c.bubble, "24? You've got ~56 years of phone ahead.")
        XCTAssertEqual(c.newLine?.label, "Age")
        XCTAssertEqual(c.newLine?.value, "24 · ~56 yrs ahead")
    }

    func test_screenTimeBeat_computesDaysPerYear() {
        // 4.2h/day * 365 / 24 = 63.875 → rounds to 64
        let c = PlanBuildBeatContent(
            beat: .screenTime, goals: [], age: 24, dailyScreenTimeHours: 4.2, isEstimate: false
        )
        XCTAssertEqual(c.bubble, "4.2h a day… that's ~64 days a year gone.")
        XCTAssertEqual(c.newLine?.value, "4.2h/day")
    }

    func test_screenTimeBeat_estimateAtOrAboveEightClampsTo8Plus() {
        let c = PlanBuildBeatContent(
            beat: .screenTime, goals: [], age: 30, dailyScreenTimeHours: 9.0, isEstimate: true
        )
        XCTAssertEqual(c.newLine?.value, "8h+/day")
        XCTAssertTrue(c.bubble.contains("8h+"))
    }

    func test_finalBeat_hasNoNewLine_andPresentingCopy() {
        let c = PlanBuildBeatContent(
            beat: .final, goals: [.doomscrolling], age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertNil(c.newLine)
        XCTAssertEqual(c.bubble, "Your counterattack's ready.")
    }

    func test_cumulativeLines_includesEveryBeatUpToCurrent() {
        let lines = PlanBuildBeatContent.cumulativeLines(
            upTo: .screenTime,
            goals: [.screenTimeFrying], age: 24, dailyScreenTimeHours: 4.2, isEstimate: false
        )
        XCTAssertEqual(lines.map(\.label), ["Goal", "Age", "Screen time"])
        XCTAssertEqual(lines.map(\.value), ["hours back", "24 · ~56 yrs ahead", "4.2h/day"])
    }

    func test_goalSummary_fallsBackWhenNoKnownGoal() {
        let c = PlanBuildBeatContent(
            beat: .goals, goals: [], age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertEqual(c.newLine?.value, "hours back")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `COPYFILE_DISABLE=1 xcodebuild test -project MindRestore.xcodeproj -scheme MindRestoreTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/mindrestore-build -only-testing:MindRestoreTests/PlanBuildBeatContentTests`
Expected: FAIL — `cannot find 'PlanBuildBeatContent' in scope`.

- [ ] **Step 3: Write the model**

```swift
import Foundation

/// Pure, UI-free content for the onboarding "Memo building your plan" beats.
/// Given the data collected so far, produces Memo's speech bubble and the
/// clipboard line items. No SwiftUI — fully unit-testable.
struct PlanBuildBeatContent {
    enum Beat: CaseIterable {
        case goals, age, screenTime, final
    }

    struct Line: Equatable {
        let label: String
        let value: String
    }

    let beat: Beat
    let goals: Set<UserFocusGoal>
    let age: Int
    let dailyScreenTimeHours: Double
    let isEstimate: Bool

    private static let lifeExpectancy = 80

    private var yearsAhead: Int { max(0, Self.lifeExpectancy - age) }

    /// Human-readable hours/day, clamped to "8h+" for high estimates (mirrors
    /// the existing screen-time presentation rule).
    private var hoursLabel: String {
        if dailyScreenTimeHours >= 8 && isEstimate { return "8h+" }
        // Trim trailing ".0" so 4.0 → "4", 4.2 → "4.2".
        let rounded = (dailyScreenTimeHours * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))h"
        }
        return "\(rounded)h"
    }

    /// Days per year spent on screen = hours/day * 365 / 24, rounded.
    private var daysPerYear: Int {
        Int((dailyScreenTimeHours * 365 / 24).rounded())
    }

    /// Goal phrase, reusing the same mapping as `onboardingPlanGoalSummary`.
    static func goalSummary(_ goals: Set<UserFocusGoal>) -> String {
        if goals.contains(.screenTimeFrying) { return "hours back" }
        if goals.contains(.doomscrolling) { return "sleep protected" }
        if goals.contains(.attentionShot) { return "attention guarded" }
        if goals.contains(.loseFocus) { return "focus that holds" }
        if goals.contains(.forgetInstantly) { return "memory that sticks" }
        if goals.contains(.getSharper) { return "sharper scores" }
        return "hours back"
    }

    var bubble: String {
        switch beat {
        case .goals:
            return "Hours back. That's the mission."
        case .age:
            return "\(age)? You've got ~\(yearsAhead) years of phone ahead."
        case .screenTime:
            return "\(hoursLabel) a day… that's ~\(daysPerYear) days a year gone."
        case .final:
            return "Your counterattack's ready."
        }
    }

    /// The single line THIS beat adds (nil for the final beat, which adds none).
    var newLine: Line? {
        switch beat {
        case .goals:
            return Line(label: "Goal", value: Self.goalSummary(goals))
        case .age:
            return Line(label: "Age", value: "\(age) · ~\(yearsAhead) yrs ahead")
        case .screenTime:
            return Line(label: "Screen time", value: "\(hoursLabel)/day")
        case .final:
            return nil
        }
    }

    /// Every line earned up to AND including `upTo`, in beat order.
    static func cumulativeLines(
        upTo: Beat,
        goals: Set<UserFocusGoal>,
        age: Int,
        dailyScreenTimeHours: Double,
        isEstimate: Bool
    ) -> [Line] {
        let order: [Beat] = [.goals, .age, .screenTime]
        let cutoff = (upTo == .final) ? order.count : (order.firstIndex(of: upTo).map { $0 + 1 } ?? 0)
        return order.prefix(cutoff).compactMap { b in
            PlanBuildBeatContent(
                beat: b, goals: goals, age: age,
                dailyScreenTimeHours: dailyScreenTimeHours, isEstimate: isEstimate
            ).newLine
        }
    }
}
```

> **Note:** Confirm the exact `UserFocusGoal` case names against `MindRestore/Models/Enums.swift` (`.screenTimeFrying`, `.doomscrolling`, `.attentionShot`, `.loseFocus`, `.forgetInstantly`, `.getSharper` are taken from the existing `onboardingPlanGoalSummary` in `OnboardingView.swift:291-299`). If any differ, fix the model and the matching test.

- [ ] **Step 4: Run tests to verify they pass**

Run: `COPYFILE_DISABLE=1 xcodebuild test -project MindRestore.xcodeproj -scheme MindRestoreTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/mindrestore-build -only-testing:MindRestoreTests/PlanBuildBeatContentTests`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add MindRestore/Views/Onboarding/PlanBuildBeatContent.swift MindRestoreTests/PlanBuildBeatContentTests.swift
git commit -m "Add pure beat-content model for onboarding plan beats"
```

---

## Task 2: Building-beat overlay view

Renders one building beat: Memo thinking loop + speech bubble + cumulative "YOUR PLAN" clipboard, then auto-advances. Lives in `OnboardingNewScreens.swift` (existing file → no project registration needed).

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` (append the new view)

- [ ] **Step 1: Append `OnboardingPlanBuildBeatOverlay`**

```swift
/// Transient full-screen beat shown after a data-collection milestone.
/// Memo "thinks", a bubble appears reflecting the latest answer, the new
/// clipboard line snaps in, then `onAdvance` fires automatically.
struct OnboardingPlanBuildBeatOverlay: View {
    let beat: PlanBuildBeatContent.Beat
    let goals: Set<UserFocusGoal>
    let age: Int
    let dailyScreenTimeHours: Double
    let isEstimate: Bool
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bubbleVisible = false
    @State private var revealedLineCount = 0
    @State private var didStart = false

    private var content: PlanBuildBeatContent {
        PlanBuildBeatContent(beat: beat, goals: goals, age: age,
                             dailyScreenTimeHours: dailyScreenTimeHours, isEstimate: isEstimate)
    }

    private var lines: [PlanBuildBeatContent.Line] {
        PlanBuildBeatContent.cumulativeLines(upTo: beat, goals: goals, age: age,
                                             dailyScreenTimeHours: dailyScreenTimeHours, isEstimate: isEstimate)
    }

    // The Memo loop video, with a static fallback if the asset isn't bundled.
    private var memoVideoName: String { "memo-building" }

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("MEMO IS BUILDING YOUR PLAN")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(OB.fg3)
                    .padding(.top, 40)

                memoView
                    .frame(width: 150, height: 150)

                speechBubble

                clipboard

                Spacer()
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: 500)
        }
        .onAppear(perform: start)
    }

    @ViewBuilder
    private var memoView: some View {
        if Bundle.main.url(forResource: memoVideoName, withExtension: "mp4") != nil {
            OnboardingLoopingVideo(videoName: memoVideoName)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        } else if let img = UIImage(named: "focus-memo-neutral") {
            Image(uiImage: img).resizable().scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(OB.surface)
        }
    }

    private var speechBubble: some View {
        Text(content.bubble)
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(OB.fg)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(OB.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(OB.border, lineWidth: 1)
            )
            .opacity(bubbleVisible ? 1 : 0)
            .offset(y: bubbleVisible ? 0 : 8)
    }

    private var clipboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR PLAN")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(OB.fg3)

            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                HStack(spacing: 9) {
                    ZStack {
                        Circle().fill(OB.success).frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(OB.bg)
                    }
                    Text("\(line.label): \(line.value)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(OB.fg)
                }
                .opacity(idx < revealedLineCount ? 1 : 0)
                .offset(x: idx < revealedLineCount ? 0 : -10)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OB.surface.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OB.border, lineWidth: 1))
    }

    private func start() {
        guard !didStart else { return }
        didStart = true

        // Prior lines (everything except this beat's new line) appear immediately.
        let priorCount = max(0, lines.count - 1)
        revealedLineCount = priorCount

        if reduceMotion {
            bubbleVisible = true
            revealedLineCount = lines.count
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onAdvance() }
            return
        }

        withAnimation(.easeOut(duration: 0.35).delay(0.25)) { bubbleVisible = true }
        // New line snaps in after the bubble reads.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                revealedLineCount = lines.count
            }
        }
        // Auto-advance once everything has settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { onAdvance() }
    }
}

/// Thin wrapper around the bundle-loop video so beats can reuse the same
/// AVPlayerLooper playback used by the welcome demo bezel.
struct OnboardingLoopingVideo: UIViewRepresentable {
    let videoName: String

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.backgroundColor = .clear
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else { return view }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(playerItem: item)
        queue.isMuted = true
        queue.actionAtItemEnd = .advance
        let looper = AVPlayerLooper(player: queue, templateItem: item)
        context.coordinator.player = queue
        context.coordinator.looper = looper
        view.playerLayer.player = queue
        view.playerLayer.videoGravity = .resizeAspectFit
        queue.play()
        return view
    }
    func updateUIView(_ uiView: PlayerHostView, context: Context) {}
}
```

> **Note:** `PlayerHostView` is `private` to `OnboardingView.swift`'s `LoopingVideoPlayer`. Two options: (a) change `PlayerHostView`'s access from `private`/file-scoped to internal so it's reusable, or (b) define a local `PlayerHostView` in `OnboardingNewScreens.swift`. Prefer (a) — locate `PlayerHostView` in `OnboardingView.swift` (just below `LoopingVideoPlayer`, ~line 3780+) and drop the `private` so both files share it. Confirm the type's exact name/shape when you get there.

- [ ] **Step 2: Build for simulator**

Run: `COPYFILE_DISABLE=1 xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/mindrestore-build`
Expected: BUILD SUCCEEDED. (Ignore SourceKit "cannot find in scope" diagnostics per CLAUDE.md.)

- [ ] **Step 3: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift MindRestore/Views/Onboarding/OnboardingView.swift
git commit -m "Add building-beat overlay view + shared loop video host"
```

---

## Task 3: Final beat view (replaces OnboardingPlanPersonalizingView)

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` (add final view, delete `OnboardingPlanPersonalizingView` at `OnboardingNewScreens.swift:3096`)

- [ ] **Step 1: Append `OnboardingPlanFinalBeatView`**

```swift
/// Final beat, shown on page 6 right before the hard paywall. Memo flips to a
/// proud "presenting" pose, holds up the now-complete clipboard with a
/// "Personalized for you" stamp, then fires `onComplete` → paywall.
struct OnboardingPlanFinalBeatView: View {
    let goals: Set<UserFocusGoal>
    let age: Int
    let dailyScreenTimeHours: Double
    let isEstimate: Bool
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didStart = false
    @State private var stampVisible = false

    private var lines: [PlanBuildBeatContent.Line] {
        PlanBuildBeatContent.cumulativeLines(upTo: .final, goals: goals, age: age,
                                             dailyScreenTimeHours: dailyScreenTimeHours, isEstimate: isEstimate)
    }
    private var bubble: String {
        PlanBuildBeatContent(beat: .final, goals: goals, age: age,
                             dailyScreenTimeHours: dailyScreenTimeHours, isEstimate: isEstimate).bubble
    }
    private var memoVideoName: String { "memo-presenting" }

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer(minLength: 30)

                Group {
                    if Bundle.main.url(forResource: memoVideoName, withExtension: "mp4") != nil {
                        OnboardingLoopingVideo(videoName: memoVideoName)
                    } else if let img = UIImage(named: "focus-memo-happy") {
                        Image(uiImage: img).resizable().scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 28, style: .continuous).fill(OB.surface)
                    }
                }
                .frame(width: 170, height: 170)

                Text(bubble)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(OB.fg)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("YOUR PLAN")
                            .font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1.4)
                            .foregroundStyle(OB.fg3)
                        Spacer()
                        Text("PERSONALIZED FOR YOU")
                            .font(.system(size: 8, weight: .black, design: .monospaced)).tracking(1.2)
                            .foregroundStyle(OB.success)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(OB.success.opacity(0.14)))
                            .opacity(stampVisible ? 1 : 0)
                            .scaleEffect(stampVisible ? 1 : 0.8)
                    }
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 9) {
                            ZStack {
                                Circle().fill(OB.success).frame(width: 18, height: 18)
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(OB.bg)
                            }
                            Text("\(line.label): \(line.value)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(OB.fg)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OB.surface.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OB.border, lineWidth: 1))

                Spacer()
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: 500)
        }
        .onAppear(perform: start)
    }

    private func start() {
        guard !didStart else { return }
        didStart = true
        let stampDelay = reduceMotion ? 0.2 : 0.8
        let advanceDelay = reduceMotion ? 1.2 : 2.8
        DispatchQueue.main.asyncAfter(deadline: .now() + stampDelay) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { stampVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + advanceDelay) { onComplete() }
    }
}
```

- [ ] **Step 2: Delete `OnboardingPlanPersonalizingView`**

Remove the entire `struct OnboardingPlanPersonalizingView: View { ... }` (starts `OnboardingNewScreens.swift:3096`) and its private helpers (`loaderAtmosphere`, `planDataChips`, `missionChip`, `missionMapSurface`, `gameShuffleSurface`, and any other members that belong only to it). Build after deleting to surface any leftover references.

- [ ] **Step 3: Build for simulator**

Run: `COPYFILE_DISABLE=1 xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/mindrestore-build`
Expected: BUILD FAILED with "cannot find 'OnboardingPlanPersonalizingView'" referenced in `OnboardingView.swift:1123` — that reference is repointed in Task 4. (If it builds, Task 4's repoint is already needed next.)

- [ ] **Step 4: Commit (after Task 4 build passes)** — defer commit; combine with Task 4 since the project won't build between deletion and repoint.

---

## Task 4: Wire beats into OnboardingView

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Add beat state + overlay layer.** Near the other `@State` (after `presentedCover`, ~line 102) add:

```swift
    /// When non-nil, a building beat overlay is shown over the current page.
    @State private var activeBeat: PlanBuildBeatContent.Beat?
    /// Page to navigate to once the active beat finishes.
    @State private var beatTargetPage: Int?
```

In `body`, add the overlay as the LAST child of the root `ZStack` (after the `VStack { ... }` that holds the header + `pageContent`, before `.preferredColorScheme(.dark)`):

```swift
            if let beat = activeBeat {
                OnboardingPlanBuildBeatOverlay(
                    beat: beat,
                    goals: selectedGoals,
                    age: selectedAge > 0 ? selectedAge : 25,
                    dailyScreenTimeHours: effectiveDailyScreenTimeHours,
                    isEstimate: projectionIsEstimate,
                    onAdvance: { finishActiveBeat() }
                )
                .transition(.opacity)
                .zIndex(1000)
            }
```

- [ ] **Step 2: Add the advance helpers.** Near `goToPage` (~line 415) add:

```swift
    /// Plays a building beat, then navigates to `target` once it auto-advances.
    private func advance(after beat: PlanBuildBeatContent.Beat, then target: Int) {
        beatTargetPage = target
        let stepName: String
        switch beat {
        case .goals: stepName = "planBeatGoals"
        case .age: stepName = "planBeatAge"
        case .screenTime: stepName = "planBeatScreenTime"
        case .final: stepName = "planBeatFinal"
        }
        trackOnboardingStepCompleted(stepName)
        withAnimation(.easeInOut(duration: 0.3)) { activeBeat = beat }
    }

    private func finishActiveBeat() {
        let target = beatTargetPage
        withAnimation(.easeInOut(duration: 0.3)) { activeBeat = nil }
        beatTargetPage = nil
        if let target { goToPage(target) }
    }
```

- [ ] **Step 3: Fire Beat 1 after goals.** Find the goals page's continue action — the site where `trackOnboardingStepCompleted("goals")` is immediately followed by `goToPage(2)`. Replace the `goToPage(2)` there with:

```swift
                advance(after: .goals, then: 2) // play beat, then → age
```

(Leave the `trackOnboardingStepCompleted("goals")` line in place; the beat fires its own `planBeatGoals` event on top.)

> If the goals continue does not currently call `goToPage(2)` directly (e.g. it routes through a name sub-step), confirm the real "leaving goals → entering age" transition and wrap that one. The target index for `age` is 2.

- [ ] **Step 4: Fire Beat 2 after age.** At `OnboardingView.swift:1860-1862`, replace:

```swift
                    Button {
                        trackOnboardingStepCompleted("age")
                        goToPage(3) // → screenTimeAccess
                    } label: {
```

with:

```swift
                    Button {
                        trackOnboardingStepCompleted("age")
                        advance(after: .age, then: 3) // play beat, then → screenTimeAccess
                    } label: {
```

- [ ] **Step 5: Fire Beat 3 after screen time / life-squares.** Locate the `lifeSquaresReceiptPage` continue that advances to `memoPlan` (page 5) — the site calling `goToPage(5)` from the life-squares receipt. Replace that `goToPage(5)` with:

```swift
                advance(after: .screenTime, then: 5) // play beat, then → memoPlan
```

> There are multiple `goToPage(5)` sites (e.g. line 1772, 2046). The correct one is the **forward** advance out of `lifeSquaresReceiptPage` toward `memoPlan`. Verify by reading the enclosing view/function; do NOT wrap a back-navigation. If life-squares advances via a different index, wrap the life-squares→next transition and keep its target index unchanged.

- [ ] **Step 6: Repoint page 6 to the final beat.** Replace `planPersonalizingPage` (`OnboardingView.swift:1122-1137`) body:

```swift
    private var planPersonalizingPage: some View {
        OnboardingPlanFinalBeatView(
            goals: selectedGoals,
            age: selectedAge > 0 ? selectedAge : 25,
            dailyScreenTimeHours: effectiveDailyScreenTimeHours,
            isEstimate: projectionIsEstimate,
            onComplete: {
                trackOnboardingStepCompleted("planBeatFinal", extraProperties: [
                    "paywall_trigger": "onboarding_personalized_plan"
                ])
                presentedCover = .paywall
            }
        )
    }
```

(Page 6 stays in `pageContent` and `progressHeaderOpacity`'s hidden set `[6]` — unchanged. The final beat hides its own chrome via full-bleed `OB.bg`.)

- [ ] **Step 7: Build for simulator**

Run: `COPYFILE_DISABLE=1 xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/mindrestore-build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Run the model tests again to confirm no regression**

Run: `COPYFILE_DISABLE=1 xcodebuild test -project MindRestore.xcodeproj -scheme MindRestoreTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/mindrestore-build -only-testing:MindRestoreTests/PlanBuildBeatContentTests`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingView.swift MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "Wire Memo building beats into onboarding flow; replace personalization loader with final beat"
```

---

## Task 5: Add Memo loop assets (MANUAL — user)

- [ ] **Step 1:** Generate the two Runway loops and export as MP4 with a dark (`#0E1014`) background: `memo-building.mp4` (thinking pose) and `memo-presenting.mp4` (presenting pose).

- [ ] **Step 2:** Add both files to the app bundle the same way `onboarding_demo.mp4` is bundled (loose resource in `MindRestore/Resources/`, included in the MindRestore target's "Copy Bundle Resources"). In Xcode: drag both MP4s into `MindRestore/Resources/`, ensure target membership = MindRestore. If using XcodeGen, place them under the resources path and regenerate.

- [ ] **Step 3:** Verify `Bundle.main.url(forResource: "memo-building", withExtension: "mp4")` resolves at runtime (the views fall back to `focus-memo-neutral` / `focus-memo-happy` static images if not, so the screen never breaks).

> Until these assets land, the beats render with the static-image fallback — that's an acceptable intermediate state for verifying flow/copy.

---

## Task 6: Device build + QA + verify-changes

Per CLAUDE.md, verification is not complete until the app builds for and installs on the physical device.

- [ ] **Step 1: Device build**

Run: `COPYFILE_DISABLE=1 xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath /tmp/mindrestore-build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Install on device**

Run: `xcrun devicectl device install app --device 00008130-000A214E11E2001C /tmp/mindrestore-build/Build/Products/Debug-iphoneos/MindRestore.app`

- [ ] **Step 3: Run `/verify-changes`** — screenshot each beat (building beat + final beat) and show the user. Onboarding is dark-pinned; confirm no cream `pageBg` bleed.

- [ ] **Step 4: Flow trace (manual on device or simulator):** goals → Beat 1 (bubble "Hours back. That's the mission." + ✓ Goal) → age → Beat 2 (years-ahead bubble + ✓ Age) → screenTimeAccess → lifeSquaresReceipt → Beat 3 (days/year bubble + ✓ Screen time) → memoPlan → Final beat (presenting + full clipboard + stamp) → paywall. Confirm: every beat auto-advances (no tap), the clipboard is cumulative, copy interpolates the user's real values, and the paywall still receives age / hours / goal.

- [ ] **Step 5: Edge cases:** screen-time estimate ≥8h shows "8h+/day"; `reduceMotion` on (fades, shortened holds, still auto-advances); missing MP4 assets fall back to static Memo; pressing back from age/screenTime/memoPlan returns to the prior real page without replaying a beat (beats are overlays, not pages, so this works by construction — verify).

- [ ] **Step 6: Verify analytics:** in a debug run, confirm `planBeatGoals`, `planBeatAge`, `planBeatScreenTime`, `planBeatFinal` events fire and the paywall attribution property `paywall_trigger: "onboarding_personalized_plan"` is preserved.

---

## Self-Review Notes

- **Spec coverage:** building beats after goals/age/screen-time (Tasks 2, 4) ✓; cumulative clipboard (Task 1 `cumulativeLines`, Tasks 2/3) ✓; final beat before paywall with presenting pose + stamp (Task 3) ✓; auto-advance (Tasks 2/3) ✓; problem-agitate-solve copy + loss-aversion punch (Task 1 strings) ✓; data-driven copy incl. 8h+ clamp and days/year (Task 1 + tests) ✓; Memo assets with fallback (Tasks 2/3/5) ✓; analytics distinct step names + preserved paywall attribution (Task 4) ✓; remove old loader (Task 3) ✓.
- **Divergence:** overlay instead of page-insertion (documented at top) — back-navigation "skip beats" requirement is satisfied for free since beats aren't pages.
- **Type consistency:** `PlanBuildBeatContent.Beat`/`.Line`, `cumulativeLines(upTo:goals:age:dailyScreenTimeHours:isEstimate:)`, `advance(after:then:)`, `finishActiveBeat()`, `OnboardingLoopingVideo(videoName:)` used consistently across tasks.
- **Open risks for the engineer to confirm at execution time:** exact `UserFocusGoal` case names; `PlayerHostView` access level; the precise goals→age and lifeSquares→memoPlan advance call sites (anchored by `trackOnboardingStepCompleted` strings, not just line numbers).
