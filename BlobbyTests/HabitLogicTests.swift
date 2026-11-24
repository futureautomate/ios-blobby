import XCTest
@testable import Blobby

/// Guards the trickiest logic: streaks, rest days, pauses, levels and loading old saved data.
/// Runs on every CI build (see .github/workflows/ios.yml → "Unit tests").
final class HabitLogicTests: XCTestCase {
    private let cal = Calendar.current

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date()))!
    }

    private func habit(days: [Int]? = nil) -> Habit {
        Habit(name: "Water", emoji: "💧", color: .ocean, kind: .drop,
              goal: 2000, unit: "ml", step: 250, days: days)
    }

    private func complete(_ h: inout Habit, _ offsets: [Int]) {
        for o in offsets { h.log[Habit.key(day(o))] = h.goal }
    }

    // MARK: Streaks

    func testStreakCountsConsecutiveDaysIncludingToday() {
        var h = habit()
        complete(&h, [0, -1, -2])
        XCTAssertEqual(h.streak, 3)
    }

    func testUnfinishedTodayDoesNotBreakStreak() {
        var h = habit()
        complete(&h, [-1, -2, -3])
        XCTAssertEqual(h.streak, 3)
    }

    func testMissedDayBreaksStreak() {
        var h = habit()
        complete(&h, [-1, -2, -4, -5])
        XCTAssertEqual(h.streak, 2)
        XCTAssertEqual(h.bestStreak, 2)
    }

    func testPartialDayIsNotDone() {
        var h = habit()
        h.log[Habit.key(day(-1))] = 1999
        XCTAssertFalse(h.isDone(on: day(-1)))
        XCTAssertEqual(h.streak, 0)
    }

    func testBestStreakFindsLongestRun() {
        var h = habit()
        complete(&h, [-1, -2, -10, -11, -12, -13, -14])
        XCTAssertEqual(h.bestStreak, 5)
        XCTAssertEqual(h.streak, 2)
    }

    // MARK: Schedule & pause

    func testRestDaysDoNotBreakStreak() {
        let restWeekday = cal.component(.weekday, from: day(-2))
        var h = habit(days: (1...7).filter { $0 != restWeekday })
        complete(&h, [-1, -3, -4])          // day -2 is a rest day
        XCTAssertFalse(h.isScheduled(on: day(-2)))
        XCTAssertEqual(h.streak, 3)
        XCTAssertEqual(h.bestStreak, 3)
    }

    func testPauseAndResumeKeepStreak() {
        var h = habit()
        complete(&h, [-6, -5, -4])
        h.pause(on: day(-3))
        XCTAssertTrue(h.isPaused)
        XCTAssertFalse(h.isScheduled(on: day(-1)))
        h.resume(on: day(0))
        XCTAssertFalse(h.isPaused)
        XCTAssertTrue(h.isScheduled(on: day(0)))
        XCTAssertEqual(h.streak, 3)
    }

    func testWeekStats() {
        var h = habit()
        complete(&h, [0, -1, -3])
        let s = h.weekStats(ending: day(0))
        XCTAssertEqual(s.scheduled, 7)
        XCTAssertEqual(s.done, 3)
    }

    func testScheduleText() {
        XCTAssertEqual(habit().scheduleText, "Every day")
        XCTAssertEqual(habit(days: [2, 3, 4, 5, 6]).scheduleText, "Weekdays")
        XCTAssertEqual(habit(days: [1, 7]).scheduleText, "Weekends")
    }

    // MARK: Levels

    func testAccessoryThresholds() {
        for (days, expected) in [(2, 0), (3, 1), (7, 2), (14, 3), (30, 4)] {
            var h = habit()
            complete(&h, (1...days).map { -$0 })
            XCTAssertEqual(h.unlocked.count, expected, "\(days) days in a row")
            XCTAssertEqual(h.level, expected + 1)
        }
    }

    // MARK: Saved data

    func testDecodesDataSavedByOlderVersions() throws {
        let json = #"[{"name":"Walk","emoji":"👟","color":1,"goal":8000,"unit":"steps","step":1000}]"#
        let habits = try JSONDecoder().decode([Habit].self, from: Data(json.utf8))
        let h = try XCTUnwrap(habits.first)
        XCTAssertEqual(h.kind, .flame)          // suggested from the name/emoji
        XCTAssertNil(h.days)
        XCTAssertFalse(h.isPaused)
        XCTAssertTrue(h.log.isEmpty)
        XCTAssertNil(h.reminderHour)
    }

    func testEncodeDecodeRoundTrip() throws {
        var h = habit(days: [2, 4, 6])
        h.reminderHour = 18
        h.reminderMinute = 30
        complete(&h, [-1])
        h.pause()
        let data = try JSONEncoder().encode([h])
        let back = try JSONDecoder().decode([Habit].self, from: data)
        XCTAssertEqual(back.first, h)
    }

    func testUnitLabelSingular() {
        let h = Habit(name: "Fruit", emoji: "🍎", color: .coral, goal: 3, unit: "servings", step: 1)
        XCTAssertEqual(h.unitLabel(for: 1), "serving")
        XCTAssertEqual(h.unitLabel(for: 2), "servings")
    }
}
