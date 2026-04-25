//
//  TotalActivityReport.swift
//  FocusUnlocksReport
//

import DeviceActivity
import ExtensionKit
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
        return totalSeconds / 3600.0
    }
}
