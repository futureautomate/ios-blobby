import Foundation
import SwiftUI

/// Holds all habits and saves them as JSON in the app's Documents folder.
/// In demo mode (used by CI screenshots) nothing is saved.
final class HabitStore: ObservableObject {
    @Published var habits: [Habit] = []
    /// Set when a reminder notification is tapped; HomeView opens that habit.
    @Published var openRequest: UUID?
    /// Most recent "+" log, shown as an Undo toast for a few seconds.
    @Published var lastLog: LogEvent?

    private let persist: Bool

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

    /// A user tap on "+": adds one step and offers Undo.
    func logStep(_ id: UUID) {
        guard let habit = habit(id) else { return }
        log(id, delta: habit.step)
        lastLog = LogEvent(habitID: id, amount: habit.step,
                           text: "+\(habit.step.clean) \(habit.unitLabel(for: habit.step)) · \(habit.name)")
    }

    func undo(_ event: LogEvent) {
        log(event.habitID, delta: -event.amount)
        if lastLog?.id == event.id { lastLog = nil }
    }

    func setPaused(_ id: UUID, _ paused: Bool) {
        guard let i = habits.firstIndex(where: { $0.id == id }) else { return }
        if paused { habits[i].pause() } else { habits[i].resume() }
        save()
    }

    /// Drag-to-reorder: move `id` to where `target` currently is.
    func move(_ id: UUID, before target: UUID) {
        guard id != target,
              let from = habits.firstIndex(where: { $0.id == id }),
              let to = habits.firstIndex(where: { $0.id == target }) else { return }
        let item = habits.remove(at: from)
        habits.insert(item, at: to)
    }

    /// Persist the order once the drag ends.
    func commitOrder() { save() }

    /// Replace an edited habit (keeps its id and history).
    func update(_ habit: Habit) {
        guard let i = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[i] = habit
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

    /// Deletes every habit and its history.
    func reset() {
        habits = []
        save()
    }

    /// Replaces everything with the 5 demo habits (handy for testing).
    func loadSample() {
        habits = HabitStore.sample()
        save()
    }

    // MARK: - Persistence

    private func load() {
        habits = HabitFile.load()
    }

    /// Pick up changes made by the widget's + button while the app was in the background.
    func reloadFromDisk() {
        guard persist else { return }
        let fresh = HabitFile.load()
        if fresh != habits { habits = fresh }
    }

    private func save() {
        guard persist else { return }
        HabitFile.save(habits)                // also refreshes the Home-screen widget
        Reminders.shared.reschedule(habits)   // keep reminders in sync with every change
    }

    // MARK: - Demo data

    static func sample() -> [Habit] {
        var water = Habit(name: "Drink water", emoji: "💧", color: .ocean, goal: 2000, unit: "ml", step: 250,
                          reminderHour: 11, reminderMinute: 0)
        var walk = Habit(name: "Walk", emoji: "👟", color: .mint, goal: 8000, unit: "steps", step: 1000,
                         days: [2, 4, 6])   // Mon, Wed, Fri
        var read = Habit(name: "Read", emoji: "📖", color: .grape, goal: 20, unit: "pages", step: 5)
        var calm = Habit(name: "Meditate", emoji: "🧘", color: .sunny, goal: 10, unit: "min", step: 5)
        var fruit = Habit(name: "Eat fruit", emoji: "🍎", color: .coral, goal: 3, unit: "servings", step: 1)

        // ~5 weeks of history so levels and the calendar have something to show:
        // Meditate never missed (crown), Water missed once (bow tie), Read 9 days (sunglasses).
        let cal = Calendar.current
        for d in 1...38 {
            guard let day = cal.date(byAdding: .day, value: -d, to: Date()) else { continue }
            let k = Habit.key(day)
            water.log[k] = d == 20 ? 1500 : 2000
            walk.log[k] = walk.isScheduled(on: day) ? (d == 15 ? 5000 : 8000) : 0
            read.log[k] = d <= 9 ? 20 : (d % 4 == 0 ? 0 : 15)
            calm.log[k] = 10
            fruit.log[k] = d % 3 == 0 ? 2 : 3
        }
        let today = Habit.key(Date())
        water.log[today] = 1250
        walk.log[today] = walk.isScheduled(on: Date()) ? 3000 : 0
        read.log[today] = 10
        calm.log[today] = 5
        fruit.log[today] = 1
        var journal = Habit(name: "Journal", emoji: "✍️", color: .grape, kind: .blob, goal: 1, unit: "entry", step: 1)
        journal.pause(on: cal.date(byAdding: .day, value: -3, to: Date()) ?? Date())
        return [water, walk, read, calm, fruit, journal]
    }
}

struct LogEvent: Identifiable, Equatable {
    let id = UUID()
    let habitID: UUID
    let amount: Double
    let text: String
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
    static var editing: Bool { args.contains("-edit") }
    static var confirmIndex: Int? { value("-confirm").flatMap { Int($0) } }
    static var showSettings: Bool { args.contains("-settings") }
    static var editHabitIndex: Int? { value("-editHabit").flatMap { Int($0) } }
    static var scrollToHistory: Bool { args.contains("-history") }
    static var showLevelUp: Bool { args.contains("-levelup") }
    static var showRecap: Bool { args.contains("-recap") }
    static var showOnboarding: Bool { args.contains("-onboarding") }
    static var showToast: Bool { args.contains("-toast") }
    static var showShare: Bool { args.contains("-share") }
    static var menuIndex: Int? { value("-menu").flatMap { Int($0) } }
    static var showMore: Bool { args.contains("-more") }
    static var night: Bool { args.contains("-night") }
}
