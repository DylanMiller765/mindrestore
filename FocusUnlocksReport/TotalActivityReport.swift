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
    /// Average daily screen time over the configured multi-day window.
    static let screenTimeAverage = Self("Screen Time Daily Average")
    /// Daily screen-time bars for the 7-day window ending yesterday.
    static let screenTimeWeekly = Self("Screen Time Weekly")
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

/// Average screen-time duration per day for the configured filter window.
struct ScreenTimeAverageReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .screenTimeAverage
    let content: (Double) -> ScreenTimeView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> Double {
        var totalSeconds: TimeInterval = 0
        var segmentCount = 0

        for await activity in data {
            for await segment in activity.activitySegments {
                totalSeconds += segment.totalActivityDuration
                segmentCount += 1
            }
        }

        let averageHours = (totalSeconds / Double(max(segmentCount, 1))) / 3600.0
        if averageHours > 0 {
            let shared = UserDefaults(suiteName: "group.com.memori.shared")
            shared?.set(averageHours, forKey: "onboarding_daily_screen_time_hours")
            shared?.set(Date(), forKey: "onboarding_screen_time_hours_updated_at")
        }
        return averageHours
    }
}

/// Daily screen-time totals for the configured 7-day window, returned as hours.
struct ScreenTimeWeeklyReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .screenTimeWeekly
    let content: ([Double]) -> WeeklyScreenTimeChartView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> [Double] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let windowStart = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        var totalsByDay: [Date: TimeInterval] = [:]

        for await activity in data {
            for await segment in activity.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                totalsByDay[day, default: 0] += segment.totalActivityDuration
            }
        }

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: windowStart) ?? windowStart
            return (totalsByDay[day] ?? 0) / 3600.0
        }
    }
}
