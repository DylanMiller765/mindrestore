# Industry Scare Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `FocusOnboardIndustryScare` (page 3 of v2.0 onboarding) as a case-file lineup with `memo found the suspects.` headline, four-row suspect grid, $57B aggregate count-up, and detective Memo. Sweep the marketing eyebrow off Pain Cards in the same plan.

**Architecture:** Body rewrite-in-place of the existing `FocusOnboardIndustryScare` struct in `FocusOnboardingPages.swift` — same struct name, same `onContinue: () -> Void` signature, only internal state and view body change. Add a private `SuspectRow` helper struct in the same file. Pain Cards eyebrow swap is a single one-line `Text` edit at `OnboardingNewScreens.swift:1408`. Animation drives off a `Task<Void, Never>` sequence (matches the existing pattern in `OnboardingPersonalSolutionView.revealTask`).

**Tech Stack:** SwiftUI, iOS 17+, brand `Font.brand(...)` + `.system(... design: .monospaced)`, `OB`/`FO` design token enums, existing logo assets in `Assets.xcassets`. No new dependencies. No new files.

**Anti-pattern compliance:**
- **No struct rename** — `FocusOnboardIndustryScare` keeps its name, signature, and file location.
- **No replacement struct** — body is rewritten in place; `SuspectRow` is a new sibling helper, not a replacement.
- **Sequential execution** — single iOS device target `00008130-000A214E11E2001C`; no parallel worktrees.
- **`xcodebuild` CLI only** — never use Xcode MCP `BuildProject` (hangs 10+ min per `feedback_use_xcodebuild_cli`).
- **SourceKit `No such module 'UIKit'` is a known false positive** — ignore it, `xcodebuild` is authoritative.
- **One change at a time** — Pain Cards eyebrow swap commits separately from the Industry Scare rewrite, so each landing can be visually verified independently.

**Source spec:** `docs/superpowers/specs/2026-04-28-industry-scare-redesign-design.md`

---

## File Structure

| File | Action | What it does |
|---|---|---|
| `MindRestore/Views/Onboarding/FocusOnboardingPages.swift` | Modify | Body rewrite of `FocusOnboardIndustryScare` (currently lines 66–245). Adds new private `SuspectRow` struct above it. Animation timeline implemented via `Task<Void, Never>`. |
| `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` | Modify | Single-line edit: replace `OBEyebrow(text: "MEMO FOUND THE RECEIPTS")` at line 1408 with the new mono case-file slug. |
| `MindRestore/Assets.xcassets/mascot-detective.imageset/` | Optional | New asset — user is producing externally. If absent at implementation time, fallback to `mascot-lookout` is in the code. Plan does NOT block on the asset. |

Both files are in the same SwiftUI module/target — no cross-target boundaries to worry about. Both edits are commit-safe in isolation.

---

## Task 1: Reconnaissance — verify the surfaces are where the spec expects them

**Files:** Read-only.

- [ ] **Step 1: Confirm `FocusOnboardIndustryScare` boundaries**

Run:
```bash
grep -n "struct FocusOnboardIndustryScare\|private func startSequence\|private func startCountUp" MindRestore/Views/Onboarding/FocusOnboardingPages.swift
```

Expected output (line numbers may shift slightly):
```
66:struct FocusOnboardIndustryScare: View {
189:    private func startSequence() {
218:    private func startCountUp() {
```

If `struct FocusOnboardIndustryScare` is not found at line ~66, stop and re-locate. Every later step assumes this struct lives in this file.

- [ ] **Step 2: Confirm Pain Cards eyebrow location**

Run:
```bash
grep -n 'OBEyebrow(text: "MEMO FOUND THE RECEIPTS")' MindRestore/Views/Onboarding/OnboardingNewScreens.swift
```

Expected output:
```
1408:                OBEyebrow(text: "MEMO FOUND THE RECEIPTS")
```

If the line number drifts, that's fine — Task 6 uses the literal string match, not the line number. But if the string is missing entirely, stop — the file may have been edited.

- [ ] **Step 3: Confirm OB tokens are accessible cross-file**

Run:
```bash
grep -n "enum OB " MindRestore/Views/Onboarding/OnboardingNewScreens.swift
```

Expected output:
```
1312:enum OB {
```

