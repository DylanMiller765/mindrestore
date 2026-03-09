import SwiftUI

// MARK: - Level Up Share Card

struct LevelUpShareCard: View {
    let level: Int
    let levelName: String
    let totalXP: Int

    var body: some View {
        VStack(spacing: 20) {
            Text("LEVEL UP")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.7))

            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(.white.opacity(0.1 - Double(i) * 0.03), lineWidth: 2)
                        .frame(width: CGFloat(80 + i * 30), height: CGFloat(80 + i * 30))
                }

                Text("\(level)")
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(levelName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("\(totalXP) XP earned")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text("Memori")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(32)
        .frame(width: 300)
        .background(
            LinearGradient(
                colors: [AppColors.violet, AppColors.indigo, AppColors.sky],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }
}

// MARK: - Achievement Share Card

struct AchievementShareCard: View {
    let achievementType: AchievementType

    var body: some View {
        VStack(spacing: 20) {
            Text("ACHIEVEMENT UNLOCKED")
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.7))

            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: achievementType.icon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(achievementType.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text(achievementType.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Text("Memori")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(32)
        .frame(width: 300)
        .background(
            LinearGradient(
                colors: achievementType.gradientColors + [achievementType.gradientColors[0].opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }
}

// MARK: - Profile Share Card

struct ProfileShareCard: View {
    let username: String
    let level: Int
    let levelName: String
    let brainScore: Int
    let streak: Int
    let achievements: Int
    let avatarEmoji: String

    var body: some View {
        VStack(spacing: 20) {
            Text(avatarEmoji)
                .font(.system(size: 48))

            VStack(spacing: 4) {
                Text(username.isEmpty ? "Brain Trainer" : username)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Level \(level) — \(levelName)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 24) {
                profileStat(value: "\(brainScore)", label: "Brain Score")
                profileStat(value: "\(streak)d", label: "Streak")
                profileStat(value: "\(achievements)", label: "Badges")
            }

            Text("Memori")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(32)
        .frame(width: 300)
        .background(
            LinearGradient(
                colors: [AppColors.accent, AppColors.teal, AppColors.mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Render to Image

extension View {
    @MainActor
    func renderAsImage(size: CGSize = CGSize(width: 300, height: 400), scale: CGFloat? = nil) -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.proposedSize = .init(size)
        renderer.scale = scale ?? UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }
}
