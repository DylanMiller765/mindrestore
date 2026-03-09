import Foundation

// MARK: - Enums

enum LeaderboardCategory: String, CaseIterable, Identifiable {
    case brainScore = "Brain Score"
    case weeklyXP = "Weekly XP"
    case streak = "Streak"
    // Per-game leaderboards
    case reactionTime = "Reaction Time"
    case colorMatch = "Color Match"
    case speedMatch = "Speed Match"
    case visualMemory = "Visual Memory"
    case numberMemory = "Number Memory"
    case mathSpeed = "Math Speed"
    case dualNBack = "Dual N-Back"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .brainScore: return "brain.head.profile"
        case .weeklyXP: return "star.fill"
        case .streak: return "flame.fill"
        case .reactionTime: return "bolt.fill"
        case .colorMatch: return "paintpalette.fill"
        case .speedMatch: return "bolt.square.fill"
        case .visualMemory: return "square.grid.3x3.fill"
        case .numberMemory: return "number.circle.fill"
        case .mathSpeed: return "multiply.circle.fill"
        case .dualNBack: return "square.grid.3x3"
        }
    }
}

enum LeaderboardTimeFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case allTime = "All Time"

    var id: String { rawValue }
}

// MARK: - Display Data

struct LeaderboardEntryData: Identifiable, Sendable {
    let id = UUID()
    let rank: Int
    let username: String
    let score: Int
    let avatarEmoji: String
    let level: Int
    let isCurrentUser: Bool
}

// MARK: - Service

final class LeaderboardService: @unchecked Sendable {
    static let shared = LeaderboardService()

    private init() {}

    private let usernames: [String] = [
        "BrainiacSam", "MemoryQueen", "CognitiveKing99", "NeuronNinja",
        "SynapseStorm", "MindMaster42", "ThinkTankTina", "RecallRocket",
        "PuzzlePro", "LogicLion", "FocusFox", "BrainWaveBen",
        "MentalMarathon", "QuickThinkQuin", "SharpMindSara", "IQBeast",
        "CortexCrusher", "DendriteDave", "AxonAce", "HippocampusHero",
        "NeuroNerd88", "MindfulMike", "BrainBuffBella", "ThoughtTiger",
        "MemoryMoose", "CerebralCat", "WitWhiz", "GeniusGiraffe",
        "SmartSparrow", "CleverCrow", "BrightBadger", "KeenKoala",
        "WisdomWolf", "AlertAlpaca", "SharpShark", "BoldBrain",
        "MindMaven", "CogChamp", "ThinkFastTom", "BrainBlitz",
        "NeuralNova", "SynapticSurge", "MindMeld77", "PuzzlePanda",
        "LogicLlama", "FocusFalcon", "RecallRaven", "MemoryMonk",
        "BrainBoltMax", "CortexCommander"
    ]

    private let emojis: [String] = [
        "\u{1F9E0}", "\u{1F31F}", "\u{1F525}", "\u{26A1}", "\u{1F680}",
        "\u{1F3AF}", "\u{1F48E}", "\u{1F451}", "\u{1F3C6}", "\u{1F31E}",
        "\u{1F338}", "\u{1F30A}", "\u{1F343}", "\u{2B50}", "\u{1F308}",
        "\u{1F30D}", "\u{1F985}", "\u{1F981}", "\u{1F43B}", "\u{1F98A}",
        "\u{1F427}", "\u{1F99C}", "\u{1F40C}", "\u{1F98B}", "\u{1F41D}"
    ]

    // MARK: - Public API

    func generateLeaderboard(
        category: LeaderboardCategory,
        filter: LeaderboardTimeFilter,
        userScore: Int,
        userName: String,
        userLevel: Int
    ) -> [LeaderboardEntryData] {
        // Simple deterministic seed from day + category + filter
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date.now) ?? 1
        let year = calendar.component(.year, from: Date.now)
        let rawSeed = year &* 1000 &+ dayOfYear &+ category.hashValue &+ filter.hashValue
        var seed = UInt64(bitPattern: Int64(rawSeed))

