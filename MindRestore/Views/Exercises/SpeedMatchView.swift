import SwiftUI
import SwiftData

// MARK: - ViewModel

@MainActor @Observable
final class SpeedMatchViewModel {
    enum Phase { case setup, showing, answering, feedback, finished }

    var phase: Phase = .setup
    var startTime: Date?
    var currentRound = 0
    let totalRounds = 25
    var correctCount = 0
    var currentSymbol: String = ""
    var previousSymbol: String = ""
    var isMatch: Bool = false
    var lastAnswerCorrect: Bool? = nil
    var responseTimes: [Double] = []
    var roundStartTime: Date?
    var falsePositives = 0
    var misses = 0

    let symbols = ["star.fill", "heart.fill", "moon.fill", "bolt.fill", "flame.fill", "leaf.fill", "drop.fill", "snowflake"]

    var score: Double {
        guard totalRounds > 0 else { return 0 }
        return Double(correctCount) / Double(totalRounds)
    }

    var accuracy: Double {
        score
    }

    var averageResponseMs: Int {
        guard !responseTimes.isEmpty else { return 0 }
        return Int(responseTimes.reduce(0, +) / Double(responseTimes.count) * 1000)
    }

    var durationSeconds: Int {
        guard let start = startTime else { return 0 }
        return Int(Date.now.timeIntervalSince(start))
    }

    var ratingText: String {
        let pct = accuracy
        if pct >= 0.95 { return "Perfect!" }
        if pct >= 0.85 { return "Excellent!" }
        if pct >= 0.70 { return "Great Job!" }
        if pct >= 0.50 { return "Good Effort!" }
        return "Keep Practicing!"
    }

    // Generate whether next card should match (~30% match rate)
    private func nextShouldMatch() -> Bool {
        Double.random(in: 0...1) < 0.30
    }

    func startGame() {
        phase = .setup
        currentRound = 0
        correctCount = 0
        falsePositives = 0
        misses = 0
        responseTimes = []
        lastAnswerCorrect = nil
        previousSymbol = ""
        currentSymbol = ""
        startTime = Date.now
        showNextCard()
    }

    func showNextCard() {
        previousSymbol = currentSymbol
        currentRound += 1

        if currentRound == 1 {
            // First card — pick a random symbol, no match possible
            currentSymbol = symbols.randomElement()!
            isMatch = false
        } else {
            let shouldMatch = nextShouldMatch()
            if shouldMatch {
                currentSymbol = previousSymbol
                isMatch = true
            } else {
                // Pick a different symbol
                var next = symbols.randomElement()!
                while next == previousSymbol {
                    next = symbols.randomElement()!
                }
                currentSymbol = next
                isMatch = false
            }
        }

        lastAnswerCorrect = nil
        phase = .answering
        roundStartTime = Date.now
    }

    func answer(yes: Bool) {
        guard phase == .answering else { return }

        let responseTime = Date.now.timeIntervalSince(roundStartTime ?? Date.now)
        responseTimes.append(responseTime)

        let correct = (yes == isMatch)
        lastAnswerCorrect = correct

        if correct {
            correctCount += 1
        } else if yes && !isMatch {
            falsePositives += 1
        } else if !yes && isMatch {
            misses += 1
        }

        if correct {
            HapticService.correct()
        } else {
            HapticService.wrong()
        }

        phase = .feedback

        // Brief feedback then advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            if self.currentRound >= self.totalRounds {
                self.phase = .finished
                SoundService.shared.playComplete()
                HapticService.complete()
            } else {
                self.showNextCard()
            }
        }
    }

    func reset() {
        phase = .setup
        currentRound = 0
        correctCount = 0
        falsePositives = 0
        misses = 0
        responseTimes = []
        lastAnswerCorrect = nil
        previousSymbol = ""
        currentSymbol = ""
    }
}

// MARK: - View

