//
//  TotalActivityView.swift
//  FocusUnlocksReport
//
//  Renders the user's pickup count in Memori's Monkeytype-style typography.
//  The main app embeds this via DeviceActivityReport(context: .unlocks).
//

import SwiftUI
import FamilyControls
import ManagedSettings
import UIKit

struct TotalActivityView: View {
    /// Pickup / unlock count produced by TotalActivityReport.
    let totalActivity: Int

    // Design tokens (inline — extension can't import app modules)
    private let fg = Color.white.opacity(0.92)
    private let accent = Color(red: 0.408, green: 0.565, blue: 0.996) // #6890FE

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(totalActivity)")
                .font(.system(size: 140, weight: .bold, design: .monospaced))
                .kerning(-7)
                .foregroundStyle(fg)
                .shadow(color: accent.opacity(0.25), radius: 30)
            Text("×")
                .font(.system(size: 140, weight: .bold, design: .monospaced))
                .kerning(-7)
                .foregroundStyle(accent)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Screen-time stat for the home Idle card. Renders as `4.3 HRS` style.
struct ScreenTimeView: View {
    /// Yesterday's total screen-time duration in hours.
    let hours: Double

    private let coral = Color(red: 0.85, green: 0.40, blue: 0.35)
    private let accent = Color(red: 0.29, green: 0.50, blue: 0.90)
    private let fg = Color.white.opacity(0.92)
    private let fg2 = Color.white.opacity(0.68)

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", hours))
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(coral)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .shadow(color: coral.opacity(0.28), radius: 18, y: 8)

                Text("h")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(fg2)
            }

            Text("yesterday's Screen Time")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(fg2)

            Text("real Screen Time data")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .padding(.bottom, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Memo-flavored weekly Screen Time bars. The report filter provides the
/// 7-day window ending yesterday, so the rightmost bar is always yesterday.
struct WeeklyScreenTimeChartView: View {
    let hoursByDay: [Double]

    private let surface = Color(red: 0.039, green: 0.039, blue: 0.059)
    private let border = Color.white.opacity(0.10)
    private let grid = Color.white.opacity(0.08)
    private let fg2 = Color.white.opacity(0.58)
    private let mint = Color(red: 0.25, green: 0.68, blue: 0.55)
    private let periwinkle = Color(red: 0.49, green: 0.55, blue: 1.00)
    private let violet = Color(red: 0.65, green: 0.42, blue: 1.00)
    private let coral = Color(red: 0.85, green: 0.40, blue: 0.35)

    private var values: [Double] {
        let padded = Array(hoursByDay.prefix(7)) + Array(repeating: 0, count: max(0, 7 - hoursByDay.count))
        return Array(padded.prefix(7))
    }

    private var labels: [String] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let windowStart = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        let symbols = calendar.shortWeekdaySymbols

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: windowStart) ?? windowStart
            let weekday = calendar.component(.weekday, from: day) - 1
            let symbol = symbols[max(0, min(weekday, symbols.count - 1))]
            return offset == 6 ? symbol : String(symbol.prefix(1))
        }
    }

    private var axisMax: Double {
        let maxHours = max(values.max() ?? 1, 1)
        return max(2, (ceil((maxHours * 1.10) / 2) * 2))
    }

    private var average: Double {
        let activeValues = values.filter { $0 > 0 }
        guard !activeValues.isEmpty else { return 0 }
        return activeValues.reduce(0, +) / Double(activeValues.count)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let plotLeft: CGFloat = 30
            let plotRight: CGFloat = 30
            let plotTop: CGFloat = 16
            let plotBottom: CGFloat = 24
            let plotWidth = max(1, width - plotLeft - plotRight)
            let plotHeight = max(1, height - plotTop - plotBottom)
            let averageY = plotTop + plotHeight * (1 - min(max(average / axisMax, 0), 1))

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [surface.opacity(0.70), Color.white.opacity(0.035)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(border, lineWidth: 1)
                    )

                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        Rectangle()
                            .fill(grid.opacity(index == 0 ? 0 : 1))
                            .frame(width: index == 0 ? 0 : 1)
                        Spacer(minLength: 0)
                    }
                }
                .padding(.leading, 34)
                .padding(.trailing, 12)
                .padding(.vertical, 10)

                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 8) {
                            Text(axisLabel(for: index))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(fg2)
                                .frame(width: 26, alignment: .leading)
                            Rectangle()
                                .fill(grid)
                                .frame(height: 1)
                        }
                        if index < 2 { Spacer(minLength: 0) }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)

                if average > 0 {
                    Path { path in
                        path.move(to: CGPoint(x: plotLeft, y: averageY))
                        path.addLine(to: CGPoint(x: width - plotRight + 8, y: averageY))
                    }
                    .stroke(
                        mint.opacity(0.72),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 6])
                    )

                    Text("avg")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(mint.opacity(0.88))
                        .position(x: width - 14, y: averageY)
                }

                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        let barHeight = max(value > 0 ? 6 : 2, plotHeight * min(value / axisMax, 1))
                        let isYesterday = index == 6

                        VStack(spacing: 5) {
                            ZStack(alignment: .top) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [violet.opacity(0.98), periwinkle.opacity(0.96)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 18, height: barHeight)
                                    .opacity(value > 0 ? 1 : 0.22)
                                    .shadow(color: violet.opacity(isYesterday ? 0.55 : 0.25), radius: isYesterday ? 12 : 7, y: 4)

                                if isYesterday && value > 0 {
                                    Capsule()
                                        .fill(coral.opacity(0.95))
                                        .frame(width: 18, height: 5)
                                        .shadow(color: coral.opacity(0.55), radius: 8, y: 2)
                                }
                            }

                            Text(labels[index])
                                .font(.system(size: isYesterday ? 10 : 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(isYesterday ? coral.opacity(0.95) : fg2.opacity(0.82))
                                .frame(height: 12)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(width: plotWidth / CGFloat(values.count), height: plotHeight + 17, alignment: .bottom)
                    }
                }
                .frame(width: plotWidth, height: plotHeight + 17, alignment: .bottom)
                .position(x: plotLeft + plotWidth / 2, y: plotTop + (plotHeight + 17) / 2)
            }
        }
    }

    private func axisLabel(for index: Int) -> String {
        switch index {
        case 0: return "\(Int(axisMax.rounded()))h"
        case 1: return "\(Int((axisMax / 2).rounded()))h"
        default: return "0"
        }
    }
}

