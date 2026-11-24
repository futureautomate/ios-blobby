import Foundation

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

    init(id: UUID = UUID(), name: String, emoji: String, color: HabitColor, kind: MascotKind? = nil,
         goal: Double, unit: String, step: Double, log: [String: Double] = [:],
         reminderHour: Int? = nil, reminderMinute: Int? = nil, days: [Int]? = nil,
         pausedSince: String? = nil, skipDays: [String] = []) {
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
    }

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, color, kind, goal, unit, step, log, reminderHour, reminderMinute, days
        case pausedSince, skipDays
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
        guard let first = log.keys.compactMap({ Habit.date(fromKey: $0) }).min() else { return 0 }
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

    var daysCompleted: Int { log.values.filter { $0 >= goal && goal > 0 }.count }

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

    func progress(on date: Date = Date()) -> Double {
        guard goal > 0 else { return 0 }
        return min(amount(on: date) / goal, 1)
    }

    /// "servings" -> "serving" when the amount is exactly 1.
    func unitLabel(for amount: Double) -> String {
        amount == 1 && unit.count > 1 && unit.hasSuffix("s") ? String(unit.dropLast()) : unit
    }

    func isDone(on date: Date = Date()) -> Bool {
        goal > 0 && amount(on: date) >= goal
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

    static let all: [HabitPreset] = [
        HabitPreset(name: "Drink water", emoji: "💧", goal: 2000, unit: "ml", step: 250, color: .ocean, kind: .drop),
        HabitPreset(name: "Walk", emoji: "👟", goal: 8000, unit: "steps", step: 1000, color: .mint, kind: .flame),
        HabitPreset(name: "Read", emoji: "📖", goal: 20, unit: "pages", step: 5, color: .grape, kind: .sprout),
        HabitPreset(name: "Meditate", emoji: "🧘", goal: 10, unit: "min", step: 5, color: .sunny, kind: .sun),
        HabitPreset(name: "Eat fruit", emoji: "🍎", goal: 3, unit: "servings", step: 1, color: .coral, kind: .apple),
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
