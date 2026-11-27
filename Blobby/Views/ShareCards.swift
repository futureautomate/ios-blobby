import SwiftUI
import UIKit

// MARK: - Share cards
//
// Cartoon "report card" images rendered with ImageRenderer and shared through the
// standard share sheet (WhatsApp, Instagram, Facebook, Messages, Save Image…).
// Characters are drawn as still frames (animated: false) because ImageRenderer
// captures a single frame.

/// 4:5 portrait card (fits WhatsApp, Instagram feed and Facebook nicely).
private let cardSize = CGSize(width: 360, height: 450)

/// Shared frame: paper background, soft circles, title area and footer.
private struct CardFrame<Content: View>: View {
    let tint: HabitColor
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Paper.color
            Circle().fill(tint.main.opacity(0.14)).frame(width: 220).offset(x: 140, y: -170)
            Circle().fill(HabitColor.sunny.main.opacity(0.18)).frame(width: 160).offset(x: -150, y: 170)
            Circle().fill(tint.main.opacity(0.10)).frame(width: 90).offset(x: -130, y: -150)

            VStack(spacing: 0) {
                content
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    BlobMascot(progress: 0.6, color: Profile.name.isEmpty ? .ocean : Profile.color,
                               kind: Profile.name.isEmpty ? .drop : Profile.kind, size: 22, animated: false)
                    Text(Profile.name.isEmpty ? "Made with Blobby" : "\(Profile.name) · made with Blobby")
                        .font(.cartoonFixed(12, .bold))
                        .foregroundStyle(Ink.text.opacity(0.5))
                }
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipped()
        // Border as an overlay on the fixed frame, so tall content can never push it out of view.
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Ink.color, lineWidth: 4)
                .padding(2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .light)   // share images always use the day look
    }
}

/// Weekly report card.
struct WeekShareCard: View {
    let habits: [Habit]
    let endDay: Date

