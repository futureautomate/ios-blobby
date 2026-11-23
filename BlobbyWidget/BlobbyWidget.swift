import SwiftUI
import WidgetKit

struct HabitEntry: TimelineEntry {
    let date: Date
    let habits: [Habit]
}

struct HabitProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: Date(), habits: HabitProvider.placeholderHabits)
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> Void) {
        let habits = HabitFile.load()
        completion(HabitEntry(date: Date(), habits: habits.isEmpty && context.isPreview ? HabitProvider.placeholderHabits : habits))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) {
        let entry = HabitEntry(date: Date(), habits: HabitFile.load())
        // Refresh at midnight so a new day starts empty. Logging also refreshes it immediately.
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(24 * 60 * 60))
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }

    /// Shown in the widget gallery before the user has any habits.
    static var placeholderHabits: [Habit] {
        let today = Habit.key(Date())
        return [
            Habit(name: "Drink water", emoji: "💧", color: .ocean, kind: .drop, goal: 2000, unit: "ml", step: 250, log: [today: 1250]),
            Habit(name: "Walk", emoji: "👟", color: .mint, kind: .flame, goal: 8000, unit: "steps", step: 1000, log: [today: 5000]),
            Habit(name: "Read", emoji: "📖", color: .grape, kind: .sprout, goal: 20, unit: "pages", step: 5, log: [today: 10]),
        ]
    }
}

struct BlobbyWidget: Widget {
    let kind = "BlobbyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
            BlobbyWidgetView(habits: entry.habits)
                .containerBackground(Paper.color, for: .widget)
        }
        .configurationDisplayName("Blobby")
        .description("Your habit buddies filling up. Tap + to log without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct BlobbyWidgetBundle: WidgetBundle {
    var body: some Widget {
        BlobbyWidget()
    }
}
