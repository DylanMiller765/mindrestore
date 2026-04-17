import Foundation

struct ChallengeLink: Equatable {
    let game: ExerciseType
    let seed: Int
    let score: Int
    let challengerName: String

    var url: URL? {
        var components = URLComponents()
        components.scheme = "memori"
        components.host = "duel"
        components.queryItems = [
            URLQueryItem(name: "game", value: game.rawValue),
            URLQueryItem(name: "seed", value: "\(seed)"),
            URLQueryItem(name: "score", value: "\(score)"),
            URLQueryItem(name: "name", value: challengerName),
        ]
        return components.url
    }

    var vercelURL: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "getmemoriapp.com"
        components.path = "/challenge"
        components.queryItems = [
            URLQueryItem(name: "game", value: game.rawValue),
            URLQueryItem(name: "seed", value: "\(seed)"),
            URLQueryItem(name: "score", value: "\(score)"),
            URLQueryItem(name: "name", value: challengerName),
        ]
        return components.url
    }

    func shareMessage() -> String {
        let display = game.challengeDisplayText(score: score)
        let emoji = game.challengeEmoji
        let urlString = vercelURL?.absoluteString ?? ""
        return "I got \(display) on \(game.displayName) \(emoji) Think you can beat me? \(urlString)"
    }

    private static let universalLinkHost = "getmemoriapp.com"

    init?(url: URL) {
        let isCustomScheme = url.scheme == "memori" && url.host == "duel"
        let isUniversalLink = url.host == Self.universalLinkHost && url.path == "/challenge"
        guard isCustomScheme || isUniversalLink else { return nil }
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        guard let gameRaw = params?.first(where: { $0.name == "game" })?.value,
              let game = ExerciseType(rawValue: gameRaw),
              let seedStr = params?.first(where: { $0.name == "seed" })?.value,
              let seed = Int(seedStr),
              let scoreStr = params?.first(where: { $0.name == "score" })?.value,
              let score = Int(scoreStr),
              let name = params?.first(where: { $0.name == "name" })?.value
        else { return nil }

        self.game = game
        self.seed = seed
        self.score = score
        self.challengerName = name
    }

    init(game: ExerciseType, seed: Int, score: Int, challengerName: String) {
        self.game = game
        self.seed = seed
        self.score = score
        self.challengerName = challengerName
    }

    static func randomSeed() -> Int {
        Int.random(in: 10000...99999)
    }
}
