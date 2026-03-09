import SwiftUI
import SwiftData

@main
struct MindRestoreApp: App {
    @AppStorage("appTheme") private var appTheme: String = AppTheme.light.rawValue

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
