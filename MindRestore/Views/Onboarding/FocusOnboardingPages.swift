import SwiftUI
import DeviceActivity
import FamilyControls
import UIKit

extension DeviceActivityReport.Context {
    /// Must match the context name declared in the `FocusUnlocksReport` extension target.
    static let unlocks = Self("Unlocks Count")
}

// Design tokens for Focus Mode onboarding pages (matches Claude Design spec)
private enum FO {
    static let bg = Color(red: 0.039, green: 0.039, blue: 0.059)         // #0A0A0F
    static let surface = Color(red: 0.078, green: 0.078, blue: 0.122)    // #14141F
    static let surface2 = Color(red: 0.110, green: 0.110, blue: 0.165)   // #1C1C2A
    static let border = Color.white.opacity(0.06)
    static let border2 = Color.white.opacity(0.10)
    static let fg = Color.white.opacity(0.92)
    static let fg2 = Color.white.opacity(0.55)
    static let fg3 = Color.white.opacity(0.35)
    static let accent = Color(red: 0.408, green: 0.565, blue: 0.996)     // #6890FE
    static let onAccent = Color(red: 0.039, green: 0.039, blue: 0.059)   // #0A0A0F
    static let memoPurple = Color(red: 0.722, green: 0.341, blue: 0.961) // #B857F5
    static let speed = Color(red: 0.980, green: 0.420, blue: 0.349)      // #FA6B59
    static let success = Color(red: 0.0, green: 0.820, blue: 0.620)      // #00D19E
    static let amber = Color(red: 1.0, green: 0.761, blue: 0.278)        // #FFC247
    static let memoIndigo = Color(red: 0.082, green: 0.047, blue: 0.180) // #150C2E
}

// MARK: - Shared atoms

