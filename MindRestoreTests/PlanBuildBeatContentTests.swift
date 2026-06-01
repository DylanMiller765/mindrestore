import XCTest
@testable import MindRestore

final class PlanBuildBeatContentTests: XCTestCase {

    func test_goalBeat_bubbleAndLine() {
        let c = PlanBuildBeatContent(
            beat: .goals,
            goals: [.screenTimeFrying],
            age: 24,
            dailyScreenTimeHours: 4.2,
            isEstimate: false
        )
        XCTAssertEqual(c.bubble, "Hours back. That's the mission.")
        XCTAssertEqual(c.newLine?.label, "Goal")
        XCTAssertEqual(c.newLine?.value, "hours back")
    }

    func test_ageBeat_interpolatesYearsAhead() {
        let c = PlanBuildBeatContent(
            beat: .age, goals: [], age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertEqual(c.bubble, "24? You've got ~56 years of phone ahead.")
        XCTAssertEqual(c.newLine?.label, "Age")
        XCTAssertEqual(c.newLine?.value, "24 · ~56 yrs ahead")
    }

    func test_screenTimeBeat_computesDaysPerYear() {
        // 4.2h/day * 365 / 24 = 63.875 → rounds to 64
        let c = PlanBuildBeatContent(
            beat: .screenTime, goals: [], age: 24, dailyScreenTimeHours: 4.2, isEstimate: false
        )
        XCTAssertEqual(c.bubble, "4.2h a day… that's ~64 days a year gone.")
        XCTAssertEqual(c.newLine?.value, "4.2h/day")
    }

    func test_screenTimeBeat_estimateAtOrAboveEightClampsTo8Plus() {
        let c = PlanBuildBeatContent(
            beat: .screenTime, goals: [], age: 30, dailyScreenTimeHours: 9.0, isEstimate: true
        )
        XCTAssertEqual(c.newLine?.value, "8h+/day")
        XCTAssertTrue(c.bubble.contains("8h+"))
    }

    func test_finalBeat_hasNoNewLine_andPresentingCopy() {
        let c = PlanBuildBeatContent(
            beat: .final, goals: [.doomscrolling], age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertNil(c.newLine)
        XCTAssertEqual(c.bubble, "Your counterattack's ready.")
    }

    func test_cumulativeLines_includesEveryBeatUpToCurrent() {
        let lines = PlanBuildBeatContent.cumulativeLines(
            upTo: .screenTime,
            goals: [.screenTimeFrying], age: 24, dailyScreenTimeHours: 4.2, isEstimate: false
        )
        XCTAssertEqual(lines.map(\.label), ["Goal", "Age", "Screen time"])
        XCTAssertEqual(lines.map(\.value), ["hours back", "24 · ~56 yrs ahead", "4.2h/day"])
    }

    func test_goalSummary_fallsBackWhenNoKnownGoal() {
        let c = PlanBuildBeatContent(
            beat: .goals, goals: [], age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertEqual(c.newLine?.value, "hours back")
    }
}
