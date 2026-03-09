import Foundation
import GameKit
import SwiftUI

@MainActor @Observable
final class GameCenterService {

    // MARK: - State

    var isAuthenticated = false

    // MARK: - Leaderboard IDs

    static let brainScoreLeaderboard = "com.dylanmiller.mindrestore.leaderboard.brainScore"
    static let weeklyXPLeaderboard = "com.dylanmiller.mindrestore.leaderboard.weeklyXP"
    static let longestStreakLeaderboard = "com.dylanmiller.mindrestore.leaderboard.longestStreak"
    static let reactionTimeLeaderboard = "com.dylanmiller.mindrestore.leaderboard.reactionTime"
    static let colorMatchLeaderboard = "com.dylanmiller.mindrestore.leaderboard.colorMatch"
    static let speedMatchLeaderboard = "com.dylanmiller.mindrestore.leaderboard.speedMatch"
    static let visualMemoryLeaderboard = "com.dylanmiller.mindrestore.leaderboard.visualMemory"
    static let numberMemoryLeaderboard = "com.dylanmiller.mindrestore.leaderboard.numberMemory"
    static let mathSpeedLeaderboard = "com.dylanmiller.mindrestore.leaderboard.mathSpeed"
    static let dualNBackLeaderboard = "com.dylanmiller.mindrestore.leaderboard.dualNBack"

    // MARK: - Achievement ID Mapping

    static func gameCenterAchievementID(for type: AchievementType) -> String {
        "com.dylanmiller.mindrestore.achievement.\(type.rawValue)"
    }

    // MARK: - Authentication

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                if let viewController {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(viewController, animated: true)
                    }
                    return
                }

                if let error {
                    print("[GameCenterService] Authentication error: \(error.localizedDescription)")
                }

                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    // MARK: - Score Reporting

    func reportScore(_ score: Int, leaderboardID: String) {
        guard isAuthenticated else { return }

        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [leaderboardID]
                )
            } catch {
                print("[GameCenterService] Failed to report score: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Achievement Reporting

    func reportAchievement(_ id: String, percentComplete: Double) {
        guard isAuthenticated else { return }

        Task {
            let achievement = GKAchievement(identifier: id)
            achievement.percentComplete = percentComplete
            achievement.showsCompletionBanner = true

            do {
                try await GKAchievement.report([achievement])
            } catch {
                print("[GameCenterService] Failed to report achievement: \(error.localizedDescription)")
            }
        }
    }

    /// Report an app achievement as fully completed to Game Center.
    func reportAchievement(for type: AchievementType) {
        let gcID = Self.gameCenterAchievementID(for: type)
        reportAchievement(gcID, percentComplete: 100.0)
    }

    // MARK: - Show Game Center UI

    func showLeaderboard(leaderboardID: String = brainScoreLeaderboard) {
        guard isAuthenticated else { return }
        presentGameCenterVC(state: .leaderboards, leaderboardID: leaderboardID)
    }

    func showAchievements() {
        guard isAuthenticated else { return }
        presentGameCenterVC(state: .achievements)
    }

    // MARK: - Private

    private func presentGameCenterVC(
        state: GKGameCenterViewControllerState,
        leaderboardID: String? = nil
    ) {
        let gcVC: GKGameCenterViewController
        if let leaderboardID, state == .leaderboards {
            gcVC = GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime)
        } else {
            gcVC = GKGameCenterViewController(state: state)
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        // Walk the presented VC chain to find the topmost one
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        gcVC.gameCenterDelegate = GameCenterDismissHandler.shared
        topVC.present(gcVC, animated: true)
    }
}

// MARK: - Dismiss Handler

/// Singleton handler for dismissing the Game Center view controller.
private final class GameCenterDismissHandler: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDismissHandler()

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
