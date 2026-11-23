import Foundation
import SwiftUI

/// Holds all habits and saves them as JSON in the app's Documents folder.
/// In demo mode (used by CI screenshots) nothing is saved.
final class HabitStore: ObservableObject {
    @Published var habits: [Habit] = []

    private let persist: Bool
    private let fileURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("habits.json")

    init(demo: String? = nil) {
        if let demo = demo {
            persist = false
            habits = demo == "sample" ? HabitStore.sample() : []
        } else {
            persist = true
            load()
        }
    }

    func habit(_ id: UUID) -> Habit? {
        habits.first { $0.id == id }
    }

    func add(_ habit: Habit) {
        habits.append(habit)
        save()
    }

    func delete(_ id: UUID) {
        habits.removeAll { $0.id == id }
        save()
    }

    /// Adds (or with a negative delta, removes) today's amount.
    func log(_ id: UUID, delta: Double) {
        guard let i = habits.firstIndex(where: { $0.id == id }) else { return }
        let key = Habit.key(Date())
        let current = habits[i].log[key] ?? 0
        habits[i].log[key] = max(0, current + delta)
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Habit].self, from: data) else { return }
        habits = decoded
    }

    private func save() {
        guard persist, let data = try? JSONEncoder().encode(habits) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Demo data

    static func sample() -> [Habit] {
        var water = Habit(name: "Drink water", emoji: "💧", color: .ocean, goal: 2000, unit: "ml", step: 250)
        var walk = Habit(name: "Walk", emoji: "👟", color: .mint, goal: 8000, unit: "steps", step: 1000)
        var read = Habit(name: "Read", emoji: "📖", color: .grape, goal: 20, unit: "pages", step: 5)
        var calm = Habit(name: "Meditate", emoji: "🧘", color: .sunny, goal: 10, unit: "min", step: 5)
        var fruit = Habit(name: "Eat fruit", emoji: "🍎", color: .coral, goal: 3, unit: "servings", step: 1)

        let cal = Calendar.current
        for d in 1...6 {
            guard let day = cal.date(byAdding: .day, value: -d, to: Date()) else { continue }
            let k = Habit.key(day)
            water.log[k] = d == 4 ? 1500 : 2000
            walk.log[k] = d % 2 == 0 ? 8000 : 5000
            read.log[k] = d == 5 ? 10 : 20
            calm.log[k] = 10
            fruit.log[k] = d % 3 == 0 ? 2 : 3
        }
        let today = Habit.key(Date())
        water.log[today] = 1250
        walk.log[today] = 8000
        read.log[today] = 10
        calm.log[today] = 5
        fruit.log[today] = 1
        return [water, walk, read, calm, fruit]
    }
}

/// Launch arguments used by CI to open specific screens for screenshots.
/// e.g. `-demo sample -open 0 -autolog`
enum LaunchOptions {
    static let args = ProcessInfo.processInfo.arguments

    static func value(_ flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var demo: String? { value("-demo") }
    static var openIndex: Int? { value("-open").flatMap { Int($0) } }
    static var celebrate: Bool { args.contains("-celebrate") }
    static var showAdd: Bool { args.contains("-add") }
    static var autolog: Bool { args.contains("-autolog") }
}
