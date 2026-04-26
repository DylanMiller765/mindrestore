import SwiftUI
import SwiftData
import UIKit
import FamilyControls
import DeviceActivity

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusModeService.self) private var focusModeService
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
    @State private var mascotBob = false
    @State private var welcomeSubtitleVisible = false
    @State private var badNewsTypingDone = false
    @State private var goodNewsTypingDone = false
    @State private var badNewsSubtitleVisible = false
    @State private var goodNewsSubtitleVisible = false
    @State private var commitmentBullet1Visible = false
    @State private var commitmentBullet2Visible = false
    @State private var commitmentBullet3Visible = false
    @State private var commitmentBullet4Visible = false
    @FocusState private var nameFieldFocused: Bool
    @State private var showingFocusModeSetup = false
    @State private var focusModeWasSetUp = false
    @State private var quickAssessmentBgColor: Color = AppColors.pageBg
    @State private var showingBrainAgeReveal = false
    @State private var screenTimeAuthorized = false
    @State private var isRequestingScreenTimeAccess = false
    @State private var screenTimeEstimateHours: Double = 4
    @State private var measuredScreenTimeHours: Double?
    @State private var useScreenTimeEstimate = false

    var onComplete: () -> Void

    private let totalPages = 15

    var body: some View {
        ZStack {
            (currentPage == 8 ? quickAssessmentBgColor : AppColors.pageBg).ignoresSafeArea()

            VStack(spacing: 0) {
                if currentPage != 8 {
                    onboardingProgressHeader
                }

                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    namePage.tag(1)
                    goalsPage.tag(2)
                    screenTimeAccessPage.tag(3)
                    screenTimeEstimatePage.tag(4)
                    empathyPage.tag(5)
                    agePage.tag(6)
                    scarePage.tag(7)
                    quickAssessmentPage.tag(8)
                    personalSolutionPage.tag(9)
                    notificationPrimingPage.tag(10)
                    stat144Page.tag(11)
                    personalUnlocksPage.tag(12)
                    focusModePage.tag(13)
                    commitmentPage.tag(14)
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
                    // Reset typewriter animation states when navigating away
                    if newPage != 7 {
                        badNewsTypingDone = false
                        badNewsSubtitleVisible = false
                    }
                    if newPage != 9 {
                        goodNewsTypingDone = false
                        goodNewsSubtitleVisible = false
                    }
                    if newPage != 14 {
                        commitmentBullet1Visible = false
                        commitmentBullet2Visible = false
                        commitmentBullet3Visible = false
                        commitmentBullet4Visible = false
                    }
                }
            }
        }
        .onDisappear {
            if users.first?.hasCompletedOnboarding != true {
                let stepNames = ["welcome", "name", "goals", "screenTimeAccess", "screenTimeEstimate", "empathy", "age", "personalizedScare", "quickAssessment", "personalSolution", "notificationPriming", "stat144", "personalUnlocks", "focusMode", "commitment"]
                let lastStep = currentPage < stepNames.count ? stepNames[currentPage] : "unknown"
                Analytics.onboardingDroppedOff(lastStep: lastStep, totalSteps: currentPage)
            }
        }
        // Single full-screen cover for reveal → paywall. Chaining two .fullScreenCover
        // presentations produces a race where the second cover can silently fail to present
        // while the first is still in its dismiss animation.
        .fullScreenCover(isPresented: $showingBrainAgeReveal, onDismiss: {
            Analytics.onboardingStep(step: "paywallDismissed")
            withAnimation { currentPage = 9 } // → personalSolution
        }) {
            OnboardingFinaleSequence(
                brainAge: assessmentResult?.brainAge ?? 25,
                userAge: selectedAge > 0 ? selectedAge : 25
            )
        }
    }

    // MARK: - Progress Header

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

    // MARK: - Stat 144× Page

    private var stat144Page: some View {
        FocusOnboardA {
            Analytics.onboardingStep(step: "stat144")
            screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
            withAnimation { currentPage = 12 } // → personalUnlocks
        }
    }

    // MARK: - Personal Unlocks (287×) Page

    private var personalUnlocksPage: some View {
        // Once iOS marks FamilyControls as .denied, requestAuthorization() silently
        // no-ops — the only path back is Settings. The page handles that CTA itself.
        let denied = (focusModeService.authorizationStatus == .denied)
        return FocusOnboardPersonalUnlocks(
            onContinue: {
                if screenTimeAuthorized {
                    Analytics.onboardingStep(step: "personalUnlocksAuthorized")
                    withAnimation { currentPage = 13 } // → focusMode
                } else if denied {
                    // CTA already deep-links to Settings inside the view. Nothing to do here.
                    // (User returns to this page; if they enabled it, screenTimeAuthorized
                    // will flip on next .onAppear via the focusModeService refresh.)
                    Analytics.onboardingStep(step: "personalUnlocksOpenedSettings")
                } else {
                    // First decline (or .notDetermined) — re-prompt auth
                    Task {
                        await focusModeService.requestAuthorization()
                        screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
                        if screenTimeAuthorized {
                            Analytics.onboardingStep(step: "personalUnlocksAuthorized")
                        } else {
                            // still declined — let them continue anyway
                            Analytics.onboardingStep(step: "personalUnlocksDeclined")
                            withAnimation { currentPage = 13 } // → focusMode
                        }
                    }
                }
            },
            authorized: screenTimeAuthorized,
            count: 287,
            previouslyDenied: denied
        )
        .onAppear {
            // Re-check authorization in case user just returned from Settings.
            screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image("mascot-welcome")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 220)
                .offset(y: mascotBob ? -6 : 6)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: mascotBob)
                .onAppear { mascotBob = true }

            VStack(spacing: 10) {
                TypewriterText(fullText: "Train your brain.\nBlock the noise.")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text("The app that blocks distractions\nand sharpens your mind.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(welcomeSubtitleVisible ? 1 : 0)
                    .offset(y: welcomeSubtitleVisible ? 0 : 10)
                    .animation(.easeOut(duration: 0.5), value: welcomeSubtitleVisible)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            welcomeSubtitleVisible = true
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(icon: "shield.fill", color: AppColors.coral, title: "Block Distracting Apps", subtitle: "Shield yourself from doomscrolling")
                FeatureRow(icon: "brain.head.profile", color: CognitiveDomain.memory.color, title: "10 Brain Games", subtitle: "Play to earn your screen time back")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", color: AppColors.accent, title: "Track Your Brain Age", subtitle: "See how your brain stacks up")
            }
            .padding(.horizontal, 36)
            .opacity(welcomeSubtitleVisible ? 1 : 0)
            .offset(y: welcomeSubtitleVisible ? 0 : 15)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: welcomeSubtitleVisible)

            Spacer()

            continueButton {
                Analytics.onboardingStep(step: "welcome")
                currentPage = 1
            }
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Name Entry Page

    private var namePage: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 60)

                // Animated greeting emoji
                Text("👋")
                    .font(.system(size: 64))

                VStack(spacing: 10) {
                    TypewriterText(fullText: "What should we\ncall you?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("So Memo knows what to call you")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }

                TextField("Your name", text: $enteredName)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.cardSurface)
                            .shadow(color: AppColors.accent.opacity(nameFieldFocused ? 0.15 : 0), radius: 12, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                nameFieldFocused ? AppColors.accent.opacity(0.5) : AppColors.cardBorder,
                                lineWidth: nameFieldFocused ? 1.5 : 1
                            )
                    )
                    .padding(.horizontal, 32)
                    .focused($nameFieldFocused)
                    .submitLabel(.continue)
                    .onSubmit { dismissAndAdvance() }
                    .animation(.easeInOut(duration: 0.2), value: nameFieldFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button("Skip") {
                                enteredName = ""
                                dismissAndAdvance()
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                dismissAndAdvance()
                            } label: {
                                Text("Continue")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppColors.accent)
                            }
                        }
                    }

                if !nameFieldFocused {
                    VStack(spacing: 12) {
                        continueButton { dismissAndAdvance() }

                        Button {
                            enteredName = ""
                            dismissAndAdvance()
                        } label: {
                            Text("Skip")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 16)
            .responsiveContent(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
                if currentPage == 1 { nameFieldFocused = true }
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
                    Text("What are you\ntaking back?")
                        .font(.system(size: 37, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(1)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Pick up to 3. Memo builds your anti-scroll plan.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                Text("Choose up to 3")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(AppColors.textTertiary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)

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

                continueButton("Build my plan") {
                    Analytics.onboardingStep(step: "goals")
                    currentPage = 3
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

            ZStack(alignment: .trailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Let Memo see\nwhat the feed\nis taking.")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("We use Screen Time to personalize your plan and block the apps you choose. No ads. No data sold.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, 76)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image("mascot-lookout")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132)
                    .offset(x: 16, y: 62)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 28)

            VStack(spacing: 0) {
                Divider().overlay(AppColors.cardBorder)
                screenTimeProofRow(number: "01", title: "Personal fear math", detail: "Your plan uses your real daily pace.")
                Divider().overlay(AppColors.cardBorder)
                screenTimeProofRow(number: "02", title: "App blocking", detail: "Memo can bounce the apps you choose.")
                Divider().overlay(AppColors.cardBorder)
                screenTimeProofRow(number: "03", title: "Apple-private", detail: "Screen Time data stays on device.")
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
                        withAnimation { currentPage = 5 }
                    } else {
                        requestScreenTimeForOnboarding()
                    }
                }
                .disabled(isRequestingScreenTimeAccess)
                .opacity(isRequestingScreenTimeAccess ? 0.6 : 1)

                Button {
                    Analytics.onboardingStep(step: "screenTimeAccessEstimate")
                    useScreenTimeEstimate = true
                    withAnimation { currentPage = 4 }
                } label: {
                    Text("Use an estimate instead")
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
    }

    private var screenTimeEstimatePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 48)

            VStack(alignment: .leading, spacing: 12) {
                Text("No access?\nGive Memo a\nrough number.")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text("We'll mark the projection as estimated and keep the flow moving.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 34)

            VStack(spacing: 0) {
                Divider().overlay(AppColors.cardBorder)
                ForEach([2.0, 4.0, 6.0, 8.0], id: \.self) { hours in
                    ScreenTimeEstimateRow(
                        hours: hours,
                        isSelected: screenTimeEstimateHours == hours,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                screenTimeEstimateHours = hours
                                measuredScreenTimeHours = nil
                                useScreenTimeEstimate = true
                            }
                        }
                    )
                    Divider().overlay(AppColors.cardBorder)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            continueButton("Use \(screenTimeEstimateLabel)") {
                Analytics.onboardingStep(step: "screenTimeEstimate")
                useScreenTimeEstimate = true
                withAnimation { currentPage = 5 }
            }
            .padding(.bottom, 18)
        }
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private var screenTimeEstimateLabel: String {
        screenTimeEstimateHours >= 8 ? "8h+" : "\(Int(screenTimeEstimateHours))h"
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
            } else {
                useScreenTimeEstimate = true
                Analytics.onboardingStep(step: "screenTimeAccessDenied")
                withAnimation { currentPage = 4 }
            }
        }
    }

    private func screenTimeProofRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(number)
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppColors.accent)
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
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 34)

            RiveMascotView(mood: .neutral, size: 148)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                Text("Your brain\nisn't broken.")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text("It's been hijacked.")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text("47 apps are fighting for your attention every minute. Memo's gonna fight back with you.")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)

            Spacer()

            continueButton("Show me my plan") {
                Analytics.onboardingStep(step: "empathy")
                withAnimation { currentPage = 6 }
            }
            .padding(.bottom, 18)
        }
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Age Page

    private var agePage: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 10) {
                Text("How many years\nare we defending?")
                    .font(.system(size: 32, weight: .bold))
                    .kerning(-0.6)
                    .multilineTextAlignment(.center)

                Text("Memo uses this to compare your Brain Age and make the stakes personal.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Picker("Age", selection: $selectedAge) {
                ForEach(18...99, id: \.self) { age in
                    Text("\(age)").tag(age)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)

            // Privacy note
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("Stored on your device only. Never shared.")
                    .font(.caption)
            }
            .foregroundStyle(AppColors.textTertiary)

            Spacer()

            VStack(spacing: 12) {
                continueButton {
                    Analytics.onboardingStep(step: "age")
                    currentPage = 7
                }

                Button {
                    selectedAge = 0
                    Analytics.onboardingStep(step: "age")
                    withAnimation { currentPage = 7 }
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scare Page

    private var scarePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 34)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    Image("mascot-low-score")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 98, height: 98)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(projectionIsEstimate ? "Estimated from your pace" : "Based on your Screen Time")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1.0)
                            .foregroundStyle(AppColors.textTertiary)
                            .textCase(.uppercase)

                        Text("At \(dailyScreenTimeLabel)/day, the feed takes")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    TypewriterText(fullText: formatProjectedHours(projectedScreenTimeHours)) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            badNewsTypingDone = true
                        }
                    }
                    .font(.system(size: 70, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.coral)
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)

                    Text("hours by 60.")
                        .font(.system(size: 31, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .opacity(badNewsTypingDone ? 1 : 0)
                        .offset(y: badNewsTypingDone ? 0 : 10)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: badNewsTypingDone)
                }

                Text("That's \(projectedYearsText) years if nothing changes.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .opacity(badNewsSubtitleVisible ? 1 : 0)
                    .offset(y: badNewsSubtitleVisible ? 0 : 10)
                    .animation(.easeOut(duration: 0.5), value: badNewsSubtitleVisible)
                    .onChange(of: badNewsTypingDone) { _, done in
                        if done {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                badNewsSubtitleVisible = true
                            }
                        }
                    }

                Text("Memo turns that time into reps.")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                    .opacity(badNewsSubtitleVisible ? 1 : 0)
                    .offset(y: badNewsSubtitleVisible ? 0 : 10)
            }
            .padding(.horizontal, 28)

            Spacer()

            Button {
                Analytics.onboardingStep(step: "scare")
                withAnimation { currentPage = 8 }
            } label: {
                Text("Test my brain")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 18)
        }
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Assessment Page

    private var quickAssessmentPage: some View {
        QuickAssessmentView(backgroundColor: $quickAssessmentBgColor) { result in
            assessmentResult = result
            Analytics.onboardingStep(step: "quickAssessment")
            // Present dramatic reveal as a full-screen cover so it escapes the TabView.
            // Cover only fires from a legitimate onComplete — swiping the TabView won't trigger it.
            showingBrainAgeReveal = true
        }
    }

    // MARK: - Personal Solution Page (NEW)

    private var personalSolutionPage: some View {
        OnboardingPersonalSolutionView(
            userGoals: selectedGoals,
            brainAge: assessmentResult?.brainAge,
            userAge: selectedAge,
            dailyScreenTimeHours: effectiveDailyScreenTimeHours,
            projectedScreenTimeHours: projectedScreenTimeHours,
            projectionIsEstimate: projectionIsEstimate,
            onContinue: {
                Analytics.onboardingStep(step: "personalSolution")
                withAnimation { currentPage = 10 } // → notification priming
            }
        )
    }

    // MARK: - Notification Priming Page (NEW)

    private var notificationPrimingPage: some View {
        OnboardingNotificationPrimingView { granted in
            notificationsEnabled = granted
            withAnimation { currentPage = 11 } // → stat144
        }
    }

    // MARK: - Commitment Page

    private var commitmentPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            // Title with user's name
            Group {
                if enteredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Join the fight")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                } else {
                    (Text(enteredName.trimmingCharacters(in: .whitespacesAndNewlines))
                        .foregroundColor(AppColors.accent)
                    + Text("'s fight plan"))
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
                    TypewriterText(fullText: "• I'll let Memo bounce the apps that drain me", speed: 0.025)
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

                    Text("Research shows that committing to contracts\nboosts follow-through and accountability")
                        .font(.caption)
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
                withAnimation { currentPage = 14 } // → commitment
            })

            // "Not now" skip button
            Button {
                Analytics.onboardingStep(step: "focusModeSkipped")
                Analytics.focusSetupSkipped()
                withAnimation { currentPage = 14 } // → commitment
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

// MARK: - Feature Row

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
        case .screenTimeFrying: return "Screen Time"
        case .doomscrolling: return "Memory"
        case .attentionShot: return "Attention"
        case .loseFocus: return "Mornings"
        case .forgetInstantly: return "Sleep"
        case .getSharper: return "Self-Control"
        }
    }

    private var missionSubtitle: String {
        switch goal {
        case .screenTimeFrying: return "Make scrolling cost reps"
        case .doomscrolling: return "Train recall daily"
        case .attentionShot: return "Stop losing the thread"
        case .loseFocus: return "Start before the feed"
        case .forgetInstantly: return "Protect your wind-down"
        case .getSharper: return "Build the no muscle"
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
                .overlay(alignment: .bottom) {
                    if isSelected {
                        SelectedGoalUnderline()
                            .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 2.25, lineCap: .round, lineJoin: .round))
                            .shadow(color: AppColors.accent.opacity(0.45), radius: 8)
                            .frame(height: 16)
                            .padding(.leading, 2)
                            .padding(.trailing, 6)
                            .offset(y: 12)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
            }
            .padding(.vertical, isSelected ? 10 : 6)
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

private struct FeedHeistBackdrop: View {
    private let reels: [FeedReelStyle] = [
        .init(color: AppColors.coral, offset: 10, opacity: 0.30),
        .init(color: AppColors.violet, offset: -6, opacity: 0.34),
        .init(color: AppColors.accent, offset: 14, opacity: 0.28),
        .init(color: AppColors.mint, offset: -2, opacity: 0.24)
    ]

    var body: some View {
        ZStack {
            HStack(alignment: .top, spacing: 9) {
                ForEach(Array(reels.enumerated()), id: \.offset) { index, reel in
                    FeedReel(style: reel, index: index)
                        .offset(y: reel.offset)
                }
            }
            .rotation3DEffect(.degrees(-28), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .rotationEffect(.degrees(4))
            .frame(width: 162)

            LinearGradient(
                colors: [
                    .clear,
                    AppColors.pageBg.opacity(0.54),
                    AppColors.pageBg
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .frame(width: 176, height: 250)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FeedReelStyle {
    let color: Color
    let offset: CGFloat
    let opacity: Double
}

private struct FeedReel: View {
    let style: FeedReelStyle
    let index: Int

    var body: some View {
        VStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { item in
                FeedFrame(color: style.color, index: index + item)
            }
        }
        .opacity(style.opacity)
    }
}

private struct FeedFrame: View {
    let color: Color
    let index: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(AppColors.cardElevated.opacity(0.84))
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.78))
                    .frame(width: 28, height: 28)
                    .padding(6)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Capsule()
                        .fill(AppColors.textPrimary.opacity(0.22))
                        .frame(width: index.isMultiple(of: 2) ? 32 : 24, height: 4)
                    Capsule()
                        .fill(AppColors.textPrimary.opacity(0.12))
                        .frame(width: 22, height: 4)
                }
                .padding(7)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.cardBorder.opacity(0.8), lineWidth: 1)
            }
            .frame(width: 44, height: 66)
            .shadow(color: color.opacity(0.18), radius: 12, y: 6)
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

private struct SelectedGoalUnderline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.maxY - 4
        let left = rect.minX + 4
        let right = rect.maxX - 4

        path.move(to: CGPoint(x: left, y: y))
        path.addLine(to: CGPoint(x: right - 48, y: y))
        path.addLine(to: CGPoint(x: right - 32, y: y - 12))
        path.addLine(to: CGPoint(x: right, y: y - 12))
        return path
    }
}
