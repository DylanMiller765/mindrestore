import SwiftUI
import SwiftData

struct ScoreRevealView: View {
    let viewModel: BrainAssessmentViewModel
    let previousScore: BrainScoreResult?
    let onDone: () -> Void

    @Query private var users: [User]
    @Environment(StoreService.self) private var storeService

    @State private var showingPaywall = false
    @State private var displayedScore: Int = 0
    @State private var shareImage: UIImage?
    @State private var showScore = false
    @State private var showType = false
    @State private var showConfetti = false
    @State private var showActions = false
    @State private var showBreakdown = false
    @State private var showComparison = false
    @State private var scoreTimer: Timer?
    @State private var showChallenge = false

    // Brain Age dramatic reveal states
    @State private var showBrainAgeOverlay = false
    @State private var displayedBrainAge: Int = 18
    @State private var showBrainAgeLabel = false
    @State private var isCountingUp = false
    @State private var countUpFinished = false
    @State private var showBrainAgeSubtitle = false
    @State private var showBrainAgePercentile = false
    @State private var showBrainAgeShare = false
    @State private var pulseGlow = false
    @State private var brainAgeOverlayDismissed = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        ZStack {
            AppColors.pageBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Spacer(minLength: 12)

                    // Brain Score
                    if showScore {
                        VStack(spacing: 8) {
                            Text("\(displayedScore)")
                                .font(.system(size: 60, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                                .contentTransition(.numericText(value: Double(displayedScore)))

                            Text("Brain Score")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Brain Score \(viewModel.brainScore) out of 1000")
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Brain Age summary (shown after overlay dismissed)
                    if brainAgeOverlayDismissed {
                        HStack(spacing: 8) {
                            Image(systemName: "brain.head.profile.fill")
                                .foregroundStyle(brainAgeColor(for: viewModel.brainAge))
                            Text("Brain Age:")
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.brainAge)")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(brainAgeColor(for: viewModel.brainAge))
                        }
                        .font(.title3)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Your brain age is \(viewModel.brainAge)")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Brain Type
                    if showType {
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.brainType.icon)
                                    .font(.title2)
                                Text(viewModel.brainType.displayName)
                                    .font(.title2.weight(.bold))
                            }
                            .foregroundStyle(brainTypeColor)

                            Text(viewModel.brainType.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }

                    // Percentile (inline, after overlay)
                    if brainAgeOverlayDismissed {
                        Text("Better than \(viewModel.percentile)% of players")
                            .font(.headline)
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppColors.accent.opacity(0.18), in: Capsule())
                            .accessibilityLabel("Better than \(viewModel.percentile) percent of players")
                            .transition(.opacity)
                    }

                    // Score Comparison
                    if showComparison, let previous = previousScore {
                        let diff = viewModel.brainScore - previous.brainScore
                        let improved = diff > 0

                        VStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Text("Previous: \(previous.brainScore)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Image(systemName: "arrow.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)

                                Text("Current: \(viewModel.brainScore)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppColors.accent)
                            }

                            if improved {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.green)
                                    Text("+\(diff) points!")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.green)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.green.opacity(0.1), in: Capsule())
                            } else {
                                Text("Keep training!")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColors.accent)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(AppColors.accent.opacity(0.18), in: Capsule())
                            }
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }

                    // Breakdown
                    if showBreakdown {
                        VStack(spacing: 12) {
                            Text("Performance Breakdown")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            breakdownRow(
                                icon: "number.circle.fill",
                                label: "Digit Span",
                                value: "\(viewModel.digitMaxCorrect) digits",
                                score: viewModel.digitScore,
                                color: .blue
                            )
                            breakdownRow(
                                icon: "bolt.fill",
                                label: "Reaction Time",
                                value: "\(viewModel.avgReactionMs)ms",
                                score: viewModel.reactionScore,
                                color: .yellow
                            )
                            breakdownRow(
                                icon: "square.grid.3x3.fill",
                                label: "Visual Memory",
                                value: "Level \(viewModel.visualMaxCorrect)",
                                score: viewModel.visualScore,
                                color: .purple
                            )
                        }
                        .appCard()
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Leaderboard rank
                    if showBreakdown {
                        LeaderboardRankCard(
                            exerciseType: nil,
                            userScore: viewModel.brainScore,
                            userName: user?.username ?? "You",
                            userLevel: user?.level ?? 1,
                            isPro: isProUser,
                            onUpgradeTap: { showingPaywall = true }
                        )
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Actions
                    if showActions {
                        VStack(spacing: 12) {
                            if let shareImage {
                                ShareLink(
                                    item: Image(uiImage: shareImage),
                                    preview: SharePreview("Brain Score: \(viewModel.brainScore)", image: Image(uiImage: shareImage))
                                ) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share Your Score")
                                    }
                                    .accentButton()
                                }
                                .accessibilityHint("Share your brain score on social media")
                            } else {
                                ShareLink(item: shareText) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share Your Score")
                                    }
                                    .accentButton()
                                }
                                .accessibilityHint("Share your brain score on social media")
                            }

                            if let previous = previousScore, viewModel.brainScore > previous.brainScore {
                                let diff = viewModel.brainScore - previous.brainScore
                                ShareLink(item: "I improved my Brain Score by +\(diff) points! (\(previous.brainScore) -> \(viewModel.brainScore)/1000)\n\nTest yours with Memori") {
                                    HStack {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                        Text("Share Your Improvement")
                                    }
                                    .gradientButton()
                                }
                            }

                            Button {
                                showChallenge = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                    Text("Challenge a Friend")
                                }
                                .gradientButton()
                            }

                            Button(action: onDone) {
                                Text("Done")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.bottom, 16)
            }

            if showConfetti {
                ConfettiView()
            }

            // MARK: - Dramatic Brain Age Overlay
            if showBrainAgeOverlay && !brainAgeOverlayDismissed {
                brainAgeOverlayView
                    .transition(.opacity)
            }
        }
        .onAppear { startRevealSequence() }
        .sheet(isPresented: $showChallenge) {
            ChallengeView(
                challengeType: .brainScore(
                    brainAge: viewModel.brainAge,
                    brainType: viewModel.brainType,
                    digitScore: viewModel.digitScore,
                    reactionScore: viewModel.reactionScore,
                    visualScore: viewModel.visualScore
                ),
                playerScore: viewModel.brainScore,
                playerName: "Me",
                percentile: viewModel.percentile
            )
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    // MARK: - Brain Age Overlay View

    private var brainAgeOverlayView: some View {
        ZStack {
            AppColors.pageBg.ignoresSafeArea()

            // Solid circle behind the number
            if countUpFinished {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 200, height: 200)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 24) {
                Spacer()

                // "Your Brain Age" label
                if showBrainAgeLabel {
                    Text("Your Brain Age")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(2)
                        .transition(.opacity)
                }

                // The big number
                if isCountingUp || countUpFinished {
                    Text("\(displayedBrainAge)")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundStyle(brainAgeColor(for: displayedBrainAge))
                        .contentTransition(.numericText(value: Double(displayedBrainAge)))
                        .scaleEffect(countUpFinished ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: countUpFinished)
                        .accessibilityLabel("Your brain age is \(viewModel.brainAge)")
                }

                // Snarky subtitle
                if showBrainAgeSubtitle {
                    Text("You have the brain of a \(viewModel.brainAge)-year-old")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Percentile
                if showBrainAgePercentile {
                    Text("Sharper than \(viewModel.percentile)% of people your age")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Sharper than \(viewModel.percentile) percent of people your age")
                        .transition(.opacity)
                }

                Spacer()

                // Share button
                if showBrainAgeShare {
                    VStack(spacing: 16) {
                        if let shareImage {
                            ShareLink(
                                item: Image(uiImage: shareImage),
                                preview: SharePreview("Brain Age: \(viewModel.brainAge)", image: Image(uiImage: shareImage))
                            ) {
                                brainAgeShareButton
                            }
                        } else {
                            ShareLink(item: brainAgeShareText) {
                                brainAgeShareButton
                            }
                        }

                        Button {
                            dismissBrainAgeOverlay()
                        } label: {
                            Text("See Brain Score")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
                    .frame(height: 40)
            }
        }
    }

    private var brainAgeShareButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(.headline)
            Text("Share Your Brain Age")
                .font(.headline.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(brainAgeColor(for: viewModel.brainAge))
        .clipShape(Capsule())
        .accessibilityHint("Share your brain age on social media")
    }

    private var brainAgeShareText: String {
        "My Brain Age is \(viewModel.brainAge)! Sharper than \(viewModel.percentile)% of people my age.\n\nTest yours with Memori"
    }

    private func brainAgeColor(for age: Int) -> Color {
        switch age {
        case ...25: return Color(red: 0, green: 0.82, blue: 0.62)       // green
        case 26...40: return Color(red: 0.25, green: 0.61, blue: 0.98)  // sky
        case 41...55: return Color(red: 1.0, green: 0.76, blue: 0.28)   // amber
        default: return Color(red: 0.98, green: 0.42, blue: 0.35)       // coral
        }
    }

    private var shareText: String {
        "My Brain Score is \(viewModel.brainScore)/1000 (Brain Age: \(viewModel.brainAge)) \u{1F9E0}\n\nI'm a \(viewModel.brainType.displayName) \u{2014} better than \(viewModel.percentile)% of players!\n\nTest yours with Memori"
    }

    private var brainTypeColor: Color {
        switch viewModel.brainType {
        case .lightningReflex: return .orange
        case .numberCruncher: return .blue
        case .patternMaster: return AppColors.violet
        case .balancedBrain: return AppColors.accent
        }
    }

    private func breakdownRow(icon: String, label: String, value: String, score: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * score / 100)
                }
            }
            .frame(width: 80, height: 8)

            Text("\(Int(score))")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .frame(width: 30, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value), score \(Int(score))")
    }

    // MARK: - Dismiss Brain Age Overlay

    private func dismissBrainAgeOverlay() {
        withAnimation(.easeOut(duration: 0.4)) {
            brainAgeOverlayDismissed = true
        }
        // NOW show the score card (was previously shown first — now comes after the overlay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5)) { showScore = true }
            startScoreCounter()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showType = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showConfetti = true
            SoundService.shared.playComplete()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if previousScore != nil {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showComparison = true }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.easeIn(duration: 0.4)) { showBreakdown = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            withAnimation(.easeIn(duration: 0.3)) { showActions = true }
        }
    }

    // MARK: - Reveal Sequence

    private func startRevealSequence() {
        // Brain Age overlay comes FIRST — this is the viral moment
        SoundService.shared.playTap()
        showBrainAgeOverlay = true

        // Generate TikTok-style share card image
        let card = TikTokBrainScoreCard(
            brainScore: viewModel.brainScore,
            brainAge: viewModel.brainAge,
            brainType: viewModel.brainType,
            percentile: viewModel.percentile,
            digitScore: viewModel.digitScore,
            reactionScore: viewModel.reactionScore,
            visualScore: viewModel.visualScore
        )
        shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)

        // Step 1: "Your Brain Age" label fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.4)) {
                showBrainAgeLabel = true
            }
        }

        // Step 2: Start count-up after label appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            startBrainAgeCountUp(target: viewModel.brainAge)
        }
    }

    private func startBrainAgeCountUp(target: Int) {
        displayedBrainAge = 18
        isCountingUp = true
        let totalSteps = max(target - 18, 1)
        let interval = 3.0 / Double(totalSteps)

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            Task { @MainActor in
                if displayedBrainAge >= target {
                    timer.invalidate()
                    displayedBrainAge = target
                    withAnimation(.easeOut(duration: 0.3)) {
                        countUpFinished = true
                    }
                    withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                        showBrainAgeSubtitle = true
                    }
                    withAnimation(.easeOut(duration: 0.5).delay(1.1)) {
                        showBrainAgePercentile = true
                    }
                    withAnimation(.easeOut(duration: 0.5).delay(1.7)) {
                        showBrainAgeShare = true
                    }
                } else {
                    displayedBrainAge += 1
                }
            }
        }
    }

    private func startScoreCounter() {
        let target = viewModel.brainScore
        let duration: Double = 2.0
        let steps = 60
        let stepDuration = duration / Double(steps)
        var currentStep = 0

        scoreTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let eased = 1.0 - pow(1.0 - progress, 3) // ease-out cubic
            let value = Int(Double(target) * eased)

            Task { @MainActor in
                displayedScore = min(value, target)
                if currentStep >= steps {
                    timer.invalidate()
                    displayedScore = target
                }
            }
        }
    }
}
