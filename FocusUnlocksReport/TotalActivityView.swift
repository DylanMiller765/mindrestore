//
//  TotalActivityView.swift
//  FocusUnlocksReport
//
//  Renders the user's pickup count in Memori's Monkeytype-style typography.
//  The main app embeds this via DeviceActivityReport(context: .unlocks).
//

import SwiftUI

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

    private let fg = Color.white.opacity(0.92)
    private let fg2 = Color.white.opacity(0.55)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(String(format: "%.1f", hours))
                .font(.system(size: 56, weight: .bold, design: .monospaced))
                .kerning(-1.5)
                .foregroundStyle(fg)
            Text("HRS")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .kerning(-0.3)
                .foregroundStyle(fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
