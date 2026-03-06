import SwiftUI

struct ShareCardView: View {
    let brainScore: Int
    let brainAge: Int
    let brainType: BrainType
    let percentile: Int
    let digitScore: Double
    let reactionScore: Double
    let visualScore: Double

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                Text("MindRestore")
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.8))

            // Score
            VStack(spacing: 4) {
                Text("\(brainScore)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Brain Score")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Brain Type + Age
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: brainType.icon)
                            .font(.caption)
                        Text(brainType.displayName)
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(typeColor)
                    Text("Brain Type")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 1, height: 32)

                VStack(spacing: 4) {
                    Text("\(brainAge)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Brain Age")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 1, height: 32)

                VStack(spacing: 4) {
                    Text("Top \(100 - percentile)%")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.accent)
                    Text("Percentile")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Score bars
            HStack(spacing: 8) {
                miniBar(label: "MEM", score: digitScore, color: .blue)
                miniBar(label: "SPD", score: reactionScore, color: .yellow)
                miniBar(label: "VIS", score: visualScore, color: .purple)
            }

            // Footer
            Text("Test yours → MindRestore app")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.12, green: 0.15, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(width: 320)
    }

    private func miniBar(label: String, score: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))
                    .frame(height: 48)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(height: 48 * score / 100)
            }
            .frame(maxWidth: .infinity)

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))

            Text("\(Int(score))")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
        }
    }

    private var typeColor: Color {
        switch brainType {
        case .lightningReflex: return .yellow
        case .numberCruncher: return .blue
        case .patternMaster: return .purple
        case .balancedBrain: return AppColors.accent
        }
    }

    @MainActor
    func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