private struct FOEyebrow: View {
    let text: String
    var color: Color = FO.accent
    var body: some View {
        Text(text)
            .font(.brand(size: 13, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(color)
    }
}

private struct FOContinueButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(FO.accent, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

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
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        (asset: "logo-tiktok", name: "TikTok", parent: "BYTEDANCE", role: "FYP"),
        (asset: "logo-instagram", name: "Instagram", parent: "META", role: "REELS"),
        (asset: "logo-youtube", name: "YouTube", parent: "GOOGLE", role: "SHORTS"),
        (asset: "logo-snapchat", name: "Snap", parent: "SNAP INC", role: "SPOTLIGHT")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Headline + detective Memo side by side — Memo is examining the case file.
            HStack(alignment: .top, spacing: 12) {
                Text("memo found\nthe suspects.")
                    .font(.brand(size: 24, weight: .heavy))
                    .kerning(-0.5)
                    .lineSpacing(2)
                    .foregroundStyle(OB.fg)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(headlineVisible ? 1 : 0)
                    .offset(y: headlineVisible ? 0 : 8)

                Spacer(minLength: 0)

                Image("mascot-detective")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .shadow(color: OB.accent.opacity(0.32), radius: 16, x: 0, y: 6)
                    .opacity(mascotVisible ? 1 : 0)
                    .scaleEffect(mascotVisible ? 1 : 0.88, anchor: .center)
                    .accessibilityHidden(true)
            }
            .padding(.top, 24)

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

                Text("$\(displayedNumber)B")
                    .font(.system(size: 56, weight: .black, design: .monospaced))
                    .kerning(-3)
                    .foregroundStyle(OB.fg)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(displayedNumber)))
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

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
        Canvas { ctx, size in
            let stripeWidth: CGFloat = 14
            let slant = size.height
            let count = Int(ceil((size.width + slant + stripeWidth) / stripeWidth)) + 1
            for i in 0..<count {
                let x = CGFloat(i) * stripeWidth - slant
                let isAmber = i % 2 == 0
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + stripeWidth, y: 0))
                path.addLine(to: CGPoint(x: x + stripeWidth - slant, y: size.height))
                path.addLine(to: CGPoint(x: x - slant, y: size.height))
                path.closeSubpath()
                ctx.fill(path, with: .color(isAmber ? OB.amber : FO.bg))
            }
        }
        .frame(height: 10)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, -24) // full-bleed past the page's 24pt margin
        .scaleEffect(x: tapeProgress, y: 1, anchor: .leading)
    }

    private func startSequence() {
        // Reset every appearance so re-entry replays the cinema.
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
                headlineVisible = true
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                mascotVisible = true
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

// MARK: - A) Stat Shock (144×) — DEPRECATED, kept for reference

struct FocusOnboardA: View {
    var onContinue: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FOEyebrow(text: "FOCUS MODE")
                .padding(.top, 24)
                .padding(.bottom, 16)

            // The number — Monkeytype-coded
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("144")
                    .font(.system(size: 132, weight: .bold, design: .monospaced))
                    .kerning(-7)
                    .foregroundStyle(FO.fg)
                Text("×")
                    .font(.system(size: 132, weight: .bold, design: .monospaced))
                    .kerning(-7)
                    .foregroundStyle(FO.accent)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text("avg phone unlocks / day")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(FO.fg3)
                .textCase(.uppercase)
                .padding(.top, 10)

            // Emotional hook — italic quote callout with accent left border
            HStack(spacing: 0) {
                Rectangle().fill(FO.accent).frame(width: 2)
                (Text("Most of those ")
                 + Text("weren't your idea").underline(color: FO.accent).fontWeight(.semibold)
                 + Text("."))
                    .font(.system(size: 19, weight: .medium).italic())
                    .kerning(-0.2)
                    .foregroundStyle(FO.fg)
                    .lineSpacing(4)
                    .padding(.leading, 14)
                    .padding(.vertical, 2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 320, alignment: .leading)
            .padding(.top, 22)

            Spacer()

            // Memo confident
            HStack {
                Image("mascot-goal")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .offset(x: -12, y: 12)
                Spacer()
            }

            // Big headline
            (Text("Take back\nyour ") + Text("attention").foregroundColor(FO.accent) + Text("."))
                .font(.system(size: 30, weight: .bold))
                .kerning(-0.9)
                .foregroundStyle(FO.fg)
                .lineSpacing(1)
                .padding(.bottom, 8)
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
    }
}

// MARK: - How It Works

struct FocusOnboardHowItWorks: View {
    var onContinue: () -> Void

    private struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let desc: String
        let tint: Color
    }

    private let steps: [Step] = [
        Step(icon: "shield.fill", label: "Pick your distractions", desc: "Choose which apps to block.", tint: FO.accent),
        Step(icon: "brain.head.profile", label: "Memo locks them", desc: "Tap a blocked app → Memo blocks you.", tint: FO.memoPurple),
        Step(icon: "gamecontroller.fill", label: "Play to unlock", desc: "Win a brain game → earn 15 min.", tint: FO.success)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                FOEyebrow(text: "HOW IT WORKS")
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                (Text("How Memo blocks\nyour ") + Text("brain rot").foregroundColor(FO.accent) + Text("."))
                    .font(.system(size: 30, weight: .bold))
                    .kerning(-0.9)
                    .foregroundStyle(FO.fg)
                    .lineSpacing(1)
                    .padding(.bottom, 28)

                // Steps with connecting dashed line
                ZStack(alignment: .topLeading) {
                    // connecting dashed line
                    Rectangle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                        .foregroundStyle(FO.accent.opacity(0.55))
                        .frame(width: 2)
                        .padding(.leading, 27)
                        .padding(.vertical, 54)

                    VStack(alignment: .leading, spacing: 26) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            stepRow(index: index, step: step)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 28)

            // Memo thinking in bottom-right
            Image("mascot-thinking")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(-8))
                .offset(x: 28, y: 20)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FO.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            FOContinueButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }

    private func stepRow(index: Int, step: Step) -> some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(FO.surface)
                    .frame(width: 56, height: 56)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(FO.border2, lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(FO.bg, lineWidth: 4).padding(-4))
                    .overlay(Image(systemName: step.icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(step.tint))

                // number badge
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(FO.onAccent)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(step.tint))
                    .overlay(Circle().strokeBorder(FO.bg, lineWidth: 2))
                    .offset(x: 6, y: -6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.label)
                    .font(.system(size: 17, weight: .bold))
                    .kerning(-0.2)
                    .foregroundStyle(FO.fg)
                Text(step.desc)
                    .font(.system(size: 14))
                    .foregroundStyle(FO.fg2)
                    .lineSpacing(2)
            }
            .padding(.top, 4)
            Spacer()
        }
    }
}

