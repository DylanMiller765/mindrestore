import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import RevenueCat

@main
struct MindRestoreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("appTheme") private var appTheme: String = AppTheme.light.rawValue

    init() {
        Analytics.configure()
        Purchases.logLevel = .info
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: "appl_NUUkNGthSiwlZSAtrDjAfxUGOPC")
                .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
                .build()
        )
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

    private var effectiveColorScheme: ColorScheme? {
        #if DEBUG
        if isDebugPaywallLaunch || isDebugFocusPassLaunch || isDebugInsightsLaunch { return .dark }
        #endif
        return colorScheme
    }

    #if DEBUG
    private var isDebugPaywallLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("--debug-paywall")
    }

    private var isDebugFocusPassLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("--debug-focus-pass")
    }

    private var isDebugInsightsLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.contains("--debug-insights") }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            rootView
                .preferredColorScheme(effectiveColorScheme)
        }
        .modelContainer(
            try! ModelContainer(
                for: User.self, Exercise.self, SpacedRepetitionCard.self,
                     DailySession.self, BrainScoreResult.self, Achievement.self,
                configurations: ModelConfiguration(cloudKitDatabase: .none)
            )
        )
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if isDebugPaywallLaunch {
            DebugPaywallHost()
        } else if isDebugFocusPassLaunch {
            DebugFocusPassHost()
        } else if isDebugInsightsLaunch {
            ProgressDashboardPreviewHost()
        } else {
            ContentView()
        }
        #else
        ContentView()
        #endif
    }
}

#if DEBUG
private struct DebugPaywallHost: View {
    @State private var storeService = StoreService()

    var body: some View {
        PaywallView(isHighIntent: true, triggerSource: "debug_paywall")
            .environment(storeService)
    }
}

private struct DebugFocusPassHost: View {
    @State private var focusModeService = FocusModeService()
    @State private var storeService = StoreService()

    var body: some View {
        FocusModeSetupView(initialStep: 3, onComplete: {})
            .environment(focusModeService)
            .environment(storeService)
    }
}
#endif

// MARK: - AppDelegate (notification handling)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Handle notification tap — convert deep link in userInfo to URL open
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = userInfo["deepLink"] as? String,
           let url = URL(string: deepLink) {
            let notificationType = response.notification.request.content.categoryIdentifier.isEmpty
                ? response.notification.request.identifier.components(separatedBy: "_").first ?? "unknown"
                : response.notification.request.content.categoryIdentifier
            Analytics.appOpenedFromNotification(notificationType: notificationType)
            UIApplication.shared.open(url)
        }
        completionHandler()
    }

    /// Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
