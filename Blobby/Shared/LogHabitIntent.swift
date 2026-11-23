import AppIntents
import Foundation
import WidgetKit

/// The widget's "+" button: adds one step to today's amount without opening the app.
struct LogHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Log habit"
    static var description = IntentDescription("Adds one step to today's progress for a habit.")

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}

    init(habitID: UUID) {
        self.habitID = habitID.uuidString
    }

    func perform() async throws -> some IntentResult {
        var habits = HabitFile.load()
        if let i = habits.firstIndex(where: { $0.id.uuidString == habitID }) {
            let key = Habit.key(Date())
            habits[i].log[key] = (habits[i].log[key] ?? 0) + habits[i].step
            HabitFile.save(habits)
        }
        return .result()
    }
}
