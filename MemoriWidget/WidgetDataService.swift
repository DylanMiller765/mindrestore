import Foundation
import WidgetKit

/// Bridges the main app's data to the widget via shared UserDefaults.
/// Configure the App Group "group.com.memori.shared" in Xcode for both
/// the main target and the widget extension target.
enum WidgetDataService {

    static let suiteName = "group.com.memori.shared"

    // MARK: - Keys

    private enum Key {
        static let streak       = "widget_streak"
        static let level        = "widget_level"
        static let levelName    = "widget_levelName"
        static let totalXP      = "widget_totalXP"
        static let xpForNextLevel = "widget_xpForNextLevel"
        static let exercisesToday = "widget_exercisesToday"
        static let dailyGoal    = "widget_dailyGoal"
        static let trainedToday = "widget_trainedToday"
        static let lastUpdated  = "widget_lastUpdated"
    }

    // MARK: - Write

    static func updateWidgetData(
        streak: Int,
        level: Int,
        levelName: String,
        xp: Int,
        xpForNextLevel: Int = 0,
        exercisesToday: Int,
        dailyGoal: Int,
        trainedToday: Bool
    ) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(streak, forKey: Key.streak)
        defaults.set(level, forKey: Key.level)
        defaults.set(levelName, forKey: Key.levelName)
        defaults.set(xp, forKey: Key.totalXP)
        defaults.set(xpForNextLevel, forKey: Key.xpForNextLevel)
        defaults.set(exercisesToday, forKey: Key.exercisesToday)
        defaults.set(dailyGoal, forKey: Key.dailyGoal)
        defaults.set(trainedToday, forKey: Key.trainedToday)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastUpdated)

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read (used by widget timeline provider)

    struct Snapshot {
        var streak: Int
        var level: Int
        var levelName: String
        var totalXP: Int
        var xpForNextLevel: Int
        var exercisesToday: Int
        var dailyGoal: Int
        var trainedToday: Bool
    }

    static func currentSnapshot() -> Snapshot {
        let defaults = UserDefaults(suiteName: suiteName)
        return Snapshot(
            streak: defaults?.integer(forKey: Key.streak) ?? 0,
            level: defaults?.integer(forKey: Key.level) ?? 1,
            levelName: defaults?.string(forKey: Key.levelName) ?? "Novice",
            totalXP: defaults?.integer(forKey: Key.totalXP) ?? 0,
            xpForNextLevel: defaults?.integer(forKey: Key.xpForNextLevel) ?? 500,
            exercisesToday: defaults?.integer(forKey: Key.exercisesToday) ?? 0,
            dailyGoal: defaults?.integer(forKey: Key.dailyGoal) ?? 3,
            trainedToday: defaults?.bool(forKey: Key.trainedToday) ?? false
        )
    }
}
