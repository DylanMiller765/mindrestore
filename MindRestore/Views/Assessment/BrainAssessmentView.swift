import SwiftUI
import SwiftData

struct BrainAssessmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]
    @State private var viewModel = BrainAssessmentViewModel()
    @State private var hasSaved = false

    private var previousScore: BrainScoreResult? { brainScores.first }

    private var assessmentProgress: Double {
        switch viewModel.phase {
        case .intro: return 0
        case .digitInstructions, .digitShow, .digitInput: return 0.1 + Double(viewModel.digitRound) * 0.05
        case .reactionInstructions, .reactionWait, .reactionGo, .reactionTooEarly, .reactionResult:
            return 0.4 + Double(viewModel.reactionRound) * 0.05
        case .visualInstructions, .visualShow, .visualInput: return 0.7 + Double(viewModel.visualRound) * 0.04
        case .calculating, .results: return 1.0
        }
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            switch viewModel.phase {
            case .intro:
                introView
            case .digitInstructions:
                instructionCard(icon: "number.circle.fill", title: "Digit Span", subtitle: "Remember the numbers in order", color: .blue)
            case .digitShow:
                digitShowView
            case .digitInput:
                digitInputView
            case .reactionInstructions:
                instructionCard(icon: "bolt.fill", title: "Reaction Time", subtitle: "Tap as fast as you can when the screen turns green", color: .yellow)
            case .reactionWait:
                reactionWaitView
            case .reactionGo:
                reactionGoView
            case .reactionTooEarly:
                reactionTooEarlyView
            case .reactionResult:
                reactionResultView
            case .visualInstructions:
                instructionCard(icon: "square.grid.3x3.fill", title: "Visual Memory", subtitle: "Remember which squares light up", color: .purple)
            case .visualShow:
                visualGridView(interactive: false)
            case .visualInput:
                visualGridView(interactive: true)
            case .calculating:
                calculatingView
            case .results:
                ScoreRevealView(viewModel: viewModel, previousScore: previousScore) {
                    // Trigger paywall AFTER the reveal is done, not before
                    let isProUser = storeService.isProUser || (users.first?.isProUser ?? false)
                    paywallTrigger.triggerAfterAssessment(isProUser: isProUser)
                    dismiss()
                }
                .onAppear {
                    saveResult()
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if viewModel.phase != .intro && viewModel.phase != .results && viewModel.phase != .calculating {
                VStack(spacing: 4) {
                    HStack(spacing: 16) {
                        assessmentStepLabel("MEM", active: assessmentProgress >= 0.1 && assessmentProgress < 0.4)
                        assessmentStepLabel("SPD", active: assessmentProgress >= 0.4 && assessmentProgress < 0.7)
                        assessmentStepLabel("VIS", active: assessmentProgress >= 0.7)
                    }
                    .font(.caption2.weight(.bold))

                    ProgressView(value: assessmentProgress)
                        .tint(AppColors.accent)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
    }

    private func assessmentStepLabel(_ text: String, active: Bool) -> some View {
        Text(text)
            .foregroundStyle(active ? AppColors.accent : .secondary)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(text == "MEM" ? "Memory" : text == "SPD" ? "Speed" : "Visual") phase\(active ? ", active" : "")")
    }

    private var backgroundColor: Color {
        switch viewModel.phase {
        case .reactionWait: return Color(red: 0.8, green: 0.2, blue: 0.2)
        case .reactionGo: return Color(red: 0.2, green: 0.8, blue: 0.2)
        case .reactionTooEarly: return Color(red: 0.9, green: 0.5, blue: 0.1)
        default: return AppColors.pageBg
        }
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(AppColors.accent.opacity(0.04))
                    .frame(width: 180, height: 180)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColors.accent)
                    .symbolEffect(.pulse)
            }

            VStack(spacing: 12) {
                Text("Brain Assessment")
                    .font(.largeTitle.bold())
                Text("3 quick tests to measure your\ncognitive performance")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                testPreviewRow(icon: "number.circle.fill", title: "Digit Span", subtitle: "Number memory", color: .blue)
                testPreviewRow(icon: "bolt.fill", title: "Reaction Time", subtitle: "Processing speed", color: .orange)
                testPreviewRow(icon: "square.grid.3x3.fill", title: "Visual Memory", subtitle: "Pattern recall", color: AppColors.violet)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardSurface)
            )
            .padding(.horizontal, 24)

            Text("Takes about 2 minutes")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                viewModel.start()
            } label: {
                Text("Begin Assessment")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
    }

    private func testPreviewRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ColoredIconBadge(icon: icon, color: color, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Instruction Card

    private func instructionCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(color)

            Text(title)
                .font(.title.bold())

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            ProgressView()
                .tint(color)
                .padding(.bottom, 40)
        }
        .transition(.opacity)
    }

    // MARK: - Digit Span

    private var digitShowView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Round \(viewModel.digitRound + 1)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            if let digit = viewModel.currentDisplayDigit {
                Text("\(digit)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                    .transition(.scale.combined(with: .opacity))
                    .id("digit_\(viewModel.displayDigitIndex)")
                    .accessibilityLabel("Remember this number: \(digit)")
            }

            Text("\(viewModel.currentDigits.count) digits")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.displayDigitIndex)
    }

    private var digitInputView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("What were the numbers?")
                .font(.title2.weight(.semibold))

            Text("\(viewModel.currentDigits.count) digits in order")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Type the numbers...", text: $viewModel.digitInput)
                .keyboardType(.numberPad)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding()
                .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 40)

            Spacer()

            Button {
                viewModel.submitDigitAnswer()
            } label: {
                Text("Submit")
                    .gradientButton()
            }
            .accessibilityHint("Submits your digit recall answer")
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Reaction Time

    private var reactionWaitView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Wait...")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
            Text("Round \(viewModel.reactionRound + 1) of 5")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.tapReaction()
        }
    }

    private var reactionGoView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("TAP!")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.tapReaction()
        }
    }

    private var reactionTooEarlyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)
            Text("Too early!")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Wait for the green screen")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }

    private var reactionResultView: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("\(viewModel.lastReactionMs)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(reactionMsColor)
                .contentTransition(.numericText(value: Double(viewModel.lastReactionMs)))

            Text("ms")
                .font(.title2.weight(.bold))
                .foregroundStyle(reactionMsColor.opacity(0.7))

            Text(reactionMsLabel)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Text("Round \(viewModel.reactionRound) of 5")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()
        }
    }

    private var reactionMsColor: Color {
        let ms = viewModel.lastReactionMs
        if ms < 200 { return .green }
        if ms < 300 { return AppColors.accent }
        if ms < 400 { return .yellow }
        return AppColors.coral
    }

    private var reactionMsLabel: String {
        let ms = viewModel.lastReactionMs
        if ms < 150 { return "Insane!" }
        if ms < 200 { return "Lightning fast!" }
        if ms < 250 { return "Great reflexes!" }
        if ms < 300 { return "Nice!" }
        if ms < 400 { return "Good" }
        return "Keep trying!"
    }

    // MARK: - Visual Memory

    private func visualGridView(interactive: Bool) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(interactive ? "Tap the squares that were highlighted" : "Remember this pattern")
                .font(.headline)

            Text(interactive ? "Select \(viewModel.highlightedCells.count) squares" : "Round \(viewModel.visualRound + 1) · \(viewModel.highlightedCells.count) squares")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: viewModel.gridSize), spacing: 8) {
                ForEach(0..<(viewModel.gridSize * viewModel.gridSize), id: \.self) { index in
                    let isHighlighted = viewModel.highlightedCells.contains(index)
                    let isSelected = viewModel.selectedCells.contains(index)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(cellColor(isHighlighted: isHighlighted, isSelected: isSelected, interactive: interactive))
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            if interactive {
                                viewModel.toggleCell(index)
                            }
                        }
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                        .accessibilityLabel(interactive ? "Grid cell \(index + 1)\(isSelected ? ", selected" : "")" : "Grid cell \(index + 1)\(isHighlighted ? ", highlighted" : "")")
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            if interactive {
                Button {
                    viewModel.submitVisualAnswer()
                } label: {
                    Text("Submit")
                        .gradientButton()
                }
                .accessibilityHint("Submits your visual memory answer")
                .padding(.horizontal, 32)
                .disabled(viewModel.selectedCells.count != viewModel.highlightedCells.count)
                .opacity(viewModel.selectedCells.count == viewModel.highlightedCells.count ? 1 : 0.4)
            }
        }
        .padding(.bottom, 16)
    }

    private func cellColor(isHighlighted: Bool, isSelected: Bool, interactive: Bool) -> Color {
        if !interactive && isHighlighted {
            return AppColors.accent
        }
        if interactive && isSelected {
            return AppColors.accent
        }
        return Color.gray.opacity(0.12)
    }

    // MARK: - Calculating

    private var calculatingView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.accent)
                .symbolEffect(.pulse)

            Text("Analyzing your results...")
                .font(.title3.weight(.semibold))

            ProgressView()
                .tint(AppColors.accent)

            Spacer()
        }
    }

    // MARK: - Save

    private func saveResult() {
        guard !hasSaved else { return }
        hasSaved = true

        let result = viewModel.createResult()
        modelContext.insert(result)

        // Also save as an exercise for streak/session tracking
        let exercise = Exercise(
            type: .activeRecall,
            difficulty: 3,
            score: Double(viewModel.brainScore) / 1000.0,
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

        let users = (try? modelContext.fetch(FetchDescriptor<User>())) ?? []
        let currentUser = users.first
        currentUser?.updateStreak()
        NotificationService.shared.cancelStreakRisk()
        if let streak = currentUser?.currentStreak {
            NotificationService.shared.scheduleMilestone(streak: streak)
        }

        if let currentUser {
            _ = ContentView.awardXP(
                user: currentUser,
                score: Double(viewModel.brainScore) / 1000.0,
                difficulty: 3,
                achievementService: achievementService,
                modelContext: modelContext
            )
        }

        // Schedule retake reminder 7 days from now
        NotificationService.shared.scheduleRetakeReminder(lastAssessmentDate: Date())

        // Paywall trigger moved to ScoreRevealView onDone — fires after the reveal, not before
    }

    @Query private var users: [User]
}
