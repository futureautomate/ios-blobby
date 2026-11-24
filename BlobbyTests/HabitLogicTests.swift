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

    // MARK: Habit types (v0.10)

    private func time(_ dayOffset: Int, _ h: Int, _ m: Int) -> Date {
        cal.date(bySettingHour: h, minute: m, second: 0, of: day(dayOffset))!
    }

    func testCheckInMorningDeadline() {
        let h = Habit(name: "Wake up early", emoji: "🌅", color: .sunny, goal: 1, unit: "days", step: 1,
                      type: .checkIn, deadlineHour: 6, deadlineMinute: 30)
        XCTAssertFalse(h.isLate(time(0, 6, 0)))
        XCTAssertFalse(h.isLate(time(0, 6, 30)))
        XCTAssertTrue(h.isLate(time(0, 7, 0)))
        // morning habits never move to the previous day
        XCTAssertTrue(cal.isDate(h.checkInDay(for: time(0, 3, 0)), inSameDayAs: day(0)))
    }

    func testCheckInBedtimeAfterMidnightCountsForLastNightAndIsLate() {
        let h = Habit(name: "Sleep by 11", emoji: "🌙", color: .grape, goal: 1, unit: "days", step: 1,
                      type: .checkIn, deadlineHour: 23, deadlineMinute: 0)
        XCTAssertFalse(h.isLate(time(0, 22, 30)))
        XCTAssertTrue(h.isLate(time(0, 23, 30)))
        XCTAssertTrue(h.isLate(time(0, 0, 30)))
        XCTAssertTrue(cal.isDate(h.checkInDay(for: time(0, 0, 30)), inSameDayAs: day(-1)))
        XCTAssertTrue(cal.isDate(h.checkInDay(for: time(0, 22, 30)), inSameDayAs: day(0)))
    }

    func testLateCheckInDoesNotCountForStreak() {
        var h = Habit(name: "Wake", emoji: "🌅", color: .sunny, goal: 1, unit: "days", step: 1,
                      type: .checkIn, deadlineHour: 6, deadlineMinute: 30)
        for o in [-1, -2, -3] { h.log[Habit.key(day(o))] = 1 }
        h.lateDays = [Habit.key(day(-2))]
        XCTAssertTrue(h.isDone(on: day(-1)))
        XCTAssertFalse(h.isDone(on: day(-2)))
        XCTAssertEqual(h.streak, 1)
        XCTAssertEqual(h.progress(on: day(-2)), 1)   // still logged, buddy still filled
    }

    func testLimitJudgesFinishedDaysOnly() {
        var h = Habit(name: "Less phone", emoji: "📵", color: .coral, goal: 120, unit: "min", step: 15,
                      type: .limit, createdKey: Habit.key(day(-5)))
        h.log[Habit.key(day(-1))] = 60     // under
        h.log[Habit.key(day(-2))] = 200    // over
        // day -3: nothing logged = stayed under
        h.log[Habit.key(day(0))] = 30
        XCTAssertTrue(h.isDone(on: day(-1)))
        XCTAssertFalse(h.isDone(on: day(-2)))
        XCTAssertTrue(h.isDone(on: day(-3)))
        XCTAssertFalse(h.isDone(on: day(0)))       // today isn't over yet
        XCTAssertFalse(h.isDone(on: day(-8)))      // before the habit existed
        XCTAssertEqual(h.streak, 1)
        XCTAssertTrue(h.goodToday)
        XCTAssertEqual(h.progress(), 0.75, accuracy: 0.001)   // buddy drains as the limit is used
        h.log[Habit.key(day(0))] = 150
        XCTAssertTrue(h.isOver())
        XCTAssertFalse(h.goodToday)
    }

    func testOldSavedHabitsDecodeAsCountType() throws {
        let json = #"[{"id":"7B0E2B1C-5A55-4C55-9D0B-2D8A2D9C1A11","name":"Water","goal":2000,"step":250,"log":{}}]"#
        let decoded = try JSONDecoder().decode([Habit].self, from: Data(json.utf8))
        XCTAssertEqual(decoded.first?.type, .count)
        XCTAssertNil(decoded.first?.deadlineHour)
    }
}