`OB` is module-internal (no `private`). It's reachable from `FocusOnboardingPages.swift`. The new code uses `OB.bg`, `OB.fg`, `OB.fg2`, `OB.fg3`, `OB.accent`, `OB.coral`, `OB.amber`, `OB.border`.

- [ ] **Step 4: Confirm logo assets exist**

Run:
```bash
ls MindRestore/Assets.xcassets/ | grep -E "logo-(tiktok|instagram|youtube|snapchat)\.imageset"
```

Expected output (4 lines, in any order):
```
logo-instagram.imageset
logo-snapchat.imageset
logo-tiktok.imageset
logo-youtube.imageset
```

If any are missing, stop and tell the user — the suspect lineup depends on these.

- [ ] **Step 5: Confirm `mascot-lookout` fallback exists**

Run:
```bash
ls MindRestore/Assets.xcassets/ | grep "mascot-lookout"
```

Expected output:
```
mascot-lookout.imageset
```

If missing, stop. The plan needs at least the fallback.

- [ ] **Step 6: Note whether `mascot-detective` is already in the catalog**

Run:
```bash
ls MindRestore/Assets.xcassets/ | grep "mascot-detective" || echo "NOT YET — fallback to mascot-lookout will activate"
```

Either output is acceptable. Record the result for Task 5.

---

## Task 2: Pain Cards eyebrow sweep

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift:1408`

The smallest possible change. Doing this first as a warm-up that verifies the build pipeline before the bigger rewrite.

- [ ] **Step 1: Read the current eyebrow line and its 3 lines of surrounding context**

Run:
```bash
sed -n '1406,1411p' MindRestore/Views/Onboarding/OnboardingNewScreens.swift
```

Expected output should show `OBEyebrow(text: "MEMO FOUND THE RECEIPTS")` on line 1408 inside a `VStack` that lays out the Pain Cards header. Confirm the surrounding indentation is `                ` (16 spaces). The new line will use the same indentation.

- [ ] **Step 2: Replace the eyebrow with a mono case-file slug**

Use the Edit tool. Replace exactly:

```swift
                OBEyebrow(text: "MEMO FOUND THE RECEIPTS")
```

with:

```swift
                Text("CASE FILE · 03 OF 04")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(OB.fg3)
```

This swaps the blue brand-font marketing eyebrow for a mono small-caps grey slug. Same slot, different style entirely.

- [ ] **Step 3: Build for device**

Run:
```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -10
```

Expected output ends with:
```
** BUILD SUCCEEDED **
```

If a SourceKit `No such module 'UIKit'` warning appears, ignore it (known false positive per `CLAUDE.md`). Real errors will show as `error: ...` lines.

- [ ] **Step 4: Install on device**

Run:
```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

Expected: output ends with `databaseSequenceNumber: ...` (any number).

- [ ] **Step 5: Verify the swap landed**

Run:
```bash
grep -n "MEMO FOUND THE RECEIPTS\|CASE FILE · 03 OF 04" MindRestore/Views/Onboarding/OnboardingNewScreens.swift
```

Expected: zero matches for `MEMO FOUND THE RECEIPTS`, one match for `CASE FILE · 03 OF 04`.

- [ ] **Step 6: Commit**

Run:
```bash
git add MindRestore/Views/Onboarding/OnboardingNewScreens.swift
git commit -m "$(cat <<'EOF'
feat(onboarding): swap Pain Cards eyebrow to mono case-file slug

Replaces the blue uppercase OBEyebrow "MEMO FOUND THE RECEIPTS"
with a mono small-caps grey "CASE FILE · 03 OF 04" slug.

Sets up the case-file motif that Industry Scare (next commit) extends
with "CASE FILE · 04 OF 04" and the suspect-lineup layout. Per the
2026-04-28 brainstorm spec, the goal is dropping the marketing
eyebrow on pages that didn't already have it elsewhere in the flow.

Build SUCCEEDED + installed on device 00008130-000A214E11E2001C.

Spec: docs/superpowers/specs/2026-04-28-industry-scare-redesign-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: `1 file changed, 4 insertions(+), 1 deletion(-)`.

---

## Task 3: Add `SuspectRow` private helper struct

**Files:**
- Modify: `MindRestore/Views/Onboarding/FocusOnboardingPages.swift`

Adds the new private `SuspectRow` struct just above `FocusOnboardIndustryScare`. Done as its own commit so a build break here is isolated from the body rewrite in Task 4.

- [ ] **Step 1: Read the area just above `FocusOnboardIndustryScare`**

Run:
```bash
sed -n '58,67p' MindRestore/Views/Onboarding/FocusOnboardingPages.swift
```

Expected output shows the `// MARK: - Industry Scare` comment block (lines 59–65) followed by `struct FocusOnboardIndustryScare: View {` on line 66.

