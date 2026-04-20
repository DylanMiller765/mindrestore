import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared")!
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard sharedDefaults.bool(forKey: "focus_mode_enabled") else { return }

        if let data = sharedDefaults.data(forKey: "focus_activity_selection"),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            let categories = selection.categoryTokens
            store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}
