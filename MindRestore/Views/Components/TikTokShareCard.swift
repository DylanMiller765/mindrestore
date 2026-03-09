import SwiftUI

// MARK: - Brain Type Color Helper

private func brainTypeSwiftColor(_ type: BrainType) -> Color {
    switch type {
    case .lightningReflex: return AppColors.coral
    case .numberCruncher: return AppColors.indigo
    case .patternMaster: return AppColors.violet
    case .balancedBrain: return AppColors.mint
    }
}

// MARK: - Shared Components

private struct CardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.04, blue: 0.08),
                Color(red: 0.06, green: 0.08, blue: 0.18),
                Color(red: 0.04, green: 0.04, blue: 0.12)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct BrandingHeader: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.accent)
            Text("MEMORI")
                .font(.system(size: 12, weight: .heavy))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private struct BrandingFooter: View {
    var body: some View {
        Text("Test yours free \u{2014} Memori")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.35))
    }
}

private struct GlowingPill<Content: View>: View {
    let color: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(color.opacity(0.25))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.6), lineWidth: 1.5)
                    )
            )
    }
}

// MARK: - Score Bar

private struct ScoreBar: View {
    let label: String
    let value: Double
    let maxValue: Double
    let color: Color

    private var fraction: CGFloat {
        guard maxValue > 0 else { return 0 }
        return min(CGFloat(value / maxValue), 1.0)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 36, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.15))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 14)

            Text(String(format: "%.0f", value))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - 1. TikTokBrainScoreCard

struct TikTokBrainScoreCard: View {
    let brainScore: Int
    let brainAge: Int
    let brainType: BrainType
    let percentile: Int
    let digitScore: Double
    let reactionScore: Double
    let visualScore: Double

    var body: some View {
        ZStack {
            CardBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                BrandingHeader()

                Spacer().frame(height: 36)

                // Massive brain score
                Text("\(brainScore)")
                    .font(.system(size: 96, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.accent)

                Text("BRAIN SCORE")
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer().frame(height: 20)

                // Brain Age
                Text("BRAIN AGE: \(brainAge)")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer().frame(height: 20)

                // Brain type badge
                HStack(spacing: 8) {
                    Image(systemName: brainType.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(brainTypeSwiftColor(brainType))

                    Text(brainType.displayName.uppercased())
                        .font(.system(size: 16, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(brainTypeSwiftColor(brainType))
                }

                Text(brainType.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 4)

                Spacer().frame(height: 24)

                // Percentile pill
                GlowingPill(color: AppColors.accent) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Better than \(percentile)% of players")
                    }
                }

                Spacer().frame(height: 32)

                // Score breakdown bars
                VStack(spacing: 10) {
                    ScoreBar(label: "MEM", value: digitScore, maxValue: 100, color: AppColors.violet)
                    ScoreBar(label: "SPD", value: reactionScore, maxValue: 100, color: AppColors.coral)
                    ScoreBar(label: "VIS", value: visualScore, maxValue: 100, color: AppColors.sky)
                }
                .padding(.horizontal, 40)

                Spacer()

                // CTA
                Text("Can you beat me?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Spacer().frame(height: 12)

                BrandingFooter()

                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
}

// MARK: - 2. TikTokChallengeCard

struct TikTokChallengeCard: View {
    let challengerName: String
    let challengerScore: Int
    let challengeType: String

    var body: some View {
        ZStack {
            CardBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                BrandingHeader()

                Spacer().frame(height: 28)

                // CHALLENGE header
                Text("CHALLENGE")
                    .font(.system(size: 42, weight: .bold))
                    .tracking(6)
                    .foregroundStyle(AppColors.coral)

                Text(challengeType.uppercased())
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 6)

                Spacer().frame(height: 36)

                // Challenger
                VStack(spacing: 8) {
                    Text(challengerName.uppercased())
                        .font(.system(size: 20, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white)

                    Text("\(challengerScore)")
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.accent)
                }

                Spacer().frame(height: 20)

                // VS Badge
                ZStack {
                    Circle()
                        .fill(AppColors.coral)
                        .frame(width: 64, height: 64)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("VS")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 8)

                Spacer().frame(height: 20)

                // Mystery challenger slot
                VStack(spacing: 8) {
                    Text("???")
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.2))

                    Text("YOUR SCORE HERE")
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                        )
                )
                .padding(.horizontal, 50)

                Spacer()

                // CTA
                Text("Accept the Challenge")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        AppColors.coral,
                        in: Capsule()
                    )

                Spacer().frame(height: 16)

                BrandingFooter()

                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
    }
}

// MARK: - 3. TikTokDuelResultCard

struct TikTokDuelResultCard: View {
    let player1Name: String
    let player1Score: Int
    let player2Name: String
    let player2Score: Int
    let exerciseType: String