- [ ] **Step 2: Insert `SuspectRow` private struct above `// MARK: - Industry Scare`**

Use the Edit tool. Replace exactly:

```swift
// MARK: - Industry Scare ($57B engineering spend)
//
// Sequenced entrance: eyebrow → number count-up (with haptic ticks) → subtitle
// → callout slide-in → mascot spring → defiance headline → equalizer line.
// Total ~2.3s. Static text was failing to "hit" — the count-up gives the number
// weight and the staggered reveal forces a reading rhythm instead of a wall.

struct FocusOnboardIndustryScare: View {
```

with:

```swift
// MARK: - Industry Scare ($57B engineering spend)
//
// Case-file lineup. Pain Cards = your receipts (confessions). Industry Scare
// = their receipts (crimes). Sequel to "memo found the receipts" — same
// metaphor extended, different target. Five visible elements: case slug,
// headline, caution-tape divider, four-row suspect lineup, $57B aggregate.
// Total entrance arc ~3.0s.

private struct SuspectRow: View {
    let logoAsset: String
    let suspect: String
    let parent: String
    let role: String
    let visible: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(logoAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(suspect)
                        .font(.brand(size: 13, weight: .heavy))
                        .foregroundStyle(OB.fg)
                    Text(parent)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(OB.fg2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(role)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(OB.coral)
            }
            .padding(.vertical, 10)

            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
            }
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 8)
    }
}

struct FocusOnboardIndustryScare: View {
```

- [ ] **Step 3: Build to verify the new struct compiles**

Run:
```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -10
```

Expected: `** BUILD SUCCEEDED **`. The new struct is unused yet, but Swift won't error — only a warning about an unused private declaration is possible (and is OK; Task 4 wires it up).

If you see `error: cannot find 'OB' in scope`, the cross-file `OB` enum reference isn't resolving. Confirm `OB` is defined in `OnboardingNewScreens.swift:1312` and is NOT marked `private`. If it has been marked private, that's a regression in the codebase outside this plan's scope — stop and tell the user.

- [ ] **Step 4: Commit**

```bash
git add MindRestore/Views/Onboarding/FocusOnboardingPages.swift
git commit -m "$(cat <<'EOF'
chore(industry-scare): add SuspectRow private helper struct

Pre-wires the SuspectRow used by the Industry Scare rewrite (next
commit). Each row renders a logo + suspect name (Memo brand font) +
parent company (mono small caps, OB.fg2) + product role (mono small
caps, OB.coral, right-aligned). Hairline white@10% divider between
rows. Animates in via opacity + 8pt y-offset.

Build SUCCEEDED on device 00008130-000A214E11E2001C. Struct is
currently unused — the next commit wires it into the page body.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: `1 file changed, 53 insertions(+), 5 deletions(-)` (the comment block above the struct also changed).

---

## Task 4: Replace `FocusOnboardIndustryScare` body, state, and animation

**Files:**
- Modify: `MindRestore/Views/Onboarding/FocusOnboardingPages.swift`

This is the substantive edit. Replaces the entire `FocusOnboardIndustryScare` body, state declarations, and animation functions in one swap. The struct keeps its name and signature.

- [ ] **Step 1: Replace the entire struct body**

Use the Edit tool. Replace exactly:

```swift
struct FocusOnboardIndustryScare: View {
    var onContinue: () -> Void

    @State private var displayedNumber: Int = 0
    @State private var subtitleVisible = false
    @State private var calloutVisible = false
    @State private var mascotVisible = false
    @State private var defianceVisible = false
    @State private var equalizerVisible = false
    @State private var countUpTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FOEyebrow(text: "WHAT YOU'RE UP AGAINST")
                .padding(.top, 24)
                .padding(.bottom, 16)