        let timeMultiplier: Double
        switch filter {
        case .today: timeMultiplier = 0.3
        case .thisWeek: timeMultiplier = 1.0
        case .allTime: timeMultiplier = 3.5
        }

        // Generate 30 simulated entries using fast inline RNG
        let count = 30
        var entries: [(username: String, score: Int, emoji: String, level: Int)] = []

        for i in 0..<count {
            seed = splitmix64(&seed)
            let nameIndex = Int(seed % UInt64(usernames.count))
            let name = usernames[nameIndex]

            seed = splitmix64(&seed)
            let score = generateScore(seed: seed, category: category, timeMultiplier: timeMultiplier)

            seed = splitmix64(&seed)
            let emojiIndex = Int(seed % UInt64(emojis.count))
            let emoji = emojis[emojiIndex]

            seed = splitmix64(&seed)
            let level = max(1, min(99, score / levelDivisor(for: category) + Int(seed % 4)))

            entries.append((username: name, score: score, emoji: emoji, level: level))
        }

        // Insert current user
        entries.append((username: userName, score: userScore, emoji: "\u{1F9E0}", level: userLevel))

        // Sort descending
        entries.sort { $0.score > $1.score }

        return entries.enumerated().map { index, entry in
            LeaderboardEntryData(
                rank: index + 1,
                username: entry.username,
                score: entry.score,
                avatarEmoji: entry.emoji,
                level: entry.level,
                isCurrentUser: entry.username == userName
            )
        }
    }

    // MARK: - Private

    /// SplitMix64 — fast inline RNG, no protocol overhead
    private func splitmix64(_ state: inout UInt64) -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    private func generateScore(seed: UInt64, category: LeaderboardCategory, timeMultiplier: Double) -> Int {
        let normalized = Double(seed % 10000) / 10000.0

        switch category {
        case .brainScore:
            let base = 200.0 + normalized * 600.0
            return max(50, Int(base * timeMultiplier))
        case .weeklyXP:
            let base = 100.0 + normalized * normalized * 800.0
            return max(10, Int(base * timeMultiplier))
        case .streak:
            let base = 1.0 + normalized * normalized * 60.0
            return max(1, Int(base * timeMultiplier))
        case .reactionTime:
            // Score in ms (lower is better) — 150-400ms range
            let base = 150.0 + normalized * 250.0
            return max(100, Int(base / max(0.3, timeMultiplier)))
        case .colorMatch:
            // Accuracy-based score 50-100%
            let base = 50.0 + normalized * 50.0
            return max(30, Int(base * min(timeMultiplier, 1.2)))
        case .speedMatch:
            // Accuracy-based score 50-100%
            let base = 55.0 + normalized * 45.0
            return max(30, Int(base * min(timeMultiplier, 1.2)))
        case .visualMemory:
            // Level reached 1-10
            let base = 2.0 + normalized * 8.0
            return max(1, Int(base * min(timeMultiplier, 1.5)))
        case .numberMemory:
            // Max digits recalled 4-12
            let base = 4.0 + normalized * 8.0
            return max(3, Int(base * min(timeMultiplier, 1.3)))
        case .mathSpeed:
            let base = 10.0 + normalized * 40.0
            return max(5, Int(base * timeMultiplier))
        case .dualNBack:
            // N-back level reached 1-8
            let base = 1.0 + normalized * 7.0
            return max(1, Int(base * min(timeMultiplier, 1.5)))
        }
    }

    private func levelDivisor(for category: LeaderboardCategory) -> Int {
        switch category {
        case .brainScore: return 60
        case .weeklyXP: return 40
        case .streak: return 5
        case .reactionTime: return 20
        case .colorMatch: return 8
        case .speedMatch: return 8
        case .visualMemory: return 1
        case .numberMemory: return 1
        case .mathSpeed: return 3
        case .dualNBack: return 1
        }
    }
}
