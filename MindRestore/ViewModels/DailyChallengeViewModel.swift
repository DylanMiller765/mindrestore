import Foundation
import UIKit

enum DailyChallengeType: Int, CaseIterable {
    case speedNumbers = 0
    case speedWords = 1
    case speedPattern = 2

    var displayName: String {
        switch self {
        case .speedNumbers: return "Speed Numbers"
        case .speedWords: return "Speed Words"
        case .speedPattern: return "Speed Pattern"
        }
    }

    var icon: String {
        switch self {
        case .speedNumbers: return "number.circle.fill"
        case .speedWords: return "textformat.abc"
        case .speedPattern: return "square.grid.3x3.fill"
        }
    }

    var instruction: String {
        switch self {
        case .speedNumbers: return "Memorize the numbers, then type them back"
        case .speedWords: return "Memorize the words, then type as many as you can"
        case .speedPattern: return "Memorize the pattern, then recreate it"
        }
    }
}

enum DailyChallengePhase {
    case preview
    case countdown
    case memorize
    case recall
    case results
}

@Observable
final class DailyChallengeViewModel {
    var phase: DailyChallengePhase = .preview
    var challengeType: DailyChallengeType = .speedNumbers
    var countdownValue: Int = 3
    var timeRemaining: Double = 10
    var recallTimeRemaining: Double = 30

    // Content
    var numbers: [Int] = []
    var words: [String] = []
    var patternCells: Set<Int> = []
    var selectedCells: Set<Int> = []
    var textInput: String = ""

    // Results
    var score: Int = 0
    var percentile: Int = 50
    var isCorrect: Bool = false

    private var timer: Timer?
    let gridSize = 4

    func setup() {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let typeIndex = dayOfYear % DailyChallengeType.allCases.count
        challengeType = DailyChallengeType(rawValue: typeIndex) ?? .speedNumbers

        var rng = SeededGenerator(seed: UInt64(dayOfYear * 31 + 2024))

        switch challengeType {
        case .speedNumbers:
            numbers = (0..<8).map { _ in Int.random(in: 0...9, using: &rng) }
        case .speedWords:
            let pool = ["apple", "river", "clock", "mountain", "paper", "bridge", "candle",
                        "forest", "guitar", "shadow", "ocean", "pencil", "rabbit", "sunset",
                        "violin", "chair", "diamond", "eagle", "flame", "garden", "hammer",
                        "island", "jacket", "kettle", "lantern", "mirror", "olive", "piano",
                        "rocket", "tunnel", "anchor", "basket", "compass", "dragon", "emerald"]
            words = Array(pool.shuffled(using: &rng).prefix(8))
        case .speedPattern:
            let total = gridSize * gridSize
            let indices = Array(0..<total).shuffled(using: &rng)
            patternCells = Set(indices.prefix(6))
        }
    }

    func startCountdown() {
        phase = .countdown
        countdownValue = 3
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.countdownValue -= 1
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if self.countdownValue <= 0 {
                    self.timer?.invalidate()
                    self.startMemorize()
                }
            }
        }
    }

    private func startMemorize() {
        phase = .memorize
        timeRemaining = 10
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.timeRemaining -= 0.1
                if self.timeRemaining <= 0 {
                    self.timer?.invalidate()
                    self.startRecall()
                }
            }
        }
    }

    private func startRecall() {
        phase = .recall
        textInput = ""
        selectedCells = []
        recallTimeRemaining = 30
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.recallTimeRemaining -= 0.1
                if self.recallTimeRemaining <= 0 {
                    self.timer?.invalidate()
                    self.submit()
                }
            }
        }
    }

    func togglePatternCell(_ index: Int) {
        if selectedCells.contains(index) {
            selectedCells.remove(index)
        } else {
            selectedCells.insert(index)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func submit() {
        timer?.invalidate()

        switch challengeType {
        case .speedNumbers:
            let correct = numbers.map(String.init).joined()
            let input = textInput.filter(\.isNumber)
            var matched = 0
            for (a, b) in zip(correct, input) where a == b { matched += 1 }
            score = Int(Double(matched) / Double(numbers.count) * 1000)
            isCorrect = input == correct

        case .speedWords:
            let inputWords = textInput
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
            let targetWords = Set(words.map { $0.lowercased() })
            let matched = inputWords.filter { targetWords.contains($0) }.count
            score = Int(Double(matched) / Double(words.count) * 1000)
            isCorrect = matched == words.count

        case .speedPattern:
            let correct = selectedCells == patternCells
            let intersection = selectedCells.intersection(patternCells).count
            score = Int(Double(intersection) / Double(patternCells.count) * 1000)
            isCorrect = correct
        }

        percentile = estimatePercentile(score: score)
        phase = .results
        UINotificationFeedbackGenerator().notificationOccurred(score >= 800 ? .success : .warning)
    }

    private func estimatePercentile(score: Int) -> Int {
        let z = (Double(score) - 550.0) / 200.0
        let absZ = abs(z)
        let t = 1.0 / (1.0 + 0.2316419 * absZ)
        let d = 0.3989422804014327 * exp(-z * z / 2.0)
        let p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.8212560 + t * 1.330274))))
        let cdf = z > 0 ? 1.0 - p : p
        return max(1, min(99, Int(cdf * 100)))
    }

    var displayContent: String {
        switch challengeType {
        case .speedNumbers:
            return numbers.map(String.init).joined(separator: "  ")
        case .speedWords:
            return words.joined(separator: "  ·  ")
        case .speedPattern:
            return ""
        }
    }
}

// MARK: - Seeded RNG

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
