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

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        NavigationStack {
            ScrollView {
                if sessions.isEmpty && brainScores.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 24) {
                        if let latestScore = brainScores.first {
                            brainScoreProgressCard(latestScore)
                        }

                        // Brain Score History Chart
                        if brainScores.count >= 2 {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Brain Score History")
                                BrainScoreChart(scores: brainScores, height: 200, showHeader: false)
                            }
                            .appCard()
                        }

                        // Level & XP Card
                        if let user {
                            levelProgressCard(user)
                        }

                        streakSection
                        calendarHeatmap
                        basicStats

                        // Achievements summary
                        achievementsSummary

                        if isProUser {
                            scoreChart
                            memoryScoreCard
                        } else {
                            proUpsell
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
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

            // Mini illustration: faded placeholder chart bars
            HStack(alignment: .bottom, spacing: 6) {
                ForEach([0.3, 0.5, 0.25, 0.65, 0.4, 0.55, 0.35], id: \.self) { height in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.cardBorder.opacity(0.5))
                        .frame(width: 18, height: 60 * height)
                }
            }
            .frame(height: 60)
            .padding(.bottom, 4)

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

    // MARK: - Brain Score Progress Card

    private func brainScoreProgressCard(_ score: BrainScoreResult) -> some View {
        VStack(spacing: 16) {
            // Top row: ring on left, stats on right
            HStack(spacing: 16) {
                BrainScoreRing(score: score.brainScore, maxScore: 1000, size: 100, lineWidth: 10)

                VStack(alignment: .leading, spacing: 10) {
                    // Brain type badge
                    HStack(spacing: 5) {
                        Image(systemName: score.brainType.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(score.brainType.displayName)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.accent.opacity(0.12))
                    )

                    // Stats row
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Brain Age")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppColors.textTertiary)
                            Text("\(score.brainAge)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Percentile")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppColors.textTertiary)
                            Text("Top \(100 - score.percentile)%")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            // Domain breakdown bars
            VStack(spacing: 8) {
                Divider()
                    .padding(.bottom, 4)

                domainBar(label: "MEM", value: score.digitSpanScore, color: AppColors.violet, icon: "brain.head.profile")
                domainBar(label: "SPD", value: score.reactionTimeScore, color: AppColors.coral, icon: "bolt.fill")
                domainBar(label: "VIS", value: score.visualMemoryScore, color: AppColors.sky, icon: "eye.fill")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Brain Score \(score.brainScore) out of 1000, \(score.brainType.displayName), brain age \(score.brainAge), top \(100 - score.percentile) percent")
        .heroCard(color: AppColors.accent)
    }

    private func domainBar(label: String, value: Double, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.12))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * min(value / 100.0, 1.0)))
                }
            }
            .frame(height: 8)

            Text("\(Int(value))")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    // MARK: - Level Progress Card

    private func levelProgressCard(_ user: User) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 68, height: 68)
                Circle()
                    .fill(AppColors.violet)
                    .frame(width: 52, height: 52)

                Text("\(user.level)")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(user.levelName)
                    .font(.subheadline.weight(.bold))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.violet.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.violet)
                            .frame(width: max(4, geo.size.width * user.xpProgress), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(user.totalXP) XP")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.violet)
                    Spacer()
                    Text("\(Int(user.xpProgress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.violet)
                }
            }
        }
        .appCard()
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

    // MARK: - Streak Section

    private var streakSection: some View {
        HStack(spacing: 10) {
            streakMiniCard(
                value: "\(user?.currentStreak ?? 0)",
                label: "Current",
                icon: "flame.fill",
                color: AppColors.coral
            )
            streakMiniCard(
                value: "\(user?.longestStreak ?? 0)",
                label: "Longest",
                icon: "trophy.fill",
                color: AppColors.amber
            )
            streakMiniCard(
                value: "\(sessions.count)",
                label: "Sessions",
                icon: "brain.head.profile",
                color: AppColors.indigo
            )
        }
    }

    private func streakMiniCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardSurface)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 14)
                .fill(color)
                .frame(height: 3)
                .padding(.horizontal, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Calendar Heatmap

    private var calendarHeatmap: some View {
        HeatmapCalendarView(trainingDays: viewModel.trainingDays)
            .appCard()
    }

    // MARK: - Basic Stats (2x2 Grid)

    private var basicStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Overview")

            let totalExercises = sessions.reduce(0) { $0 + $1.exercisesCompleted.count }
            let totalTime = sessions.reduce(0) { $0 + $1.durationSeconds }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                statGridCard(icon: "list.bullet.rectangle", value: "\(sessions.count)", label: "Sessions", color: AppColors.teal)
                statGridCard(icon: "figure.mind.and.body", value: "\(totalExercises)", label: "Exercises", color: AppColors.indigo)
                statGridCard(icon: "clock.fill", value: totalTime.durationString, label: "Training Time", color: AppColors.violet)
                statGridCard(icon: "star.fill", value: "\(user?.totalXP ?? 0)", label: "Total XP", color: AppColors.amber)
            }
        }
    }

    private func statGridCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardSurface)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Score Chart (Pro)

    private var scoreChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Score Trends")

            if viewModel.weeklyScores.isEmpty {
                Text("Complete exercises to see trends")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

    // MARK: - Memory Score (Pro) — Angular Gradient Ring

    private var memoryScoreCard: some View {
        VStack(spacing: 14) {
            Text("MEMORY SCORE")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)

            ZStack {
                // Background ring
                Circle()
                    .stroke(AppColors.cardBorder, lineWidth: 10)
                    .frame(width: 120, height: 120)

                // Angular gradient ring
                Circle()
                    .trim(from: 0, to: min(viewModel.memoryScore, 1.0))
                    .stroke(
                        AngularGradient(
                            colors: [AppColors.teal, AppColors.accent, AppColors.violet, AppColors.accent],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: viewModel.memoryScore)

                Text(viewModel.memoryScore.percentString)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.accent)
            }

            Text("7-day weighted average")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .heroCard(color: AppColors.teal)
    }

    // MARK: - Pro Upsell

    private var proUpsell: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Detailed Analytics")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Score trends, memory score, and more")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
            .background(
                AppColors.premiumGradient,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }
}