// MARK: - B) Bouncer

struct FocusOnboardB: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // aura behind memo
            RadialGradient(
                colors: [FO.accent.opacity(0.30), FO.memoPurple.opacity(0.12), .clear],
                center: .center, startRadius: 0, endRadius: 200
            )
            .frame(width: 360, height: 360)
            .blur(radius: 8)
            .offset(y: -80)

            // Apps queueing on the right
            VStack(spacing: 10) {
                ForEach(Array(apps.enumerated()), id: \.offset) { i, a in
                    appBadge(a, index: i)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)
            .padding(.top, 140)

            // Velvet rope
            HStack {
                Spacer()
                ZStack {
                    Capsule()
                        .fill(LinearGradient(colors: [FO.memoPurple, FO.accent], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3)
                        .shadow(color: FO.accent.opacity(0.5), radius: 4)
                    VStack {
                        Circle().fill(FO.amber).frame(width: 9, height: 9)
                            .shadow(color: FO.amber, radius: 3)
                        Spacer()
                        Circle().fill(FO.amber).frame(width: 9, height: 9)
                            .shadow(color: FO.amber, radius: 3)
                    }
                }
                .frame(height: 280)
                .padding(.trailing, 70)
                .padding(.top, 100)
            }

            // Memo the bouncer
            HStack {
                Spacer()
                Image("mascot-goal")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280, height: 280)
                    .shadow(color: FO.accent.opacity(0.45), radius: 30, y: 16)
                    .padding(.trailing, 60)
                    .padding(.top, 60)
                Spacer()
            }

            // Bottom text block
            VStack(alignment: .leading, spacing: 0) {
                FOEyebrow(text: "FOCUS MODE")
                    .padding(.bottom, 12)

                (Text("Your apps just\ngot a ")
                 + Text("bouncer").foregroundColor(FO.accent).underline(color: FO.accent)
                 + Text("."))
                    .font(.system(size: 36, weight: .bold))
                    .kerning(-1.3)
                    .foregroundStyle(FO.fg)
                    .lineSpacing(-4)
                    .padding(.bottom, 14)

                Text("Memo only lets apps through if you beat a brain game. Earn your scroll.")
                    .font(.system(size: 15))
                    .foregroundStyle(FO.fg2)
                    .lineSpacing(3)
                    .frame(maxWidth: 340, alignment: .leading)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FO.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            FOContinueButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }

    private struct BouncerApp {
        let glyph: String
        let bg: AnyShapeStyle
        let denied: Bool
    }

    private var apps: [BouncerApp] {
        [
            BouncerApp(glyph: "IG", bg: AnyShapeStyle(LinearGradient(colors: [FO.speed, FO.memoPurple], startPoint: .topLeading, endPoint: .bottomTrailing)), denied: true),
            BouncerApp(glyph: "TT", bg: AnyShapeStyle(Color.black), denied: true),
            BouncerApp(glyph: "YT", bg: AnyShapeStyle(Color(red: 1.0, green: 0.0, blue: 0.2)), denied: false),
            BouncerApp(glyph: "X",  bg: AnyShapeStyle(Color.black), denied: false)
        ]
    }

    @ViewBuilder
    private func appBadge(_ a: BouncerApp, index: Int) -> some View {
        let rotations: [Double] = [3, -2, 4, -1]
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 16)
                .fill(a.bg)
                .frame(width: 58, height: 58)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 6)
                .overlay(
                    Text(a.glyph)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                )
                .opacity(0.55)
                .saturation(0.7)
                .rotationEffect(.degrees(rotations[index % rotations.count]))

            if a.denied {
                Text("DENIED")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(FO.speed)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).strokeBorder(FO.speed, lineWidth: 2))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 16, y: -8)
            }
        }
    }
}

// MARK: - C) Demo (apps locking)

struct FocusOnboardC: View {
    var onContinue: () -> Void

