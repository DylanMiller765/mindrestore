import Foundation

/// Pure, UI-free content for the onboarding "Memo building your plan" beats.
/// Given the data collected so far, produces Memo's speech bubble and the
/// clipboard line items. No SwiftUI — fully unit-testable.
struct PlanBuildBeatContent {
    enum Beat: CaseIterable {
        case goals, age, screenTime, final
    }

    struct Line: Equatable {
        let label: String
        let value: String
    }

    let beat: Beat
    let goals: Set<UserFocusGoal>
    let age: Int
    let dailyScreenTimeHours: Double
    let isEstimate: Bool

    private static let lifeExpectancy = 80

    private var yearsAhead: Int { max(0, Self.lifeExpectancy - age) }

    /// Human-readable hours/day, clamped to "8h+" for high estimates (mirrors
    /// the existing screen-time presentation rule).
    private var hoursLabel: String {
        if dailyScreenTimeHours >= 8 && isEstimate { return "8h+" }
        // Trim trailing ".0" so 4.0 → "4", 4.2 → "4.2".
        let rounded = (dailyScreenTimeHours * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))h"
        }
        return "\(rounded)h"
    }

    /// Days per year spent on screen = hours/day * 365 / 24, rounded.
    private var daysPerYear: Int {
        Int((dailyScreenTimeHours * 365 / 24).rounded())
    }

    /// Goal phrase, reusing the same mapping as `onboardingPlanGoalSummary`.
    static func goalSummary(_ goals: Set<UserFocusGoal>) -> String {
        if goals.contains(.screenTimeFrying) { return "hours back" }
        if goals.contains(.doomscrolling) { return "sleep protected" }
        if goals.contains(.attentionShot) { return "attention guarded" }
        if goals.contains(.loseFocus) { return "focus that holds" }
        if goals.contains(.forgetInstantly) { return "memory that sticks" }
        if goals.contains(.getSharper) { return "sharper scores" }
        return "hours back"
    }

    var bubble: String {
        switch beat {
        case .goals:
            return "Hours back. That's the mission."
        case .age:
            return "\(age)? You've got ~\(yearsAhead) years of phone ahead."
        case .screenTime:
            return "\(hoursLabel) a day… that's ~\(daysPerYear) days a year gone."
        case .final:
            return "Your counterattack's ready."
        }
    }

    /// The single line THIS beat adds (nil for the final beat, which adds none).
    var newLine: Line? {
        switch beat {
        case .goals:
            return Line(label: "Goal", value: Self.goalSummary(goals))
        case .age:
            return Line(label: "Age", value: "\(age) · ~\(yearsAhead) yrs ahead")
        case .screenTime:
            return Line(label: "Screen time", value: "\(hoursLabel)/day")
        case .final:
            return nil
        }
    }

    /// Every line earned up to AND including `upTo`, in beat order.
    static func cumulativeLines(
        upTo: Beat,
        goals: Set<UserFocusGoal>,
        age: Int,
        dailyScreenTimeHours: Double,
        isEstimate: Bool
    ) -> [Line] {
        let order: [Beat] = [.goals, .age, .screenTime]
        let cutoff = (upTo == .final) ? order.count : (order.firstIndex(of: upTo).map { $0 + 1 } ?? 0)
        return order.prefix(cutoff).compactMap { b in
            PlanBuildBeatContent(
                beat: b, goals: goals, age: age,
                dailyScreenTimeHours: dailyScreenTimeHours, isEstimate: isEstimate
            ).newLine
        }
    }
}