struct FocusHomeDashboardView: View {
    let data: FocusHomeDashboardData

    private let fg = Color.white.opacity(0.92)
    private let fg2 = Color.white.opacity(0.58)
    private let fg3 = Color.white.opacity(0.38)
    private let border = Color.white.opacity(0.10)
    private let coral = Color(red: 0.98, green: 0.42, blue: 0.35)
    private let accent = Color(red: 0.408, green: 0.565, blue: 0.996)

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 0) {
                metricBlock(title: "Screen Time Today", value: screenTimeLabel, color: coral)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(border)
                    .frame(width: 1, height: 44)

                metricBlock(title: "Phone pickups", value: "\(data.pickups)", color: fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
            }

            Rectangle()
                .fill(border)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 9) {
                Text("Top offenders")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)

                if data.topOffenders.isEmpty {
                    Text("No app activity yet today")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(fg3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 5)
                } else {
                    ForEach(Array(data.topOffenders.enumerated()), id: \.offset) { _, offender in
                        offenderRow(offender)
                    }
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricBlock(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(fg2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    @ViewBuilder
    private func offenderRow(_ offender: FocusHomeOffender) -> some View {
        HStack(spacing: 11) {
            appIcon(for: offender.application)

            Text(offender.application.localizedDisplayName ?? "App")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(fg)
                .lineLimit(1)

            Spacer()

            Text(durationLabel(offender.duration))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(fg2)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func appIcon(for application: Application) -> some View {
        if let token = application.token {
            Label(token)
                .labelStyle(.iconOnly)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent.opacity(0.18))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "app.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accent)
                )
        }
    }

    private var screenTimeLabel: String {
        durationLabel(data.screenTimeSeconds)
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }
}

struct FocusInsightsReceiptView: View {
    let data: FocusInsightsReceiptData
    @State private var showsAllPullers = false

    private struct ReceiptBucket: Hashable {
        let title: String
        let subtitle: String
        let seconds: TimeInterval
        let pickups: Int
        let isLatest: Bool
    }

    private enum ReceiptMood {
        case pulled
        case neutral
        case protected
    }

    private let fg = Color.white.opacity(0.95)
    private let fg2 = Color.white.opacity(0.68)
    private let fg3 = Color.white.opacity(0.45)
    private let hairline = Color.white.opacity(0.11)
    private let coral = Color(red: 1.00, green: 0.39, blue: 0.31)
    private let coralHot = Color(red: 1.00, green: 0.55, blue: 0.40)
    private let mint = Color(red: 0.31, green: 0.88, blue: 0.68)
    private let accent = Color(red: 0.30, green: 0.50, blue: 1.00)
    private let periwinkle = Color(red: 0.60, green: 0.68, blue: 1.00)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            receiptTimelineRail
            summaryReceiptCard
            pullSignalChart
            topPullers
            memoPushbackPanel
        }
        .padding(.top, 8)
        .padding(.bottom, 96)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            if showsAllPullers {
                pullerDrawer
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.smooth(duration: 0.34), value: showsAllPullers)
    }

    private var hasMemoPushback: Bool {
        data.protectedMinutes > 0 || data.unlockReps > 0 || data.blockedAttempts > 0
    }

    private var receiptProofBand: some View {
        let topOffender = data.topOffenders.first
        let memoAccent = hasMemoPushback ? mint : periwinkle

        return VStack(spacing: 10) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            coral.opacity(0.40),
                            hairline.opacity(0.90),
                            memoAccent.opacity(0.42)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            HStack(alignment: .center, spacing: 11) {
                HStack(spacing: 10) {
                    if let offender = topOffender {
                        appIcon(for: offender.application, size: 58)
                    } else {
                        fallbackAppIcon(size: 58, color: coral)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("PULLED")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(coral)
                            .lineLimit(1)

                        Text(topOffender?.application.localizedDisplayName ?? "Screen Time")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(fg)
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)

                        Text(topOffender.map { durationLabel($0.duration) } ?? compactDuration(data.latestDaySeconds))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(coralHot)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 7) {
                    Rectangle()
                        .fill(hairline.opacity(0.80))
                        .frame(width: 1, height: 32)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(fg3)

                    Rectangle()
                        .fill(hairline.opacity(0.80))
                        .frame(width: 1, height: 32)
                }
                .frame(width: 22)

                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(memoAccent.opacity(0.14))
                            .frame(width: 58, height: 58)

                        bundledMemoImage(hasMemoPushback ? "focus-memo-happy" : "focus-memo-neutral", size: 54)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(hasMemoPushback ? "PUSHED BACK" : "MEMO")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(memoAccent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)

                        Text(hasMemoPushback ? "Memo" : "Learning")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(fg)
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)

                        Text(hasMemoPushback ? durationLabel(TimeInterval(data.protectedMinutes * 60)) : "0m")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(memoAccent)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 2)

            HStack(spacing: 0) {
                receiptMetaItem(systemName: "shield.checkered", text: data.blockedAttempts == 1 ? "1 block" : "\(data.blockedAttempts) blocks")

                Rectangle()
                    .fill(hairline.opacity(0.70))
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, 14)

                receiptMetaItem(systemName: "lock.open", text: data.unlockReps == 1 ? "1 rep" : "\(data.unlockReps) reps")
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(hairline.opacity(0.64))
                    .frame(height: 1)
            }

            Text(receiptProofLine)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(fg2)
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .background(alignment: .leading) {
            Circle()
                .fill(coral.opacity(0.10))
                .blur(radius: 26)
                .frame(width: 120, height: 120)
                .offset(x: -46)
        }
        .background(alignment: .trailing) {
            Circle()
                .fill(memoAccent.opacity(0.10))
                .blur(radius: 28)
                .frame(width: 136, height: 136)
                .offset(x: 44)
        }
        .accessibilityElement(children: .combine)
    }

    private var receiptProofLine: String {
        let total = data.screenTimeSeconds > 0 ? durationLabel(data.screenTimeSeconds) : "--"
        let blocks = data.blockedAttempts == 1 ? "1 block" : "\(data.blockedAttempts) blocks"
        let reps = data.unlockReps == 1 ? "1 unlock rep" : "\(data.unlockReps) unlock reps"
        if hasMemoPushback {
            return "\(total) total pull · \(blocks) · \(reps)"
        }
        return "\(total) total pull · Memo is learning"
    }

    private var thinRule: some View {
        Rectangle()
            .fill(hairline)
            .frame(height: 1)
    }

    private var isTodayReceipt: Bool {
        data.days.count <= 2
    }

    private var rangeLabel: String {
        if isTodayReceipt { return "Today" }
        if data.days.count <= 8 { return "This week" }
        return "This month"
    }

    private var chartBuckets: [ReceiptBucket] {
        if data.days.count > 12 {
            let days = data.days
            let bucketSize = max(1, Int(ceil(Double(days.count) / 4.0)))
            return stride(from: 0, to: days.count, by: bucketSize).prefix(4).enumerated().map { index, start in
                let end = min(start + bucketSize, days.count)
                let slice = Array(days[start..<end])
                let totalSeconds = slice.reduce(0) { $0 + $1.screenTimeSeconds }
                let activeCount = max(slice.filter { $0.screenTimeSeconds > 0 }.count, 1)
                let avgSeconds = totalSeconds / Double(activeCount)
                let pickups = slice.reduce(0) { $0 + $1.pickups }
                return ReceiptBucket(
                    title: "Week \(index + 1)",
                    subtitle: compactDuration(avgSeconds),
                    seconds: avgSeconds,
                    pickups: pickups,
                    isLatest: end == days.count
                )
            }
        }

        let shown = Array(data.days.suffix(isTodayReceipt ? 2 : 7))
        return shown.enumerated().map { index, day in
            ReceiptBucket(
                title: dayLabel(for: day.date, isLatest: index == shown.count - 1),
                subtitle: day.date.formatted(.dateTime.day()),
                seconds: day.screenTimeSeconds,
                pickups: day.pickups,
                isLatest: index == shown.count - 1
            )
        }
    }

    private var receiptTimelineRail: some View {
        let buckets = chartBuckets
        let averageSeconds = averageSeconds(for: buckets)

        return HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(buckets.enumerated()), id: \.offset) { index, bucket in
                let mood = receiptMood(for: bucket, averageSeconds: averageSeconds)
                let accentColor = receiptMoodColor(mood)

                VStack(spacing: 6) {
                    Text(chartLabel(for: bucket).uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(bucket.isLatest ? fg : fg3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    Text(bucket.isLatest ? "Today" : bucket.subtitle)
                        .font(.system(size: bucket.isLatest ? 11 : 20, weight: .black, design: .rounded))
                        .foregroundStyle(bucket.isLatest ? fg : fg2)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)

                    timelineMiniBar(bucket: bucket, averageSeconds: averageSeconds, color: accentColor)
                        .frame(height: 38, alignment: .bottom)
                }
                .padding(.horizontal, bucket.isLatest ? 8 : 2)
                .padding(.top, 7)
                .padding(.bottom, 9)
                .frame(maxWidth: .infinity)
                .background {
                    if bucket.isLatest {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.052))
                    }
                }
                .overlay {
                    if bucket.isLatest {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(coral.opacity(0.62), lineWidth: 1.2)
                    }
                }
                .accessibilityLabel("\(bucket.title), \(receiptMoodAccessibilityLabel(mood))")
                .layoutPriority(bucket.isLatest ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func timelineMiniBar(bucket: ReceiptBucket, averageSeconds: TimeInterval, color: Color) -> some View {
        let maxSeconds = max(chartBuckets.map(\.seconds).max() ?? 1, 1)
        let barHeight = max(bucket.seconds > 0 ? 8 : 3, CGFloat(bucket.seconds / maxSeconds) * 32)
        let overAverage = max(0, bucket.seconds - averageSeconds)
        let overHeight = min(barHeight * 0.34, CGFloat(overAverage / maxSeconds) * 32)
        let baseHeight = max(6, barHeight - overHeight)

        return VStack(spacing: 0) {
            if overHeight > 0 {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(coral.opacity(bucket.isLatest ? 0.95 : 0.76))
                    .frame(width: bucket.isLatest ? 19 : 15, height: overHeight)
            } else if bucket.seconds > 0, bucket.seconds <= averageSeconds * 0.90 {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(mint.opacity(bucket.isLatest ? 0.95 : 0.74))
                    .frame(width: bucket.isLatest ? 19 : 15, height: 6)
            }

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            periwinkle.opacity(bucket.isLatest ? 1 : 0.78),
                            accent.opacity(bucket.isLatest ? 0.94 : 0.62)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: bucket.isLatest ? 19 : 15, height: baseHeight)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .shadow(color: color.opacity(bucket.isLatest ? 0.20 : 0.07), radius: bucket.isLatest ? 10 : 4, y: 3)
    }

    private var summaryReceiptCard: some View {
        summaryReceipt
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.036))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.34),
                                mint.opacity(0.24),
                                coral.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private var memoPushbackPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memo Pushback")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(mint)

            HStack(spacing: 10) {
                pushbackMetric(
                    value: durationLabel(TimeInterval(data.protectedMinutes * 60)),
                    label: "protected",
                    color: mint
                )

                pushbackMetric(
                    value: "\(data.unlockReps)",
                    label: data.unlockReps == 1 ? "unlock rep" : "unlock reps",
                    color: fg
                )

                pushbackMetric(
                    value: data.blockedAttempts == 1 ? "1 block" : "\(data.blockedAttempts) blocks",
                    label: "blocked",
                    color: coralHot
                )
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.036), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(mint.opacity(0.28), lineWidth: 1)
        )
    }

    private func pushbackMetric(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(fg3)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var receiptRail: some View {
        let buckets = chartBuckets
        let averageSeconds = averageSeconds(for: buckets)

        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(rangeLabel)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(mint)
                    .textCase(.uppercase)

                Spacer()

                Text("receipt slices")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(fg3)
            }

            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                        let mood = receiptMood(for: bucket, averageSeconds: averageSeconds)
                        let accentColor = receiptMoodColor(mood)

                        VStack(spacing: 5) {
                            Text(chartLabel(for: bucket).uppercased())
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(bucket.isLatest ? fg : fg2)
                                .lineLimit(1)

                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(bucket.isLatest ? 0.18 : 0.10))
                                    .frame(width: 42, height: 42)

                                bundledMemoImage(receiptMoodAsset(mood), size: 38)
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .frame(width: 62, alignment: .center)
                        .background {
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .fill(Color.white.opacity(bucket.isLatest ? 0.070 : 0.032))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .stroke(accentColor.opacity(bucket.isLatest ? 0.62 : 0.24), lineWidth: bucket.isLatest ? 1.2 : 1)
                        }
                        .overlay(alignment: .bottom) {
                            if bucket.isLatest {
                                Capsule()
                                    .fill(accentColor)
                                    .frame(width: 22, height: 2)
                                    .offset(y: 5)
                            }
                        }
                        .accessibilityLabel("\(bucket.title), \(receiptMoodAccessibilityLabel(mood))")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var summaryReceipt: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                receiptMetric(
                    title: isTodayReceipt ? "SCREEN TIME" : "DAILY AVG",
                    value: durationLabel(isTodayReceipt ? data.latestDaySeconds : data.dailyAverageSeconds),
                    suffix: isTodayReceipt ? nil : "/ day",
                    accentColor: isTodayReceipt ? fg : mint
                )

                divider(height: 42)

                receiptMetric(
                    title: isTodayReceipt ? "PICKUPS" : "TOP PULL",
                    value: isTodayReceipt ? "\(data.latestDayPickups)" : topPullLabel,
                    accentColor: isTodayReceipt ? mint : coral
                )
            }
            .frame(minHeight: 64, alignment: .top)

            thinRule

            HStack(spacing: 14) {
                receiptMetric(
                    title: "PEAK PULL",
                    value: peakLabel,
                    accentColor: coral
                )

                divider(height: 42)

                receiptMetric(
                    title: isTodayReceipt ? "TOP PULL" : "PICKUPS",
                    value: isTodayReceipt ? topPullLabel : "\(data.pickups)",
                    suffix: isTodayReceipt ? nil : "checks",
                    accentColor: isTodayReceipt ? coral : mint
                )
            }
            .frame(minHeight: 64, alignment: .top)

            thinRule

            if !isTodayReceipt {
                Text("\(durationLabel(data.screenTimeSeconds)) total in this receipt")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(fg3)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(receiptRead)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(fg2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 2)
    }

    private func receiptMetric(title: String, value: String, suffix: String? = nil, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.84)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(fg)
                    .monospacedDigit()
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)

                if let suffix {
                    Text(suffix)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(fg2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func divider(height: CGFloat) -> some View {
        Rectangle()
            .fill(hairline)
            .frame(width: 1, height: height)
    }

    private var pullSignalChart: some View {
        let buckets = chartBuckets
        let values = buckets.map(\.seconds)
        let maxSeconds = max(values.max() ?? 1, 1)
        let averageSeconds = averageSeconds(for: buckets)
        let lowIndex = values.enumerated().filter { $0.element > 0 }.min(by: { $0.element < $1.element })?.offset ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Feed Pull")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(fg)

                Spacer()

                Text("avg \(compactDuration(averageSeconds))")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(mint)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                let height = proxy.size.height
                let plotTop: CGFloat = 32
                let plotBottom: CGFloat = 30
                let plotLeading: CGFloat = 30
                let plotHeight = max(1, height - plotTop - plotBottom)
                let averageY = plotTop + plotHeight * (1 - min(max(averageSeconds / maxSeconds, 0), 1))

                ZStack(alignment: .topLeading) {
                    chartHourScale(maxSeconds: maxSeconds, plotTop: plotTop, plotBottom: plotBottom)
                        .frame(width: plotLeading - 5, height: height, alignment: .leading)

                    Path { path in
                        path.move(to: CGPoint(x: plotLeading, y: averageY))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: averageY))
                    }
                    .stroke(mint.opacity(0.48), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, dash: [7, 8]))

                    VStack(spacing: 0) {
                        ForEach([4, 3, 2, 1, 0], id: \.self) { _ in
                            Rectangle()
                                .fill(hairline.opacity(0.44))
                                .frame(height: 1)
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.leading, plotLeading)
                    .padding(.top, plotTop)
                    .padding(.bottom, plotBottom)

                    HStack(alignment: .bottom, spacing: buckets.count > 8 ? 14 : 9) {
                        ForEach(Array(buckets.enumerated()), id: \.offset) { index, bucket in
                            let baseHeight = max(bucket.seconds > 0 ? 10 : 4, CGFloat(bucket.seconds / maxSeconds) * plotHeight)
                            let isWonBack = index == lowIndex && bucket.seconds > 0 && bucket.seconds <= averageSeconds
                            let isLatest = bucket.isLatest
                            let isOverAverage = bucket.seconds > averageSeconds

                            VStack(spacing: 7) {
                                Color.clear
                                    .frame(height: 18)
                                pullBar(
                                    height: baseHeight,
                                    width: isLatest ? 31 : 26,
                                    isLatest: isLatest,
                                    isOverAverage: isOverAverage,
                                    isWonBack: isWonBack
                                )
                                .frame(height: plotHeight, alignment: .bottom)

                                Text(chartLabel(for: bucket))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(isLatest ? fg : fg3)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .bottom)
                        }
                    }
                    .padding(.leading, plotLeading)
                    .padding(.top, 0)
                    .padding(.bottom, 0)
                }
            }
            .frame(height: 186)

            thinRule
        }
    }

    private var chartAtmosphere: some View {
        Color.clear
    }

    private func chartHourScale(maxSeconds: TimeInterval, plotTop: CGFloat, plotBottom: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(chartAxisHour(maxSeconds))
            Spacer(minLength: 0)
            Text(chartAxisHour(maxSeconds / 2))
            Spacer(minLength: 0)
            Text("0")
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(fg3)
        .monospacedDigit()
        .padding(.top, plotTop - 3)
        .padding(.bottom, plotBottom + 12)
    }

    @ViewBuilder
    private func chartCallout(bucket: ReceiptBucket, isLatest: Bool, isPeak: Bool, isWonBack: Bool) -> some View {
        if isLatest {
            Text("now")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(fg)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.075), in: Capsule())
                .overlay(Capsule().stroke(periwinkle.opacity(0.32), lineWidth: 1))
        } else if isWonBack {
            Text("low")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(mint)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(mint.opacity(0.10), in: Capsule())
                .overlay(Capsule().stroke(mint.opacity(0.35), lineWidth: 1))
        } else if isPeak {
            Text("max")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(coralHot)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(coral.opacity(0.10), in: Capsule())
                .overlay(Capsule().stroke(coral.opacity(0.36), lineWidth: 1))
        } else {
            Color.clear
        }
    }

    private func pullBar(height: CGFloat, width: CGFloat, isLatest: Bool, isOverAverage: Bool, isWonBack: Bool) -> some View {
        let colors: [Color] = {
            if isOverAverage {
                return [
                    coralHot.opacity(isLatest ? 1 : 0.92),
                    coral.opacity(isLatest ? 0.95 : 0.78),
                    periwinkle.opacity(isLatest ? 1 : 0.86),
                    accent.opacity(isLatest ? 0.92 : 0.66)
                ]
            }
            if isWonBack {
                return [
                    mint.opacity(isLatest ? 0.95 : 0.82),
                    periwinkle.opacity(isLatest ? 1 : 0.88),
                    accent.opacity(isLatest ? 0.90 : 0.66)
                ]
            }
            return [
                periwinkle.opacity(isLatest ? 1 : 0.88),
                accent.opacity(isLatest ? 0.96 : 0.68)
            ]
        }()

        return RoundedRectangle(cornerRadius: width * 0.46, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)
            .overlay(alignment: .top) {
                if isWonBack {
                    Capsule()
                        .fill(mint)
                        .frame(width: width * 0.92, height: 5)
                        .offset(y: -2)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.46, style: .continuous)
                    .stroke(Color.white.opacity(isLatest ? 0.16 : 0.06), lineWidth: 1)
            )
            .shadow(color: (isOverAverage ? coral : periwinkle).opacity(isLatest ? 0.30 : 0.14), radius: isLatest ? 14 : 8, y: 4)
    }

    private var topPullers: some View {
        let defaultCount = 3
        let pullers = Array(data.topOffenders.prefix(defaultCount))
        let canExpand = data.topOffenders.count > defaultCount

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Top Pullers")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(fg)

                Spacer(minLength: 0)

                HStack(spacing: 13) {
                    Text("TIME")
                        .foregroundStyle(coralHot)
                    Text("OPENS")
                        .foregroundStyle(fg3)
                    Text("SHARE")
                        .foregroundStyle(coralHot)
                }
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.7)

                if canExpand {
                    Button {
                        withAnimation(.smooth(duration: 0.34)) {
                            showsAllPullers = true
                        }
                    } label: {
                        Text("View more")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(mint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.065), in: Capsule())
                            .overlay(Capsule().stroke(hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View more top pullers")
                }
            }

            if data.topOffenders.isEmpty {
                Text("App-level activity unavailable. Screen Time sometimes hides app tokens.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(fg3)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            } else {
                pullerRows(pullers)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.036), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(hairline.opacity(0.90), lineWidth: 1)
        )
    }

    private var pullerDrawer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Top Pullers")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(fg)

                Spacer()

                Button {
                    withAnimation(.smooth(duration: 0.34)) {
                        showsAllPullers = false
                    }
                } label: {
                    Text("Show less")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(fg2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.075), in: Capsule())
                        .overlay(Capsule().stroke(hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show fewer top pullers")
            }

            ScrollView {
                pullerRows(Array(data.topOffenders.prefix(10)))
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 338)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.045, green: 0.045, blue: 0.070).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 28, y: 16)
    }

    private func pullerRows(_ pullers: [FocusHomeOffender]) -> some View {
        return VStack(spacing: 0) {
            ForEach(Array(pullers.enumerated()), id: \.offset) { index, offender in
                offenderRow(offender)
                if index < pullers.count - 1 {
                    thinRule
                }
            }
        }
    }

    private func offenderRow(_ offender: FocusHomeOffender) -> some View {
        HStack(spacing: 13) {
            appIcon(for: offender.application, size: 38)

            Text(offender.application.localizedDisplayName ?? "App")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(fg)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 0)

            Text(durationLabel(offender.duration))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(coralHot)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: 62, alignment: .trailing)

            Text("\(offender.pickups) opens")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(fg2)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .frame(width: 58, alignment: .trailing)

            Text(offenderShare(offender))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(coralHot)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private func appIcon(for application: Application, size: CGFloat) -> some View {
        if let token = application.token {
            Label(token)
                .labelStyle(.iconOnly)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(accent.opacity(0.18))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "app.fill")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(accent)
                )
        }
    }

    private func fallbackAppIcon(size: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(color.opacity(0.14))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(color.opacity(0.90))
            )
    }

    private func receiptMetaItem(systemName: String, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(fg3)

            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(fg2)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func offenderShare(_ offender: FocusHomeOffender) -> String {
        guard data.screenTimeSeconds > 0 else { return "0%" }
        let percent = Int((offender.duration / data.screenTimeSeconds * 100).rounded())
        return "\(percent)%"
    }

    private func averageSeconds(for buckets: [ReceiptBucket]) -> TimeInterval {
        let active = buckets.map(\.seconds).filter { $0 > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0, +) / Double(active.count)
    }

    private func receiptMood(for bucket: ReceiptBucket, averageSeconds: TimeInterval) -> ReceiptMood {
        guard bucket.seconds > 0, averageSeconds > 0 else { return .neutral }
        if bucket.seconds >= averageSeconds * 1.10 { return .pulled }
        if bucket.seconds <= averageSeconds * 0.90 { return .protected }
        return .neutral
    }

    private func receiptMoodColor(_ mood: ReceiptMood) -> Color {
        switch mood {
        case .pulled: return coral
        case .neutral: return periwinkle
        case .protected: return mint
        }
    }

    private func receiptMoodAsset(_ mood: ReceiptMood) -> String {
        switch mood {
        case .pulled: return "focus-memo-sad"
        case .neutral: return "focus-memo-neutral"
        case .protected: return "focus-memo-happy"
        }
    }

    @ViewBuilder
    private func bundledMemoImage(_ name: String, size: CGFloat) -> some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "brain.head.profile")
                .font(.system(size: size * 0.46, weight: .black))
                .foregroundStyle(periwinkle)
                .frame(width: size, height: size)
        }
    }

    private func receiptMoodAccessibilityLabel(_ mood: ReceiptMood) -> String {
        switch mood {
        case .pulled: return "above average pull"
        case .neutral: return "near average pull"
        case .protected: return "below average pull"
        }
    }

    private var peakLabel: String {
        guard let peakDay = data.peakDay, peakDay.screenTimeSeconds > 0 else { return "--" }
        let day = peakDay.date.formatted(.dateTime.weekday(.abbreviated))
        return "\(day) · \(durationLabel(peakDay.screenTimeSeconds))"
    }

    private var topPullLabel: String {
        guard let offender = data.topOffenders.first else { return "--" }
        return offender.application.localizedDisplayName ?? "App"
    }

    private var receiptRead: String {
        if let offender = data.topOffenders.first {
            let app = offender.application.localizedDisplayName ?? "An app"
            return "\(app) pulled \(offenderShare(offender)) of this receipt."
        }

        if data.screenTimeSeconds > 0 {
            return "Screen Time exposed totals, but not app-level pullers."
        }

        return "Connect Screen Time to see what pulled you back."
    }

    private func dayLabel(for date: Date, isLatest: Bool) -> String {
        if isLatest { return "Today" }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func chartLabel(for bucket: ReceiptBucket) -> String {
        if bucket.title.hasPrefix("Week") {
            return bucket.title.replacingOccurrences(of: "Week ", with: "W")
        }

        return String(bucket.title.prefix(3))
    }

    private func chartAxisHour(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        if hours < 1 && seconds > 0 { return "<1h" }
        return "\(Int(hours.rounded()))h"
    }

    private func compactDuration(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "--" }
        let totalMinutes = Int((seconds / 60).rounded())
        let hourPart = totalMinutes / 60
        let minutePart = totalMinutes % 60
        if hourPart == 0 { return "\(minutePart)m" }
        if minutePart == 0 { return "\(hourPart)h" }
        return "\(hourPart)h \(minutePart)m"
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }
}

#Preview("Unlocks") {
    TotalActivityView(totalActivity: 287)
        .preferredColorScheme(.dark)
        .padding()
        .background(Color.black)
}

#Preview("Screen Time") {
    ScreenTimeView(hours: 4.3)
        .preferredColorScheme(.dark)
        .padding()
        .background(Color.black)
}

#Preview("Weekly Screen Time") {
    WeeklyScreenTimeChartView(hoursByDay: [6.2, 7.8, 5.1, 9.4, 4.2, 8.1, 11.9])
        .preferredColorScheme(.dark)
        .frame(height: 106)
        .padding()
        .background(Color.black)
}
