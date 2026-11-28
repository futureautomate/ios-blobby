import Foundation

/// What kind of habit this is.
enum HabitType: String, Codable, CaseIterable, Identifiable {
    /// Do more: fill up to a goal (2 L water, 20 pages).
    case count
    /// Do it once a day, optionally before a deadline (wake up by 6:30, sleep by 11).
    case checkIn
    /// Do less: stay under a daily limit (phone time, sugar). The day is judged when it ends.
    case limit

    var id: String { rawValue }
    var title: String {
        switch self {
        case .count: return "Build up"
        case .checkIn: return "Check in"
        case .limit: return "Cut down"
        }
    }
    var emoji: String {
        switch self {
        case .count: return "📈"
        case .checkIn: return "✅"
        case .limit: return "✂️"
        }
    }
    var hint: String {
        switch self {
        case .count: return "Reach a daily amount"
        case .checkIn: return "Once a day, maybe by a time"
        case .limit: return "Stay under a daily limit"
        }
    }
}

struct Habit: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var emoji: String
    var color: HabitColor
    var kind: MascotKind      // which cartoon character represents this habit
    var goal: Double          // e.g. 2000
    var unit: String          // e.g. "ml"
    var step: Double          // amount added per tap, e.g. 250
    var log: [String: Double] // "yyyy-MM-dd" -> amount that day
    var reminderHour: Int?    // daily reminder time (nil = no reminder)
    var reminderMinute: Int?
    /// Weekdays the habit runs on (Calendar weekday: 1 = Sunday … 7 = Saturday). nil = every day.
    var days: [Int]?
    /// Paused habits are hidden from Today, send no reminders and keep their streak.
    var pausedSince: String?        // day key the pause started, nil = active
    var skipDays: [String]          // day keys from past pauses (treated like rest days)
    var type: HabitType = .count
    /// Check-in deadline ("by 6:30"). nil = any time that day.
    var deadlineHour: Int?
    var deadlineMinute: Int?
    /// Check-in days that were tapped after the deadline (logged, but they don't count).
    var lateDays: [String] = []
    /// Day the habit was created. Limit habits are judged from this day on
    /// (a day with nothing logged is a win, so we need to know where to start).
    var createdKey: String?

    init(id: UUID = UUID(), name: String, emoji: String, color: HabitColor, kind: MascotKind? = nil,
         goal: Double, unit: String, step: Double, log: [String: Double] = [:],
         reminderHour: Int? = nil, reminderMinute: Int? = nil, days: [Int]? = nil,
         pausedSince: String? = nil, skipDays: [String] = [],
         type: HabitType = .count, deadlineHour: Int? = nil, deadlineMinute: Int? = nil,
         createdKey: String? = Habit.key(Date())) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.kind = kind ?? MascotKind.suggested(emoji: emoji, name: name)
        self.goal = goal
        self.unit = unit
        self.step = step
        self.log = log
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.days = days
        self.pausedSince = pausedSince
        self.skipDays = skipDays
        self.type = type
        self.deadlineHour = deadlineHour
        self.deadlineMinute = deadlineMinute
        self.createdKey = createdKey
    }

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, color, kind, goal, unit, step, log, reminderHour, reminderMinute, days
        case pausedSince, skipDays
        case type, deadlineHour, deadlineMinute, lateDays, createdKey
    }

    /// Tolerant decoding: habits saved by v0.1 have no `kind`, so we pick one from the emoji/name.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? "⭐️"
        color = try c.decodeIfPresent(HabitColor.self, forKey: .color) ?? .ocean
        goal = try c.decode(Double.self, forKey: .goal)
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
        step = try c.decode(Double.self, forKey: .step)
        log = try c.decodeIfPresent([String: Double].self, forKey: .log) ?? [:]
        kind = try c.decodeIfPresent(MascotKind.self, forKey: .kind)
            ?? MascotKind.suggested(emoji: emoji, name: name)
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour)
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute)
        days = try c.decodeIfPresent([Int].self, forKey: .days)
        pausedSince = try c.decodeIfPresent(String.self, forKey: .pausedSince)
        skipDays = try c.decodeIfPresent([String].self, forKey: .skipDays) ?? []
        type = try c.decodeIfPresent(HabitType.self, forKey: .type) ?? .count
        deadlineHour = try c.decodeIfPresent(Int.self, forKey: .deadlineHour)
        deadlineMinute = try c.decodeIfPresent(Int.self, forKey: .deadlineMinute)
        lateDays = try c.decodeIfPresent([String].self, forKey: .lateDays) ?? []
        createdKey = try c.decodeIfPresent(String.self, forKey: .createdKey)
    }

    // MARK: - Types

    /// First day this habit counts. Limit habits start on the day they were created
    /// (or the first log for older data); others from their first log.
    var startDay: Date? {
        let firstLog = log.keys.compactMap { Habit.date(fromKey: $0) }.min()
        let created = createdKey.flatMap { Habit.date(fromKey: $0) }
        switch type {
        case .limit: return [created, firstLog].compactMap { $0 }.min()
        default: return firstLog
        }
    }

    var hasDeadline: Bool { type == .checkIn && deadlineHour != nil }

    /// "6:30"
    var deadlineText: String? {
        guard hasDeadline, let h = deadlineHour else { return nil }
        let date = Calendar.current.date(from: DateComponents(hour: h, minute: deadlineMinute ?? 0)) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Bedtime-style deadlines (6 pm or later): a tap after midnight still belongs to the night before.
    var isNightDeadline: Bool { (deadlineHour ?? 0) >= 18 }

    /// Which day a check-in made at `time` counts for. For bedtime habits, a tap before 4 am
    /// still belongs to "last night".
    func checkInDay(for time: Date) -> Date {
        let cal = Calendar.current
        if isNightDeadline && cal.component(.hour, from: time) < 4 {
            return cal.date(byAdding: .day, value: -1, to: time) ?? time
        }
        return time
    }

    /// When today's check-in window opens: bedtime habits 5 hours before the deadline,
    /// others 4 hours before. Nil when there's no deadline (any time is fine).
    func checkInOpens(on now: Date = Date()) -> Date? {
        guard hasDeadline, let h = deadlineHour else { return nil }
        let cal = Calendar.current
        // Just after midnight is still last night's bedtime window.
        if isNightDeadline && cal.component(.hour, from: now) < 4 { return nil }
        guard let deadline = cal.date(bySettingHour: h, minute: deadlineMinute ?? 0, second: 0, of: now) else { return nil }
        return deadline.addingTimeInterval(Double(isNightDeadline ? -5 : -4) * 3600)
    }

    /// A check-in now would be suspiciously early (e.g. "Sleep by 11" at noon).
    func isTooEarlyToCheckIn(_ now: Date = Date()) -> Bool {
        guard let opens = checkInOpens(on: now) else { return false }
        return now < opens
    }

    /// Is a check-in at `time` after the deadline?
    func isLate(_ time: Date) -> Bool {
        guard hasDeadline, let h = deadlineHour else { return false }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: time)
        let minutes = hour * 60 + cal.component(.minute, from: time)
        let deadline = h * 60 + (deadlineMinute ?? 0)
        if isNightDeadline && hour < 4 { return true }   // after midnight = past an evening deadline
        return minutes > deadline
    }

    /// Limit habits: went over the limit that day.
    func isOver(on date: Date = Date()) -> Bool {
        type == .limit && amount(on: date) > goal
    }

    /// Limit habits: how much is left today.
    func remaining(on date: Date = Date()) -> Double {
        max(0, goal - amount(on: date))
    }


    // MARK: - Pause

    var isPaused: Bool { pausedSince != nil }

    mutating func pause(on date: Date = Date()) {
        guard pausedSince == nil else { return }
        pausedSince = Habit.key(date)
    }

    /// Resuming turns every paused day (start ... yesterday) into a skip day, so the streak survives.
    mutating func resume(on date: Date = Date()) {
        guard let startKey = pausedSince, let start = Habit.date(fromKey: startKey) else { return }
        let cal = Calendar.current
        var day = cal.startOfDay(for: start)
        let today = cal.startOfDay(for: date)
        var count = 0
        while day < today && count < 3650 {
            let k = Habit.key(day)
            if !skipDays.contains(k) { skipDays.append(k) }
            day = cal.date(byAdding: .day, value: 1, to: day) ?? today
            count += 1
        }
        pausedSince = nil
    }

    // MARK: - Schedule

    /// Does this habit run on that day? (Rest days don't break streaks.)
    func isScheduled(on date: Date = Date()) -> Bool {
        let key = Habit.key(date)
        if skipDays.contains(key) { return false }
        if let start = pausedSince, key >= start { return false }   // keys sort chronologically
        guard let days = days, !days.isEmpty, days.count < 7 else { return true }
        return days.contains(Calendar.current.component(.weekday, from: date))
    }

    /// "Every day", "Weekdays", "Weekends" or "Mon, Wed, Fri".
    var scheduleText: String {
        guard let days = days, !days.isEmpty, days.count < 7 else { return "Every day" }
        let set = Set(days)
        if set == [2, 3, 4, 5, 6] { return "Weekdays" }
        if set == [1, 7] { return "Weekends" }
        let names = Calendar.current.shortWeekdaySymbols
        return days.sorted().map { names[$0 - 1] }.joined(separator: ", ")
    }

    var hasReminder: Bool { reminderHour != nil }

    // MARK: - Levels & history

    static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Longest run of completed days ever (accessories are earned by this, so they're never lost).
    var bestStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let first = startDay else { return 0 }
        var day = cal.startOfDay(for: first)
        var best = 0
        var run = 0
        var guardCount = 0
        while day <= today && guardCount < 3650 {
            if isScheduled(on: day) {
                if isDone(on: day) {
                    run += 1
                    best = max(best, run)
                } else if day < today {
                    run = 0          // a missed scheduled day breaks the run (today isn't over yet)
                }
            }
            day = cal.date(byAdding: .day, value: 1, to: day) ?? today.addingTimeInterval(86_400)
            guardCount += 1
        }
        return best
    }

    var unlocked: [Accessory] { Accessory.allCases.filter { bestStreak >= $0.days } }
    var level: Int { unlocked.count + 1 }
    var levelTitle: String { unlocked.last?.levelTitle ?? "Newbie" }
    var nextAccessory: Accessory? { Accessory.allCases.first { bestStreak < $0.days } }

    var daysCompleted: Int {
        guard let start = startDay else { return 0 }
        return stats(from: start, to: Date()).done
    }

    /// Done / scheduled counts for the 7 days ending on `end` (weekly recap).
    func weekStats(ending end: Date) -> (done: Int, scheduled: Int) {
        let cal = Calendar.current
        var done = 0
        var scheduled = 0
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: end) else { continue }
            if isScheduled(on: day) {
                scheduled += 1
                if isDone(on: day) { done += 1 }
            }
        }
        return (done, scheduled)
    }
    var totalLogged: Double { log.values.reduce(0, +) }

    /// First day anything was logged (used so reports don't count days before the habit existed).
    var firstLogDay: Date? {
        if type == .limit { return startDay }
        return log.filter { $0.value > 0 }.keys.compactMap { Habit.date(fromKey: $0) }.min()
    }

    /// Done / scheduled days and amount logged between two days (inclusive),
    /// ignoring days before the first log, days after today, and today unless it's already done.
    func stats(from start: Date, to end: Date) -> (done: Int, scheduled: Int, amount: Double) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let first = firstLogDay.map { cal.startOfDay(for: $0) } ?? today
        var day = cal.startOfDay(for: start)
        let last = min(cal.startOfDay(for: end), today)
        var done = 0, scheduled = 0
        var amount = 0.0
        while day <= last {
            if day >= first {
                amount += self.amount(on: day)
                // An unfinished today isn't a miss yet: it only counts once it's done.
                if isScheduled(on: day) && (day < today || isDone(on: day)) {
                    scheduled += 1
                    if isDone(on: day) { done += 1 }
                }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return (done, scheduled, amount)
    }

    /// "42.5 L" for ml habits, otherwise "1,250 pages".
    func formatTotal(_ value: Double) -> String {
        if unit.lowercased() == "ml" && value >= 1000 { return "\((value / 1000).clean) L" }
        return "\(value.clean) \(unitLabel(for: value))"
    }

    /// "18:00"
    var reminderText: String? {
        guard let h = reminderHour else { return nil }
        return String(format: "%02d:%02d", h, reminderMinute ?? 0)
    }

    static func key(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func amount(on date: Date = Date()) -> Double {
        log[Habit.key(date)] ?? 0
    }

    /// How full the buddy is. Limit habits start full and drain as you use up the limit.
    func progress(on date: Date = Date()) -> Double {
        switch type {
        case .count:
            guard goal > 0 else { return 0 }
            return min(amount(on: date) / goal, 1)
        case .checkIn:
            return amount(on: date) >= 1 ? 1 : 0
        case .limit:
            guard goal > 0 else { return 1 }
            return max(0, 1 - amount(on: date) / goal)
        }
    }

    /// "servings" -> "serving" when the amount is exactly 1.
    func unitLabel(for amount: Double) -> String {
        amount == 1 && unit.count > 1 && unit.hasSuffix("s") ? String(unit.dropLast()) : unit
    }

    /// Count: reached the goal. Check-in: checked in (on time). Limit: a finished day that stayed under.
    func isDone(on date: Date = Date()) -> Bool {
        switch type {
        case .count:
            return goal > 0 && amount(on: date) >= goal
        case .checkIn:
            return amount(on: date) >= 1 && !lateDays.contains(Habit.key(date))
        case .limit:
            let cal = Calendar.current
            let day = cal.startOfDay(for: date)
            guard day < cal.startOfDay(for: Date()) else { return false }   // today isn't over yet
            if let start = startDay, day < cal.startOfDay(for: start) { return false }
            return amount(on: date) <= goal
        }
    }

    /// Limit habits today: still under the limit (shown as "on track", not "done").
    var onTrackToday: Bool { type == .limit && !isOver() }

    /// Check-in habits: tapped today (on time or late).
    var checkedToday: Bool { type == .checkIn && amount(on: checkInDay(for: Date())) >= 1 }

    /// "Going well today" for the Today header: goal reached, checked in on time, or under the limit so far.
    var goodToday: Bool {
        switch type {
        case .count: return isDone()
        case .checkIn: return isDone(on: checkInDay(for: Date()))
        case .limit: return !isOver()
        }
    }

    /// Shown on the + button: ✓ when there's nothing more to do today.
    var finishedToday: Bool {
        switch type {
        case .count: return isDone()
        case .checkIn: return checkedToday
        case .limit: return false
        }
    }

    /// Progress bar: limit habits show how much of the limit is used.
    var barProgress: Double {
        guard type == .limit else { return progress() }
        return goal > 0 ? min(amount() / goal, 1) : 0
    }

    /// Check-in cards: "⏰ 2h 10m left" before the deadline, a gentle note after it.
    func countdownText(now: Date = Date()) -> String {
        guard let h = deadlineHour else { return "Any time today" }
        let cal = Calendar.current
        guard var deadline = cal.date(bySettingHour: h, minute: deadlineMinute ?? 0, second: 0, of: now) else {
            return "Any time today"
        }
        // Bedtime habits: just after midnight still belongs to the previous evening's deadline.
        if isNightDeadline && cal.component(.hour, from: now) < 4 {
            deadline = cal.date(byAdding: .day, value: -1, to: deadline) ?? deadline
        }
        let minutes = Int(deadline.timeIntervalSince(now) / 60)
        if minutes < 0 { return "Deadline passed today" }
        if minutes < 60 { return "⏰ \(max(minutes, 1))m left" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "⏰ \(hours)h left" : "⏰ \(hours)h \(rest)m left"
    }

    /// Short status for cards: "1,250 / 2,000 ml", "Done at 6:12" style, "45 min left".
    func statusText(on date: Date = Date()) -> String {
        switch type {
        case .count:
            return "\(amount(on: date).clean) / \(goal.clean) \(unitLabel(for: goal))"
        case .checkIn:
            if amount(on: date) >= 1 {
                return lateDays.contains(Habit.key(date)) ? "Checked in late" : "Done for today ✓"
            }
            if let d = deadlineText { return "Check in by \(d)" }
            return "Not yet today"
        case .limit:
            let used = amount(on: date)
            if used > goal { return "Over by \((used - goal).clean) \(unitLabel(for: used - goal))" }
            return "\(used.clean) / \(goal.clean) \(unitLabel(for: goal)) · \(remaining(on: date).clean) left"
        }
    }

    /// Consecutive completed *scheduled* days. Rest days are skipped; today only counts once done.
    var streak: Int {
        let cal = Calendar.current
        var day = Date()
        var count = 0
        var steps = 0
        if !isDone(on: day) {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while steps < 3650 {
            steps += 1
            if !isScheduled(on: day) {
                day = cal.date(byAdding: .day, value: -1, to: day) ?? day
                continue
            }
            guard isDone(on: day) else { break }
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }
}

struct HabitPreset: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let goal: Double
    let unit: String
    let step: Double
    let color: HabitColor
    let kind: MascotKind
    var type: HabitType = .count
    var deadline: (Int, Int)? = nil

    /// "2000 ml", "by 6:30 AM", "max 120 min"
    var summary: String {
        switch type {
        case .count: return "\(goal.clean) \(unit)"
        case .checkIn:
            guard let d = deadline,
                  let t = Calendar.current.date(from: DateComponents(hour: d.0, minute: d.1)) else { return "once a day" }
            return "by \(t.formatted(date: .omitted, time: .shortened))"
        case .limit: return "max \(goal.clean) \(unit)"
        }
    }

    static let all: [HabitPreset] = [
        HabitPreset(name: "Drink water", emoji: "💧", goal: 2000, unit: "ml", step: 250, color: .ocean, kind: .drop),
        HabitPreset(name: "Walk", emoji: "👟", goal: 8000, unit: "steps", step: 1000, color: .mint, kind: .flame),
        HabitPreset(name: "Read", emoji: "📖", goal: 20, unit: "pages", step: 5, color: .grape, kind: .sprout),
        HabitPreset(name: "Meditate", emoji: "🧘", goal: 10, unit: "min", step: 5, color: .sunny, kind: .sun),
        HabitPreset(name: "Eat fruit", emoji: "🍎", goal: 3, unit: "servings", step: 1, color: .coral, kind: .apple),
        HabitPreset(name: "Wake up early", emoji: "🌅", goal: 1, unit: "days", step: 1, color: .sunny, kind: .sun,
                    type: .checkIn, deadline: (6, 30)),
        HabitPreset(name: "Sleep by 11", emoji: "🌙", goal: 1, unit: "days", step: 1, color: .grape, kind: .blob,
                    type: .checkIn, deadline: (23, 0)),
        HabitPreset(name: "Less phone", emoji: "📵", goal: 120, unit: "min", step: 15, color: .coral, kind: .flame,
                    type: .limit),
        HabitPreset(name: "Less sugar", emoji: "🍬", goal: 1, unit: "treats", step: 1, color: .mint, kind: .apple,
                    type: .limit),
    ]
}

/// The cartoon characters a habit can use. Each one shows progress differently.
enum MascotKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case drop, apple, sprout, sun, flame, blob

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drop: return "Droplet"
        case .apple: return "Apple"
        case .sprout: return "Sprout"
        case .sun: return "Sunny"
        case .flame: return "Flame"
        case .blob: return "Blobby"
        }
    }

    var hint: String {
        switch self {
        case .drop: return "fills with water"
        case .apple: return "fills with juice"
        case .sprout: return "grows leaves, then blooms"
        case .sun: return "rays grow, shines brighter"
        case .flame: return "burns bigger"
        case .blob: return "fills up with jelly"
        }
    }

    /// Reminder title in the character's voice.
    func reminderTitle(habit name: String) -> String {
        switch self {
        case .drop: return "Droplet is thirsty! Time for \(name.lowercased())"
        case .apple: return "Apple is hungry — \(name.lowercased()) time"
        case .sprout: return "Sprout wants to grow — \(name.lowercased()) time"
        case .sun: return "Sunny saved you a calm moment — \(name.lowercased())"
        case .flame: return "Keep Flame burning — \(name.lowercased()) time"
        case .blob: return "Blobby is waiting — \(name.lowercased()) time"
        }
    }

    /// Picks a sensible character from the habit's emoji or name.
    static func suggested(emoji: String, name: String) -> MascotKind {
        let n = name.lowercased()
        func has(_ set: [String]) -> Bool { !emoji.isEmpty && set.contains(emoji) }
        if has(["💧", "🥤", "🍵", "☕️", "🫖"]) || n.contains("water") || n.contains("drink") { return .drop }
        if has(["🍎", "🥗", "🥦", "🍌", "🥕"]) || n.contains("fruit") || n.contains("eat") || n.contains("veg") { return .apple }
        if has(["👟", "🏃", "🚴", "🏋️", "⚽️", "🏊"]) || n.contains("walk") || n.contains("run")
            || n.contains("workout") || n.contains("step") || n.contains("gym") { return .flame }
        if has(["📖", "✍️", "🌿", "🎨", "🎸", "💻"]) || n.contains("read") || n.contains("learn")
            || n.contains("study") || n.contains("write") { return .sprout }
        if has(["🧘", "☀️", "😴", "🌙"]) || n.contains("meditat") || n.contains("sleep") { return .sun }
        return .blob
    }
}

/// Wearables a character earns by keeping a streak. Raw value = days in a row needed.
enum Accessory: Int, CaseIterable, Identifiable, Hashable {
    case partyHat = 3, sunglasses = 7, bowTie = 14, crown = 30

    var id: Int { rawValue }
    var days: Int { rawValue }

    var title: String {
        switch self {
        case .partyHat: return "Party hat"
        case .sunglasses: return "Sunglasses"
        case .bowTie: return "Bow tie"
        case .crown: return "Crown"
        }
    }

    var emoji: String {
        switch self {
        case .partyHat: return "🎉"
        case .sunglasses: return "😎"
        case .bowTie: return "🎀"
        case .crown: return "👑"
        }
    }

    /// Title for the level this accessory unlocks.
    var levelTitle: String {
        switch self {
        case .partyHat: return "Party starter"
        case .sunglasses: return "Cool cat"
        case .bowTie: return "Dapper"
        case .crown: return "Royalty"
        }
    }
}
