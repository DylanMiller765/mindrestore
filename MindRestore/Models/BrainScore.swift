import Foundation
import SwiftData

// MARK: - Brain Type

enum BrainType: String, Codable, CaseIterable {
    case lightningReflex
    case numberCruncher
    case patternMaster
    case balancedBrain

    var displayName: String {
        switch self {
        case .lightningReflex: return "Lightning Reflex"
        case .numberCruncher: return "Number Cruncher"
        case .patternMaster: return "Pattern Master"
        case .balancedBrain: return "Balanced Brain"
        }
    }

    var icon: String {
        switch self {
        case .lightningReflex: return "bolt.fill"
        case .numberCruncher: return "number.circle.fill"
        case .patternMaster: return "square.grid.3x3.fill"
        case .balancedBrain: return "brain.head.profile.fill"
        }
    }

    var description: String {
        switch self {
        case .lightningReflex: return "Your reaction speed is elite. You process visual information faster than most."
        case .numberCruncher: return "You excel at holding numbers in memory. Your digit span is impressive."
        case .patternMaster: return "You have exceptional visual-spatial memory. Patterns are your superpower."
        case .balancedBrain: return "Your cognitive abilities are well-rounded across all areas."
        }
    }

    var color: String {
        switch self {
        case .lightningReflex: return "yellow"
        case .numberCruncher: return "blue"
        case .patternMaster: return "purple"
        case .balancedBrain: return "green"
        }
    }
}

// MARK: - Brain Score Result

@Model
final class BrainScoreResult {
    var id: UUID = UUID()
    var date: Date = Date()
    var brainScore: Int = 0
    var brainAge: Int = 25
    var brainTypeRaw: String = BrainType.balancedBrain.rawValue
    var digitSpanScore: Double = 0
    var reactionTimeScore: Double = 0
    var visualMemoryScore: Double = 0
    var digitSpanMax: Int = 0
    var reactionTimeAvgMs: Int = 0
    var visualMemoryMax: Int = 0
    var percentile: Int = 50

    init() {}

    var brainType: BrainType {
        get { BrainType(rawValue: brainTypeRaw) ?? .balancedBrain }
        set { brainTypeRaw = newValue.rawValue }
    }
}

// MARK: - Scoring Utilities

enum BrainScoring {
    static func digitSpanScore(maxDigits: Int) -> Double {
        min(100, max(0, Double(maxDigits - 3) * 14.3))
    }

    static func reactionTimeScore(avgMs: Int) -> Double {
        min(100, max(0, Double(450 - avgMs) / 3.0))
    }

    static func visualMemoryScore(maxLevel: Int) -> Double {
        min(100, max(0, Double(maxLevel - 2) * 14.3))
    }

    static func compositeBrainScore(digit: Double, reaction: Double, visual: Double) -> Int {
        let avg = (digit + reaction + visual) / 3.0
        return min(1000, max(0, Int(avg * 10)))
    }

    static func brainAge(from score: Int) -> Int {
        let age = 80.0 - (Double(score) / 1000.0) * 62.0
        return max(18, min(80, Int(age)))
    }

    static func determineBrainType(digit: Double, reaction: Double, visual: Double) -> BrainType {
        let scores = [digit, reaction, visual]
        let maxScore = scores.max() ?? 0
        let minScore = scores.min() ?? 0

        if maxScore - minScore < 15 {
            return .balancedBrain
        }

        if reaction == maxScore { return .lightningReflex }
        if digit == maxScore { return .numberCruncher }
        return .patternMaster
    }

    static func percentile(score: Int) -> Int {
        let z = (Double(score) - 500.0) / 150.0
        let cdf = normalCDF(z)
        return max(1, min(99, Int(cdf * 100)))
    }

    private static func normalCDF(_ z: Double) -> Double {
        let absZ = abs(z)
        let t = 1.0 / (1.0 + 0.2316419 * absZ)
        let d = 0.3989422804014327 * exp(-z * z / 2.0)
        let p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.8212560 + t * 1.330274))))
        return z > 0 ? 1.0 - p : p
    }
}
