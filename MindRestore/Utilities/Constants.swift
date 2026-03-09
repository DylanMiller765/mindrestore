import Foundation

enum Constants {
    enum ProductIDs {
        static let monthly = "com.memori.pro.monthly"
        static let annual = "com.memori.pro.annual"
    }

    enum Defaults {
        static let dailyGoal = 3
        static let reminderHour = 9
        static let reminderMinute = 0
        static let freeExercisesPerDay = 3
    }

    enum Exercise {
        static let spacedRepetitionSessionSize = 15
        static let dualNBackTrialInterval: TimeInterval = 2.5
        static let activeRecallDisplayDuration: TimeInterval = 30
    }
}
