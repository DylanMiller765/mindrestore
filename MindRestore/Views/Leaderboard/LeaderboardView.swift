import SwiftUI
import SwiftData

struct LeaderboardView: View {
    @Query private var users: [User]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]
    @Query(sort: \Exercise.completedAt, order: .reverse) private var exercises: [Exercise]
    @Environment(GameCenterService.self) private var gameCenterService
    @Environment(StoreService.self) private var storeService
    @Environment(PaywallTriggerService.self) private var paywallTrigger

    @State private var selectedCategory: LeaderboardCategory = .brainScore
    @State private var selectedFilter: LeaderboardTimeFilter = .allTime
    @State private var entries: [LeaderboardEntryData] = []
    @State private var isLoading = false
    @State private var hasLoaded = false

    private var user: User? { users.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Honesty label
                Text("See where you'd rank among typical players")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Category picker
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(LeaderboardCategory.allCases) { category in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = category
                                }
                                loadLeaderboard()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: category.icon)
                                        .font(.caption)
                                    Text(category.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background {
                                    if selectedCategory == category {
                                        Capsule().fill(AppColors.accentGradient)
                                    } else {
                                        Capsule().fill(AppColors.cardSurface)
                                            .overlay(
                                                Capsule().stroke(AppColors.cardBorder, lineWidth: 1)
                                            )
                                    }
                                }
                                .foregroundStyle(selectedCategory == category ? .white : .primary)
                            }
                            .accessibilityLabel("\(category.rawValue)\(selectedCategory == category ? ", selected" : "")")
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .padding(.vertical, 12)

                // Time filter
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(LeaderboardTimeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 12)
                .onChange(of: selectedFilter) {
                    loadLeaderboard()
                }

                if !storeService.isProUser {
                    proGateView
                } else if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    leaderboardList
                }
            }
            .pageBackground()
            .navigationTitle("Rankings")
            .toolbar {
                if gameCenterService.isAuthenticated {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            let leaderboardID: String
                            switch selectedCategory {
                            case .brainScore:
                                leaderboardID = GameCenterService.brainScoreLeaderboard
                            case .weeklyXP:
                                leaderboardID = GameCenterService.weeklyXPLeaderboard
                            case .streak:
                                leaderboardID = GameCenterService.longestStreakLeaderboard
                            case .reactionTime:
                                leaderboardID = GameCenterService.reactionTimeLeaderboard
                            case .colorMatch:
                                leaderboardID = GameCenterService.colorMatchLeaderboard
                            case .speedMatch:
                                leaderboardID = GameCenterService.speedMatchLeaderboard
                            case .visualMemory:
                                leaderboardID = GameCenterService.visualMemoryLeaderboard
                            case .numberMemory:
                                leaderboardID = GameCenterService.numberMemoryLeaderboard
                            case .mathSpeed:
                                leaderboardID = GameCenterService.mathSpeedLeaderboard
                            case .dualNBack:
                                leaderboardID = GameCenterService.dualNBackLeaderboard
                            }
                            gameCenterService.showLeaderboard(leaderboardID: leaderboardID)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "gamecontroller.fill")
                                Text("Game Center")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                }
            }
            .onAppear {
                guard !hasLoaded else { return }
                loadLeaderboard()
            }
        }
    }

    // MARK: - Leaderboard List

    private var leaderboardList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Top 3 podium
                if entries.count >= 3 {
                    podiumView
                        .padding(.bottom, 16)
                }

                // Current user position
                if let userEntry = entries.first(where: { $0.isCurrentUser }) {
                    yourRankCard(userEntry)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }

                // Full list
                LazyVStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        leaderboardRow(entry, index: index)
                    }
                }
                .appCard(padding: 0)
                .padding(.horizontal)
                .padding(.bottom, 16)

                // Coming Soon card
                comingSoonCard
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Coming Soon Card

    private var comingSoonCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.violet.opacity(0.10))
                    .frame(width: 80, height: 80)
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.violet)
            }

            Text("1v1 Challenges Coming Soon")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("Challenge friends head-to-head and compete in real-time brain battles.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.violet.opacity(0.7))
                Text("Connected to Game Center")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .glowingCard(color: AppColors.violet, intensity: 0.15)
    }

    // MARK: - Pro Gate

    private var proGateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Mini podium illustration with trophy
            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppColors.violet)

                HStack(alignment: .bottom, spacing: 6) {
                    // 2nd place bar
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color(red: 0.75, green: 0.75, blue: 0.78))
                            .frame(width: 12, height: 12)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.75, green: 0.75, blue: 0.78).opacity(0.3))
                            .frame(width: 24, height: 32)
                    }
                    .frame(width: 28)
                    // 1st place bar
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.84, blue: 0.0))
                            .frame(width: 14, height: 14)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3))
                            .frame(width: 28, height: 44)
                    }
                    .frame(width: 28)
                    // 3rd place bar
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color(red: 0.80, green: 0.50, blue: 0.20))
                            .frame(width: 10, height: 10)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.80, green: 0.50, blue: 0.20).opacity(0.3))
                            .frame(width: 20, height: 24)
                    }
                    .frame(width: 28)
                }
            }

            VStack(spacing: 8) {
                Text("Compete with Pro")
                    .font(.title2.weight(.bold))
                Text("Unlock leaderboards to see how you rank\nagainst other players worldwide.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                paywallTrigger.triggerLeaderboard(isProUser: false)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("Unlock Leaderboards")
                        .font(.headline.weight(.bold))
                }
                .gradientButton(AppColors.premiumGradient)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Podium

    private var podiumView: some View {
        VStack(spacing: 0) {
            // Player info row (floats above podium blocks)
            if entries.count >= 3 {
                HStack(alignment: .bottom, spacing: 8) {
                    // 2nd place
                    podiumPlayer(entries[1], medal: "2", color: medalColor("2"))
                        .padding(.bottom, 8)
                    // 1st place (taller)
                    podiumPlayer(entries[0], medal: "1", color: medalColor("1"))
                        .padding(.bottom, 30)
                    // 3rd place
                    podiumPlayer(entries[2], medal: "3", color: medalColor("3"))
                        .padding(.bottom, 0)
                }

                // Podium blocks
                HStack(alignment: .bottom, spacing: 4) {
                    // 2nd place block
                    podiumBlock(rank: "2", height: 56, color: medalColor("2"))
                    // 1st place block
                    podiumBlock(rank: "1", height: 80, color: medalColor("1"))
                    // 3rd place block
                    podiumBlock(rank: "3", height: 40, color: medalColor("3"))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private func podiumPlayer(_ entry: LeaderboardEntryData, medal: String, color: Color) -> some View {
        VStack(spacing: 4) {
            // Crown for 1st place
            if medal == "1" {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.5), radius: 4)
            }

            // Score (the hero number)
            Text(formatScore(entry.score))
                .font(.system(size: medal == "1" ? 24 : 18, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(color)

            // Username
            Text(entry.username)
                .font(.system(size: medal == "1" ? 13 : 11, weight: .bold))
                .lineLimit(1)

            // Level
            Text("Lv \(entry.level)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func podiumBlock(rank: String, height: CGFloat, color: Color) -> some View {
        ZStack {
            // Block shape
            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.25), color.opacity(0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 10)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )

            // Rank number
            Text(rank)
                .font(.system(size: rank == "1" ? 28 : 22, weight: .black, design: .rounded))
                .foregroundStyle(color.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    // MARK: - Level Badge

    private func levelBadge(level: Int, color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            Circle()
                .stroke(color.opacity(0.4), lineWidth: 1.5)
                .frame(width: size, height: size)
            Text("Lv\(level)")
                .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private func medalColor(_ medal: String) -> Color {
        switch medal {
        case "1": return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "2": return Color(red: 0.75, green: 0.75, blue: 0.78)
        case "3": return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return .secondary
        }
    }

    // MARK: - Your Rank Card

    private func yourRankCard(_ entry: LeaderboardEntryData) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 56, height: 56)
                Text("#\(entry.rank)")
                    .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR RANK")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text(entry.username.isEmpty ? "You" : entry.username)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatScore(entry.score))
                    .font(.headline.weight(.bold).monospacedDigit())
                Text("Lvl \(entry.level)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardSurface)
                .shadow(color: AppColors.accent.opacity(0.10), radius: 8, y: 2)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.accent.opacity(0.15), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your rank: number \(entry.rank), \(entry.username.isEmpty ? "You" : entry.username), score \(formatScore(entry.score)), level \(entry.level)")
    }

    // MARK: - Row

    private func leaderboardRow(_ entry: LeaderboardEntryData, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(entry.rank <= 3 ? medalColor("\(entry.rank)") : .secondary)
                .frame(width: 30, alignment: .center)

            // Level badge instead of emoji avatar
            levelBadge(
                level: entry.level,
                color: entry.rank <= 3 ? medalColor("\(entry.rank)") : AppColors.textTertiary,
                size: 36
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.username)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(entry.isCurrentUser ? AppColors.accent : .primary)
                Text("Lvl \(entry.level)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatScore(entry.score))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(entry.isCurrentUser ? AppColors.accent : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            if entry.isCurrentUser {
                // Accent left border for current user
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.accent)
                        .frame(width: 3)
                    Spacer()
                }
                .background(AppColors.accent.opacity(0.06))
            } else if index % 2 == 0 {
                // Alternating row background
                AppColors.pageBg.opacity(0.5)
            }
        }
        .overlay(alignment: .bottom) {
            if entry.rank < entries.count {
                Divider().padding(.leading, 56)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.username), level \(entry.level), score \(formatScore(entry.score))\(entry.isCurrentUser ? ", you" : "")")
    }

    // MARK: - Helpers

    private func formatScore(_ score: Int) -> String {
        switch selectedCategory {
        case .streak: return "\(score)d"
        case .reactionTime: return "\(score)ms"
        case .colorMatch, .speedMatch: return "\(score)%"
        case .visualMemory, .dualNBack: return "Lvl \(score)"
        case .numberMemory: return "\(score) digits"
        default:
            if score >= 1000 {
                return String(format: "%.1fk", Double(score) / 1000.0)
            }
            return "\(score)"
        }
    }

    private func exerciseType(for category: LeaderboardCategory) -> ExerciseType? {
        switch category {
        case .reactionTime: return .reactionTime
        case .colorMatch: return .colorMatch
        case .speedMatch: return .speedMatch
        case .visualMemory: return .visualMemory
        case .numberMemory: return .sequentialMemory
        case .mathSpeed: return .mathSpeed
        case .dualNBack: return .dualNBack
        default: return nil
        }
    }

    private func bestScore(for category: LeaderboardCategory) -> Int {
        guard let type = exerciseType(for: category) else { return 0 }
        let matching = exercises.filter { $0.type == type }
        guard let best = matching.map(\.score).max() else { return 0 }

        // Convert 0.0-1.0 normalized score to leaderboard-appropriate value
        switch category {
        case .reactionTime:
            // Lower is better: score 1.0 → 150ms, score 0.0 → 400ms
            return max(100, Int(400.0 - best * 250.0))
        case .colorMatch, .speedMatch:
            return max(30, Int(best * 100.0))
        case .visualMemory:
            return max(1, Int(best * 10.0))
        case .numberMemory:
            return max(3, Int(4.0 + best * 8.0))
        case .mathSpeed:
            return max(5, Int(best * 50.0))
        case .dualNBack:
            return max(1, Int(best * 8.0))
        default:
            return Int(best * 100.0)
        }
    }

    private func loadLeaderboard() {
        guard !isLoading else { return }
        isLoading = true
        hasLoaded = true

        // Capture all model values on the main actor BEFORE leaving.
        let userScore: Int
        switch selectedCategory {
        case .brainScore:
            userScore = brainScores.first?.brainScore ?? 0
        case .weeklyXP:
            userScore = user?.totalXP ?? 0
        case .streak:
            userScore = user?.longestStreak ?? 0
        case .reactionTime, .colorMatch, .speedMatch, .visualMemory, .numberMemory, .mathSpeed, .dualNBack:
            // Per-game scores — use best score from exercise history
            userScore = bestScore(for: selectedCategory)
        }

        let category = selectedCategory
        let filter = selectedFilter
        let userName = (user?.username.isEmpty == false ? user?.username : nil) ?? "You"
        let userLevel = user?.level ?? 1

        Task {
            let result = LeaderboardService.shared.generateLeaderboard(
                category: category,
                filter: filter,
                userScore: userScore,
                userName: userName,
                userLevel: userLevel
            )
            entries = result
            isLoading = false
        }
    }
}
