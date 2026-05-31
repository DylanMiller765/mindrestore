# Coach Plan Paywall Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current generic paywall card fan with a friendly first-week Memo coach plan while preserving purchase behavior.

**Architecture:** Keep the change inside `MindRestore/Views/Paywall/PaywallView.swift`. Update both the production `PaywallView` helpers and the debug-only `MemoCutePaywallPreviewView` helpers so Xcode preview matches the shipped paywall. Do not change StoreKit, RevenueCat, analytics, routing, product IDs, or the Xcode project.

**Tech Stack:** SwiftUI, existing `PW` aliases backed by `AppColors`, existing asset-catalog images, existing `StoreService`.

---

### Task 1: Update Production Hero Card

**Files:**
- Modify: `MindRestore/Views/Paywall/PaywallView.swift`

- [ ] **Step 1: Confirm the implementation target**

Run:

```bash
rg -n "cutePlanHero|planCardMiniContent|mainPlanCard|planHeroRow|trialPaymentNotice" MindRestore/Views/Paywall/PaywallView.swift
```

Expected: the production helpers appear near the top of the file, and debug-only preview helpers appear later inside `#if DEBUG`.

- [ ] **Step 2: Replace the production side-card contents**

In `cutePlanHero(compact:)`, replace the two `planCardMiniContent(...)` calls with:

```swift
coachNoteContent(
    eyebrow: "Your pull",
    value: screenTimeReceiptValue,
    icon: "chart.bar.fill",
    color: PW.coral,
    compact: compact
)
```

and:

```swift
coachNoteContent(
    eyebrow: "Memo's move",
    value: "Guard + train",
    icon: "sparkles",
    color: PW.accent,
    compact: compact
)
```

Keep the current card rotations, offsets, and scale values.

- [ ] **Step 3: Replace the production main plan card**

Replace the body of `mainPlanCard(compact:)` with:

```swift
VStack(alignment: .leading, spacing: compact ? 7 : 8) {
    VStack(alignment: .leading, spacing: 3) {
        Text("YOUR FIRST WEEK")
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(1.1)
            .foregroundStyle(PW.accent)
            .lineLimit(1)

        Text("Memo made your first-week plan")
            .font(.system(size: compact ? 13 : 14, weight: .black, design: .rounded))
            .foregroundStyle(PW.bg)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
    }

    planHeroRow(icon: "chart.bar.fill", title: "Start point", value: "\(screenTimeReceiptValue) feed pull", color: PW.coral, compact: compact)
    planHeroRow(icon: "lock.fill", title: "Day 1", value: "Guard your loudest app", color: PW.accent, compact: compact)
    planHeroRow(icon: "brain.head.profile", title: "Day 2", value: "Train attention first", color: PW.mint, compact: compact)
    planHeroRow(icon: "flame.fill", title: "This week", value: "Build your comeback streak", color: PW.amber, compact: compact)
}
.padding(.horizontal, compact ? 13 : 15)
.padding(.top, compact ? 34 : 40)
.padding(.bottom, compact ? 11 : 13)
.frame(width: compact ? 188 : 214, height: compact ? 170 : 194)
.background(
    RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(.white)
)
.overlay(
    RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(PW.accent.opacity(0.16), lineWidth: 1)
)
.shadow(color: PW.bg.opacity(0.22), radius: 18, y: 12)
.offset(y: compact ? 26 : 30)
.accessibilityElement(children: .combine)
.accessibilityLabel("Your first week. Start point \(screenTimeReceiptValue) feed pull. Day 1 guard your loudest app. Day 2 train attention before unlocks. This week build your comeback streak.")
```

Use `Train attention first` in the visible row value to avoid clipping on small screens; the accessibility label keeps the fuller approved phrase.

- [ ] **Step 4: Replace `planCardMiniContent` with `coachNoteContent`**

Rename the production helper `planCardMiniContent(...)` to:

```swift
private func coachNoteContent(
    eyebrow: String,
    value: String,
    icon: String,
    color: Color,
    compact: Bool
) -> some View {
    VStack(alignment: .leading, spacing: compact ? 6 : 7) {
        Image(systemName: icon)
            .font(.system(size: compact ? 16 : 18, weight: .bold))
            .foregroundStyle(color)
            .frame(width: compact ? 28 : 30, height: compact ? 28 : 30)
            .background(Circle().fill(color.opacity(0.13)))

        Spacer(minLength: 2)

        Text(eyebrow)
            .font(.system(size: compact ? 9 : 10, weight: .black, design: .rounded))
            .foregroundStyle(PW.bg.opacity(0.46))
            .lineLimit(1)
            .minimumScaleFactor(0.74)

        Text(value)
            .font(.system(size: compact ? 14 : 16, weight: .black, design: .rounded))
            .foregroundStyle(PW.bg)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
    }
    .padding(12)
}
```

Expected: no remaining production call to `planCardMiniContent`.

- [ ] **Step 5: Confirm trial reminder left the hero card**

Run:

```bash
rg -n "Trial Reminder|Before billing|Reminder before trial ends|Memo reminds you before billing" MindRestore/Views/Paywall/PaywallView.swift
```

Expected: no `Trial Reminder` text appears in `mainPlanCard(compact:)`; reminder copy only appears in the trust area below the CTA or debug preview equivalent.

### Task 2: Update Production Trust Copy

**Files:**
- Modify: `MindRestore/Views/Paywall/PaywallView.swift`

- [ ] **Step 1: Update `trialPaymentNotice`**

Replace the production `trialPaymentNotice` text with:

```swift
Text(selectedPlan.hasTrial ? "No payment today. Memo reminds you before billing." : "Cancel anytime in the App Store.")
    .font(.system(size: 11, weight: .bold, design: .rounded))
    .foregroundStyle(PW.fgMuted)
    .lineLimit(1)
    .minimumScaleFactor(0.70)
```

