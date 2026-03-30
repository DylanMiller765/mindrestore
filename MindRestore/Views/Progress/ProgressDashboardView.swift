import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Environment(StoreService.self) private var storeService
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]
    @Query private var achievements: [Achievement]

    @State private var viewModel = ProgressViewModel()
    @State private var showingPaywall = false
    @Query(sort: \Exercise.completedAt, order: .reverse) private var exercises: [Exercise]

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }

    /// The 10 games available on the Train tab
    private static let availableGames: [ExerciseType] = [
        .reactionTime, .colorMatch, .speedMatch, .visualMemory,
        .sequentialMemory, .mathSpeed, .dualNBack, .chunkingTraining
        // v1.2: uncomment when ready to ship new games
        // , .wordScramble, .memoryChain
    ]

    private var triedExerciseTypes: Set<ExerciseType> {
        Set(exercises.map(\.type)).intersection(Self.availableGames)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if sessions.isEmpty && brainScores.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 24) {
                        // 1. Brain Score Overview (hero)
                        if let latestScore = brainScores.first {
                            brainScoreOverview(latestScore)
                        }

                        // 2. Brain Score History Chart
                        if brainScores.count >= 2 {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Score History")
                                BrainScoreChart(scores: brainScores, height: 200, showHeader: false)
                            }
                            .appCard()
                        }

                        // 3. This Week Summary
                        thisWeekSummary

                        // 4. Personal Records
                        personalRecordsSection

                        // 5. Training Consistency (heatmap only)
                        calendarHeatmap

                        // 6. Achievements summary
                        achievementsSummary

                        // 7. Pro Analytics or Upsell
                        if isProUser {
                            exerciseScoreTrends
                            scoreChart
                        } else {
                            proUpsell
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .responsiveContent()
                    .frame(maxWidth: .infinity)
                }
            }
            .pageBackground()
            .navigationTitle("Insights")
            .onAppear { viewModel.refresh(sessions: sessions) }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 40)

            Image("mascot-bored")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 160)

            Text("No Progress Yet")
                .font(.title3.weight(.semibold))

            Text("Complete your first exercise to see your progress here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
                .frame(height: 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .appCard()
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Brain Score Overview (Hero)

    private func brainScoreOverview(_ score: BrainScoreResult) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brain Score")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)
                    Text("\(score.brainScore)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.accent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Brain Age")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)
                    Text("\(score.brainAge)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(score.brainAge <= (user?.userAge ?? 25) ? AppColors.teal : AppColors.coral)
                }
            }

            // Domain bars
            VStack(spacing: 8) {
                domainBar(label: "Memory", score: score.digitSpanScore, color: AppColors.violet)
                domainBar(label: "Speed", score: score.reactionTimeScore, color: AppColors.coral)
                domainBar(label: "Visual", score: score.visualMemoryScore, color: AppColors.sky)
            }
        }
        .appCard()
    }

    private func domainBar(label: String, score: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * min(1, score / 100))
                }
            }
            .frame(height: 8)

            Text("\(Int(score))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - This Week Summary

    private var thisWeekSummary: some View {
        VStack(spacing: 14) {
            SectionHeader(title: "This Week")

            HStack(spacing: 12) {
                weekStat(value: "\(exercisesThisWeek)", label: "Games", icon: "gamecontroller.fill", color: AppColors.accent)
                weekStat(value: formatTrainingTime(minutesThisWeek), label: "Trained", icon: "clock.fill", color: AppColors.teal)
                weekStat(value: "\(user?.currentStreak ?? 0)", label: "Streak", icon: "flame.fill", color: AppColors.coral)
            }
        }
    }

    private func weekStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.12), lineWidth: 1))
    }

    private var exercisesThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return exercises.filter { $0.completedAt >= weekAgo }.count
    }

    private var minutesThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let seconds = exercises.filter { $0.completedAt >= weekAgo }.reduce(0) { $0 + $1.durationSeconds }
        return seconds / 60
    }

    private func formatTrainingTime(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    // MARK: - Calendar Heatmap

    private var calendarHeatmap: some View {
        HeatmapCalendarView(trainingDays: viewModel.trainingDays)
            .appCard()
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Personal Records")

            let records = Self.availableGames.compactMap { type -> (type: ExerciseType, best: Int)? in
                let best = PersonalBestTracker.shared.best(for: type)
                guard best > 0 else { return nil }
                return (type: type, best: best)
            }

            if records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.amber.opacity(0.4))
                    Text("No records yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Play some games to set your first records!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardSurface)
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                        HStack(spacing: 12) {
                            Image(systemName: record.type.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(exerciseColor(record.type), in: RoundedRectangle(cornerRadius: 8))

                            Text(record.type.displayName)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Text(personalBestDisplay(type: record.type, value: record.best))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(exerciseColor(record.type))

                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.amber)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)

                        if index < records.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardSurface)
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                }
            }
        }
    }

    private func personalBestDisplay(type: ExerciseType, value: Int) -> String {
        switch type {
        case .reactionTime: return "\(1000 - value)ms"
        case .dualNBack: return "N=\(value)"
        case .sequentialMemory: return "\(value) digits"
        case .visualMemory: return "Level \(value)"
        case .mathSpeed: return "\(value) solved"
        case .colorMatch, .speedMatch: return "\(value)%"
        case .chunkingTraining: return "\(value)"
        case .wordScramble: return "\(value)/10 words"
        case .memoryChain: return "Chain \(value)"
        default: return "\(value)"
        }
    }

    private func exerciseColor(_ type: ExerciseType) -> Color {
        switch type {
        case .reactionTime: return AppColors.coral
        case .colorMatch: return AppColors.violet
        case .speedMatch: return AppColors.sky
        case .visualMemory: return AppColors.indigo
        case .sequentialMemory: return AppColors.teal
        case .mathSpeed: return AppColors.amber
        case .dualNBack: return AppColors.sky
        case .chunkingTraining: return AppColors.teal
        case .wordScramble: return AppColors.rose
        case .memoryChain: return AppColors.mint
        default: return AppColors.accent
        }
    }

    // MARK: - Achievements Summary

    private var achievementsSummary: some View {
        NavigationLink {
            AchievementsView()
        } label: {
            HStack(spacing: 12) {
                ColoredIconBadge(icon: "medal.fill", color: AppColors.violet, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements")
                        .font(.subheadline.weight(.semibold))
                    Text("\(achievements.count) of \(AchievementType.allCases.count) unlocked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Mini progress
                Text("\(Int(Double(achievements.count) / Double(AchievementType.allCases.count) * 100))%")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.violet)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .appCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exercise Score Trends (Pro)

    private var exerciseScoreTrends: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Performance by Exercise")

            let recentExercises = exercises.prefix(100)
            let grouped = Dictionary(grouping: recentExercises) { $0.type }
            let matchedGames = Self.availableGames.filter { grouped[$0] != nil }

            if matchedGames.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.indigo.opacity(0.4))
                    Text("No performance data yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Complete some exercises to track your performance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardSurface)
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                }
            } else {

            VStack(spacing: 0) {
                ForEach(Array(matchedGames.enumerated()), id: \.element) { index, type in
                    let typeExercises = grouped[type]!.sorted(by: { $0.completedAt < $1.completedAt }).suffix(7)
                    let scores = Array(typeExercises.map(\.score))
                    let avg = scores.isEmpty ? 0.0 : scores.reduce(0, +) / Double(scores.count)
                    let trend = scores.count >= 2 ? (scores.last! - scores.first!) : 0.0

                    HStack(spacing: 12) {
                        Image(systemName: type.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(exerciseColor(type), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .font(.subheadline.weight(.medium))
                            Text("\(scores.count) session\(scores.count == 1 ? "" : "s")")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        // Mini sparkline
                        if scores.count >= 2 {
                            miniSparkline(scores: scores, color: exerciseColor(type))
                                .frame(width: 50, height: 20)
                        }

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(avg.percentString)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            if trend != 0 {
                                Text("\(trend > 0 ? "+" : "")\(Int(trend * 100))%")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(trend > 0 ? Color.green : AppColors.coral)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)

                    if index < matchedGames.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardSurface)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            }

            } // else
        }
    }

    private func miniSparkline(scores: [Double], color: Color) -> some View {
        GeometryReader { geo in
            let maxVal = max(scores.max() ?? 1, 0.01)
            let minVal = scores.min() ?? 0
            let range = max(maxVal - minVal, 0.01)
            Path { path in
                for (index, score) in scores.enumerated() {
                    let x = geo.size.width * CGFloat(index) / CGFloat(max(scores.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((score - minVal) / range))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Score Chart (Pro)

    private var scoreChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Score Trends")

            if viewModel.weeklyScores.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.accent.opacity(0.4))
                    Text("No trends yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Complete a few sessions to see your progress over time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                Chart {
                    ForEach(viewModel.weeklyScores.indices, id: \.self) { index in
                        let item = viewModel.weeklyScores[index]
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("Score", item.score)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.accent.opacity(0.3), AppColors.accent.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Score", item.score)
                        )
                        .foregroundStyle(AppColors.accent)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Date", item.date),
                            y: .value("Score", item.score)
                        )
                        .foregroundStyle(AppColors.accent)
                        .symbolSize(30)
                    }
                }
                .chartYScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v.percentString)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .appCard()
    }

    // MARK: - Pro Upsell

    private var proUpsell: some View {
        Button {
            showingPaywall = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unlock Pro Analytics")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("See where you're improving")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }

                // What you get
                HStack(spacing: 16) {
                    proFeaturePill(icon: "chart.xyaxis.line", text: "Trends")
                    proFeaturePill(icon: "arrow.up.right", text: "+/- Stats")
                    proFeaturePill(icon: "sparkles", text: "Sparklines")
                }
            }
            .padding(16)
            .background(
                AppColors.premiumGradient,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }

    private func proFeaturePill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.15), in: Capsule())
    }
}
