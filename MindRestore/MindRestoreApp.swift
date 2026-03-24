import SwiftUI
import SwiftData
import TelemetryDeck
import UIKit

@main
struct MindRestoreApp: App {
    @AppStorage("appTheme") private var appTheme: String = AppTheme.light.rawValue

    init() {
        Analytics.configure()
        configureTabBarAppearance()
    }

    private func configureTabBarAppearance() {
        // Force non-translucent tab bar to avoid iOS 26 Liquid Glass black icons
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground

        let gray = UIColor(white: 0.55, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.iconColor = gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: gray]
        appearance.inlineLayoutAppearance.normal.iconColor = gray
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: gray]
        appearance.compactInlineLayoutAppearance.normal.iconColor = gray
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: gray]

        let accent = UIColor(AppColors.accent)
        appearance.stackedLayoutAppearance.selected.iconColor = accent
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        appearance.inlineLayoutAppearance.selected.iconColor = accent
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        appearance.compactInlineLayoutAppearance.selected.iconColor = accent
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private var colorScheme: ColorScheme? {
        AppTheme(rawValue: appTheme)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
        .modelContainer(for: [
            User.self,
            Exercise.self,
            SpacedRepetitionCard.self,
            DailySession.self,
            BrainScoreResult.self,
            Achievement.self,
        ])
    }
}