    private let cal = Calendar.current
    private var start: Date { cal.date(byAdding: .day, value: -6, to: endDay) ?? endDay }
    private var days: [Date] { (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) } }

    /// Same counting as Reports: days before a habit's first log don't count against it.
    /// Today only counts if it's already done (an unfinished today isn't a miss yet).
    private var rows: [(habit: Habit, done: Int, scheduled: Int)] {
        habits.filter { !$0.isPaused }.prefix(5).map { h in
            var done = 0, due = 0
            for day in days where counts(h, day) {
                due += 1
                if h.isDone(on: day) { done += 1 }
            }
            return (h, done, due)
        }
    }

    private func counts(_ h: Habit, _ day: Date) -> Bool {
        let first = h.firstLogDay.map { cal.startOfDay(for: $0) }
        guard let first = first, cal.startOfDay(for: day) >= first else { return false }
        if cal.startOfDay(for: day) > cal.startOfDay(for: Date()) { return false }
        if cal.isDateInToday(day) && !h.isDone(on: day) { return false }
        return h.isScheduled(on: day)
    }

    /// If everything started mid-week, say so instead of leaving the empty days unexplained.
    private var startedLabel: String? {
        let firsts = rows.compactMap { $0.habit.firstLogDay }.map { cal.startOfDay(for: $0) }
        guard let first = firsts.min(), first > cal.startOfDay(for: start),
              first <= cal.startOfDay(for: endDay) else { return nil }
        return "🌱 Started \(first.formatted(.dateTime.weekday(.abbreviated)))"
    }

    private var bestStreak: (name: String, days: Int)? {
        let best = rows.map(\.habit).max { $0.streak < $1.streak }
        guard let b = best, b.streak >= 2 else { return nil }
        return (b.name, b.streak)
    }

    var body: some View {
        let done = rows.reduce(0) { $0 + $1.done }
        let total = rows.reduce(0) { $0 + $1.scheduled }
        let percent = total == 0 ? 0 : Int((Double(done) / Double(total) * 100).rounded())
        let star = rows.filter { $0.scheduled > 0 && $0.done > 0 }
            .max { Double($0.done) / Double($0.scheduled) < Double($1.done) / Double($1.scheduled) }?.habit

        CardFrame(tint: star?.color ?? .ocean) {
            VStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(Profile.possessive()) week")
                        .font(.cartoonFixed(28))
                        .foregroundStyle(Ink.text)
                    Text("\(start.formatted(.dateTime.day().month())) – \(endDay.formatted(.dateTime.day().month()))")
                        .font(.cartoonFixed(12, .bold))
                        .foregroundStyle(Ink.text.opacity(0.5))
                }

                HStack(spacing: 14) {
                    if let star = star {
                        BlobMascot(progress: 1, color: star.color, kind: star.kind, size: 84,
                                   celebrate: true, sticker: star.emoji, accessories: star.unlocked, animated: false)
                            .padding(.top, 26)   // room for flowers / hats so they don't cover the date
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        // A brag card leads with what went well: the % when it's high, wins otherwise.
                        let showPercent = total > 0 && percent >= 60
                        Text(showPercent ? "\(percent)%" : (done > 0 ? "\(done)" : "🌱"))
                            .font(.cartoonFixed(44))
                            .foregroundStyle(Ink.text)
                        Text(showPercent ? "of habits done" : (done > 0 ? (done == 1 ? "win this week 🎉" : "wins this week 🎉")
                                                                   : "Fresh week ahead"))
                            .font(.cartoonFixed(15, .bold))
                            .foregroundStyle(Ink.text.opacity(0.7))
                        if let streak = bestStreak {
                            Text("🔥 \(streak.days)-day streak: \(streak.name)")
                                .font(.cartoonFixed(13, .bold))
                                .foregroundStyle(Ink.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        } else if let star = star {
                            Text("👑 Top habit: \(star.name)")
                                .font(.cartoonFixed(13, .bold))
                                .foregroundStyle(Ink.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    Spacer(minLength: 0)
                }

                VStack(spacing: 5) {
                    // Weekday letters line up with the dots below.
                    HStack(spacing: 8) {
                        if let label = startedLabel {
                            Text(label)
                                .font(.cartoonFixed(10, .bold))
                                .foregroundStyle(Ink.text.opacity(0.55))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        dayLetters
                        Text("").frame(width: 34)
                    }
                    ForEach(rows.indices, id: \.self) { i in
                        row(rows[i].habit, done: rows[i].done, scheduled: rows[i].scheduled)
                    }
                    legend.padding(.top, 2)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Card.color))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Ink.color, lineWidth: 2.5))
            }
        }
    }

    private var dayLetters: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.cartoonFixed(10, .bold))
                    .foregroundStyle(Ink.text.opacity(0.5))
                    .frame(width: 14)
            }
        }
    }

    private func row(_ h: Habit, done: Int, scheduled: Int) -> some View {
        HStack(spacing: 8) {
            BlobMascot(progress: scheduled > 0 ? Double(done) / Double(scheduled) : 0, color: h.color,
                       kind: h.kind, size: 26, animated: false)
            Text(h.name)
                .font(.cartoonFixed(13, .bold))
                .foregroundStyle(Ink.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { day in
                    dot(h, day)
                }
            }
            Text(scheduled == 0 ? "–" : "\(done)/\(scheduled)")
                .font(.cartoonFixed(12, .bold))
                .foregroundStyle(Ink.text.opacity(0.7))
                .frame(width: 34, alignment: .trailing)
        }
    }

    /// Filled with a tick = done, plain circle = missed, dotted = didn't count (not due / not started).
    private func dot(_ h: Habit, _ day: Date) -> some View {
        let isDone = h.isDone(on: day) && counts(h, day)
        let due = counts(h, day)
        return ZStack {
            Circle().fill(isDone ? h.color.main : (due ? Card.color : Color.clear))
            Circle().stroke(Ink.color.opacity(due ? 0.55 : 0.2),
                            style: StrokeStyle(lineWidth: 1, dash: due ? [] : [2, 2]))
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(Ink.color)
            }
        }
        .frame(width: 14, height: 14)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(fill: HabitColor.sunny.main, tick: true, dashed: false, "done")
            legendItem(fill: Card.color, tick: false, dashed: false, "missed")
            legendItem(fill: .clear, tick: false, dashed: true, "not due / to do")
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(fill: Color, tick: Bool, dashed: Bool, _ text: String) -> some View {
        HStack(spacing: 4) {
            ZStack {
                Circle().fill(fill)
                Circle().stroke(Ink.color.opacity(dashed ? 0.25 : 0.55),
                                style: StrokeStyle(lineWidth: 1, dash: dashed ? [2, 2] : []))
                if tick {
                    Image(systemName: "checkmark").font(.system(size: 6, weight: .black)).foregroundStyle(Ink.color)
                }
            }
            .frame(width: 11, height: 11)
            Text(text).font(.cartoonFixed(10, .bold)).foregroundStyle(Ink.text.opacity(0.55))
        }
    }
}

