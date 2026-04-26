//
//  TotalActivityReport.swift
//  FocusUnlocksReport
//

import DeviceActivity
import ExtensionKit
import Foundation
import SwiftUI

extension DeviceActivityReport.Context {
    /// Yesterday's phone-unlock (pickup) count.
    static let unlocks = Self("Unlocks Count")
    /// Yesterday's total screen time (in hours).
    static let screenTime = Self("Screen Time")
}

/// Sums phone pickups across all apps + pickups-without-app-activity.
struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .unlocks
    let content: (Int) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> Int {
        var total = 0
        for await activity in data {
            for await segment in activity.activitySegments {
                total += segment.totalPickupsWithoutApplicationActivity
                for await category in segment.categories {
                    for await app in category.applications {
                        total += app.numberOfPickups
                    }
                }
            }
        }
        UserDefaults(suiteName: "group.com.memori.shared")?.set(total, forKey: "onboarding_yesterday_unlocks")
        return total
    }
}

/// Total screen-time duration for the configured filter window, returned as hours (Double).
struct ScreenTimeReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .screenTime
    let content: (Double) -> ScreenTimeView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> Double {
        var totalSeconds: TimeInterval = 0
        for await activity in data {
            for await segment in activity.activitySegments {
                totalSeconds += segment.totalActivityDuration
            }
        }
        let hours = totalSeconds / 3600.0
        if hours > 0 {
            let shared = UserDefaults(suiteName: "group.com.memori.shared")
            shared?.set(hours, forKey: "onboarding_daily_screen_time_hours")
            shared?.set(Date(), forKey: "onboarding_screen_time_hours_updated_at")
        }
        return hours
    }
}
