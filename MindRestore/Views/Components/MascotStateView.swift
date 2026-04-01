import SwiftUI

/// Animated mascot that reflects the user's brain health.
/// Brain Score determines mood/state, Brain Age determines aging effects.
struct MascotStateView: View {
    let brainScore: Int
    let brainAge: Int
    let size: CGFloat

    @State private var breathe: Bool = false
    @State private var currentMascot: String = ""

    private var mascotState: MascotMood {
        MascotMood.from(brainScore: brainScore)
    }

    private var mascotImage: String {
        mascotState.imageName
    }

    // Aging: 0.0 (young, 18) to 1.0 (old, 75)
    private var agingFactor: Double {
        let clamped = Double(max(18, min(75, brainAge)))
        return (clamped - 18.0) / 57.0
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let bobPhase = time * (2 * .pi / mascotState.bobSpeed)
            let sparklePhase = time * (2 * .pi / 3.0)
            let sweatPhase = time * (2 * .pi / 2.0)

            ZStack {
                // Background glow (stronger for higher scores)
                if brainScore >= 600 {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [mascotState.glowColor.opacity(breathe ? 0.15 : 0.08), .clear],
                                center: .center,
                                startRadius: size * 0.1,
                                endRadius: size * 0.6
                            )
                        )
                        .frame(width: size * 1.4, height: size * 1.4)
                }

                // Sparkle particles for 800+
                if brainScore >= 800 {
                    SparkleOverlay(size: size, phase: CGFloat(sparklePhase), color: mascotState.glowColor)
                }

                // Sweat drops for <300
                if brainScore < 300 && brainScore > 0 {
                    SweatOverlay(size: size, phase: CGFloat(sweatPhase))
                }

                // The mascot
                Image(mascotImage)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    // Floating bob — smooth vertical sine wave
                    .offset(y: CGFloat(sin(bobPhase)) * mascotState.bobAmplitude)
                    // Breathing scale — symmetric sine wave
                    .scaleEffect(1.0 + CGFloat(sin(time * .pi / 1.5)) * mascotState.breatheScale)
                    // Aging effects
                    .saturation(1.0 - agingFactor * 0.35)
                    .contrast(1.0 - agingFactor * 0.1)
                    // Slight wobble for low scores — symmetric left AND right
                    .rotationEffect(.degrees(brainScore < 400 ? sin(bobPhase * 0.7) * 2 : 0))
                    // State change transition
                    .id(mascotImage)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: mascotImage)
        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: breathe)
        .onAppear {
            currentMascot = mascotImage
            breathe = true
        }
    }
}

// MARK: - Mascot Mood States

enum MascotMood: String, CaseIterable {
    case legendary    // 900+
    case thriving     // 800-899
    case strong       // 700-799
    case healthy      // 600-699
    case content      // 500-599
    case tired        // 400-499
    case sluggish     // 300-399
    case declining    // 200-299
    case critical     // <200

    static func from(brainScore: Int) -> MascotMood {
        switch brainScore {
        case 900...: return .legendary
        case 800..<900: return .thriving
        case 700..<800: return .strong
        case 600..<700: return .healthy
        case 500..<600: return .content
        case 400..<500: return .tired
        case 300..<400: return .sluggish
        case 200..<300: return .declining
        default: return .critical
        }
    }

    var imageName: String {
        switch self {
        case .legendary: return "mascot-crown"
        case .thriving: return "mascot-cool"
        case .strong: return "mascot-celebrate"
        case .healthy: return "mascot-wave"
        case .content: return "mascot-thinking"
        case .tired: return "mascot-bored"
        case .sluggish: return "mascot-bored"
        case .declining: return "mascot-low-score"
        case .critical: return "mascot-streak-broken"
        }
    }

    var glowColor: Color {
        switch self {
        case .legendary: return .yellow
        case .thriving: return AppColors.accent
        case .strong: return AppColors.teal
        case .healthy: return AppColors.accent
        case .content: return AppColors.violet
        case .tired, .sluggish: return .gray
        case .declining, .critical: return AppColors.coral
        }
    }

    var bobAmplitude: CGFloat {
        switch self {
        case .legendary: return 6
        case .thriving: return 5
        case .strong: return 4
        case .healthy: return 3.5
        case .content: return 3
        case .tired: return 2
        case .sluggish: return 1.5
        case .declining: return 1
        case .critical: return 0.5
        }
    }

    var bobSpeed: Double {
        switch self {
        case .legendary, .thriving, .strong: return 2.0
        case .healthy, .content: return 2.5
        case .tired, .sluggish: return 3.5
        case .declining, .critical: return 5.0
        }
    }

    var breatheScale: CGFloat {
        switch self {
        case .legendary, .thriving: return 0.025
        case .strong, .healthy: return 0.02
        case .content, .tired: return 0.015
        case .sluggish, .declining, .critical: return 0.01
        }
    }

    var statusText: String {
        switch self {
        case .legendary: return "Your brain is elite"
        case .thriving: return "Sharp as ever"
        case .strong: return "Brain's in great shape"
        case .healthy: return "Looking good up there"
        case .content: return "Not bad, keep going"
        case .tired: return "Getting rusty... train me"
        case .sluggish: return "Put the phone down and train"
        case .declining: return "TikTok won today huh"
        case .critical: return "Hello?? I need help"
        }
    }

    var statusColor: Color {
        switch self {
        case .legendary: return .yellow
        case .thriving: return AppColors.accent
        case .strong: return AppColors.teal
        case .healthy: return .green
        case .content: return AppColors.violet
        case .tired: return AppColors.amber
        case .sluggish: return .orange
        case .declining: return AppColors.coral
        case .critical: return .red
        }
    }
}

// MARK: - Sparkle Overlay

struct SparkleOverlay: View {
    let size: CGFloat
    let phase: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                let angle = (CGFloat(i) / 5.0) * .pi * 2 + phase
                let radius = size * 0.5
                Image(systemName: "sparkle")
                    .font(.system(size: 10 + CGFloat(i % 3) * 4))
                    .foregroundStyle(color.opacity(0.6))
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius * 0.6
                    )
                    .scaleEffect(0.5 + CGFloat(sin(Float(phase + CGFloat(i)))) * 0.5)
                    .opacity(0.3 + Double(sin(Float(phase * 2 + CGFloat(i)))) * 0.4)
            }
        }
    }
}

// MARK: - Sweat Overlay

struct SweatOverlay: View {
    let size: CGFloat
    let phase: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let xOffset = CGFloat([-20, 15, -5][i])
                let yVal = CGFloat(sin(Float(phase + CGFloat(i) * 2))) * size * 0.15
                let opacityVal = 0.3 + Double(sin(Float(phase + CGFloat(i)))) * 0.5
                Circle()
                    .fill(AppColors.sky.opacity(0.4))
                    .frame(width: 6, height: 8)
                    .offset(x: xOffset, y: -size * 0.2 + yVal)
                    .opacity(opacityVal)
            }
        }
    }
}

// MARK: - Preview

#Preview("Legendary (900+)") {
    MascotStateView(brainScore: 950, brainAge: 20, size: 200)
        .padding()
}

#Preview("Healthy (650)") {
    MascotStateView(brainScore: 650, brainAge: 35, size: 200)
        .padding()
}

#Preview("Declining (250)") {
    MascotStateView(brainScore: 250, brainAge: 65, size: 200)
        .padding()
}
