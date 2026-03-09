import Foundation

@MainActor @Observable
final class HomeViewModel {
    var todaySessionCount: Int = 0
    var totalSessions: Int = 0
    var averageScore: Double = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var dailyGoal: Int = 3
    var hasTrainedToday: Bool = false

    // Streak Freeze
    var streakFreezes: Int = 0
    var maxStreakFreezes: Int = 2
    var streakFreezeJustUsed: Bool = false
    var streakFreezeJustEarned: Bool = false
    var savedStreakCount: Int = 0

    func refresh(user: User?, sessions: [DailySession]) {
        guard let user else { return }

        currentStreak = user.currentStreak
        longestStreak = user.longestStreak
        dailyGoal = user.dailyGoal
        totalSessions = sessions.count
        hasTrainedToday = user.lastSessionDate?.isToday ?? false

        // Streak freeze state
        streakFreezes = user.streakFreezes
        maxStreakFreezes = user.maxStreakFreezes

        // Check if a freeze was used today (the used-date is set to yesterday when consumed)
        if let usedDate = user.streakFreezeUsedDate {
            let calendar = Calendar.current
            if calendar.isDateInYesterday(usedDate) || calendar.isDateInToday(usedDate) {
                streakFreezeJustUsed = true
                savedStreakCount = user.currentStreak
            }
        }

        let todaySessions = sessions.filter { Calendar.current.isDateInToday($0.date) }
        todaySessionCount = todaySessions.first?.exercisesCompleted.count ?? 0

        let allScores = sessions.compactMap { $0.totalScore }
        averageScore = allScores.isEmpty ? 0 : allScores.reduce(0, +) / Double(allScores.count)
    }

    func handleFreezeEvent(_ event: StreakFreezeEvent, user: User?) {
        guard let user else { return }
        streakFreezes = user.streakFreezes
        if event.freezeUsed {
            streakFreezeJustUsed = true
            savedStreakCount = event.savedStreak
        }
        if event.freezeEarned {
            streakFreezeJustEarned = true
        }
    }
}