    private struct DemoApp: Identifiable {
        let id = UUID()
        let name: String
        let glyph: String
        let bg: AnyShapeStyle
        let fg: Color
        let locked: Bool
    }

    private let apps: [DemoApp] = [
        DemoApp(name: "Insta",   glyph: "IG", bg: AnyShapeStyle(LinearGradient(colors: [FO.speed, FO.memoPurple], startPoint: .topLeading, endPoint: .bottomTrailing)), fg: .white, locked: true),
        DemoApp(name: "TikTok",  glyph: "TT", bg: AnyShapeStyle(Color.black), fg: .white, locked: true),
        DemoApp(name: "X",       glyph: "X",  bg: AnyShapeStyle(Color.black), fg: .white, locked: true),
        DemoApp(name: "YT",      glyph: "YT", bg: AnyShapeStyle(Color(red: 1.0, green: 0.0, blue: 0.2)), fg: .white, locked: true),
        DemoApp(name: "Reddit",  glyph: "RD", bg: AnyShapeStyle(Color(red: 1.0, green: 0.27, blue: 0.0)), fg: .white, locked: false),
        DemoApp(name: "Snap",    glyph: "SC", bg: AnyShapeStyle(Color(red: 1.0, green: 0.99, blue: 0.0)), fg: FO.onAccent, locked: true),
        DemoApp(name: "Spotify", glyph: "SP", bg: AnyShapeStyle(Color(red: 0.114, green: 0.725, blue: 0.329)), fg: .white, locked: false),
        DemoApp(name: "Maps",    glyph: "M",  bg: AnyShapeStyle(Color(red: 0.247, green: 0.612, blue: 0.980)), fg: .white, locked: false)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FOEyebrow(text: "FOCUS MODE")
                .padding(.top, 20)
                .padding(.bottom, 10)

            Text("Pick your\ndistraction list.")
                .font(.system(size: 32, weight: .bold))
                .kerning(-0.96)
                .foregroundStyle(FO.fg)
                .lineSpacing(-2)
                .padding(.bottom, 10)

            Text("These apps stay locked until you earn 5 minutes by winning a brain game.")
                .font(.system(size: 14))
                .foregroundStyle(FO.fg2)
                .lineSpacing(3)
                .padding(.bottom, 18)

            // Mock home-screen panel
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [FO.memoIndigo, FO.surface], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(FO.border2, lineWidth: 1))

                VStack(spacing: 0) {
                    // wallpaper time
                    VStack(spacing: 2) {
                        Text("WED · APR 24")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(Color.white.opacity(0.5))
                        Text("9:41")
                            .font(.system(size: 38, weight: .light))
                            .kerning(-0.76)
                            .foregroundStyle(Color.white.opacity(0.95))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 14)

                    // grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 12) {
                        ForEach(apps) { appTile($0) }
                    }
                    .padding(.horizontal, 18)
                    Spacer()
                }

                // Memo peeking
                Image("mascot-goal")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-8))
                    .offset(x: 32, y: 28)
                    .allowsHitTesting(false)

                // Counter chip
                HStack(spacing: 6) {
                    Circle().fill(FO.accent).frame(width: 6, height: 6).shadow(color: FO.accent, radius: 3)
                    Text("5 LOCKED")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(FO.fg)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(FO.bg.opacity(0.7))
                        .overlay(Capsule().stroke(FO.border2, lineWidth: 1))
                )
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))

            Spacer()
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
    }

    private func appTile(_ app: DemoApp) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(app.bg)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(app.glyph)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(app.fg)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 4)

                if app.locked {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(FO.bg.opacity(0.62))
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(FO.accent, lineWidth: 1.5)
                        )
                        .shadow(color: FO.accent.opacity(0.5), radius: 8)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(FO.accent)
                        )
                }
            }
            Text(app.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(app.locked ? Color.white.opacity(0.5) : Color.white.opacity(0.92))
        }
    }
}

// MARK: - D) Personal Unlocks reveal (287×)

struct FocusOnboardPersonalUnlocks: View {
    var onContinue: () -> Void
    var authorized: Bool = true
    var count: Int = 287  // fallback for preview / declined
    /// When the user previously denied auth, iOS won't re-prompt. We surface an
    /// "Open Settings" deep-link instead of the standard "Unlock" CTA.
    var previouslyDenied: Bool = false

