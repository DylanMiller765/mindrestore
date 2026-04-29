//
//  FocusUnlocksReport.swift
//  FocusUnlocksReport
//

import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct FocusUnlocksReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { totalActivity in
            TotalActivityView(totalActivity: totalActivity)
        }
        ScreenTimeReport { hours in
            ScreenTimeView(hours: hours)
        }
        ScreenTimeAverageReport { hours in
            ScreenTimeView(hours: hours)
        }
        ScreenTimeWeeklyReport { hoursByDay in
            WeeklyScreenTimeChartView(hoursByDay: hoursByDay)
        }
    }
}
