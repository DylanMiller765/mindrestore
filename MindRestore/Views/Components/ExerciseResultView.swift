import SwiftUI

struct ExerciseResultView: View {
    let gameTitle: String
    let gameIcon: String
    let gameColor: Color
    let score: Double // 0-100
    let ratingText: String // e.g. "Lightning Fast!", "Perfect!", "Great Memory!"
    let xpEarned: Int
    let stats: [(label: String, value: String)]
    let onPlayAgain: () -> Void
    let onDone: () -> Void

    @State private var animateScore = false
    @State private var animateContent = false
    @State private var animateDots = false
    @State private var displayedScore: Double = 0

    private var scoreProgress: CGFloat {
        min(CGFloat(score) / 100.0, 1.0)
    }

    var body: some View {
        ZStack {
            AppColors.pageBg.ignoresSafeArea()

            // Decorative confetti dots
            confettiDots

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 32)

                    // Game icon badge
                    gameBadge
                        .staggeredEntrance(index: 0)

                    Spacer().frame(height: 24)

                    // Score ring
                    scoreRing
                        .staggeredEntrance(index: 1)

                    Spacer().frame(height: 16)

                    // Rating text
                    Text(ratingText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .staggeredEntrance(index: 2)

                    Spacer().frame(height: 12)

                    // XP pill
                    xpBadge
                        .staggeredEntrance(index: 3)

                    Spacer().frame(height: 28)

                    // Stats card
                    statsCard
                        .staggeredEntrance(index: 4)

                    Spacer().frame(height: 32)

                    // Buttons
                    actionButtons
                        .staggeredEntrance(index: 5)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateContent = true
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) {
                animateScore = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateDots = true
            }
            // Animate the score number counting up
            animateScoreCounter()
        }
    }

    // MARK: - Game Badge

    private var gameBadge: some View {
        VStack(spacing: 8) {
            Image(systemName: gameIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(gameColor, in: RoundedRectangle(cornerRadius: 14))

            Text(gameTitle.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.textTertiary)
                .tracking(1.5)
        }
    }

    // MARK: - Score Ring

    private var scoreRing: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(gameColor.opacity(0.08))
                .frame(width: 190, height: 190)

            // Track
            Circle()
                .stroke(AppColors.cardBorder, lineWidth: 14)
                .frame(width: 160, height: 160)

            // Progress arc
            Circle()
                .trim(from: 0, to: animateScore ? scoreProgress : 0)
                .stroke(
                    AngularGradient(
                        colors: [gameColor.opacity(0.6), gameColor, gameColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))

            // Score number
            VStack(spacing: 2) {
                Text("\(Int(displayedScore))")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(gameColor)
                    .contentTransition(.numericText())

                Text("SCORE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary)
                    .tracking(1.5)
            }
        }
    }

    // MARK: - XP Badge

    private var xpBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 12, weight: .bold))
            Text("+\(xpEarned) XP")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(gameColor)
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(gameColor)
                Text("SESSION STATS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary)
                    .tracking(1.2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 14)

            // Stat rows
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                if index > 0 {
                    Divider()
                        .overlay(AppColors.cardBorder)
                }

                HStack {
                    Text(stat.label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()

                    Text(stat.value)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
                .padding(.vertical, 12)
            }
        }
        .appCard(padding: 18)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onPlayAgain) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold))
                    Text("Play Again")
                }
                .accentButton(color: gameColor)
            }

            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Confetti Dots

    private var confettiDots: some View {
        GeometryReader { geo in
            let dots = generateDotPositions(in: geo.size)
            ForEach(Array(dots.enumerated()), id: \.offset) { index, dot in
                Circle()
                    .fill(gameColor.opacity(dot.opacity))
                    .frame(width: dot.size, height: dot.size)
                    .position(x: dot.x, y: dot.y)
                    .offset(y: animateDots ? dot.drift : -dot.drift)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: - Helpers

    private struct DotInfo {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
        let drift: CGFloat
    }

    private func generateDotPositions(in size: CGSize) -> [DotInfo] {
        // Use a fixed seed based on score so dots are stable across redraws
        let seed = Int(score * 100) + gameTitle.hashValue
        var rng = SeededRNG(seed: UInt64(abs(seed)))

        let count = 14
        return (0..<count).map { _ in
            let x = CGFloat.random(in: 20...(size.width - 20), using: &rng)
            let y = CGFloat.random(in: 30...(size.height * 0.35), using: &rng)
            let dotSize = CGFloat.random(in: 4...10, using: &rng)
            let opacity = Double.random(in: 0.06...0.18, using: &rng)
            let drift = CGFloat.random(in: 3...8, using: &rng)
            return DotInfo(x: x, y: y, size: dotSize, opacity: opacity, drift: drift)
        }
    }

    private func animateScoreCounter() {
        let steps = 30
        let duration = 0.8
        let delay = 0.3

        for step in 0...steps {
            let fraction = Double(step) / Double(steps)
            // Ease-out curve
            let eased = 1.0 - pow(1.0 - fraction, 3)
            let value = score * eased

            DispatchQueue.main.asyncAfter(deadline: .now() + delay + duration * fraction) {
                displayedScore = value
            }
        }
    }
}

// MARK: - Seeded RNG for stable dot positions

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

// MARK: - Preview

#Preview {
    ExerciseResultView(
        gameTitle: "Dual N-Back",
        gameIcon: "brain.head.profile",
        gameColor: AppColors.violet,
        score: 85,
        ratingText: "Excellent Memory!",
        xpEarned: 35,
        stats: [
            (label: "Level Reached", value: "N-3"),
            (label: "Accuracy", value: "85%"),
            (label: "Rounds Played", value: "20"),
            (label: "Best Streak", value: "8")
        ],
        onPlayAgain: {},
        onDone: {}
    )
}