    /// Filter to yesterday 00:00 → today 00:00 for pickup count.
    private var yesterdayFilter: DeviceActivityFilter {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: yesterdayStart, end: todayStart)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FOEyebrow(text: "PATTERN FOUND")
                .padding(.top, 24)
                .padding(.bottom, 14)

            Text("You unlocked your phone")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(FO.fg2)
                .lineSpacing(3)
                .padding(.bottom, 12)

            // THE NUMBER — real data from DeviceActivityReport extension when authorized
            Group {
                if authorized {
                    DeviceActivityReport(.unlocks, filter: yesterdayFilter)
                        .frame(height: 140)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("???")
                            .font(.system(size: 140, weight: .bold, design: .monospaced))
                            .kerning(-7)
                            .foregroundStyle(FO.fg3.opacity(0.6))
                        Text("×")
                            .font(.system(size: 140, weight: .bold, design: .monospaced))
                            .kerning(-7)
                            .foregroundStyle(FO.accent.opacity(0.3))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }
            }

            Text("yesterday.")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(FO.fg3)
                .textCase(.uppercase)
                .padding(.top, 12)

            // quote or auth prompt
            Group {
                if authorized {
                    HStack(spacing: 0) {
                        Rectangle().fill(FO.accent).frame(width: 2)
                        Text("Every unlock is another shot for the feed to pull you back.")
                            .font(.system(size: 18, weight: .semibold))
                            .kerning(-0.2)
                            .foregroundStyle(FO.fg)
                            .lineSpacing(4)
                            .padding(.leading, 14)
                            .padding(.vertical, 2)
                    }
                } else if previouslyDenied {
                    HStack(spacing: 0) {
                        Rectangle().fill(FO.speed).frame(width: 2)
                        (Text("Permission was denied earlier. ")
                         + Text("Open Settings").foregroundColor(FO.fg).fontWeight(.semibold)
                         + Text(" to enable Screen Time access."))
                            .font(.system(size: 15))
                            .foregroundStyle(FO.fg2)
                            .lineSpacing(3)
                            .padding(.leading, 14)
                            .padding(.vertical, 2)
                    }
                } else {
                    HStack(spacing: 0) {
                        Rectangle().fill(FO.border2).frame(width: 2)
                        (Text("We need ")
                         + Text("Screen Time access").foregroundColor(FO.fg).fontWeight(.semibold)
                         + Text(" to show your real number. Apple-private, never leaves your phone."))
                            .font(.system(size: 15))
                            .foregroundStyle(FO.fg2)
                            .lineSpacing(3)
                            .padding(.leading, 14)
                            .padding(.vertical, 2)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 320, alignment: .leading)
            .padding(.top, 24)

            Spacer()

            // Memo + bridge into the assessment.
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    (Text("Now let's check\nwhat it's doing\nto your brain."))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .kerning(-0.8)
                        .lineSpacing(2)
                        .foregroundStyle(FO.fg)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image("mascot-detective")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .shadow(color: FO.accent.opacity(0.28), radius: 18, y: 8)
                    .offset(x: 8, y: -14)
                    .accessibilityHidden(true)
            }
            .frame(height: 150)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FO.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            FOContinueButton(title: ctaTitle, action: ctaAction)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }

    private var ctaTitle: String {
        if authorized { return "Start Brain Age Test" }
        if previouslyDenied { return "Continue" }
        return "Unlock the Real Numbers"
    }

    private func ctaAction() {
        if !authorized && previouslyDenied {
            onContinue()
            return
        }
        onContinue()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Industry Scare · $57B") {
    FocusOnboardIndustryScare(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("A · 144×") {
    FocusOnboardA(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("A2 · How It Works") {
    FocusOnboardHowItWorks(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("B · Bouncer") {
    FocusOnboardB(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("C · Demo") {
    FocusOnboardC(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("D · Personal (287)") {
    FocusOnboardPersonalUnlocks(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("D2 · Personal (declined)") {
    FocusOnboardPersonalUnlocks(onContinue: {}, authorized: false)
        .preferredColorScheme(.dark)
}
#endif
