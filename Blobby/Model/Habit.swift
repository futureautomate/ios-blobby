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

    init(id: UUID = UUID(), name: String, emoji: String, color: HabitColor, kind: MascotKind? = nil,
         goal: Double, unit: String, step: Double, log: [String: Double] = [:]) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.kind = kind ?? MascotKind.suggested(emoji: emoji, name: name)
        self.goal = goal
        self.unit = unit
        self.step = step
        self.log = log
    }

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, color, kind, goal, unit, step, log
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

    /// Consecutive completed days, counting today only if it's already done.
    var streak: Int {
        let cal = Calendar.current
        var day = Date()
        if !isDone(on: day) {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while isDone(on: day) && count < 3650 {
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
