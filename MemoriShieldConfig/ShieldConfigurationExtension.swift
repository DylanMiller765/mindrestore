import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared")!

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        buildShieldConfig(appName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        buildShieldConfig(appName: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        buildShieldConfig(appName: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        buildShieldConfig(appName: webDomain.domain ?? category.localizedDisplayName)
    }

    private func buildShieldConfig(appName: String? = nil) -> ShieldConfiguration {
        let attemptCount = dailyAttemptCount
        let name = appName ?? "this app"

        let (title, subtitle) = pickMessage(attemptCount: attemptCount, appName: name)

        // Load mascot and scale it up for a larger display
        let mascotIcon: UIImage? = {
            guard let original = UIImage(named: "shield-mascot") else { return nil }
            let targetSize = CGSize(width: 120, height: 120)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { _ in
                original.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }()

        return ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: UIColor(red: 0.039, green: 0.039, blue: 0.059, alpha: 1.0),
            icon: mascotIcon,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor(white: 0.6, alpha: 1.0)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Play a game", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.29, green: 0.50, blue: 0.90, alpha: 1.0),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Stay focused", color: UIColor(white: 0.5, alpha: 1.0))
        )
    }

    /// Rotating Gen Z shield messages that escalate with attempt count.
    /// Designed to be screenshot-worthy and shareable.
    private func pickMessage(attemptCount: Int, appName: String) -> (String, String) {
        // Tier 1 (0-2 attempts) — friendly callout
        let tier1: [(String, String)] = [
            ("Bro really tried to open \(appName) 💀", "Brain game first."),
            ("Caught in 4K", "Play to unlock \(appName)."),
            ("Be so for real right now", "One game and you're free."),
            ("Nice try", "Beat the brain game to open \(appName)."),
            ("\(appName)? Brain first.", "You know the drill."),
            ("Not today", "Play a quick game to unlock."),
            ("Memo says no.", "Earn it with a brain game."),
        ]

        // Tier 2 (3-5 attempts) — pointed callout
        let tier2: [(String, String)] = [
            ("\(attemptCount) times. We're counting.", "Brain game to unlock \(appName)."),
            ("Again? Embarrassing.", "Beat the game to open \(appName)."),
            ("Your brain is begging you.", "Quick game to unlock."),
            ("We see you.", "One game and you're back in."),
            ("Bestie.", "\(attemptCount) attempts and counting."),
            ("This is your \(attemptCount)th attempt btw.", "Game first."),
        ]

        // Tier 3 (6+ attempts) — intervention mode
        let tier3: [(String, String)] = [
            ("\(attemptCount) tries today. Touch grass.", "Or play a brain game I guess."),
            ("Bro is COOKED.", "Put the phone down. Or play."),
            ("We need to talk.", "\(attemptCount) attempts. Concerning."),
            ("Put. The phone. Down.", "Or earn it with a brain game."),
            ("Get a grip my guy.", "Brain game to unlock if you must."),
            ("\(attemptCount) times? Be honest.", "Play a game or stay focused."),
            ("Memo is disappointed.", "\(attemptCount) attempts today."),
        ]

        let pool: [(String, String)]
        switch attemptCount {
        case 0...2: pool = tier1
        case 3...5: pool = tier2
        default:    pool = tier3
        }

        return pool.randomElement() ?? pool[0]
    }

    private var dailyAttemptCount: Int {
        let savedDate = sharedDefaults.object(forKey: "focus_daily_attempt_date") as? Date
        if let savedDate, Calendar.current.isDateInToday(savedDate) {
            return sharedDefaults.integer(forKey: "focus_daily_attempt_count")
        }
        return 0
    }
}