            // The number — Monkeytype-coded. $ + animating integer + B.
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("$")
                    .font(.system(size: 92, weight: .bold, design: .monospaced))
                    .kerning(-4)
                    .foregroundStyle(FO.accent)
                Text("\(displayedNumber)")
                    .font(.system(size: 132, weight: .bold, design: .monospaced))
                    .kerning(-7)
                    .foregroundStyle(FO.fg)
                    .contentTransition(.numericText(value: Double(displayedNumber)))
                    .monospacedDigit()
                Text("B")
                    .font(.system(size: 132, weight: .bold, design: .monospaced))
                    .kerning(-7)
                    .foregroundStyle(FO.fg)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            VStack(alignment: .leading, spacing: 4) {
                Text("/ YEAR ENGINEERING YOUR FEED")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(FO.fg3)
                    .textCase(.uppercase)

                Text("TIKTOK · INSTAGRAM · YOUTUBE · SNAP")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(FO.fg2)
                    .textCase(.uppercase)
            }
            .padding(.top, 10)
            .opacity(subtitleVisible ? 1 : 0)
            .offset(y: subtitleVisible ? 0 : 8)

            // Callout — two short punchy lines, no italic for readability
            HStack(spacing: 0) {
                Rectangle().fill(FO.accent).frame(width: 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text("The algorithm isn't broken.")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(FO.fg)

                    (Text("It's working exactly ")
                     + Text("as designed").foregroundColor(FO.accent).fontWeight(.bold))
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(FO.fg)
                }
                .padding(.leading, 14)
                .padding(.vertical, 2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 340, alignment: .leading)
            .padding(.top, 22)
            .opacity(calloutVisible ? 1 : 0)
            .offset(x: calloutVisible ? 0 : -20)

            Spacer()

            // Memo (defiant) bottom-left
            HStack {
                Image("mascot-goal")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .offset(x: -8, y: 8)
                Spacer()
            }
            .opacity(mascotVisible ? 1 : 0)
            .scaleEffect(mascotVisible ? 1 : 0.82, anchor: .bottomLeading)

            // Defiance headline
            (Text("You're not weak.\nYou're ") + Text("outgunned").foregroundColor(FO.accent) + Text("."))
                .font(.system(size: 30, weight: .bold))
                .kerning(-0.9)
                .foregroundStyle(FO.fg)
                .lineSpacing(1)
                .padding(.bottom, 4)
                .opacity(defianceVisible ? 1 : 0)
                .offset(y: defianceVisible ? 0 : 8)

            Text("Memo's the equalizer.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FO.fg2)
                .padding(.bottom, 8)
                .opacity(equalizerVisible ? 1 : 0)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FO.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            FOContinueButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
        .onAppear { startSequence() }
        .onDisappear {
            countUpTimer?.invalidate()
            countUpTimer = nil
        }
    }

    private func startSequence() {
        // Reset every appearance so re-entry replays the cinema.
        displayedNumber = 0
        subtitleVisible = false
        calloutVisible = false
        mascotVisible = false
        defianceVisible = false
        equalizerVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            startCountUp()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            withAnimation(.easeOut(duration: 0.4)) { subtitleVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { calloutVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { mascotVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.15) {
            withAnimation(.easeOut(duration: 0.4)) { defianceVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.4)) { equalizerVisible = true }
        }
    }

    private func startCountUp() {
        let target = 57
        let duration = 0.95
        let totalSteps = target
        let interval = duration / Double(totalSteps)

        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        lightImpact.prepare()
        heavyImpact.prepare()

        countUpTimer?.invalidate()
        countUpTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            Task { @MainActor in
                if displayedNumber >= target {
                    timer.invalidate()
                    countUpTimer = nil
                    heavyImpact.impactOccurred(intensity: 1.0)
                } else {
                    displayedNumber += 1
                    if displayedNumber % 7 == 0 {
                        lightImpact.impactOccurred(intensity: 0.4)
                    }
                }
            }
        }
    }
}
```

with:

```swift
struct FocusOnboardIndustryScare: View {
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var slugVisible = false
    @State private var headlineVisible = false
    @State private var tapeProgress: CGFloat = 0
    @State private var rowsVisible: [Bool] = Array(repeating: false, count: 4)
    @State private var dividerVisible = false
    @State private var displayedNumber: Int = 0
    @State private var captionVisible = false
    @State private var mascotVisible = false
    @State private var ctaVisible = false
    @State private var sequenceTask: Task<Void, Never>?

