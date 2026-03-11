import Foundation
import TelemetryDeck

enum Analytics {
    // Replace with your actual TelemetryDeck App ID
    static let appID = "07CABBEB-051B-4AC3-937F-FD0A276D09C7"

    static func configure() {
        let config = TelemetryDeck.Config(appID: appID)
        TelemetryDeck.initialize(config: config)
    }

    // MARK: - Onboarding

    static func onboardingCompleted(goals: [String]) {
        TelemetryDeck.signal("onboarding.completed", parameters: [
            "goalCount": "\(goals.count)",
            "goals": goals.joined(separator: ",")
        ])
    }

    static func onboardingSkippedAssessment() {
        TelemetryDeck.signal("onboarding.skippedAssessment")
    }

    // MARK: - Exercises

    static func exerciseCompleted(game: String, score: Double, difficulty: Int) {
        TelemetryDeck.signal("exercise.completed", parameters: [
            "game": game,
            "score": String(format: "%.2f", score),
            "difficulty": "\(difficulty)"
        ])
    }

    // MARK: - Brain Score

    static func brainScoreCompleted(score: Int, brainAge: Int) {
        TelemetryDeck.signal("brainScore.completed", parameters: [
            "score": "\(score)",
            "brainAge": "\(brainAge)"
        ])
    }

    // MARK: - Paywall

    static func paywallShown(trigger: String = "unknown") {
        TelemetryDeck.signal("paywall.shown", parameters: [
            "trigger": trigger
        ])
    }

    static func paywallConverted(plan: String) {
        TelemetryDeck.signal("paywall.converted", parameters: [
            "plan": plan
        ])
    }

    static func paywallDismissed() {
        TelemetryDeck.signal("paywall.dismissed")
    }

    // MARK: - Sharing

    static func shareTapped(type: String) {
        TelemetryDeck.signal("share.tapped", parameters: [
            "type": type
        ])
    }

    // MARK: - Engagement

    static func streakUpdated(streak: Int) {
        TelemetryDeck.signal("streak.updated", parameters: [
            "streak": "\(streak)"
        ])
    }

    static func dailyChallengeCompleted() {
        TelemetryDeck.signal("dailyChallenge.completed")
    }

    static func tabViewed(tab: String) {
        TelemetryDeck.signal("tab.viewed", parameters: [
            "tab": tab
        ])
    }
}
