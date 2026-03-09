import Foundation
import UserNotifications

final class NotificationService: Sendable {
    static let shared = NotificationService()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Daily Reminder

    private static let reminderMessages: [(title: String, body: String)] = [
        ("Your brain is waiting", "A quick 5-minute session keeps your mind sharp."),
        ("Memory check-in", "How's your memory today? Let's find out."),
        ("Brain training time", "The best minds train daily. Your turn."),
        ("Don't skip brain day", "You wouldn't skip leg day... right?"),
        ("Quick brain boost", "5 minutes now = sharper thinking all day."),
        ("Level up your mind", "Your brain has XP waiting to be earned."),
        ("Time to train", "Champions train every day. Be a champion."),
        ("Mental fitness", "Your brain is a muscle. Let's work it out."),
        ("Stay sharp", "A few minutes of training goes a long way."),
        ("Challenge yourself", "Today's daily challenge is waiting for you."),
    ]

    func scheduleDailyReminder(hour: Int, minute: Int, streak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let message = Self.reminderMessages[dayOfYear % Self.reminderMessages.count]

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = streak > 0
            ? "\(message.body) (\(streak)-day streak!)"
            : message.body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Streak Risk

    private static let streakRiskMessages: [(title: String, body: String)] = [
        ("Your streak is at risk!", "You haven't trained today. Don't lose your progress!"),
        ("Don't break the chain!", "Just 5 minutes to keep your streak alive."),
        ("Streak alert", "Your streak is about to end. Quick session?"),
        ("Still time!", "The day isn't over yet — save your streak."),
        ("One more day", "Keep the momentum going. Train now."),
    ]

    func scheduleStreakRisk(streak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["streak_risk"])

        guard streak > 0 else { return }

        let message = Self.streakRiskMessages[streak % Self.streakRiskMessages.count]

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = "\(message.body) (\(streak)-day streak)"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "streak_risk", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Milestones

    func scheduleMilestone(streak: Int) {
        let milestones = [3, 7, 14, 30, 60, 100]
        guard milestones.contains(streak) else { return }

        let messages: [Int: (title: String, body: String)] = [
            3: ("3-Day Streak!", "You're building a habit. Keep it up!"),
            7: ("One Week Strong!", "7 days straight — you're on fire!"),
            14: ("Two Weeks!", "14 days of brain training. Impressive dedication."),
            30: ("30-Day Legend!", "A full month of training. Your brain thanks you."),
            60: ("60-Day Titan!", "Two months strong. You're in the top 1%."),
            100: ("100 DAYS!", "Triple digits! You are a cognitive legend."),
        ]

        let message = messages[streak] ?? ("Milestone!", "You've trained for \(streak) days straight!")

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "milestone_\(streak)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Comeback Notifications

    func scheduleComebackNotification(lastTrainedDaysAgo: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["comeback"])

        guard lastTrainedDaysAgo >= 2 else { return }

        let messages: [(title: String, body: String)] = [
            ("We miss you!", "Your brain misses its daily workout. Come back for a quick session."),
            ("It's been a while", "Memory fades without practice. Just 5 minutes to get back on track."),
            ("Come back stronger", "Every champion takes breaks. Now it's time to return."),
            ("Your brain called", "It wants to know when you're coming back to train."),
        ]

        let message = messages[lastTrainedDaysAgo % messages.count]

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(identifier: "comeback", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Achievement Nudge

    func scheduleAchievementNudge(achievementName: String, progress: String) {
        let content = UNMutableNotificationContent()
        content.title = "Almost there!"
        content.body = "\(progress) to unlock \"\(achievementName)\". You got this!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "achievement_nudge", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Level Up

    func scheduleLevelUpNotification(level: Int, levelName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Level \(level) — \(levelName)!"
        content.body = "You leveled up! Keep training to reach the next milestone."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "level_up", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Weekly Brain Report

    func scheduleWeeklyReport(trainedDays: Int, avgScore: Double, streakLength: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weeklyReport"])

        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Brain Report"
        content.sound = .default

        if trainedDays == 0 {
            content.body = "You didn't train this week. Even 5 minutes helps!"
        } else {
            let scorePercent = Int(avgScore * 100)
            content.body = "This week: trained \(trainedDays) day\(trainedDays == 1 ? "" : "s"), avg score \(scorePercent)%, streak: \(streakLength) day\(streakLength == 1 ? "" : "s"). Keep it up!"
        }

        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 19    // 7 PM
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weeklyReport", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Retake Assessment Reminder

    private static let retakeIdentifier = "retake-reminder"

    func scheduleRetakeReminder(lastAssessmentDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.retakeIdentifier])

        guard let fireDate = Calendar.current.date(byAdding: .day, value: 7, to: lastAssessmentDate),
              fireDate > Date.now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your brain has been training!"
        content.body = "Retake your Brain Score to see how much you've improved"
        content.sound = .default

        let interval = fireDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        let request = UNNotificationRequest(identifier: Self.retakeIdentifier, content: content, trigger: trigger)

        center.add(request)
    }

    func cancelRetakeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.retakeIdentifier])
    }

    func cancelStreakRisk() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streak_risk"])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