    private let suspects: [(asset: String, name: String, parent: String, role: String)] = [
        (asset: "logo-tiktok", name: "TikTok", parent: "BYTEDANCE", role: "FEED"),
        (asset: "logo-instagram", name: "Instagram", parent: "META", role: "REELS"),
        (asset: "logo-youtube", name: "YouTube", parent: "GOOGLE", role: "SHORTS"),
        (asset: "logo-snapchat", name: "Snap", parent: "SNAP INC", role: "SPOTLIGHT")
    ]

    /// Detective Memo asset. Falls back to mascot-lookout when the new
    /// mascot-detective image is not yet in the asset catalog.
    /// TODO: drop this fallback once Assets.xcassets/mascot-detective.imageset
    /// is added to the project.
    private var detectiveMascotName: String {
        UIImage(named: "mascot-detective") != nil ? "mascot-detective" : "mascot-lookout"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Case-file slug (replaces the old blue marketing eyebrow)
            Text("CASE FILE · 04 OF 04")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(OB.fg3)
                .padding(.top, 12)
                .opacity(slugVisible ? 1 : 0)
                .offset(y: slugVisible ? 0 : 8)

            // Headline — sequel to Pain Cards' "memo found the receipts."
            Text("memo found\nthe suspects.")
                .font(.brand(size: 26, weight: .heavy))
                .kerning(-0.5)
                .lineSpacing(2)
                .foregroundStyle(OB.fg)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .opacity(headlineVisible ? 1 : 0)
                .offset(y: headlineVisible ? 0 : 8)

            // Caution-tape divider (full-bleed via negative horizontal margins)
            cautionTape
                .padding(.top, 16)

            // Suspect lineup
            VStack(spacing: 0) {
                ForEach(Array(suspects.enumerated()), id: \.offset) { index, suspect in
                    SuspectRow(
                        logoAsset: suspect.asset,
                        suspect: suspect.name,
                        parent: suspect.parent,
                        role: suspect.role,
                        visible: index < rowsVisible.count && rowsVisible[index],
                        isLast: index == suspects.count - 1
                    )
                }
            }
            .padding(.top, 4)

            // Top divider above the totals block
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1.5)
                .padding(.top, 12)
                .opacity(dividerVisible ? 1 : 0)