struct SpeedMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Query private var users: [User]

    @State private var viewModel = SpeedMatchViewModel()
    @State private var showingPaywall = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.phase {
            case .setup:
                setupView
                    .transition(.opacity)
            case .answering, .showing, .feedback:
                gameView
                    .transition(.opacity)
            case .finished:
                resultsView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase == .finished)
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase == .setup)
        .sheet(isPresented: $showingPaywall) { PaywallView() }
        .navigationTitle("Speed Match")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("Speed Match")
                    .font(.title.weight(.bold))
                Text("Does this match the last one?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "eye", text: "Symbols appear one at a time")
                infoRow(icon: "checkmark.circle", text: "Tap YES if it matches the previous symbol")
                infoRow(icon: "xmark.circle", text: "Tap NO if it's different")
                infoRow(icon: "timer", text: "25 rounds — be fast and accurate")
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button {
                viewModel.startGame()
            } label: {
                Text("Start")
                    .accentButton()
            }
            .accessibilityHint("Starts the exercise")
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.sky)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Game

    private var gameView: some View {
        VStack(spacing: 24) {
            // Header: round counter + progress
            HStack {
                Text("Round \(viewModel.currentRound)")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)
                Spacer()
                Text("\(viewModel.currentRound) / \(viewModel.totalRounds)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ProgressView(value: Double(viewModel.currentRound), total: Double(viewModel.totalRounds))
                .tint(AppColors.accent)
                .padding(.horizontal)

            Spacer()

            // Current symbol — large and prominent
            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 180, height: 180)

                Image(systemName: viewModel.currentSymbol)
                    .font(.system(size: 80, weight: .medium))
                    .foregroundStyle(AppColors.accent)

                // Feedback overlay
                if viewModel.phase == .feedback, let correct = viewModel.lastAnswerCorrect {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(correct ? AppColors.teal : AppColors.coral)
                        .transition(.scale.combined(with: .opacity))
                        .offset(x: 50, y: -50)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.lastAnswerCorrect)

            Spacer()

            // YES / NO buttons
            if viewModel.currentRound > 1 {
                HStack(spacing: 16) {
                    Button {
                        viewModel.answer(yes: false)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                                .font(.title2.weight(.bold))
                            Text("NO")
                                .font(.headline.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.coral.opacity(0.20))
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.coral.opacity(0.15), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.coral.opacity(0.25), lineWidth: 1)
                        )
                        .foregroundStyle(AppColors.coral)
                    }
                    .disabled(viewModel.phase == .feedback)

                    Button {
                        viewModel.answer(yes: true)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.title2.weight(.bold))
                            Text("YES")
                                .font(.headline.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.teal.opacity(0.20))
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.teal.opacity(0.15), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.teal.opacity(0.25), lineWidth: 1)
                        )
                        .foregroundStyle(AppColors.teal)
                    }
                    .disabled(viewModel.phase == .feedback)
                }
                .padding(.horizontal)
            } else {
                // First card — no answer needed, auto-advance
                Text("Remember this symbol")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            if viewModel.currentRound < viewModel.totalRounds {
                                viewModel.showNextCard()
                            }
                        }
                    }
            }

            Spacer().frame(height: 16)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.square.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.sky, in: RoundedRectangle(cornerRadius: 14))
                    Text(viewModel.ratingText)
                        .font(.title2.weight(.bold))
                }
                .padding(.top, 20)

                VStack(spacing: 12) {
                    resultRow(label: "Accuracy", value: viewModel.accuracy.percentString)
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Correct", value: "\(viewModel.correctCount) / \(viewModel.totalRounds)")
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Avg Response", value: "\(viewModel.averageResponseMs) ms")
                        .accessibilityElement(children: .combine)

                    Divider()

                    resultRow(label: "False Positives", value: "\(viewModel.falsePositives)")
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Misses", value: "\(viewModel.misses)")
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Time", value: viewModel.durationSeconds.durationString)
                        .accessibilityElement(children: .combine)
                }
                .glowingCard(color: AppColors.accent, intensity: 0.08)
                .padding(.horizontal)

                LeaderboardRankCard(
                    exerciseType: .speedMatch,
                    userScore: Int(viewModel.accuracy * 100),
                    userName: user?.username ?? "You",
                    userLevel: user?.level ?? 1,
                    isPro: isProUser,
                    onUpgradeTap: { showingPaywall = true }
                )
                .padding(.horizontal)

                VStack(spacing: 12) {
                    Button {
                        viewModel.startGame()
                    } label: {
                        Text("Play Again")
                            .accentButton()
                    }

                    Button {
                        saveExercise()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }

    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Save

    private func saveExercise() {
        paywallTrigger.recordExerciseCompleted()
        trainingManager.addTrainingTime(viewModel.durationSeconds)

        AdaptiveDifficultyEngine.shared.recordBlock(domain: .speedMatch, correct: viewModel.correctCount, total: viewModel.totalRounds)
        PersonalBestTracker.shared.record(score: Int(viewModel.accuracy * 100), for: .speedMatch)

        let exercise = Exercise(
            type: .speedMatch,
            difficulty: 1,
            score: viewModel.score,
            durationSeconds: viewModel.durationSeconds
        )
        modelContext.insert(exercise)

        let descriptor = FetchDescriptor<DailySession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allSessions = (try? modelContext.fetch(descriptor)) ?? []
        let session: DailySession
        if let existing = allSessions.first(where: { Calendar.current.isDateInToday($0.date) }) {
            session = existing
        } else {
            session = DailySession()
            modelContext.insert(session)
        }
        session.addExercise(exercise)
        user?.updateStreak()
        NotificationService.shared.cancelStreakRisk()
        if let streak = user?.currentStreak {
            NotificationService.shared.scheduleMilestone(streak: streak)
        }

        if let user {
            _ = ContentView.awardXP(
                user: user,
                score: viewModel.score,
                difficulty: 1,
                achievementService: achievementService,
                modelContext: modelContext
            )
        }
    }
}
