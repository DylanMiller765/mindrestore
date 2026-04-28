import SwiftUI
import SwiftData
import UIKit
import FamilyControls
import DeviceActivity

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusModeService.self) private var focusModeService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var users: [User]
    @State private var currentPage = 0
    @State private var selectedGoals: Set<UserFocusGoal> = []
    @State private var assessmentResult: BrainScoreResult?
    @State private var notificationsEnabled = false
    @State private var enteredName: String = ""
    @State private var selectedAge: Int = 25
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    @State private var commitmentCompleted = false
    @State private var welcomeHeadlineVisible = false
    @State private var welcomeAppsVisible: [Bool] = Array(repeating: false, count: 6)
    @State private var welcomeAppsLeaning = false
    @State private var welcomeAppsPushed: [Bool] = Array(repeating: false, count: 6)
    @State private var welcomeMemoVisible = false
    @State private var welcomeMemoLeaning = false
    @State private var welcomeMemoShoving = false
    @State private var welcomeMemoEnlarged = false
    @State private var welcomeSublineVisible = false
    @State private var welcomeCTAVisible = false
    @State private var commitmentBullet1Visible = false
    @State private var commitmentBullet2Visible = false
    @State private var commitmentBullet3Visible = false
    @State private var commitmentBullet4Visible = false
    @State private var nameMascotBob = false
    @State private var nameSubheadVisible = false
    @State private var nameInputVisible = false
    @FocusState private var nameFieldFocused: Bool
    @State private var empathySceneVisible = false
    @State private var empathySignalBroken = false
    @State private var empathyCopyVisible = false
    @State private var empathyCTAVisible = false
    @State private var focusModeWasSetUp = false
    @State private var quickAssessmentBgColor: Color = AppColors.pageBg
    @State private var screenTimeAuthorized = false
    @State private var isRequestingScreenTimeAccess = false
    @State private var screenTimeEstimateHours: Double = 4
    @State private var measuredScreenTimeHours: Double?
    @State private var useScreenTimeEstimate = false
    @State private var showingScreenTimeEstimateSheet = false
    @State private var agePageAppeared = false
    @State private var receiptCount: Int = 0
    /// Single-slot cover state. iOS 17 SwiftUI silently no-ops the second of two
    /// stacked .fullScreenCover(isPresented:) modifiers — using item-based with
    /// an enum forces a clean swap and fixes the "paywall doesn't present" bug.
    @State private var presentedCover: OnboardingCover?

    enum OnboardingCover: Identifiable {
        case brainAgeReveal
        case paywall
        var id: Self { self }
    }

    var onComplete: () -> Void

    private let totalPages = 16

    var body: some View {
        ZStack {
            // Onboarding is dark-pinned regardless of system theme — use OB.bg
            // directly so light-mode iPhones don't bleed cream pageBg through
            // the chrome around the TabView. Quick Assessment keeps its
            // dynamic bg color (the assessment animates color shifts).
            (currentPage == 9 ? quickAssessmentBgColor : OB.bg).ignoresSafeArea()

            // Page-specific atmosphere lifted out of individual pages so
            // blurs/glows extend behind the progress bar instead of clipping
            // at the page's top edge. Pages should leave their atmosphere
            // empty and declare effects here keyed off `currentPage`.
            pageAtmosphere
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

            VStack(spacing: 0) {
                if currentPage != 9 {
                    onboardingProgressHeader
                }

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
                .onChange(of: currentPage) { _, newPage in
                    // Animate keyboard dismiss smoothly
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    nameFieldFocused = false
                    if newPage == 1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            nameFieldFocused = true
                        }
                    }
                    // Reset commitment typewriter bullets when navigating away
                    if newPage != 15 {
                        commitmentBullet1Visible = false
                        commitmentBullet2Visible = false
                        commitmentBullet3Visible = false
                        commitmentBullet4Visible = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .onDisappear {
            if users.first?.hasCompletedOnboarding != true {
                let stepNames = ["welcome", "name", "painCards", "industryScare", "empathy", "goals", "age", "screenTimeAccess", "personalScare", "quickAssessment", "planReveal", "comparison", "differentiation", "focusMode", "notificationPriming", "commitment"]
                let lastStep = currentPage < stepNames.count ? stepNames[currentPage] : "unknown"
                Analytics.onboardingDroppedOff(lastStep: lastStep, totalSteps: currentPage)
            }
        }
        // Single-cover slot: brain age reveal first, then paywall after differentiation.
        // Tracked-last-value handles per-cover dismissal routing.
        .fullScreenCover(item: $presentedCover, onDismiss: handleCoverDismiss) { cover in
            switch cover {
            case .brainAgeReveal:
                OnboardingBrainAgeReveal(
                    brainAge: assessmentResult?.brainAge ?? 25,
                    userAge: selectedAge > 0 ? selectedAge : 25,
                    onContinue: { presentedCover = nil }
                )
            case .paywall:
                PaywallView(isHighIntent: true, triggerSource: "onboarding")
            }
        }
        .onChange(of: presentedCover) { oldValue, newValue in
            // onDismiss fires after the binding is already nil, so capture the
            // outgoing identity here for routing.
            if newValue == nil, oldValue != nil {
                lastDismissedCover = oldValue
            }
        }
    }

    @State private var lastDismissedCover: OnboardingCover?

    private func handleCoverDismiss() {
        // Route based on which cover just closed.
        switch lastDismissedCover {
        case .brainAgeReveal:
            Analytics.onboardingStep(step: "revealDismissed")
            withAnimation { currentPage = 10 } // → planReveal
        case .paywall:
            Analytics.onboardingStep(step: "paywallDismissed")
            withAnimation { currentPage = 13 } // → focusMode
        case nil:
            break
        }
        lastDismissedCover = nil
    }

    // MARK: - Page Atmosphere
    //
    // Lives at the outer ZStack level so blur effects extend full-screen
    // (including behind the progress bar). Add new cases as pages adopt
    // atmosphere effects.

    @ViewBuilder
    private var pageAtmosphere: some View {
        switch currentPage {
        case 0:
            welcomeAtmosphere
        default:
            EmptyView()
        }
    }

    // MARK: - Progress Header

    /// Pages where the top progress bar is hidden (full-bleed editorial moments):
    /// 4 Empathy, 9 Quick Assessment, 10 Plan Reveal.
    private var progressHeaderOpacity: Double {
        let hiddenPages: Set<Int> = [4, 9, 10]
        return hiddenPages.contains(currentPage) ? 0 : 1
    }

    /// Single funnel for every page advance / back-step. The animation
    /// context for `currentPage` state changes is tunable here in one place.
    /// The visual transition CURVE itself is defined by `.transition(...)` on
    /// the page container — this `withAnimation` only schedules SwiftUI's
    /// re-render block.
    private func goToPage(_ page: Int) {
        guard (0..<totalPages).contains(page) else { return }
        withAnimation(.easeInOut(duration: 0.40)) {
            currentPage = page
        }
    }

    private var onboardingProgressHeader: some View {
        ZStack {
            GeometryReader { proxy in
                let barWidth = min(proxy.size.width * 0.76, 320)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.cardBorder)

                    Capsule()
                        .fill(AppColors.accent)
                        .frame(width: barWidth * onboardingProgress)
                }
                .frame(width: barWidth, height: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 34)

            Button {
                guard currentPage > 0 else { return }
                withAnimation { currentPage -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(currentPage > 0 ? AppColors.textSecondary : .clear)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .disabled(currentPage == 0)
            .accessibilityLabel("Back")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
    }

    private var onboardingProgress: CGFloat {
        guard totalPages > 1 else { return 1 }
        return CGFloat(currentPage + 1) / CGFloat(totalPages)
    }

    private var onboardingGoalOrder: [UserFocusGoal] {
        [.attentionShot, .screenTimeFrying, .doomscrolling, .loseFocus, .forgetInstantly, .getSharper]
    }

    private var effectiveDailyScreenTimeHours: Double {
        if useScreenTimeEstimate { return screenTimeEstimateHours }
        let measured = measuredScreenTimeHours ?? readCachedScreenTimeHours()
        return measured ?? screenTimeEstimateHours
    }

    private var projectionIsEstimate: Bool {
        if useScreenTimeEstimate { return true }
        return measuredScreenTimeHours == nil && readCachedScreenTimeHours() == nil
    }

    private var yearsUntilSixty: Int {
        max(1, 60 - (selectedAge > 0 ? selectedAge : 25))
    }

    private var projectedScreenTimeHours: Int {
        Int((effectiveDailyScreenTimeHours * 365 * Double(yearsUntilSixty)).rounded())
    }

    private var yesterdayScreenTimeFilter: DeviceActivityFilter {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: yesterdayStart, end: todayStart)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    private func readCachedScreenTimeHours() -> Double? {
        let value = UserDefaults(suiteName: "group.com.memori.shared")?
            .double(forKey: "onboarding_daily_screen_time_hours") ?? 0
        return value > 0 ? value : nil
    }

    private func refreshCachedScreenTimeHours() {
        measuredScreenTimeHours = readCachedScreenTimeHours()
    }

    private func formatProjectedHours(_ value: Int) -> String {
        if value >= 1000 {
            let rounded = Int((Double(value) / 1000.0).rounded()) * 1000
            return rounded.formatted()
        }
        return value.formatted()
    }

    private var projectedYearsText: String {
        String(format: "%.1f", Double(projectedScreenTimeHours) / 8760.0)
    }

    // MARK: - Personal Scare (287×) Page
    //
    // Sits AFTER ScreenTime auth, BEFORE assessment. Shows the user's real pickup
    // count from yesterday — concrete personal stat that lands harder than any
    // industry average. Auth was already negotiated on screenTimeAccessPage so
    // we don't re-prompt here.

    private var personalScarePage: some View {
        FocusOnboardPersonalUnlocks(
            onContinue: {
                Analytics.onboardingStep(step: "personalScare")
                withAnimation { currentPage = 9 } // → quickAssessment
            },
            authorized: screenTimeAuthorized,
            count: 287,
            previouslyDenied: (focusModeService.authorizationStatus == .denied)
        )
        .onAppear {
            screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
        }
    }

    private var welcomePage: some View {
        ZStack {
            // Atmosphere is rendered at the outer body so it can extend behind
            // the progress bar. The page body itself sits on the global pageBg.
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    OBEyebrow(text: "MEMO · DOOMSCROLL BLOCKER")
                    (Text("Apps want you.\n") + Text("Memo wants you back.").foregroundColor(OB.accent))
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(OB.fg)
                        .lineSpacing(1)
                        .kerning(-0.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .opacity(welcomeHeadlineVisible ? 1 : 0)
                .offset(y: welcomeHeadlineVisible ? 0 : 8)

                Spacer(minLength: 28)

                WelcomeBouncerHero(
                    appsVisible: welcomeAppsVisible,
                    appsLeaning: welcomeAppsLeaning,
                    appsPushed: welcomeAppsPushed,
                    memoVisible: welcomeMemoVisible,
                    memoLeaning: welcomeMemoLeaning,
                    memoShoving: welcomeMemoShoving,
                    memoEnlarged: welcomeMemoEnlarged
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)

                Spacer(minLength: 28)

                Text("Block Apps. Train Your Brain.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(OB.fg2)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)
                    .opacity(welcomeSublineVisible ? 1 : 0)
                    .offset(y: welcomeSublineVisible ? 0 : 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 14) {
                OBContinueButton(title: "Let's go") {
                    Analytics.onboardingStep(step: "welcome")
                    currentPage = 1
                }

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .heavy))
                    Text("No ads. No data sold. Just your brain fighting back.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(OB.fg3)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
            .opacity(welcomeCTAVisible ? 1 : 0)
            .offset(y: welcomeCTAVisible ? 0 : 8)
        }
        .preferredColorScheme(.dark)
        .onAppear { startWelcomeEntrance() }
    }

    private var welcomeAtmosphere: some View {
        // Two blurs that extend behind the progress bar (rendered at the
        // outer ZStack level, ignoring safe area). Top-left accent blur
        // bleeds through the bar area, creating a continuous "you vs them"
        // color tension; bottom-right coral anchors the app pile side.
        ZStack {
            Circle()
                .fill(OB.accent.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 76)
                .offset(x: -130, y: -180)

            Circle()
                .fill(OB.coral.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 68)
                .offset(x: 140, y: 200)
        }
    }

    private func startWelcomeEntrance() {
        // Reset state so re-entering the welcome (e.g., from a back swipe) replays.
        welcomeHeadlineVisible = false
        welcomeAppsVisible = Array(repeating: false, count: 6)
        welcomeAppsLeaning = false
        welcomeAppsPushed = Array(repeating: false, count: 6)
        welcomeMemoVisible = false
        welcomeMemoLeaning = false
        welcomeMemoShoving = false
        welcomeMemoEnlarged = false
        welcomeSublineVisible = false
        welcomeCTAVisible = false

        // Beat 1 — Headline (threat is being framed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeOut(duration: 0.4)) { welcomeHeadlineVisible = true }
        }

        // Beat 2 — Apps press in (cascade from right, 0.40s start, 0.08s stagger)
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40 + Double(i) * 0.08) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    if i < welcomeAppsVisible.count {
                        welcomeAppsVisible[i] = true
                    }
                }
            }
        }

        // Beat 3 — Memo arrives, holds the line
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.78)) {
                welcomeMemoVisible = true
            }
        }

        // Beat 4 — TENSION: apps lean toward Memo, Memo leans into them
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.40) {
            withAnimation(.easeOut(duration: 0.30)) {
                welcomeAppsLeaning = true
                welcomeMemoLeaning = true
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        // Beat 5 — THE SHOVE: Memo bursts forward, apps fly off-screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.80) {
            withAnimation(.easeOut(duration: 0.20)) {
                welcomeAppsLeaning = false
                welcomeMemoLeaning = false
            }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.70)) {
                welcomeMemoShoving = true
            }
        }
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.80 + Double(i) * 0.04) {
                withAnimation(.easeIn(duration: 0.5)) {
                    if i < welcomeAppsPushed.count {
                        welcomeAppsPushed[i] = true
                    }
                }
            }
        }

        // Beat 6 — Snapback: Memo recovers from the shove with overshoot
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.10) {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.55)) {
                welcomeMemoShoving = false
            }
        }

        // Beat 7 — VICTORY: Memo enlarges
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.35) {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.62)) {
                welcomeMemoEnlarged = true
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        // Beat 8 — Copy + CTA settle in
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.55) {
            withAnimation(.easeOut(duration: 0.35)) { welcomeSublineVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.80) {
            withAnimation(.easeOut(duration: 0.4)) { welcomeCTAVisible = true }
        }
    }

    // MARK: - Name Entry Page

    // MARK: - Name Entry Page (redesigned)
    //
    // Memo introduces himself in first person; the user types their name on a
    // borderless underlined input field. No big Continue button — return submits.
    // Skip is a tiny tertiary link. Page is the user's first interactive moment,
    // designed to feel personal, not like a form. Pinned to dark mode + FO
    // design tokens for visual continuity with Industry Scare.
    private var namePage: some View {
        // Local color tokens — match FO.bg / FO.accent from FocusOnboardingPages.swift
        let pageBg = Color(red: 0.039, green: 0.039, blue: 0.059)
        let accent = Color(red: 0.408, green: 0.565, blue: 0.996)
        let textPrimary = Color.white.opacity(0.94)
        let textSecondary = Color.white.opacity(0.62)
        let textTertiary = Color.white.opacity(0.40)

        return ZStack {
            pageBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 18)

                // Memo waving in top-left, gentle bob
                Image("mascot-welcome")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .offset(y: nameMascotBob ? -4 : 4)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: nameMascotBob)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)

                // Memo's intro — typewriter on the headline, fade-up on the question
                VStack(alignment: .leading, spacing: 6) {
                    TypewriterText(fullText: "Hi, I'm Memo.")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(textPrimary)

                    Text("What should I call you?")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(textSecondary)
                        .opacity(nameSubheadVisible ? 1 : 0)
                        .offset(y: nameSubheadVisible ? 0 : 6)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 48)

                // Subtle label, no military cosplay
                Text("YOUR NAME")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .opacity(nameInputVisible ? 1 : 0)

                // Borderless underlined input — feels like signing on a line
                VStack(alignment: .leading, spacing: 8) {
                    TextField("", text: $enteredName)
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundStyle(textPrimary)
                    .tint(accent)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .onSubmit { dismissAndAdvance() }

                    // Underline shifts color on focus
                    Rectangle()
                        .fill(nameFieldFocused ? accent : Color.white.opacity(0.35))
                        .frame(height: 1.5)
                        .animation(.easeInOut(duration: 0.25), value: nameFieldFocused)
                }
                .padding(.horizontal, 24)
                .opacity(nameInputVisible ? 1 : 0)

                Spacer()

                // Subtle skip link, not a button
                HStack {
                    Spacer()
                    Button {
                        enteredName = ""
                        dismissAndAdvance()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(textTertiary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .toolbar {
            // Keyboard accessory — quiet "Done" path for users who don't tap return
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    dismissAndAdvance()
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(accent)
                }
            }
        }
        .onAppear {
            nameMascotBob = true
            nameSubheadVisible = false
            nameInputVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.4)) { nameSubheadVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.5)) { nameInputVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if currentPage == 1 { nameFieldFocused = true }
            }
        }
        .onDisappear {
            nameFieldFocused = false
        }
    }

    private func dismissAndAdvance() {
        nameFieldFocused = false
        Analytics.onboardingStep(step: "name")
        withAnimation { currentPage = 2 }
    }

    private var goalsPage: some View {
        ZStack(alignment: .topTrailing) {
            FeedHeistBackdrop()
                .padding(.top, 18)
                .padding(.trailing, 0)

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 2)

                MemoLookoutHeader()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("What do you\nwant back?")
                        .font(.system(size: 37, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(1)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Pick up to 3. Memo's plan goes after these first.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                VStack(spacing: 0) {
                    Divider()
                        .overlay(AppColors.cardBorder)

                    ForEach(Array(onboardingGoalOrder.enumerated()), id: \.element.id) { index, goal in
                        GoalCard(goal: goal, index: index, isSelected: selectedGoals.contains(goal)) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                                if selectedGoals.contains(goal) {
                                    selectedGoals.remove(goal)
                                } else if selectedGoals.count < 3 {
                                    selectedGoals.insert(goal)
                                }
                            }
                        }

                        Divider()
                            .overlay(AppColors.cardBorder.opacity(selectedGoals.contains(goal) ? 0.9 : 0.7))
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 10)

                continueButton("Continue") {
                    Analytics.onboardingStep(step: "goals")
                    withAnimation { currentPage = 6 } // → age
                }
                    .disabled(selectedGoals.isEmpty)
                    .opacity(selectedGoals.isEmpty ? 0.4 : 1)
            }
            .padding(.bottom, 12)
            .responsiveContent(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .clipped()
        .onAppear { nameFieldFocused = false }
    }

    // MARK: - Screen Time Access Page

    private var screenTimeAccessPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 28)

            VStack(alignment: .leading, spacing: 12) {
                Text("Let Memo see\nwhat's been\ntaken from you.")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Screen Time powers your plan and lets Memo block the apps you pick. No ads. No data sold. We never see it.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Image("mascot-thinking")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 98, height: 98)
                .shadow(color: AppColors.accent.opacity(0.22), radius: 16, y: 8)
                .accessibilityHidden(true)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 34)
                .padding(.top, 14)
                .padding(.bottom, 18)

            VStack(spacing: 0) {
                Divider().overlay(AppColors.cardBorder)
                screenTimeReasonRow(title: "Make the math personal", detail: "Plan calibrated to your real pace, not an industry average.")
                Divider().overlay(AppColors.cardBorder)
                screenTimeReasonRow(title: "Bounce the worst offenders", detail: "Memo locks the apps you pick. You earn them back.")
                Divider().overlay(AppColors.cardBorder)
                screenTimeReasonRow(title: "Stays on your phone", detail: "Apple-private. We never see it. We don't want to.")
                Divider().overlay(AppColors.cardBorder)
            }
            .padding(.horizontal, 28)

            if screenTimeAuthorized {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yesterday's Screen Time")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.0)
                        .foregroundStyle(AppColors.textTertiary)
                        .textCase(.uppercase)

                    DeviceActivityReport(.screenTime, filter: yesterdayScreenTimeFilter)
                        .frame(height: 58)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                refreshCachedScreenTimeHours()
                            }
                        }
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer(minLength: 18)

            VStack(spacing: 12) {
                continueButton(screenTimeAuthorized ? "Continue" : "Allow Screen Time") {
                    if screenTimeAuthorized {
                        Analytics.onboardingStep(step: "screenTimeAccessApproved")
                        useScreenTimeEstimate = false
                        refreshCachedScreenTimeHours()
                        withAnimation { currentPage = 8 } // → personalScare
                    } else {
                        requestScreenTimeForOnboarding()
                    }
                }
                .disabled(isRequestingScreenTimeAccess)
                .opacity(isRequestingScreenTimeAccess ? 0.6 : 1)

                Button {
                    Analytics.onboardingStep(step: "screenTimeAccessEstimate")
                    showingScreenTimeEstimateSheet = true
                } label: {
                    Text("Use a rough estimate")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.bottom, 18)
        }
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .onAppear {
            screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
            refreshCachedScreenTimeHours()
        }
        .sheet(isPresented: $showingScreenTimeEstimateSheet) {
            ScreenTimeEstimateSheet(
                selection: $screenTimeEstimateHours,
                onConfirm: {
                    useScreenTimeEstimate = true
                    measuredScreenTimeHours = nil
                    showingScreenTimeEstimateSheet = false
                    Analytics.onboardingStep(step: "screenTimeEstimate")
                    withAnimation { currentPage = 8 } // → personalScare
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var dailyScreenTimeLabel: String {
        if effectiveDailyScreenTimeHours >= 8 && projectionIsEstimate {
            return "8h+"
        }
        return String(format: "%.1fh", effectiveDailyScreenTimeHours)
    }

    private func requestScreenTimeForOnboarding() {
        isRequestingScreenTimeAccess = true
        Task {
            await focusModeService.requestAuthorization()
            screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
            refreshCachedScreenTimeHours()
            isRequestingScreenTimeAccess = false
            if screenTimeAuthorized {
                useScreenTimeEstimate = false
                Analytics.onboardingStep(step: "screenTimeAccessApproved")
                withAnimation { currentPage = 8 } // → personalScare
            } else {
                useScreenTimeEstimate = true
                Analytics.onboardingStep(step: "screenTimeAccessDenied")
                showingScreenTimeEstimateSheet = true
            }
        }
    }

    private func screenTimeReasonRow(title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(AppColors.accent)
                .frame(width: 8, height: 8)
                .shadow(color: AppColors.accent.opacity(0.55), radius: 8)
                .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text(detail)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 16)
    }

    // MARK: - Empathy Page

    private var empathyPage: some View {
        ZStack {
            EmpathySignalBackdrop(signalBroken: empathySignalBroken)
                .opacity(empathySceneVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.55), value: empathySceneVisible)

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 28)

                EmpathyFeedWallScene(sceneVisible: empathySceneVisible, feedMuted: empathySignalBroken)
                    .frame(height: 330)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: -2) {
                        Text("Your brain")
                        Text("isn't broken.")
                    }
                    .font(.brand(size: 38, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(empathyCopyVisible ? 1 : 0)
                    .offset(y: empathyCopyVisible ? 0 : 10)

                    Text("It's been hijacked.")
                        .font(.brand(size: 38, weight: .heavy))
                        .foregroundStyle(AppColors.accent)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(empathySignalBroken ? 1 : 0.97, anchor: .leading)
                        .opacity(empathySignalBroken ? 1 : 0)

                    Text("You're not weak. You're outgunned. Memo helps you take the controls back.")
                        .font(.brand(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .frame(maxWidth: 320, alignment: .leading)
                        .opacity(empathyCopyVisible ? 1 : 0)
                        .offset(y: empathyCopyVisible ? 0 : 8)
                }
                .padding(.horizontal, 28)

                Spacer()

                Button {
                    Analytics.onboardingStep(step: "empathy")
                    withAnimation { currentPage = 5 } // → goals
                } label: {
                    Text("Pick what I take back")
                        .gradientButton()
                }
                .accessibilityHint("Continues to the goals selection step")
                .padding(.horizontal, 32)
                .padding(.bottom, 18)
                .opacity(empathyCTAVisible ? 1 : 0)
                .offset(y: empathyCTAVisible ? 0 : 8)
            }
            .responsiveContent(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            resetEmpathyAnimation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeOut(duration: 0.45)) { empathySceneVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                withAnimation(.easeOut(duration: 0.38)) { empathyCopyVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) { empathySignalBroken = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.92) {
                withAnimation(.easeOut(duration: 0.32)) { empathyCTAVisible = true }
            }
        }
        .onDisappear(perform: resetEmpathyAnimation)
    }

    private func resetEmpathyAnimation() {
        empathySceneVisible = false
        empathySignalBroken = false
        empathyCopyVisible = false
        empathyCTAVisible = false
    }

    // MARK: - Age Page

    private var agePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 22)

            VStack(alignment: .leading, spacing: 10) {
                Text("How old is the brain\nwe're defending?")
                    .font(.brand(size: 32, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Memo uses this to calculate what the feed costs you over time.")
                    .font(.brand(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(agePageAppeared ? 1 : 0)
            .offset(y: agePageAppeared ? 0 : 10)

            Spacer().frame(height: 82)

            VStack(alignment: .leading, spacing: 18) {
                AgeNumberRail(selectedAge: $selectedAge)
                    .opacity(agePageAppeared ? 1 : 0)
                    .scaleEffect(agePageAppeared ? 1 : 0.96)

                // Quiet inline privacy line — no border, no box, no coral. Trust whispers.
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Stays on your phone · Never sold")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(0.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(AppColors.textTertiary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(agePageAppeared ? 1 : 0)
                .offset(y: agePageAppeared ? 0 : 6)
            }

            Spacer(minLength: 18)

            VStack(spacing: 12) {
                Button {
                    Analytics.onboardingStep(step: "age")
                    withAnimation { currentPage = 7 } // → screenTimeAccess
                } label: {
                    Text("Run my numbers")
                        .gradientButton()
                }
                .accessibilityHint("Uses your age to personalize the next onboarding step")

                Button {
                    selectedAge = 0
                    Analytics.onboardingStep(step: "age")
                    withAnimation { currentPage = 7 } // → screenTimeAccess
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .preferredColorScheme(.dark)
        .onAppear {
            selectedAge = selectedAge == 0 ? 25 : selectedAge
            withAnimation(.easeOut(duration: 0.38)) {
                agePageAppeared = true
            }
        }
        .onDisappear {
            agePageAppeared = false
        }
    }

    // MARK: - Quick Assessment Page

    private var quickAssessmentPage: some View {
        QuickAssessmentView(backgroundColor: $quickAssessmentBgColor) { result in
            assessmentResult = result
            Analytics.onboardingStep(step: "quickAssessment")
            // Present dramatic reveal as a full-screen cover so it escapes the TabView.
            // Cover only fires from a legitimate onComplete — swiping the TabView won't trigger it.
            presentedCover = .brainAgeReveal
        }
    }

    // MARK: - Plan Reveal Page (was Personal Solution)
    //
    // Critical: this page presents the paywall on CTA. The user has now seen the
    // plan they're paying for. Paywall dismiss → focusMode setup.

    private var planRevealPage: some View {
        OnboardingPersonalSolutionView(
            userGoals: selectedGoals,
            brainAge: assessmentResult?.brainAge,
            userAge: selectedAge,
            dailyScreenTimeHours: effectiveDailyScreenTimeHours,
            projectedScreenTimeHours: projectedScreenTimeHours,
            projectionIsEstimate: projectionIsEstimate,
            receiptCount: receiptCount,
            onContinue: {
                Analytics.onboardingStep(step: "planReveal")
                withAnimation { currentPage = 11 } // → comparison
            }
        )
    }

    // MARK: - Notification Priming Page

    private var notificationPrimingPage: some View {
        OnboardingNotificationPrimingView { granted in
            notificationsEnabled = granted
            withAnimation { currentPage = 15 } // → commitment
        }
    }

    // MARK: - Industry Scare Page (NEW — $57B engineering spend)

    private var industryScarePage: some View {
        FocusOnboardIndustryScare {
            Analytics.onboardingStep(step: "industryScare")
            withAnimation { currentPage = 4 } // → empathy
        }
    }

    // MARK: - Pain Cards Page (NEW)

    private var painCardsPage: some View {
        OnboardingPainCardsView { count in
            receiptCount = count
            withAnimation { currentPage = 3 } // → industryScare
        }
    }

    // MARK: - Comparison Page (NEW)

    private var comparisonPage: some View {
        OnboardingComparisonView(
            pickupCount: 287,
            dailyHours: effectiveDailyScreenTimeHours,
            brainAge: assessmentResult?.brainAge,
            onContinue: {
                withAnimation { currentPage = 12 } // → differentiation
            }
        )
    }

    // MARK: - Differentiation Page (NEW)

    private var differentiationPage: some View {
        OnboardingDifferentiationView {
            Analytics.onboardingStep(step: "differentiation")
            presentedCover = .paywall
        }
    }

    // MARK: - Commitment Page

    private var commitmentPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            // Title with user's name
            Group {
                if enteredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Your plan")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                } else {
                    (Text(enteredName.trimmingCharacters(in: .whitespacesAndNewlines))
                        .foregroundColor(AppColors.accent)
                    + Text("'s plan"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
            }
            .padding(.bottom, 28)

            // Commitment bullets
            VStack(alignment: .leading, spacing: 16) {
                if commitmentBullet1Visible {
                    TypewriterText(fullText: "• I'll train before the feed gets me", speed: 0.025)
                        .font(.subheadline)
                        .transition(.opacity)
                }
                if commitmentBullet2Visible {
                    TypewriterText(fullText: "• I'll make scrolling cost reps", speed: 0.025)
                        .font(.subheadline)
                        .transition(.opacity)
                }
                if commitmentBullet3Visible {
                    TypewriterText(fullText: "• I'll let Memo block the apps draining me", speed: 0.025)
                        .font(.subheadline)
                        .transition(.opacity)
                }
                if commitmentBullet4Visible {
                    TypewriterText(fullText: "• I'll stop being free real estate", speed: 0.025)
                        .font(.subheadline)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 32)
            .onAppear {
                let delays = [0.15, 0.85, 1.55, 2.25]
                DispatchQueue.main.asyncAfter(deadline: .now() + delays[0]) {
                    withAnimation { commitmentBullet1Visible = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delays[1]) {
                    withAnimation { commitmentBullet2Visible = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delays[2]) {
                    withAnimation { commitmentBullet3Visible = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delays[3]) {
                    withAnimation { commitmentBullet4Visible = true }
                }
            }

            Spacer()

            // Hold to agree — organic shape
            VStack(spacing: 12) {
                ZStack {
                    // Invisible hit target
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 100, height: 100)
                        .contentShape(Circle())

                    // Base grey ring (always visible)
                    OrganicCircle()
                        .stroke(AppColors.cardBorder, lineWidth: 2.5)
                        .frame(width: 80, height: 80)

                    // Bright accent ring fades in as you hold
                    OrganicCircle()
                        .stroke(AppColors.accent, lineWidth: 3.5)
                        .frame(width: 80, height: 80)
                        .opacity(holdProgress)
                        .shadow(color: AppColors.accent.opacity(0.7 * holdProgress), radius: 14 * holdProgress)
                        .animation(.easeOut(duration: 0.08), value: holdProgress)

                    // Progress fill — strong at full hold
                    OrganicCircle()
                        .fill(AppColors.accent.opacity(0.85 * holdProgress))
                        .frame(width: 74, height: 74)
                        .scaleEffect(0.5 + 0.5 * holdProgress)
                        .shadow(color: AppColors.accent.opacity(0.5 * holdProgress), radius: 16 * holdProgress)
                        .animation(.easeOut(duration: 0.08), value: holdProgress)

                    // Completed state
                    if commitmentCompleted {
                        OrganicCircle()
                            .fill(AppColors.accent)
                            .frame(width: 74, height: 74)
                            .shadow(color: AppColors.accent.opacity(0.6), radius: 18)

                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !commitmentCompleted else { return }
                            if holdTimer == nil {
                                startHoldTimer()
                            }
                        }
                        .onEnded { _ in
                            if !commitmentCompleted {
                                cancelHoldTimer()
                            }
                        }
                )

                if !commitmentCompleted {
                    Text("Hold to agree")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(holdProgress > 0.05 ? AppColors.accent : Color.primary)
                        .animation(.easeOut(duration: 0.15), value: holdProgress > 0.05)

                    Text("Hold to commit. The feed doesn't get a vote.")
                        .font(.brand(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.bottom, 32)

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("No ads. No data sold. Memo stays on your side.")
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)
            .padding(.top, 8)
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private func commitmentBullet(_ prefix: String, bold: String, suffix: String = "") -> some View {
        (Text("• " + prefix)
            .font(.subheadline)
        + Text(bold)
            .font(.subheadline.weight(.bold))
        + Text(suffix)
            .font(.subheadline))
            .foregroundStyle(.primary)
    }

    private func startHoldTimer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                holdProgress += 0.05 / 3.0 // 3 seconds total
                if holdProgress.truncatingRemainder(dividingBy: 0.1) < 0.02 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                if holdProgress >= 1.0 {
                    holdProgress = 1.0
                    cancelHoldTimer()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        commitmentCompleted = true
                    }
                    Analytics.onboardingStep(step: "commitment")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        completeOnboarding()
                    }
                }
            }
        }
    }

    private func cancelHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        // Don't reset progress — let users resume from where they stopped
    }

    // MARK: - Focus Mode Page

    private var focusModePage: some View {
        ZStack(alignment: .bottom) {
            FocusModeSetupView(onComplete: {
                focusModeWasSetUp = true
                Analytics.onboardingStep(step: "focusModeCompleted")
                withAnimation { currentPage = 14 } // → notificationPriming
            })

            // "Not now" skip button
            Button {
                Analytics.onboardingStep(step: "focusModeSkipped")
                Analytics.focusSetupSkipped()
                withAnimation { currentPage = 14 } // → notificationPriming
            } label: {
                Text("Not now")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
        }
    }

    private func continueButton(_ title: String = "Continue", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .gradientButton()
        }
        .accessibilityHint("Continues to the next step")
        .padding(.horizontal, 32)
    }

    private func completeOnboarding() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let user: User
        if let existing = users.first {
            user = existing
        } else {
            user = User()
            modelContext.insert(user)
        }

        user.hasCompletedOnboarding = true
        user.username = enteredName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.focusGoals = Array(selectedGoals)
        user.notificationsEnabled = notificationsEnabled
        user.userAge = selectedAge
        let sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared")
        sharedDefaults?.set(effectiveDailyScreenTimeHours, forKey: "onboarding_projection_daily_hours")
        sharedDefaults?.set(projectionIsEstimate, forKey: "onboarding_projection_is_estimate")
        sharedDefaults?.set(projectedScreenTimeHours, forKey: "onboarding_projected_screen_time_hours")

        // Save brain score result — assessment does NOT count toward daily session/limit
        if let result = assessmentResult {
            modelContext.insert(result)
            user.totalXP += 50  // Bonus XP for completing onboarding assessment
        }

        Analytics.onboardingCompleted(goals: Array(selectedGoals).map(\.rawValue))

        UserDefaults.standard.set(AppTheme.dark.rawValue, forKey: "appTheme")
        try? modelContext.save()
        onComplete()
    }
}

// MARK: - Organic Circle Shape

struct AgeNumberRail: View {
    @Binding var selectedAge: Int
    @State private var dragStartAge: Int?
    @State private var dragOffset: CGFloat = 0
    /// Per-tick compensation that accumulates as selectedAge changes during drag.
    /// dragOffset = rawTranslation + committedOffset. Without this separate state,
    /// reassigning dragOffset from rawTranslation every frame wiped the
    /// per-tick compensation and caused 60pt visual jumps at each age boundary.
    @State private var committedOffset: CGFloat = 0

    private let range = 18...99
    private let tickWidth: CGFloat = 60

    private var isDragging: Bool { dragStartAge != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Top row: lab-coat Memo on the LEFT, big age number on the RIGHT.
            HStack(alignment: .center, spacing: 0) {
                Image("mascot-lab-coat")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-4))
                    .shadow(color: AppColors.accent.opacity(0.22), radius: 22, y: 10)

                Spacer(minLength: 8)

                Text("\(selectedAge)")
                    .font(.system(size: 100, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText(value: Double(selectedAge)))
                    .shadow(color: AppColors.accent.opacity(0.28), radius: 22, y: 10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedAge)
            }
            .padding(.trailing, 12)

            // Manual rail: stable full range, continuous offset that tracks finger
            // 1:1 during drag, snaps to selectedAge on release. Compensates dragOffset
            // when selectedAge ticks so the visual position stays continuous (no
            // jumping mid-drag). Skips animation during drag — animations queueing
            // per-tick was the original jitter source. DragGesture (vs ScrollView)
            // because the parent TabView's `scrollDisabled` blocks DragGesture but
            // not ScrollView's internal pan gesture.
            GeometryReader { geo in
                let centerX = geo.size.width / 2
                let baseOffset = centerX - (CGFloat(selectedAge - range.lowerBound) * tickWidth + tickWidth / 2)

                HStack(spacing: 0) {
                    ForEach(Array(range), id: \.self) { age in
                        railTick(age: age)
                    }
                }
                .frame(width: tickWidth * CGFloat(range.count), alignment: .leading)
                .offset(x: baseOffset + dragOffset)
                .animation(isDragging ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: selectedAge)
                .animation(isDragging ? nil : .spring(response: 0.28, dampingFraction: 0.85), value: dragOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(railDragGesture)
            }
            .frame(height: 56)
            .clipped()
            .overlay(alignment: .bottom) {
                // Fixed center indicator — numbers scroll under it
                Capsule()
                    .fill(AppColors.accent)
                    .frame(width: 24, height: 4)
                    .offset(y: -2)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Age")
        .accessibilityValue("\(selectedAge)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                selectedAge = min(range.upperBound, selectedAge + 1)
            case .decrement:
                selectedAge = max(range.lowerBound, selectedAge - 1)
            @unknown default:
                break
            }
        }
    }

    private var railDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragStartAge == nil {
                    dragStartAge = selectedAge
                    committedOffset = 0
                }
                let raw = value.translation.width

                // Compute target age from RAW translation relative to drag start —
                // not from selectedAge, since selectedAge moves as we tick.
                let stepsFromStart = (-raw / tickWidth).rounded()
                let candidate = clampedAge((dragStartAge ?? selectedAge) + Int(stepsFromStart))

                if candidate != selectedAge {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    let ageDiff = candidate - selectedAge
                    selectedAge = candidate
                    // Accumulate compensation: when age decreases by 1, baseOffset
                    // jumps right by tickWidth. Counter that with -tickWidth here
                    // so the rail's visual position stays continuous with the finger.
                    committedOffset += CGFloat(ageDiff) * tickWidth
                }

                // Always derived from raw translation + accumulated compensation —
                // never assigned from raw alone (that was the bug).
                dragOffset = raw + committedOffset
            }
            .onEnded { _ in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dragStartAge = nil
                dragOffset = 0
                committedOffset = 0
            }
    }

    @ViewBuilder
    private func railTick(age: Int) -> some View {
        let isCentered = age == selectedAge
        Text("\(age)")
            .font(.system(
                size: isCentered ? 20 : 16,
                weight: isCentered ? .heavy : .semibold,
                design: .monospaced
            ))
            .foregroundStyle(
                isCentered ? AppColors.accent : AppColors.textTertiary.opacity(0.55)
            )
            .frame(width: tickWidth, height: 50)
    }

    private func clampedAge(_ age: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, age))
    }
}

struct OrganicCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        let cy = rect.midY

        var path = Path()
        let points = 60
        for i in 0..<points {
            let angle = Double(i) / Double(points) * 2 * .pi
            let wobble = sin(angle * 3) * 0.06 + cos(angle * 5) * 0.04
            let r = 0.5 + wobble
            let x = cx + CGFloat(cos(angle) * r) * w
            let y = cy + CGFloat(sin(angle) * r) * h
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

struct EmpathySignalBackdrop: View {
    let signalBroken: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(
                colors: [
                    AppColors.accent.opacity(signalBroken ? 0.24 : 0.14),
                    AppColors.violet.opacity(0.10),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 330
            )
            .frame(maxWidth: .infinity, maxHeight: 430, alignment: .topTrailing)
            .blur(radius: 10)
            .offset(y: 42)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.pageBg.opacity(0.0),
                            AppColors.pageBg.opacity(0.64),
                            AppColors.pageBg
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 360)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(false)
    }
}

struct EmpathyFeedWallScene: View {
    let sceneVisible: Bool
    let feedMuted: Bool

    private let tiles: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: Color, asset: String, rotation: Double)] = [
        (184, 8, 66, 78, AppColors.coral, "logo-tiktok", -7),
        (270, 26, 58, 70, AppColors.rose, "logo-instagram", 5),
        (222, 102, 80, 64, AppColors.violet, "logo-youtube", -4),
        (318, 112, 66, 78, AppColors.coral, "logo-snapchat", 7),
        (174, 190, 68, 76, AppColors.amber, "logo-x", 6),
        (268, 202, 84, 70, AppColors.coral, "logo-reddit", -5),
        (356, 214, 62, 74, AppColors.rose, "logo-tiktok", 4)
    ]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        AppColors.pageBg.opacity(0.0),
                        AppColors.coral.opacity(0.10),
                        AppColors.coral.opacity(0.22)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: width * 0.72, height: height * 1.10)
                .blur(radius: 16)
                .offset(x: 18, y: -4)
                .opacity(sceneVisible ? 1 : 0)

                ZStack {
                    ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                        FeedWallTile(
                            width: tile.w,
                            height: tile.h,
                            color: tile.color,
                            assetName: tile.asset,
                            dimmed: feedMuted
                        )
                        .rotationEffect(.degrees(tile.rotation))
                        .offset(
                            x: tile.x + (feedMuted ? 18 : 0),
                            y: tile.y + (feedMuted ? CGFloat(index % 2 == 0 ? -8 : 6) : 0)
                        )
                        .opacity(sceneVisible ? (feedMuted ? 0.54 : 0.82) : 0)
                        .blur(radius: feedMuted ? 1.1 : 0.4)
                        .animation(.easeOut(duration: 0.46).delay(Double(index) * 0.035), value: sceneVisible)
                        .animation(.easeInOut(duration: 0.55).delay(Double(index) * 0.025), value: feedMuted)
                    }
                }
                .frame(width: width, height: height, alignment: .topLeading)
                .mask(
                    LinearGradient(
                        colors: [
                            .clear,
                            AppColors.pageBg,
                            AppColors.pageBg,
                            AppColors.pageBg.opacity(0.15)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .rotation3DEffect(.degrees(-18), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                .offset(x: feedMuted ? 22 : 0, y: sceneVisible ? 0 : 8)

                RadialGradient(
                    colors: [
                        AppColors.accent.opacity(feedMuted ? 0.36 : 0.26),
                        AppColors.accent.opacity(0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 8,
                    endRadius: 126
                )
                .frame(width: 220, height: 220)
                .position(x: 124, y: 218)
                .blur(radius: 4)
                .opacity(sceneVisible ? 1 : 0)

                Image("mascot-cool")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 126, height: 126)
                    .rotationEffect(.degrees(-3))
                    .shadow(color: AppColors.accent.opacity(0.55), radius: 24, y: 12)
                    .shadow(color: AppColors.pageBg.opacity(0.95), radius: 14)
                    .position(x: 120, y: 218)
                    .opacity(sceneVisible ? 1 : 0)
                    .scaleEffect(sceneVisible ? 1 : 0.92)
                    .animation(.spring(response: 0.44, dampingFraction: 0.78), value: sceneVisible)
                    .accessibilityHidden(true)

                LinearGradient(
                    colors: [
                        AppColors.pageBg.opacity(0.0),
                        AppColors.pageBg.opacity(0.52),
                        AppColors.pageBg
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 130)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .allowsHitTesting(false)
    }
}

struct FeedWallTile: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let assetName: String
    let dimmed: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(dimmed ? 0.18 : 0.30),
                        AppColors.cardElevated.opacity(dimmed ? 0.34 : 0.52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay(
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(width, height) * 0.58, height: min(width, height) * 0.58)
                    .opacity(dimmed ? 0.56 : 0.90)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(color.opacity(dimmed ? 0.22 : 0.38), lineWidth: 1)
            )
            .shadow(color: color.opacity(dimmed ? 0.20 : 0.34), radius: 18, y: 10)
    }
}

// MARK: - Welcome Bouncer Hero (the bouncer scene composition)
//
// Memo holds the line on the left; six real social media app logos
// cascade in from the right edge, layered like a fan. Composition is
// asymmetric on purpose. After the entrance, everything is static.

private struct WelcomeBouncerHero: View {
    let appsVisible: [Bool]
    let appsLeaning: Bool
    let appsPushed: [Bool]
    let memoVisible: Bool
    let memoLeaning: Bool
    let memoShoving: Bool
    let memoEnlarged: Bool

    private struct AppSlot {
        let asset: String
        let size: CGFloat
        let rotation: Double
        let xOffset: CGFloat
        let opacity: Double
        let blur: CGFloat
    }

    private let slots: [AppSlot] = [
        AppSlot(asset: "logo-tiktok",    size: 64, rotation:  -8, xOffset:  30, opacity: 1.00, blur: 0.0),
        AppSlot(asset: "logo-instagram", size: 60, rotation:   6, xOffset:  62, opacity: 0.92, blur: 0.0),
        AppSlot(asset: "logo-snapchat",  size: 56, rotation: -12, xOffset:  94, opacity: 0.85, blur: 0.0),
        AppSlot(asset: "logo-youtube",   size: 54, rotation:   9, xOffset: 122, opacity: 0.75, blur: 0.5),
        AppSlot(asset: "logo-reddit",    size: 50, rotation:  -6, xOffset: 148, opacity: 0.62, blur: 1.0),
        AppSlot(asset: "logo-x",         size: 48, rotation:  14, xOffset: 170, opacity: 0.45, blur: 2.0),
    ]

    /// Memo's horizontal offset from his resting x:
    ///  - shoving: +30 (lurching into the apps)
    ///  - leaning: +6 (pressing into them)
    ///  - else: 0
    private var memoXOffset: CGFloat {
        if memoShoving { return 30 }
        if memoLeaning { return 6 }
        return 0
    }

    /// Memo's scale composes lean (compressed 0.97), enlarge (victory 1.2),
    /// or default 1.0. Lean and enlarge never co-occur in the timeline.
    private var memoScale: CGFloat {
        guard memoVisible else { return 0.92 }
        if memoEnlarged { return 1.2 }
        if memoLeaning { return 0.97 }
        return 1.0
    }

    var body: some View {
        ZStack(alignment: .center) {
            // App pile cascading from right-of-center; tension lean toward Memo, then shoved off-screen
            ZStack {
                ForEach(Array(slots.enumerated().reversed()), id: \.offset) { index, slot in
                    let visible = index < appsVisible.count ? appsVisible[index] : false
                    let pushed = index < appsPushed.count ? appsPushed[index] : false

                    let enterOffset: CGFloat = visible ? 0 : 120
                    // Lean toward Memo: shift left, dim, slightly tilt harder. Pushed overrides lean.
                    let leanOffset: CGFloat = (appsLeaning && !pushed) ? -8 : 0
                    let leanRotationMultiplier: Double = (appsLeaning && !pushed) ? 1.4 : 1.0
                    let leanOpacityMultiplier: Double = (appsLeaning && !pushed) ? 0.85 : 1.0

                    let pushOffset: CGFloat = pushed ? 320 : 0
                    let pushRotation: Double = pushed ? 30 : 0
                    let pushOpacityMultiplier: Double = pushed ? 0 : 1

                    WelcomeAppLogo(
                        assetName: slot.asset,
                        size: slot.size,
                        baseRotation: slot.rotation * leanRotationMultiplier + pushRotation,
                        targetOpacity: slot.opacity * leanOpacityMultiplier * pushOpacityMultiplier,
                        blur: slot.blur,
                        visible: visible
                    )
                    .offset(x: slot.xOffset + enterOffset + leanOffset + pushOffset)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Memo (cool / sunglasses pose) holding the line on the left
            HStack {
                Image("mascot-cool")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .shadow(
                        color: OB.accent.opacity(memoEnlarged ? 0.45 : 0.32),
                        radius: memoEnlarged ? 36 : 28,
                        y: 12
                    )
                    .scaleEffect(memoScale)
                    .offset(x: memoXOffset)
                    .opacity(memoVisible ? 1 : 0)

                Spacer()
            }
            .padding(.leading, 8)
        }
        .frame(height: 240)
    }
}

private struct WelcomeAppLogo: View {
    let assetName: String
    let size: CGFloat
    let baseRotation: Double
    let targetOpacity: Double
    let blur: CGFloat
    let visible: Bool

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            .blur(radius: blur)
            .rotationEffect(.degrees(baseRotation))
            .opacity(visible ? targetOpacity : 0)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ColoredIconBadge(icon: icon, color: color, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Screen Time Estimate Sheet
//
// Replaces the old standalone "rough estimate" page. Surfaces 4 hour buckets
// the user can pick from when they decline Screen Time access. Shorter than
// the old full page, keeps the funnel moving.

struct ScreenTimeEstimateSheet: View {
    @Binding var selection: Double
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("Roughly how much\ndoes the feed get you?")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(1)

                Text("We'll mark the projection as estimated. You can hand Memo Screen Time later.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            VStack(spacing: 0) {
                Divider().overlay(AppColors.cardBorder)
                ForEach([2.0, 4.0, 6.0, 8.0], id: \.self) { hours in
                    ScreenTimeEstimateRow(
                        hours: hours,
                        isSelected: selection == hours,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                selection = hours
                            }
                        }
                    )
                    Divider().overlay(AppColors.cardBorder)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onConfirm) {
                Text("Use \(selection >= 8 ? "8h+" : "\(Int(selection))h")")
                    .gradientButton()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 18)
        }
        .background(AppColors.pageBg.ignoresSafeArea())
    }
}

// MARK: - Screen Time Estimate Row

struct ScreenTimeEstimateRow: View {
    let hours: Double
    let isSelected: Bool
    let action: () -> Void

    private var title: String {
        hours >= 8 ? "8h+" : "\(Int(hours))h"
    }

    private var subtitle: String {
        switch hours {
        case ..<3: return "Light scroll, still worth defending"
        case ..<5: return "Average phone pace"
        case ..<7: return "Heavy feed territory"
        default: return "The algorithm is clocked in"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AppColors.accent : AppColors.textSecondary)
                    .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(subtitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("\(projectedAnnualHours.formatted()) hours a year")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isSelected ? AppColors.accent : AppColors.cardBorder)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var projectedAnnualHours: Int {
        Int((hours * 365).rounded())
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: UserFocusGoal
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    private var missionTitle: String {
        switch goal {
        case .attentionShot:    return "Sharper attention"
        case .screenTimeFrying: return "Hours back"
        case .doomscrolling:    return "Quality sleep"
        case .loseFocus:        return "Beat the room"
        case .forgetInstantly:  return "Better memory"
        case .getSharper:       return "Brain age glow-up"
        }
    }

    private var missionSubtitle: String {
        switch goal {
        case .attentionShot:    return "Finish a paragraph without checking your phone"
        case .screenTimeFrying: return "Get your time back from the feed"
        case .doomscrolling:    return "Stop scrolling at 2am"
        case .loseFocus:        return "Climb the weekly leaderboard"
        case .forgetInstantly:  return "Remember what you walked into a room for"
        case .getSharper:       return "Push your Brain Score up"
        }
    }

    private var missionNumber: String {
        String(format: "%02d", index + 1)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                HStack(spacing: 16) {
                    Rectangle()
                        .fill(isSelected ? AppColors.accent : Color.clear)
                        .frame(width: 3, height: 44)
                        .shadow(color: AppColors.accent.opacity(isSelected ? 0.6 : 0), radius: 8)

                    Text(missionNumber)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(isSelected ? AppColors.accent : AppColors.textTertiary.opacity(0.74))
                        .frame(width: 36, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(missionTitle)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.92))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)

                        Text(missionSubtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GoalSelectionMark(isSelected: isSelected)
                }
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(missionTitle), \(missionSubtitle)\(isSelected ? ", selected" : "")")
    }
}

private struct MemoLookoutHeader: View {
    var body: some View {
        Image("mascot-lookout")
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 265, height: 118, alignment: .leading)
            .offset(x: -20)
            .shadow(color: AppColors.accent.opacity(0.28), radius: 18, y: 8)
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Stack of social-media app tiles in the top-right.
// Visual story: Memo (lookout) is watching the actual apps farming you.
//
// Each tile prefers a real logo asset (e.g. "logo-tiktok") if present in
// Assets.xcassets. Falls back to a brand-colored tile with an SF Symbol
// approximation so the page never looks broken if assets are missing.
private struct FeedHeistBackdrop: View {
    private struct FeedApp {
        let logoAsset: String          // Image asset name; renders if present
        let fallbackSymbol: String     // SF Symbol used until logoAsset is added
        let fallbackBg: AnyShapeStyle  // Brand color for the fallback tile
        let fallbackFg: Color
        let rotation: Double
        let xOffset: CGFloat
    }

    private let apps: [FeedApp] = [
        FeedApp(
            logoAsset: "logo-tiktok",
            fallbackSymbol: "music.note",
            fallbackBg: AnyShapeStyle(Color.black),
            fallbackFg: .white,
            rotation: -6,
            xOffset: 6
        ),
        FeedApp(
            logoAsset: "logo-youtube",
            fallbackSymbol: "play.rectangle.fill",
            fallbackBg: AnyShapeStyle(Color(red: 1.0, green: 0.0, blue: 0.2)),
            fallbackFg: .white,
            rotation: 5,
            xOffset: -8
        ),
        FeedApp(
            logoAsset: "logo-instagram",
            fallbackSymbol: "camera.fill",
            fallbackBg: AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.42, blue: 0.35),
                    Color(red: 0.72, green: 0.34, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )),
            fallbackFg: .white,
            rotation: -3,
            xOffset: 8
        ),
        FeedApp(
            logoAsset: "logo-snapchat",
            fallbackSymbol: "bubble.left.fill",
            fallbackBg: AnyShapeStyle(Color(red: 1.0, green: 0.99, blue: 0.0)),
            fallbackFg: .black,
            rotation: 4,
            xOffset: -6
        ),
        FeedApp(
            logoAsset: "logo-x",
            fallbackSymbol: "xmark",
            fallbackBg: AnyShapeStyle(Color.black),
            fallbackFg: .white,
            rotation: -4,
            xOffset: 2
        ),
        FeedApp(
            logoAsset: "logo-reddit",
            fallbackSymbol: "bubble.left.and.bubble.right.fill",
            fallbackBg: AnyShapeStyle(Color(red: 1.0, green: 0.27, blue: 0.0)),
            fallbackFg: .white,
            rotation: 3,
            xOffset: -4
        )
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(apps.enumerated()), id: \.offset) { _, app in
                appTile(app)
            }
        }
        .rotation3DEffect(.degrees(-18), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
        .rotationEffect(.degrees(3))
        .frame(width: 132, height: 320)
        .mask(
            RadialGradient(
                colors: [.black, .black.opacity(0.7), .clear],
                center: .topTrailing,
                startRadius: 60,
                endRadius: 240
            )
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func appTile(_ app: FeedApp) -> some View {
        Group {
            if UIImage(named: app.logoAsset) != nil {
                Image(app.logoAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(app.fallbackBg)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: app.fallbackSymbol)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(app.fallbackFg)
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
        .rotationEffect(.degrees(app.rotation))
        .offset(x: app.xOffset)
    }
}

private struct GoalSelectionMark: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                    .shadow(color: AppColors.accent.opacity(0.55), radius: 8)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .stroke(AppColors.cardBorder.opacity(0.92), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
        .frame(width: 30, height: 30)
    }
}
