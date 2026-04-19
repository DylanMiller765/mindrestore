import SwiftUI

// MARK: - QuickGameView
//
// A self-contained mini Reaction Time game used to unlock Focus Mode.
// Does NOT save exercise results, does NOT count toward daily limits.
// Presents a 3-round Reaction Time game; calls onComplete when finished.

struct QuickGameView: View {
    let unlockDurationMinutes: Int
    let onComplete: () -> Void

    @State private var phase: Phase = .countdown
    @State private var roundsCompleted = 0
    @State private var reactionTimes: [Int] = []
    @State private var lastReactionMs = 0
    @State private var greenShownAt: Date?
    @State private var waitTask: Task<Void, Never>?
    @State private var countdownDone = false
    @State private var unlockAnimDone = false
    @Environment(\.dismiss) private var dismiss

    private let totalRounds = 3

    enum Phase {
        case countdown
        case waiting   // red screen — wait for green
        case ready     // green screen — tap!
        case tooEarly  // amber — tapped too early, restarting round
        case roundResult
        case done
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            switch phase {
            case .countdown:
                countdownView
            case .waiting:
                waitingView
            case .ready:
                readyView
            case .tooEarly:
                tooEarlyView
            case .roundResult:
                roundResultView
            case .done:
                doneView
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phase)
        .ignoresSafeArea()
    }

    // MARK: - Countdown

    private var countdownView: some View {
        ZStack {
            AppColors.pageBg.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "bolt.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.coral)

                VStack(spacing: 8) {
                    Text("Quick Reaction Test")
                        .font(.title2.weight(.bold))
                    Text("Tap the green screen as fast as you can")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Text("3 rounds · takes ~15 seconds")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)

                Spacer()

                GameCountdown {
                    startWaiting()
                }
                .frame(height: 120)

                Spacer()
            }
        }
    }

    // MARK: - Waiting (red)

    private var waitingView: some View {
        AppColors.reactionWait
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 20) {
                    Text("Round \(roundsCompleted + 1) of \(totalRounds)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))

                    Text("Wait for green...")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                tappedTooEarly()
            }
    }

    // MARK: - Ready (green)

    private var readyView: some View {
        AppColors.reactionGo
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 20) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.white)

                    Text("TAP!")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                tappedOnGreen()
            }
    }

    // MARK: - Too Early (amber)

    private var tooEarlyView: some View {
        AppColors.reactionTooEarly
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)

                    Text("Too Early!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Wait for the green screen")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            )
    }

    // MARK: - Round Result

    private var roundResultView: some View {
        Color.black.ignoresSafeArea()
            .overlay(
                VStack(spacing: 12) {
                    Text("\(lastReactionMs)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(msColor(lastReactionMs))
                        .contentTransition(.numericText(value: Double(lastReactionMs)))

                    Text("ms")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(msColor(lastReactionMs).opacity(0.7))

                    Text(msLabel(lastReactionMs))
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 4)

                    Text("Round \(roundsCompleted) of \(totalRounds)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)
                }
            )
    }

    // MARK: - Done

    private var doneView: some View {
        Color.black.ignoresSafeArea()
            .overlay(
                VStack(spacing: 24) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(AppColors.reactionGo.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(AppColors.reactionGo)
                            .scaleEffect(unlockAnimDone ? 1.0 : 0.5)
                            .opacity(unlockAnimDone ? 1 : 0)
                    }

                    VStack(spacing: 8) {
                        Text("Unlocked!")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        if let avg = averageMs {
                            Text("Avg: \(avg) ms · \(msLabel(avg))")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Text("Focus Mode paused for \(unlockDurationMinutes) min")
                            .font(.headline)
                            .foregroundStyle(AppColors.reactionGo)
                            .padding(.top, 4)
                    }

                    Spacer()
                }
            )
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    unlockAnimDone = true
                }
                HapticService.complete()
                // Wait 1.5s then call onComplete so the user sees the success screen
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    onComplete()
                }
            }
    }

    // MARK: - Game Logic

    private func startWaiting() {
        phase = .waiting
        let delay = Double.random(in: 1.5...4.0)
        waitTask?.cancel()
        waitTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                phase = .ready
                greenShownAt = Date.now
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    private func tappedTooEarly() {
        waitTask?.cancel()
        HapticService.wrong()
        phase = .tooEarly
        // Restart the round after a short pause
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                startWaiting()
            }
        }
    }

    private func tappedOnGreen() {
        guard let start = greenShownAt else { return }
        let ms = Int(Date.now.timeIntervalSince(start) * 1000)
        lastReactionMs = ms
        reactionTimes.append(ms)
        roundsCompleted += 1
        HapticService.tap()
        phase = .roundResult

        // Advance after a short display pause
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                if roundsCompleted >= totalRounds {
                    HapticService.complete()
                    phase = .done
                } else {
                    startWaiting()
                }
            }
        }
    }

    // MARK: - Helpers

    private var averageMs: Int? {
        guard !reactionTimes.isEmpty else { return nil }
        return reactionTimes.reduce(0, +) / reactionTimes.count
    }

    private func msColor(_ ms: Int) -> Color {
        if ms < 200 { return AppColors.reactionGo }
        if ms < 300 { return AppColors.accent }
        if ms < 400 { return .yellow }
        return AppColors.reactionTooEarly
    }

    private func msLabel(_ ms: Int) -> String {
        if ms < 150 { return "Insane!" }
        if ms < 200 { return "Lightning fast!" }
        if ms < 250 { return "Great reflexes!" }
        if ms < 300 { return "Nice!" }
        if ms < 400 { return "Good" }
        return "Keep practicing!"
    }
}