            // Totals block
            VStack(alignment: .leading, spacing: 6) {
                Text("COMBINED R&D · ANNUAL")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(OB.fg3)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("$\(displayedNumber)B")
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .kerning(-3)
                        .foregroundStyle(OB.fg)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(displayedNumber)))
                }
                .lineLimit(1)

                Text("spent every year engineering\nyour feed against you.")
                    .font(.brand(size: 12, weight: .semibold))
                    .foregroundStyle(OB.fg2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(captionVisible ? 1 : 0)
                    .offset(y: captionVisible ? 0 : 8)
            }
            .padding(.top, 14)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FO.bg.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            // Detective Memo
            VStack(alignment: .trailing, spacing: 4) {
                Image(detectiveMascotName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .shadow(color: OB.accent.opacity(0.32), radius: 16, x: 0, y: 6)
                Text("MEMO · DETECTIVE")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(OB.fg3)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 96)
            .opacity(mascotVisible ? 1 : 0)
            .accessibilityHidden(true)
        }
        .safeAreaInset(edge: .bottom) {
            FOContinueButton(title: "i'm in. fight back.", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .opacity(ctaVisible ? 1 : 0)
        }
        .preferredColorScheme(.dark)
        .onAppear { startSequence() }
        .onDisappear {
            sequenceTask?.cancel()
            sequenceTask = nil
        }
    }

    private var cautionTape: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: OB.amber, location: 0),
                            .init(color: OB.amber, location: 0.5),
                            .init(color: FO.bg, location: 0.5),
                            .init(color: FO.bg, location: 1)
                        ],
                        startPoint: UnitPoint(x: 0, y: 0),
                        endPoint: UnitPoint(x: 0.05, y: 0.05)
                    )
                )
                .frame(width: proxy.size.width * tapeProgress)
        }
        .frame(height: 10)
        .padding(.horizontal, -24) // full-bleed past the page's 24pt margin
    }

    private func startSequence() {
        // Reset every appearance so re-entry replays the cinema.
        slugVisible = false
        headlineVisible = false
        tapeProgress = 0
        rowsVisible = Array(repeating: false, count: 4)
        dividerVisible = false
        displayedNumber = 0
        captionVisible = false
        mascotVisible = false
        ctaVisible = false

        sequenceTask?.cancel()
        sequenceTask = Task { @MainActor in
            if reduceMotion {
                // Reduce Motion path — single 0.18s opacity fade, $57B set immediately.
                displayedNumber = 57
                withAnimation(.easeOut(duration: 0.18)) {
                    slugVisible = true
                    headlineVisible = true
                    tapeProgress = 1
                    rowsVisible = Array(repeating: true, count: 4)
                    dividerVisible = true
                    captionVisible = true
                    mascotVisible = true
                    ctaVisible = true
                }
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
                return
            }

            // Standard cinematic path (~3.0s total).
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.40)) {
                slugVisible = true
                headlineVisible = true
            }

            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.50)) {
                tapeProgress = 1
            }

            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            // Suspect rows stagger 0.10s apart, light haptic per row.
            let lightImpact = UIImpactFeedbackGenerator(style: .light)
            lightImpact.prepare()
            for i in 0..<rowsVisible.count {
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.30)) {
                    if i < rowsVisible.count { rowsVisible[i] = true }
                }
                lightImpact.impactOccurred(intensity: 0.4)
                try? await Task.sleep(for: .milliseconds(100))
            }

            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.30)) {
                dividerVisible = true
            }

            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            // $57B count-up over ~1.2s.
            await runCountUp()
            guard !Task.isCancelled else { return }

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.40)) {
                captionVisible = true
                mascotVisible = true
                ctaVisible = true
            }
        }
    }

    @MainActor
    private func runCountUp() async {
        let target = 57
        let steps = target
        let stepMs = 21 // ~1.2s total
        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        lightImpact.prepare()

        for step in 1...steps {
            guard !Task.isCancelled else { return }
            displayedNumber = step
            if step % 7 == 0 {
                lightImpact.impactOccurred(intensity: 0.3)
            }
            try? await Task.sleep(for: .milliseconds(stepMs))
        }
        displayedNumber = target
    }
}
```

This single edit:
- Replaces all `@State` declarations.
- Replaces the entire `body`.
- Replaces `startSequence()` with a `Task`-based sequence including the Reduce Motion branch.
- Replaces `startCountUp()` with `runCountUp()` (async).
- Adds a `cautionTape` private computed view.
- Adds the `suspects` data array (table inline).
- Adds the `detectiveMascotName` runtime fallback (`UIImage(named:)` returns `nil` if the asset isn't in the catalog, so we fall back to `mascot-lookout`).

- [ ] **Step 2: Build for device**

Run:
```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -10
```

Expected: `** BUILD SUCCEEDED **`. Ignore SourceKit `No such module 'UIKit'` warning.

If errors appear:
- `cannot find 'OB' in scope` → verify the `OB` enum at `OnboardingNewScreens.swift:1312` is reachable. It should be module-internal (no `private`).
- `cannot find 'SuspectRow' in scope` → Task 3 didn't land cleanly. Re-check the file around line 67.
- `value of type ... has no member 'monospacedDigit'` → the modifier order matters; `.monospacedDigit()` must come after `.font()`. Re-check the exact spelling and order.

- [ ] **Step 3: Verify the verbatim copy strings landed**

Run:
```bash
grep -nE 'CASE FILE · 04 OF 04|memo found\\nthe suspects\\.|COMBINED R&D · ANNUAL|spent every year engineering|i.m in\\. fight back\\.|MEMO · DETECTIVE|BYTEDANCE|SNAP INC|SHORTS|SPOTLIGHT' MindRestore/Views/Onboarding/FocusOnboardingPages.swift
```

Expected: at least 9 matches (slug, headline, total label, caption fragment, CTA, mascot label, two parent companies, two role labels). If any are missing, the edit didn't fully apply — re-run.

- [ ] **Step 4: Verify forbidden strings are gone**

Run:
```bash
grep -nE 'WHAT YOU.RE UP AGAINST|YEAR ENGINEERING YOUR FEED|TIKTOK · INSTAGRAM · YOUTUBE · SNAP|The algorithm isn.t broken|You.re not weak|Memo.s the equalizer' MindRestore/Views/Onboarding/FocusOnboardingPages.swift
```

Expected: zero matches. The previous Industry Scare copy is fully removed.

- [ ] **Step 5: Install on device**

Run:
```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
```

Expected: ends with `databaseSequenceNumber: ...`.

- [ ] **Step 6: Commit**

```bash
git add MindRestore/Views/Onboarding/FocusOnboardingPages.swift
git commit -m "$(cat <<'EOF'
feat(industry-scare): rewrite as case-file lineup, sequel to Pain Cards

