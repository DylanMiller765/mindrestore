//
//  TotalActivityReport.swift
//  FocusUnlocksReport
//

import DeviceActivity
import ExtensionKit
import Foundation
import ManagedSettings
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
    /// Home dashboard: today's Screen Time, pickups, and top apps.
    static let focusHomeDashboard = Self("Focus Home Dashboard")
    /// Insights receipt: selected-range Screen Time, pickups, top apps, and trend.
    static let focusInsightsReceipt = Self("Focus Insights Receipt")
}

struct FocusHomeOffender: Hashable {
    let application: Application
    let duration: TimeInterval
    let pickups: Int
}

struct FocusHomeDashboardData: Hashable {
    let screenTimeSeconds: TimeInterval
    let pickups: Int
    let topOffenders: [FocusHomeOffender]
}

struct FocusReceiptDay: Hashable {
    let date: Date
    let screenTimeSeconds: TimeInterval
    let pickups: Int
}

struct FocusInsightsReceiptData: Hashable {
    let screenTimeSeconds: TimeInterval
    let pickups: Int
    let latestDaySeconds: TimeInterval
    let latestDayPickups: Int
    let dailyAverageSeconds: TimeInterval
    let peakDay: FocusReceiptDay?
    let topOffenders: [FocusHomeOffender]
    let days: [FocusReceiptDay]
    let protectedMinutes: Int
    let unlockReps: Int
    let blockedAttempts: Int
    let targetCount: Int
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

/// Today's compact home dashboard. It keeps Screen Time details inside the
/// DeviceActivity extension, where Apple exposes per-app usage.
struct FocusHomeDashboardReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .focusHomeDashboard
    let content: (FocusHomeDashboardData) -> FocusHomeDashboardView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> FocusHomeDashboardData {
        var totalSeconds: TimeInterval = 0
        var totalPickups = 0
        var appsByName: [String: FocusHomeOffender] = [:]

        for await activity in data {
            for await segment in activity.activitySegments {
                totalSeconds += segment.totalActivityDuration
                totalPickups += segment.totalPickupsWithoutApplicationActivity

                for await category in segment.categories {
                    for await app in category.applications {
                        totalPickups += app.numberOfPickups

                        let key = app.application.bundleIdentifier
                            ?? app.application.localizedDisplayName
                            ?? "\(app.application.hashValue)"

                        if let existing = appsByName[key] {
                            appsByName[key] = FocusHomeOffender(
                                application: existing.application,
                                duration: existing.duration + app.totalActivityDuration,
                                pickups: existing.pickups + app.numberOfPickups
                            )
                        } else {
                            appsByName[key] = FocusHomeOffender(
                                application: app.application,
                                duration: app.totalActivityDuration,
                                pickups: app.numberOfPickups
                            )
                        }
                    }
                }
            }
        }

        let topOffenders = appsByName.values
            .filter { $0.duration > 0 }
            .sorted { lhs, rhs in
                if lhs.duration == rhs.duration { return lhs.pickups > rhs.pickups }
                return lhs.duration > rhs.duration
            }
            .prefix(3)

        return FocusHomeDashboardData(
            screenTimeSeconds: totalSeconds,
            pickups: totalPickups,
            topOffenders: Array(topOffenders)
        )
    }
}