    private var player1Wins: Bool { player1Score >= player2Score }

    var body: some View {
        ZStack {
            CardBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                BrandingHeader()

                Spacer().frame(height: 24)

                // 1v1 DUEL header
                Text("1v1 DUEL")
                    .font(.system(size: 44, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(AppColors.violet)

                Text(exerciseType.uppercased())
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 6)

                Spacer().frame(height: 44)

                // Side by side comparison
                HStack(spacing: 0) {
                    // Player 1
                    playerColumn(
                        name: player1Name,
                        score: player1Score,
                        isWinner: player1Wins,
                        color: AppColors.accent
                    )

                    // VS divider
                    VStack(spacing: 8) {
                        Rectangle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 1.5, height: 40)

                        Text("VS")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.4))

                        Rectangle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 1.5, height: 40)
                    }
                    .frame(width: 50)

                    // Player 2
                    playerColumn(
                        name: player2Name,
                        score: player2Score,
                        isWinner: !player1Wins,
                        color: AppColors.coral
                    )
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 40)

                // Winner announcement
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))

                    Text("\(player1Wins ? player1Name : player2Name) wins!")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

                // Score difference
                let diff = abs(player1Score - player2Score)
                if diff > 0 {
                    Text("by \(diff) points")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 6)
                }

                Spacer()

                // CTA
                Text("Think you can do better?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Spacer().frame(height: 16)

                BrandingFooter()

                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
    }

    @ViewBuilder
    private func playerColumn(name: String, score: Int, isWinner: Bool, color: Color) -> some View {
        VStack(spacing: 12) {
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
            } else {
                Spacer().frame(height: 24)
            }

            // Avatar circle
            ZStack {
                Circle()
                    .fill(color.opacity(isWinner ? 0.25 : 0.1))
                    .frame(width: 72, height: 72)

                if isWinner {
                    Circle()
                        .stroke(color.opacity(0.6), lineWidth: 2.5)
                        .frame(width: 72, height: 72)
                }

                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(isWinner ? color : .white.opacity(0.5))
            }

            Text(name.uppercased())
                .font(.system(size: 13, weight: .heavy))
                .tracking(1)
                .foregroundStyle(isWinner ? .white : .white.opacity(0.5))
                .lineLimit(1)

            Text("\(score)")
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(
                    isWinner
                        ? AnyShapeStyle(color)
                        : AnyShapeStyle(.white.opacity(0.3))
                )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 4. ReactionTimeShareCard

struct ReactionTimeShareCard: View {
    let averageMs: Int
    let bestMs: Int
    let ratingText: String
    let roundTimes: [Int]

    private var ratingColor: Color {
        if averageMs < 200 { return Color.green }
        if averageMs < 250 { return AppColors.accent }
        if averageMs < 300 { return AppColors.sky }
        if averageMs < 350 { return AppColors.amber }
        return AppColors.coral
    }

    var body: some View {
        ZStack {
            CardBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                BrandingHeader()

                Spacer().frame(height: 28)

                // REACTION TIME header
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("REACTION TIME")
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(3)
                }
                .foregroundStyle(AppColors.coral)

                Spacer().frame(height: 32)

                // Big average time
                Text("\(averageMs)")
                    .font(.system(size: 96, weight: .bold, design: .monospaced))
                    .foregroundStyle(ratingColor)

                Text("MILLISECONDS")
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer().frame(height: 16)

                // Rating badge
                GlowingPill(color: ratingColor) {
                    Text(ratingText.uppercased())
                }

                Spacer().frame(height: 28)

                // Round breakdown
                HStack(spacing: 0) {
                    ForEach(Array(roundTimes.enumerated()), id: \.offset) { index, ms in
                        VStack(spacing: 6) {
                            Text("R\(index + 1)")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("\(ms)")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(ms == bestMs ? ratingColor : .white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 30)

                Spacer().frame(height: 16)

                // Best time highlight
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
                    Text("Best: \(bestMs)ms")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                // CTA
                Text("How fast are you?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Spacer().frame(height: 12)

                BrandingFooter()

                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
    }
}

// MARK: - Previews

#Preview("Brain Score Card") {
    TikTokBrainScoreCard(
        brainScore: 87,
        brainAge: 23,
        brainType: .lightningReflex,
        percentile: 94,
        digitScore: 82,
        reactionScore: 95,
        visualScore: 78
    )
}

#Preview("Challenge Card") {
    TikTokChallengeCard(
        challengerName: "Dylan",
        challengerScore: 92,
        challengeType: "Speed Round"
    )
}

#Preview("Duel Result Card") {
    TikTokDuelResultCard(
        player1Name: "Dylan",
        player1Score: 87,
        player2Name: "Alex",
        player2Score: 72,
        exerciseType: "Dual N-Back"
    )
}