/// One habit's brag card: character with accessories, streak, level, this week.
struct HabitShareCard: View {
    let habit: Habit

    var body: some View {
        CardFrame(tint: habit.color) {
            VStack(spacing: 10) {
                Text(habit.name)
                    .font(.cartoonFixed(28))
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                BlobMascot(progress: max(habit.progress(), 0.6), color: habit.color, kind: habit.kind, size: 150,
                           celebrate: habit.isDone(), sticker: habit.emoji, accessories: habit.unlocked, animated: false)
                    .padding(.top, 44)   // room for hats / crowns under the title
                HStack(spacing: 10) {
                    pill("🔥 \(habit.streak)-day streak", fill: HabitColor.sunny.light)
                    pill("LV \(habit.level) · \(habit.levelTitle)", fill: habit.color.light)
                }
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        let day = Calendar.current.date(byAdding: .day, value: i - 6, to: Date()) ?? Date()
                        VStack(spacing: 3) {
                            Circle()
                                .fill(habit.isDone(on: day) ? habit.color.main
                                      : (habit.isScheduled(on: day) ? habit.color.light : Color.clear))
                                .overlay(Circle().stroke(Ink.color.opacity(habit.isScheduled(on: day) ? 0.7 : 0.2), lineWidth: 2))
                                .frame(width: 26, height: 26)
                            Text(day.formatted(.dateTime.weekday(.narrow)))
                                .font(.cartoonFixed(10, .bold))
                                .foregroundStyle(Ink.text.opacity(0.5))
                        }
                    }
                }
                .padding(.top, 4)
                Text("\(habit.formatTotal(habit.totalLogged)) logged so far")
                    .font(.cartoonFixed(13, .bold))
                    .foregroundStyle(habit.color.deep)
            }
        }
    }

    private func pill(_ text: String, fill: Color) -> some View {
        Text(text)
            .font(.cartoonFixed(13, .bold))
            .foregroundStyle(Ink.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(Ink.color, lineWidth: 2))
    }
}

// MARK: - Share button

/// Renders `card` to a 1080×1350 image and offers it through the share sheet.
struct ShareCardButton<CardView: View>: View {
    let title: String
    let card: CardView
    var compact = false

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                ShareLink(item: Image(uiImage: image),
                          preview: SharePreview(title, image: Image(uiImage: image))) {
                    label
                }
            } else {
                label.opacity(0.5)
            }
        }
        .buttonStyle(BouncyButtonStyle())
        .task { render() }
        .accessibilityLabel("Share \(title)")
    }

    private var label: some View {
        Group {
            if compact {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Ink.text)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Card.color))
                    .overlay(Circle().stroke(Ink.color, lineWidth: 2.5))
                    .background(Circle().fill(Ink.color).offset(y: 3))
            } else {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.cartoon(17))
                    .foregroundStyle(Ink.color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .cartoonCard(radius: 18, fill: HabitColor.sunny.main)
            }
        }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .light))
        renderer.scale = 3   // 360x450 pt -> 1080x1350 px
        image = renderer.uiImage
    }
}

/// Preview of a share card inside the app (used in CI screenshots).
struct ShareCardPreview: View {
    let habits: [Habit]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                WeekShareCard(habits: habits, endDay: Date())
                if let h = habits.first {
                    HabitShareCard(habit: h)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Paper.color)
    }
}