/// Selected-range Focus Insights receipt. The main app controls the filter
/// window, while this extension keeps Apple-exposed app identity and icons in
/// the report process where FamilyControls can render them.
struct FocusInsightsReceiptReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .focusInsightsReceipt
    let content: (FocusInsightsReceiptData) -> FocusInsightsReceiptView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> FocusInsightsReceiptData {
        let calendar = Calendar.current
        var totalSeconds: TimeInterval = 0
        var totalPickups = 0
        var appsByName: [String: FocusHomeOffender] = [:]
        var totalsByDay: [Date: TimeInterval] = [:]
        var pickupsByDay: [Date: Int] = [:]

        for await activity in data {
            for await segment in activity.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                totalSeconds += segment.totalActivityDuration
                totalPickups += segment.totalPickupsWithoutApplicationActivity
                totalsByDay[day, default: 0] += segment.totalActivityDuration
                pickupsByDay[day, default: 0] += segment.totalPickupsWithoutApplicationActivity

                for await category in segment.categories {
                    for await app in category.applications {
                        totalPickups += app.numberOfPickups
                        pickupsByDay[day, default: 0] += app.numberOfPickups

                        let key = app.application.bundleIdentifier
                            ?? app.application.localizedDisplayName
                            ?? "\(app.application.hashValue)"

                        if let existing = appsByName[key] {
                            appsByName[key] = FocusHomeOffender(
                                application: existing.application,
                                duration: existing.duration + app.totalActivityDuration,
                                pickups: existing.pickups + app.numberOfPickups
                            )
                        } else {
                            appsByName[key] = FocusHomeOffender(
                                application: app.application,
                                duration: app.totalActivityDuration,
                                pickups: app.numberOfPickups
                            )
                        }
                    }
                }
            }
        }

        let topOffenders = appsByName.values
            .filter { $0.duration > 0 && $0.application.token != nil && !isMemoApplication($0.application) }
            .sorted { lhs, rhs in
                if lhs.duration == rhs.duration { return lhs.pickups > rhs.pickups }
                return lhs.duration > rhs.duration
            }
            .prefix(10)

        let orderedDays = totalsByDay.keys.sorted()
        let days = orderedDays.map { day in
            FocusReceiptDay(
                date: day,
                screenTimeSeconds: totalsByDay[day] ?? 0,
                pickups: pickupsByDay[day] ?? 0
            )
        }
        let activeDays = max(days.filter { $0.screenTimeSeconds > 0 }.count, 1)
        let latestDay = days.last
        let peakDay = days.max { lhs, rhs in
            lhs.screenTimeSeconds < rhs.screenTimeSeconds
        }

        let defaults = UserDefaults(suiteName: "group.com.memori.shared")
        let receipt = FocusInsightsReceiptData(
            screenTimeSeconds: totalSeconds,
            pickups: totalPickups,
            latestDaySeconds: latestDay?.screenTimeSeconds ?? totalSeconds,
            latestDayPickups: latestDay?.pickups ?? totalPickups,
            dailyAverageSeconds: totalSeconds / Double(activeDays),
            peakDay: peakDay,
            topOffenders: Array(topOffenders),
            days: days,
            protectedMinutes: defaults?.integer(forKey: "focus_receipt_protected_minutes") ?? 0,
            unlockReps: defaults?.integer(forKey: "focus_receipt_unlock_reps") ?? 0,
            blockedAttempts: defaults?.integer(forKey: "focus_receipt_blocked_attempts") ?? 0,
            targetCount: defaults?.integer(forKey: "focus_receipt_target_count") ?? 0
        )
        persistLatestFocusReceipt(receipt)
        return receipt
    }

    private func isMemoApplication(_ application: Application) -> Bool {
        let bundleIdentifier = application.bundleIdentifier?.lowercased() ?? ""
        let displayName = application.localizedDisplayName?.lowercased() ?? ""
        return bundleIdentifier.contains("mindrestore")
            || bundleIdentifier.contains("memori")
            || displayName == "memo"
            || displayName == "memori"
            || displayName == "mindrestore"
    }

    private func persistLatestFocusReceipt(_ receipt: FocusInsightsReceiptData) {
        let defaults = UserDefaults(suiteName: "group.com.memori.shared")
        let topOffender = receipt.topOffenders.first
        defaults?.set(receipt.screenTimeSeconds, forKey: "focus_receipt_screen_time_seconds")
        defaults?.set(receipt.dailyAverageSeconds, forKey: "focus_receipt_daily_average_seconds")
        defaults?.set(receipt.latestDaySeconds, forKey: "focus_receipt_latest_day_seconds")
        defaults?.set(receipt.pickups, forKey: "focus_receipt_pickups")
        defaults?.set(topOffender?.application.localizedDisplayName, forKey: "focus_receipt_top_app_name")
        defaults?.set(topOffender?.duration ?? 0, forKey: "focus_receipt_top_app_seconds")
        defaults?.set(topOffender?.pickups ?? 0, forKey: "focus_receipt_top_app_pickups")
        defaults?.set(Date(), forKey: "focus_receipt_updated_at")
    }
}