Expected: annual mode shows the approved trial reassurance below the CTA.

- [ ] **Step 2: Keep footer unchanged**

Confirm `cuteFooter` still reads:

```swift
Text("No ads. No data sold.")
```

and:

```swift
Text("Restore")
```

Expected: footer remains `No ads. No data sold. · Restore`.

### Task 3: Keep Debug Preview Honest

**Files:**
- Modify: `MindRestore/Views/Paywall/PaywallView.swift`

- [ ] **Step 1: Update debug `planHero(compact:)` side cards**

Inside `MemoCutePaywallPreviewView`, replace `miniCardContent(...)` calls in `planHero(compact:)` with the same `coachNoteContent(...)` calls used in production, except the left note can use the preview value:

```swift
coachNoteContent(title: "Your pull", value: "4h 43m/day", icon: "chart.bar.fill", color: PW.coral, compact: compact)
```

and:

```swift
coachNoteContent(title: "Memo's move", value: "Guard + train", icon: "sparkles", color: PW.accent, compact: compact)
```

- [ ] **Step 2: Update debug `mainPlanCard(compact:)`**

Inside `MemoCutePaywallPreviewView`, make the debug main card match the production card with static preview copy:

```swift
Text("YOUR FIRST WEEK")
Text("Memo made your first-week plan")
planHeroRow(icon: "chart.bar.fill", title: "Start point", value: "4h 43m/day feed pull", color: PW.coral, compact: compact)
planHeroRow(icon: "lock.fill", title: "Day 1", value: "Guard your loudest app", color: PW.accent, compact: compact)
planHeroRow(icon: "brain.head.profile", title: "Day 2", value: "Train attention first", color: PW.mint, compact: compact)
planHeroRow(icon: "flame.fill", title: "This week", value: "Build your comeback streak", color: PW.amber, compact: compact)
```

Use the same frame, padding, shadow, and offset as production.

- [ ] **Step 3: Rename debug `miniCardContent`**

Rename the debug helper `miniCardContent(...)` to:

```swift
private func coachNoteContent(
    title: String,
    value: String,
    icon: String,
    color: Color,
    compact: Bool
) -> some View
```

Keep its body aligned with production. The parameter can stay `title` in the preview helper to avoid changing unrelated preview code.

- [ ] **Step 4: Update debug trial note**

Replace the debug `trialNote` annual text with:

```swift
"No payment today. Memo reminds you before billing."
```

Expected: Xcode preview shows the same trust copy as production.

### Task 4: Flow Trace

**Files:**
- Modify: none

- [ ] **Step 1: Trace annual path**

Mentally verify:

```text
Paywall appears -> annual is selected -> first-week plan card renders -> CTA says Start Free Trial -> tapping CTA calls purchaseSelectedPlan() -> selectedPlan.productID remains annual product ID.
```

- [ ] **Step 2: Trace weekly path**

Mentally verify:

```text
Tap Weekly card -> selectPlan(.weekly) fires analytics + haptic -> CTA says Start Weekly Access -> trust line says Cancel anytime in the App Store -> tapping CTA calls purchaseSelectedPlan() -> selectedPlan.productID remains weekly product ID.
```

- [ ] **Step 3: Trace restore path**

Mentally verify:

```text
Tap Restore -> Analytics.paywallRestoreTapped fires -> storeService.restorePurchases() runs -> Analytics.paywallRestoreCompleted fires -> dismisses only if restored is true.
```

- [ ] **Step 4: Trace hard-paywall close behavior**

Mentally verify:

```text
isHardPaywall true -> interactiveDismissDisabled(true) remains -> close button visibility still depends on shouldShowCloseButton -> exit offer behavior remains unchanged.
```

### Task 5: Verify Changes

**Files:**
- Build artifacts only

- [ ] **Step 1: Build for simulator**

Run:

```bash
COPYFILE_DISABLE=1 xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/mindrestore-build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2: Render the Xcode preview with Computer Use**

Open `MindRestore/Views/Paywall/PaywallView.swift` in Xcode, select the `MemoCutePaywallPreviewView` or `Paywall` preview, and capture a screenshot.

Expected:

```text
The center card says YOUR FIRST WEEK, has four readable rows, side cards read Your pull and Memo's move, CTA is not clipped, and footer remains readable.
```

- [ ] **Step 3: Build for physical device**

Run:

```bash
COPYFILE_DISABLE=1 xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath /tmp/mindrestore-build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Install on physical device**

Run:

```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C /tmp/mindrestore-build/Build/Products/Debug-iphoneos/MindRestore.app
```

Expected: install completes without a CodeSign metadata error.

### Task 6: Commit and Push

**Files:**
- Modify: `MindRestore/Views/Paywall/PaywallView.swift`
- Modify: `docs/superpowers/plans/2026-05-31-coach-plan-paywall-cards.md` if implementation notes changed during execution

- [ ] **Step 1: Review the focused diff**

Run:

```bash
git diff -- MindRestore/Views/Paywall/PaywallView.swift
```

Expected: only the coach-plan card, side notes, preview parity, and trial trust copy changed.

- [ ] **Step 2: Stage only the paywall implementation**

Run:

```bash
git add MindRestore/Views/Paywall/PaywallView.swift
```

Expected: unrelated dirty files remain unstaged.

- [ ] **Step 3: Commit**

Run:

```bash
git commit --only MindRestore/Views/Paywall/PaywallView.swift -m "feat: refine paywall coach plan cards"
```

Expected: commit includes only `MindRestore/Views/Paywall/PaywallView.swift`.

- [ ] **Step 4: Push**

Run:

```bash
git push origin v2.0-focus-mode
```

Expected: branch pushes successfully.
