import Foundation
import UIKit

enum AssessmentPhase: Equatable {
    case intro
    case digitInstructions
    case digitShow
    case digitInput
    case reactionInstructions
    case reactionWait
    case reactionGo
    case reactionTooEarly
    case reactionResult
    case visualInstructions
    case visualShow
    case visualInput
    case calculating
    case results
}

@Observable
final class BrainAssessmentViewModel {
    var phase: AssessmentPhase = .intro
    var startTime = Date()

    // Digit Span
    var currentDigits: [Int] = []
    var displayDigitIndex: Int = 0
    var digitInput: String = ""
    var digitRound: Int = 0
    var digitStartLength: Int = 4
    var digitMaxCorrect: Int = 3
    private var digitTimer: Timer?

    // Reaction Time
    var reactionRound: Int = 0
    var reactionTimes: [Int] = []
    var reactionStartTime: Date?
    var lastReactionMs: Int = 0
    private var reactionTimer: Timer?

    // Visual Memory
    var gridSize: Int = 4
    var highlightedCells: Set<Int> = []
    var selectedCells: Set<Int> = []
    var visualRound: Int = 0
    var visualStartCount: Int = 3
    var visualMaxCorrect: Int = 2
    private var visualTimer: Timer?

    // Results
    var digitScore: Double = 0
    var reactionScore: Double = 0
    var visualScore: Double = 0
    var brainScore: Int = 0
    var brainAge: Int = 25
    var brainType: BrainType = .balancedBrain
    var percentile: Int = 50
    var avgReactionMs: Int = 300

    // MARK: - Flow Control

    func start() {
        startTime = Date()
        phase = .digitInstructions
        scheduleTransition(after: 2.5) { [weak self] in
            self?.startDigitSpan()
        }
    }

    // MARK: - Digit Span

    private func startDigitSpan() {
        digitRound = 0
        digitMaxCorrect = 3
        digitStartLength = 4
        nextDigitRound()
    }

    private func nextDigitRound() {
        let length = digitStartLength + digitRound
        currentDigits = (0..<length).map { _ in Int.random(in: 0...9) }
        displayDigitIndex = -1
        digitInput = ""
        phase = .digitShow

        showNextDigit()
    }

    private func showNextDigit() {
        digitTimer?.invalidate()
        displayDigitIndex += 1

        if displayDigitIndex >= currentDigits.count {
            digitTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.phase = .digitInput
                }
            }
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        digitTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.showNextDigit()
            }
        }
    }

    func submitDigitAnswer() {
        let correct = currentDigits.map(String.init).joined()
        if digitInput == correct {
            digitMaxCorrect = digitStartLength + digitRound
            digitRound += 1
            if digitRound < 6 {
                nextDigitRound()
            } else {
                finishDigitSpan()
            }
        } else {
            finishDigitSpan()
        }
    }

    private func finishDigitSpan() {
        digitTimer?.invalidate()
        digitScore = BrainScoring.digitSpanScore(maxDigits: digitMaxCorrect)
        phase = .reactionInstructions
        scheduleTransition(after: 2.5) { [weak self] in
            self?.startReactionTime()
        }
    }

    // MARK: - Reaction Time

    private func startReactionTime() {
        reactionRound = 0
        reactionTimes = []
        nextReactionRound()
    }

    private func nextReactionRound() {
        phase = .reactionWait
        let delay = Double.random(in: 1.5...4.0)
        reactionTimer?.invalidate()
        reactionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.phase = .reactionGo
                self?.reactionStartTime = Date()
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
    }

    func tapReaction() {
        if phase == .reactionWait {
            reactionTimer?.invalidate()
            phase = .reactionTooEarly
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            scheduleTransition(after: 1.0) { [weak self] in
                self?.nextReactionRound()
            }
            return
        }

        guard phase == .reactionGo, let start = reactionStartTime else { return }
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        lastReactionMs = ms
        reactionTimes.append(ms)
        reactionRound += 1

        phase = .reactionResult
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        scheduleTransition(after: 1.0) { [weak self] in
            guard let self else { return }
            if self.reactionRound < 5 {
                self.nextReactionRound()
            } else {
                self.finishReactionTime()
            }
        }
    }

    private func finishReactionTime() {
        reactionTimer?.invalidate()
        let avg = reactionTimes.isEmpty ? 500 : reactionTimes.reduce(0, +) / reactionTimes.count
        avgReactionMs = avg
        reactionScore = BrainScoring.reactionTimeScore(avgMs: avg)
        phase = .visualInstructions
        scheduleTransition(after: 2.5) { [weak self] in
            self?.startVisualMemory()
        }
    }

    // MARK: - Visual Memory

    private func startVisualMemory() {
        visualRound = 0
        visualMaxCorrect = 2
        nextVisualRound()
    }

    private func nextVisualRound() {
        let count = visualStartCount + visualRound
        selectedCells = []
        highlightedCells = Set((0..<(gridSize * gridSize)).shuffled().prefix(count))
        phase = .visualShow

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        visualTimer?.invalidate()
        visualTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.phase = .visualInput
            }
        }
    }

    func toggleCell(_ index: Int) {
        if selectedCells.contains(index) {
            selectedCells.remove(index)
        } else if selectedCells.count < highlightedCells.count {
            selectedCells.insert(index)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func submitVisualAnswer() {
        if selectedCells == highlightedCells {
            visualMaxCorrect = visualStartCount + visualRound
            visualRound += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if visualRound < 6 {
                nextVisualRound()
            } else {
                finishVisualMemory()
            }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            finishVisualMemory()
        }
    }

    private func finishVisualMemory() {
        visualTimer?.invalidate()
        visualScore = BrainScoring.visualMemoryScore(maxLevel: visualMaxCorrect)
        phase = .calculating
        calculateResults()
    }

    // MARK: - Results

    private func calculateResults() {
        brainScore = BrainScoring.compositeBrainScore(digit: digitScore, reaction: reactionScore, visual: visualScore)
        brainAge = BrainScoring.brainAge(from: brainScore)
        brainType = BrainScoring.determineBrainType(digit: digitScore, reaction: reactionScore, visual: visualScore)
        percentile = BrainScoring.percentile(score: brainScore)

        scheduleTransition(after: 2.0) { [weak self] in
            self?.phase = .results
        }
    }

    func createResult() -> BrainScoreResult {
        let result = BrainScoreResult()
        result.brainScore = brainScore
        result.brainAge = brainAge
        result.brainType = brainType
        result.digitSpanScore = digitScore
        result.reactionTimeScore = reactionScore
        result.visualMemoryScore = visualScore
        result.digitSpanMax = digitMaxCorrect
        result.reactionTimeAvgMs = avgReactionMs
        result.visualMemoryMax = visualMaxCorrect
        result.percentile = percentile
        return result
    }

    var currentDisplayDigit: Int? {
        guard displayDigitIndex >= 0, displayDigitIndex < currentDigits.count else { return nil }
        return currentDigits[displayDigitIndex]
    }

    var durationSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }

    // MARK: - Helpers

    private func scheduleTransition(after seconds: TimeInterval, action: @escaping () -> Void) {
        Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            Task { @MainActor in
                action()
            }
        }
    }
}
