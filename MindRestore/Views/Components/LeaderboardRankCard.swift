import SwiftUI

/// Shows the user's leaderboard rank after completing an exercise.
/// Pro users see their exact rank + nearby competitors.
/// Free users see a blurred tease with upgrade CTA.
struct LeaderboardRankCard: View {
    let exerciseType: ExerciseType?  // nil for brain score
    let userScore: Int
    let userName: String
    let userLevel: Int
    let isPro: Bool
    var onUpgradeTap: (() -> Void)?

    @State private var entries: [LeaderboardEntryData] = []
    @State private var userRank: Int = 0
    @State private var totalPlayers: Int = 0
    @State private var animateIn = false

    private var leaderboardCategory: LeaderboardCategory {
        guard let type = exerciseType else { return .brainScore }
        switch type {
        case .reactionTime: return .reactionTime
        case .colorMatch: return .colorMatch
        case .speedMatch: return .speedMatch
        case .visualMemory: return .visualMemory
        case .sequentialMemory: return .numberMemory
        case .mathSpeed: return .mathSpeed
        case .dualNBack: return .dualNBack
        default: return .brainScore
        }
    }

    private var accentColor: Color {
        guard let type = exerciseType else { return AppColors.accent }
        switch type {
        case .reactionTime: return AppColors.coral
        case .colorMatch: return AppColors.violet
        case .speedMatch: return AppColors.sky
        case .visualMemory: return AppColors.indigo
        case .sequentialMemory: return AppColors.teal
        case .mathSpeed: return AppColors.amber
        case .dualNBack: return AppColors.sky
        case .chunkingTraining: return AppColors.rose
        default: return AppColors.accent
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isPro {
                proRankView
            } else {
                freeTeaseView
            }
        }
        .appCard(padding: 0)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isPro ? accentColor.opacity(0.2) : AppColors.amber.opacity(0.3), lineWidth: 1)
        )
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 12)
        .onAppear {
            loadRank()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                animateIn = true
            }
        }
    }

    // MARK: - Pro User: Full Rank View

    private var proRankView: some View {
        VStack(spacing: 0) {
            // Header + Rank in one row
            HStack(spacing: 12) {
                // Rank number
                VStack(spacing: 1) {
                    Text("#\(userRank)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(accentColor)
                    Text(percentileText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(width: 64)

                // Rank bar + labels
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(accentColor)
                        Text("LEADERBOARD")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppColors.textTertiary)
                            .tracking(1.0)
                        Spacer()
                        Text("\(totalPlayers) players")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    rankBar
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Nearby competitors
            if nearbyEntries.count > 1 {
                Rectangle().fill(AppColors.cardBorder).frame(height: 1)

                VStack(spacing: 0) {
                    ForEach(nearbyEntries) { entry in
                        nearbyRow(entry)
                        if entry.id != nearbyEntries.last?.id {
                            Rectangle().fill(AppColors.cardBorder).frame(height: 0.5)
                                .padding(.leading, 42)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Free User: Blurred Tease

    private var freeTeaseView: some View {
        HStack(spacing: 12) {
            // Blurred rank
            ZStack {
                Text("#\(userRank)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(accentColor)
                    .blur(radius: 6)
                    .allowsHitTesting(false)
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.amber)
            }
            .frame(width: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("You placed \(percentileBracket)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Button {
                    onUpgradeTap?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("See Your Exact Rank")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppColors.amber)
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Subviews

    private var rankBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let position = totalPlayers > 1
                ? CGFloat(userRank - 1) / CGFloat(totalPlayers - 1)
                : 0.5

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(AppColors.cardBorder)
                    .frame(height: 4)

                // Filled portion
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, width * (1 - position)), height: 4)

                // User marker
                Circle()
                    .fill(accentColor)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .shadow(color: accentColor.opacity(0.3), radius: 2)
                    .offset(x: width * position - 5)
            }
        }
        .frame(height: 10)
    }

    private func nearbyRow(_ entry: LeaderboardEntryData) -> some View {
        HStack(spacing: 8) {
            Text("#\(entry.rank)")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(entry.isCurrentUser ? accentColor : AppColors.textTertiary)
                .frame(width: 28, alignment: .trailing)

            Text(entry.username)
                .font(.system(size: 12, weight: entry.isCurrentUser ? .bold : .medium))
                .foregroundStyle(entry.isCurrentUser ? AppColors.textPrimary : AppColors.textSecondary)
                .lineLimit(1)

            Spacer()

            Text("\(entry.score)")
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(entry.isCurrentUser ? accentColor : AppColors.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(entry.isCurrentUser ? accentColor.opacity(0.06) : .clear)
    }

    // MARK: - Data

    private var percentileText: String {
        guard totalPlayers > 0 else { return "" }
        let percentile = Int((1.0 - Double(userRank - 1) / Double(totalPlayers)) * 100)
        return "Top \(max(1, percentile))%"
    }

    private var percentileBracket: String {
        guard totalPlayers > 0 else { return "in the top half" }
        let percentile = (1.0 - Double(userRank - 1) / Double(totalPlayers)) * 100
        if percentile >= 90 { return "in the Top 10%" }
        if percentile >= 75 { return "in the Top 25%" }
        if percentile >= 50 { return "in the Top 50%" }
        return "in the Top 75%"
    }

    private var nearbyEntries: [LeaderboardEntryData] {
        guard let userIndex = entries.firstIndex(where: { $0.isCurrentUser }) else { return [] }
        let start = max(0, userIndex - 1)
        let end = min(entries.count - 1, userIndex + 1)
        return Array(entries[start...end])
    }

    private func loadRank() {
        let leaderboard = LeaderboardService.shared.generateLeaderboard(
            category: leaderboardCategory,
            filter: .allTime,
            userScore: userScore,
            userName: userName,
            userLevel: userLevel
        )
        entries = leaderboard
        totalPlayers = leaderboard.count
        if let userEntry = leaderboard.first(where: { $0.isCurrentUser }) {
            userRank = userEntry.rank
        }
    }
}

// MARK: - Preview

#Preview("Pro User") {
    LeaderboardRankCard(
        exerciseType: .reactionTime,
        userScore: 245,
        userName: "You",
        userLevel: 5,
        isPro: true
    )
    .padding()
}

#Preview("Free User") {
    LeaderboardRankCard(
        exerciseType: .reactionTime,
        userScore: 245,
        userName: "You",
        userLevel: 5,
        isPro: false,
        onUpgradeTap: {}
    )
    .padding()
}
