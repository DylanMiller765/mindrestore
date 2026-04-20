import SwiftUI

struct FocusModeCard: View {
    @Environment(FocusModeService.self) private var focusModeService
    @State private var showingSettings = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.7

    // Convenience
    private var isActive: Bool { focusModeService.isEnabled }
    private var isUnlocked: Bool { focusModeService.isTemporarilyUnlocked }

    var body: some View {
        Button {
            showingSettings = true
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSettings) {
            if focusModeService.isEnabled {
                FocusModeSettingsView()
            } else {
                FocusModeSetupView()
            }
        }
        .padding(.horizontal)
        .onAppear {
            if isActive && !isUnlocked {
                startPulse()
            }
        }
        .onChange(of: isActive) { _, active in
            if active && !isUnlocked {
                startPulse()
            }
        }
    }

    // MARK: - Card Body

    @ViewBuilder
    private var cardContent: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background fill
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    // Subtle violet or amber tint when active
                    RoundedRectangle(cornerRadius: 20)
                        .fill(backgroundTint)
                )

            // Gradient border
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderGradient, lineWidth: isActive ? 1.5 : 1)

            // Main row
            HStack(spacing: 14) {
                // Mascot
                mascotImage
                    .frame(height: 56)

                // Text stack
                VStack(alignment: .leading, spacing: 5) {
                    Text("Focus Mode")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    subtitleText
                }

                Spacer()

                // Trailing indicator
                trailingIndicator
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        // Violet glow shadow when active
        .shadow(
            color: isActive && !isUnlocked
                ? AppColors.violet.opacity(0.20)
                : .clear,
            radius: 12, x: 0, y: 4
        )
    }

    // MARK: - Sub-views

    private var mascotImage: some View {
        let name: String
        if isUnlocked {
            name = "mascot-thinking"     // paused / unlocked state
        } else if isActive {
            name = "mascot-streak-fire"  // actively guarding
        } else {
            name = "mascot-goal"         // invite to set up
        }
        return Image(name)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
    }

    @ViewBuilder
    private var subtitleText: some View {
        if isActive {
            if isUnlocked {
                // Unlocked state — amber, countdown
                Label {
                    Text("Unlocked · \(unlockTimeRemaining) left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.amber)
                } icon: {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppColors.amber)
                }
            } else {
                // Active, protecting state — violet
                Label {
                    Text(activeSubtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.violet)
                } icon: {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppColors.violet)
                }
            }
        } else {
            // Not set up
            Text("Block distracting apps · earn unlock time")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        if isActive && !isUnlocked {
            // Pulsing shield badge
            ZStack {
                Circle()
                    .fill(AppColors.violet.opacity(0.15 * pulseOpacity))
                    .frame(width: 36, height: 36)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(AppColors.violet.opacity(0.18))
                    .frame(width: 28, height: 28)

                Image(systemName: "shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.violet)
            }
        } else if isUnlocked {
            // Amber lock-open
            ZStack {
                Circle()
                    .fill(AppColors.amber.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.amber)
            }
        } else {
            // Not set up — "Set Up" pill
            Text("Set Up")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [AppColors.violet, AppColors.violet.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
        }
    }

    // MARK: - Helpers

    private var activeSubtitle: String {
        let count = focusModeService.blockedAppCount
        let appPart = "\(count) app\(count == 1 ? "" : "s") blocked"
        let unlockPart = "\(focusModeService.unlockDuration) min unlock"
        return "\(appPart) · \(unlockPart)"
    }

    private var backgroundTint: Color {
        if isUnlocked {
            return AppColors.amber.opacity(0.06)
        } else if isActive {
            return AppColors.violet.opacity(0.07)
        } else {
            return Color.clear
        }
    }

    private var borderGradient: LinearGradient {
        if isUnlocked {
            return LinearGradient(
                colors: [AppColors.amber.opacity(0.45), AppColors.amber.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isActive {
            return LinearGradient(
                colors: [AppColors.violet.opacity(0.55), AppColors.violet.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var unlockTimeRemaining: String {
        guard let until = focusModeService.unlockUntil else { return "" }
        let remaining = max(0, Int(until.timeIntervalSince(.now)))
        let min = remaining / 60
        let sec = remaining % 60
        return "\(min):\(String(format: "%02d", sec))"
    }

    private func startPulse() {
        withAnimation(
            .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.35
            pulseOpacity = 0.0
        }
    }
}