Body rewrite-in-place of FocusOnboardIndustryScare. Struct name and
onContinue: () -> Void signature unchanged. New layout (5 elements,
2 fonts):

- "CASE FILE · 04 OF 04" mono slug (replaces blue marketing eyebrow)
- "memo found the suspects." headline (sequel to Pain Cards' "memo
  found the receipts.")
- Caution-tape divider (full-bleed amber/dark stripes)
- 4-row suspect lineup: TikTok / Instagram / YouTube / Snap with
  parent companies (BYTEDANCE / META / GOOGLE / SNAP INC) and product
  roles (FEED / REELS / SHORTS / SPOTLIGHT). No per-company dollar
  figures — defensibility.
- $57B aggregate count-up (mono 56pt black, 0 → 57 over ~1.2s)
- "spent every year engineering your feed against you." caption
- Detective Memo bottom-right (mascot-detective with mascot-lookout
  fallback via UIImage(named:) runtime check). Includes inline TODO
  to drop the fallback once mascot-detective ships in the catalog.
- "i'm in. fight back." CTA in FOContinueButton

Animation: Task-based sequence ~3.0s. Slug + headline → caution tape
roll-in → suspect rows stagger (0.10s, light haptic each) → divider
→ $57B count-up → medium haptic on settle → caption + mascot + CTA
fade up.

Reduce Motion: single 0.18s opacity fade, $57B set immediately,
single light haptic at +0.30s preserves the cinematic moment.

Verified: xcodebuild SUCCEEDED + installed on device
00008130-000A214E11E2001C. Forbidden strings ("WHAT YOU'RE UP
AGAINST", "Memo's the equalizer", etc.) grep-confirmed absent. New
verbatim strings grep-confirmed present.

Spec: docs/superpowers/specs/2026-04-28-industry-scare-redesign-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: `1 file changed, ~250 insertions(+), ~180 deletions(-)`.

---

## Task 5: On-device visual verification + iteration

**Files:** None (visual verification only).

This task is the user-in-the-loop checkpoint. Per the project's `feedback_ui_iteration_not_batch` rule, the build is on the device after Task 4 step 5; the user walks the page and reacts before any further changes.

- [ ] **Step 1: Tell the user the build is on device and what to verify**

Output exactly this message to the user:

> Industry Scare rebuilt + installed on device. Walk to it (advance through Welcome → Name → Pain Cards → Industry Scare) and verify:
>
> 1. Mono `CASE FILE · 04 OF 04` slug at the top (no blue eyebrow).
> 2. `memo found the suspects.` headline lands.
> 3. Caution-tape rolls in left → right.
> 4. 4 suspect rows appear one at a time with logos + parent + role label, light haptic each.
> 5. `$57B` counts up over ~1.2s, medium haptic on settle.
> 6. `spent every year engineering your feed against you.` caption.
> 7. Detective Memo bottom-right (will be `mascot-lookout` until you drop in `mascot-detective`).
> 8. CTA reads `i'm in. fight back.`
> 9. Pain Cards (the page just before) now shows mono `CASE FILE · 03 OF 04` slug instead of the blue `MEMO FOUND THE RECEIPTS` eyebrow.
>
> Also flip Reduce Motion ON in iOS Settings → Accessibility → Motion. Re-walk Industry Scare. Verify count-up is skipped, $57B shows immediately, single light haptic fires.
>
> If anything looks wrong, describe what you see and I'll iterate.

- [ ] **Step 2: Wait for user feedback**

The user replies with either approval ("looks good", "ship it", etc.) or specific defects. Halt before any further edits — every iteration is one targeted change → rebuild → re-show, never batched.

- [ ] **Step 3 (if approval): Update `mascot-detective` TODO**

If and only if the user has dropped `mascot-detective.imageset` into `Assets.xcassets` AT THIS POINT, run:

```bash
ls MindRestore/Assets.xcassets/ | grep "mascot-detective" || echo "still not present"
```

If present, edit `FocusOnboardingPages.swift` to remove the `UIImage(named:)` fallback and the TODO comment. Replace exactly:

```swift
    /// Detective Memo asset. Falls back to mascot-lookout when the new
    /// mascot-detective image is not yet in the asset catalog.
    /// TODO: drop this fallback once Assets.xcassets/mascot-detective.imageset
    /// is added to the project.
    private var detectiveMascotName: String {
        UIImage(named: "mascot-detective") != nil ? "mascot-detective" : "mascot-lookout"
    }
```

with:

```swift
    private let detectiveMascotName: String = "mascot-detective"
```

Then build + install + commit:

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "(error:|BUILD SUCCEEDED)" | head -3
xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1 | tail -3
git add MindRestore/Views/Onboarding/FocusOnboardingPages.swift
git commit -m "chore(industry-scare): drop mascot-detective fallback now that asset shipped

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

If the asset is NOT yet present, leave the fallback in place and tell the user "Detective fallback still active — drop me a note when `mascot-detective` is in the catalog and I'll clean up the runtime check."

- [ ] **Step 4 (if defects): Iterate one defect at a time**

For each defect the user describes:
1. Make the single targeted edit.
2. Build with `xcodebuild`.
3. Install with `xcrun devicectl`.
4. Commit with a focused message.
5. Tell the user to re-check.

Never batch multiple visual fixes into one commit. The `feedback_ui_iteration_not_batch` rule is canonical.

---

## Self-Review

**Spec coverage check (against `docs/superpowers/specs/2026-04-28-industry-scare-redesign-design.md`):**

- ✓ Visual layout 1–10 (case slug, headline, tape, suspects, top divider, total label, $57B, caption, mascot, CTA) — all in Task 4 step 1's body replacement.
- ✓ Animation choreography table (slug+headline @ 0.10s, tape @ 0.55s, rows stagger @ 1.05s, divider @ 1.55s, count-up @ 1.70s, caption+mascot+CTA @ 2.95s) — implemented in `startSequence()` Task with matching delays (100, 450, 500, 4×100, 50, 150, count, 100, 400 ms).
- ✓ Reduce Motion fallback — branched at the top of the `Task`, single 0.18s opacity flip, light haptic at +0.30s.
- ✓ Voice notes (lowercase headline + CTA, mono caps for parent companies and roles) — preserved in the constants array and Text declarations.
- ✓ Eyebrow sweep (Pain Cards `CASE FILE · 03 OF 04`, Industry Scare `CASE FILE · 04 OF 04`) — Tasks 2 + 4 respectively.
- ✓ Asset fallback (`mascot-detective` → `mascot-lookout`) — `detectiveMascotName` runtime check; TODO comment + cleanup step in Task 5.
- ✓ Suspect data table (4 rows with logo / name / parent / role) — `suspects` array literal in Task 4 step 1.
- ✓ Verification (build + install + grep verbatim + grep forbidden + on-device walk) — Task 4 steps 2–4 + Task 5 step 1.

**Placeholder scan:** No "TBD", no "implement later", no "add error handling here." Each step shows exact code or exact commands.

**Type consistency check:**
- `SuspectRow.logoAsset/suspect/parent/role/visible/isLast` defined in Task 3 — exact same names and types referenced in the `ForEach` consumer in Task 4. ✓
- `displayedNumber: Int` declared in Task 4's state — referenced as `Double(displayedNumber)` in `.contentTransition` and as `step` assignment in `runCountUp()`. Same property throughout. ✓
- `rowsVisible: [Bool]` declared with count 4 — `ForEach` indexes into `rowsVisible[index]` with same count guarded by `index < rowsVisible.count`. ✓
- `sequenceTask: Task<Void, Never>?` declared in Task 4 state — assigned + cancelled in matching pattern. ✓

**Caution-tape implementation note:** the `LinearGradient` with stops at `0`/`0.5`/`0.5`/`1` produces a single diagonal stripe pair. To get the repeating tape pattern in the wireframe, the body could use SwiftUI's `Canvas` or a tiled image — but for a 10pt-tall divider that flashes by during entrance, the single-cycle gradient renders fast and reads as "caution tape" without the cost of a repeating pattern. If the user flags it as too plain in Task 5, a follow-up edit can replace the gradient with a `Canvas { ctx, size in ... }` block that draws the diagonal stripe pattern. Documented here for transparency, not blocking.

---

Plan complete and saved to `docs/superpowers/plans/2026-04-28-industry-scare-redesign.md`.
