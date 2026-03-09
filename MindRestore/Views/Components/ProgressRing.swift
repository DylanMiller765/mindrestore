import SwiftUI

struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = 60
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.accent.opacity(0.20), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AngularGradient(
                        colors: [AppColors.accent, AppColors.teal, AppColors.accent],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: progress)

            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Progress: \(Int(progress * 100)) percent")
    }
}
