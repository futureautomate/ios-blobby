import Foundation

struct Habit: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var color: HabitColor
    var goal: Double          // e.g. 2000
    var unit: String          // e.g. "ml"
    var step: Double          // amount added per tap, e.g. 250
    var log: [String: Double] = [:]   // "yyyy-MM-dd" -> amount that day

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

    static let all: [HabitPreset] = [
        HabitPreset(name: "Drink water", emoji: "💧", goal: 2000, unit: "ml", step: 250, color: .ocean),
        HabitPreset(name: "Walk", emoji: "👟", goal: 8000, unit: "steps", step: 1000, color: .mint),
        HabitPreset(name: "Read", emoji: "📖", goal: 20, unit: "pages", step: 5, color: .grape),
        HabitPreset(name: "Meditate", emoji: "🧘", goal: 10, unit: "min", step: 5, color: .sunny),
        HabitPreset(name: "Eat fruit", emoji: "🍎", goal: 3, unit: "servings", step: 1, color: .coral),
    ]
}
