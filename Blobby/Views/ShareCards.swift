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

    /// Same counting as Reports: days before a habit's first log don't count against it,
    /// and today only counts once it's done.
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
        guard let first = h.firstLogDay.map({ cal.startOfDay(for: $0) }),
              cal.startOfDay(for: day) >= first else { return false }
        if cal.startOfDay(for: day) > cal.startOfDay(for: Date()) { return false }
        if cal.isDateInToday(day) && !h.isDone(on: day) { return false }
        return h.isScheduled(on: day)
    }

    /// Share of all habits done on one day (nil = nothing counted that day).
    private func dayRatio(_ day: Date) -> Double? {
        var done = 0, due = 0
        for r in rows where counts(r.habit, day) {
            due += 1
            if r.habit.isDone(on: day) { done += 1 }
        }
        return due == 0 ? nil : Double(done) / Double(due)
    }

    private var bestStreak: Habit? {
        rows.map(\.habit).filter { $0.streak >= 2 }.max { $0.streak < $1.streak }
    }

    private var buddyColor: HabitColor { Profile.name.isEmpty ? .ocean : Profile.color }

    var body: some View {
        let done = rows.reduce(0) { $0 + $1.done }
        let total = rows.reduce(0) { $0 + $1.scheduled }
        let percent = total == 0 ? 0 : Int((Double(done) / Double(total) * 100).rounded())
        let perfect = days.filter { (dayRatio($0) ?? 0) >= 1 }.count
        let showPercent = total > 0 && percent >= 60

        CardFrame(tint: buddyColor) {
            VStack(spacing: 14) {
                // Title
                VStack(spacing: 2) {
                    Text("\(Profile.possessive()) week")
                        .font(.cartoonFixed(26))
                        .foregroundStyle(Ink.text)
                    Text("\(start.formatted(.dateTime.day().month())) – \(endDay.formatted(.dateTime.day().month()))")
                        .font(.cartoonFixed(12, .bold))
                        .foregroundStyle(Ink.text.opacity(0.5))
                }

                // Hero: your buddy + one big, good number
                HStack(spacing: 16) {
                    BlobMascot(progress: max(0.35, Double(percent) / 100), color: buddyColor,
                               kind: Profile.name.isEmpty ? .drop : Profile.kind, size: 92,
                               celebrate: done > 0, animated: false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(showPercent ? "\(percent)%" : (done > 0 ? "\(done)" : "🌱"))
                            .font(.cartoonFixed(50))
                            .foregroundStyle(Ink.text)
                        Text(showPercent ? "of habits done" : (done == 0 ? "Fresh start" : (done == 1 ? "win this week" : "wins this week")))
                            .font(.cartoonFixed(15, .bold))
                            .foregroundStyle(Ink.text.opacity(0.7))
                        HStack(spacing: 6) {
                            if let s = bestStreak { pill("🔥 \(s.streak) days") }
                            if perfect > 0 { pill("⭐️ \(perfect) perfect") }
                        }
                        .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)

                // The squad: each habit's character, filled by how its week went
                HStack(alignment: .top, spacing: 6) {
                    ForEach(rows.indices, id: \.self) { i in
                        squadMember(rows[i].habit, done: rows[i].done, due: rows[i].scheduled)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Card.color))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Ink.color, lineWidth: 2.5))

                weekStrip
            }
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.cartoonFixed(11, .bold))
            .foregroundStyle(Ink.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(HabitColor.sunny.light))
            .overlay(Capsule().stroke(Ink.color, lineWidth: 1.5))
    }

    private func squadMember(_ h: Habit, done: Int, due: Int) -> some View {
        let ratio = due > 0 ? Double(done) / Double(due) : 0
        return VStack(spacing: 4) {
            BlobMascot(progress: max(0.2, ratio), color: h.color, kind: h.kind, size: 46,
                       celebrate: due > 0 && ratio >= 1, accessories: h.unlocked, animated: false)
                .frame(height: 58, alignment: .bottom)
            Text(h.name)
                .font(.cartoonFixed(10, .bold))
                .foregroundStyle(Ink.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(due == 0 ? "new" : "\(done)/\(due)")
                .font(.cartoonFixed(11, .heavy))
                .foregroundStyle(due > 0 && ratio >= 1 ? Ink.color : Ink.text.opacity(0.6))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(due > 0 && ratio >= 1 ? h.color.main : Color.clear))
        }
        .frame(maxWidth: .infinity)
    }

    /// One dot per day for all habits together: full = everything done, light = some, white = none.
    private var weekStrip: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { day in
                let r = dayRatio(day)
                VStack(spacing: 3) {
                    ZStack {
                        Circle().fill(r == nil ? Color.clear
                                      : (r! >= 1 ? HabitColor.sunny.main
                                         : (r! > 0 ? HabitColor.sunny.main.opacity(0.4) : Card.color)))
                        Circle().stroke(Ink.color.opacity(r == nil ? 0.2 : 0.6),
                                        style: StrokeStyle(lineWidth: 1.5, dash: r == nil ? [2, 2] : []))
                        if let r = r, r >= 1 {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Ink.color)
                        }
                    }
                    .frame(width: 24, height: 24)
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.cartoonFixed(10, .bold))
                        .foregroundStyle(Ink.text.opacity(0.5))
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
