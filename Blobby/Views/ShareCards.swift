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
                    BlobMascot(progress: 0.6, color: .ocean, kind: .drop, size: 22, animated: false)
                    Text("Made with Blobby")
                        .font(.cartoonFixed(12, .bold))
                        .foregroundStyle(Ink.text.opacity(0.5))
                }
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Ink.color, lineWidth: 4)
                .padding(2)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .light)   // share images always use the day look
    }
}

/// Weekly report card.
struct WeekShareCard: View {
    let habits: [Habit]
    let endDay: Date

    private var start: Date { Calendar.current.date(byAdding: .day, value: -6, to: endDay) ?? endDay }

    private var rows: [(habit: Habit, done: Int, scheduled: Int)] {
        habits.filter { !$0.isPaused }.prefix(5).map { h in
            let s = h.weekStats(ending: endDay)
            return (h, s.done, s.scheduled)
        }
    }

    var body: some View {
        let done = rows.reduce(0) { $0 + $1.done }
        let total = rows.reduce(0) { $0 + $1.scheduled }
        let star = rows.filter { $0.scheduled > 0 }
            .max { Double($0.done) / Double($0.scheduled) < Double($1.done) / Double($1.scheduled) }?.habit

        CardFrame(tint: star?.color ?? .ocean) {
            VStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text("My week")
                        .font(.cartoonFixed(28))
                        .foregroundStyle(Ink.text)
                    Text("\(start.formatted(.dateTime.day().month())) – \(endDay.formatted(.dateTime.day().month()))")
                        .font(.cartoonFixed(12, .bold))
                        .foregroundStyle(Ink.text.opacity(0.5))
                }
                HStack(spacing: 14) {
                    if let star = star {
                        BlobMascot(progress: 1, color: star.color, kind: star.kind, size: 92,
                                   celebrate: true, sticker: star.emoji, accessories: star.unlocked, animated: false)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(done)/\(total)")
                            .font(.cartoonFixed(40))
                            .foregroundStyle(Ink.text)
                        Text("goals hit")
                            .font(.cartoonFixed(15, .bold))
                            .foregroundStyle(Ink.text.opacity(0.6))
                    }
                }
                VStack(spacing: 6) {
                    ForEach(rows.indices, id: \.self) { i in
                        row(rows[i].habit, done: rows[i].done, scheduled: rows[i].scheduled)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Card.color))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Ink.color, lineWidth: 2.5))
            }
        }
    }

    private func row(_ h: Habit, done: Int, scheduled: Int) -> some View {
        HStack(spacing: 8) {
            BlobMascot(progress: scheduled > 0 ? Double(done) / Double(scheduled) : 0, color: h.color,
                       kind: h.kind, size: 28, animated: false)
            Text(h.name)
                .font(.cartoonFixed(13, .bold))
                .foregroundStyle(Ink.text)
                .lineLimit(1)
            Spacer(minLength: 4)
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { i in
                    let day = Calendar.current.date(byAdding: .day, value: i - 6, to: endDay) ?? endDay
                    Circle()
                        .fill(h.isDone(on: day) ? h.color.main : (h.isScheduled(on: day) ? h.color.light : Color.clear))
                        .overlay(Circle().stroke(Ink.color.opacity(h.isScheduled(on: day) ? 0.5 : 0.15), lineWidth: 1))
                        .frame(width: 11, height: 11)
                }
            }
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
        ScrollView {
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
