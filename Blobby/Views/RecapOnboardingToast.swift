import SwiftUI

// MARK: - Undo toast

/// "+250 ml · Drink water   [Undo]" for a few seconds after every + tap.
struct UndoToast: View {
    @EnvironmentObject var store: HabitStore

    var body: some View {
        VStack {
            Spacer()
            if let event = store.lastLog {
                HStack(spacing: 12) {
                    Text(event.text)
                        .font(.cartoon(15, .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.undo(event) }
                    } label: {
                        Text("Undo")
                            .font(.cartoon(15))
                            .foregroundStyle(Ink.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(HabitColor.sunny.main))
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .background(Capsule().fill(Ink.color))
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(event.id)
                .task(id: event.id) {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if store.lastLog?.id == event.id {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { store.lastLog = nil }
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.lastLog)
    }
}

// MARK: - Weekly recap

/// A report card for the last 7 days (shown Sunday evening / Monday, or from Settings).
struct WeeklyRecapView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    /// Week ends today on Sunday, otherwise yesterday (the last complete day).
    private var endDay: Date {
        let cal = Calendar.current
        if cal.component(.weekday, from: Date()) == 1 { return Date() }
        return cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }

    private var startDay: Date {
        Calendar.current.date(byAdding: .day, value: -6, to: endDay) ?? endDay
    }

    private var stats: [(habit: Habit, done: Int, scheduled: Int)] {
        store.habits.filter { !$0.isPaused }.map { h in
            let s = h.weekStats(ending: endDay)
            return (h, s.done, s.scheduled)
        }
    }

    private var totalDone: Int { stats.reduce(0) { $0 + $1.done } }
    private var totalScheduled: Int { stats.reduce(0) { $0 + $1.scheduled } }

    private var star: Habit? {
        stats.filter { $0.scheduled > 0 }
            .max { Double($0.done) / Double($0.scheduled) < Double($1.done) / Double($1.scheduled) }?
            .habit
    }

    var body: some View {
        ZStack {
            Paper.color.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your week")
                                .font(.cartoon(30))
                                .foregroundStyle(Ink.text)
                            Text("\(startDay.formatted(.dateTime.day().month())) – \(endDay.formatted(.dateTime.day().month()))")
                                .font(.cartoon(14, .bold))
                                .foregroundStyle(Ink.text.opacity(0.5))
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(Ink.text)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(Card.color))
                                .overlay(Circle().stroke(Ink.color, lineWidth: 2.5))
                        }
                        .buttonStyle(BouncyButtonStyle())
                    }

                    // Headline
                    VStack(spacing: 6) {
                        if let star = star {
                            BlobMascot(progress: 1, color: star.color, kind: star.kind, size: 120,
                                       celebrate: true, sticker: star.emoji, accessories: star.unlocked)
                            Text("Star of the week: \(star.name)")
                                .font(.cartoon(18))
                                .foregroundStyle(Ink.text)
                        }
                        Text("You hit \(totalDone) of \(totalScheduled) goals")
                            .font(.cartoon(24))
                            .foregroundStyle(Ink.text)
                        Text(headline)
                            .font(.cartoon(15, .semibold))
                            .foregroundStyle(Ink.text.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .cartoonCard(fill: HabitColor.sunny.light)

                    let rows = stats
                    ForEach(rows.indices, id: \.self) { i in
                        recapRow(rows[i].habit, done: rows[i].done, scheduled: rows[i].scheduled)
                    }

                    ShareCardButton(title: "My week on Blobby",
                                    card: WeekShareCard(habits: store.habits, endDay: endDay))
                        .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Paper.color)
        .appAppearance()
        .onAppear { WeeklyRecap.markShown() }
    }

    private var headline: String {
        guard totalScheduled > 0 else { return "Add a habit to start your first week." }
        let ratio = Double(totalDone) / Double(totalScheduled)
        switch ratio {
        case 1: return "A perfect week. Your buddies are throwing a party! 🎉"
        case 0.75...: return "Great week! Just a few slips. 🌟"
        case 0.4...: return "Solid start. Small steps add up. 💪"
        default: return "New week, fresh start. Your buddies believe in you. 🌱"
        }
    }

    private func recapRow(_ h: Habit, done: Int, scheduled: Int) -> some View {
        let ratio = scheduled > 0 ? Double(done) / Double(scheduled) : 0
        let badge = scheduled == 0 ? "😴" : (ratio >= 1 ? "🏆" : (ratio >= 0.7 ? "🌟" : "💪"))
        return HStack(spacing: 12) {
            BlobMascot(progress: ratio, color: h.color, kind: h.kind, size: 58, sticker: h.emoji,
                       sad: scheduled > 0 && ratio < 0.4, accessories: h.unlocked)
            VStack(alignment: .leading, spacing: 6) {
                Text(h.name)
                    .font(.cartoon(17))
                    .foregroundStyle(Ink.text)
                HStack(spacing: 5) {
                    ForEach(0..<7, id: \.self) { i in
                        dayDot(h, offset: 6 - i)
                    }
                }
                Text(scheduled == 0 ? "No days scheduled" : "\(done) of \(scheduled) days")
                    .font(.cartoon(12, .bold))
                    .foregroundStyle(Ink.text.opacity(0.55))
            }
            Spacer()
            Text(badge).font(.system(size: 30))
        }
        .padding(14)
        .cartoonCard()
    }

    private func dayDot(_ h: Habit, offset: Int) -> some View {
        let day = Calendar.current.date(byAdding: .day, value: -offset, to: endDay) ?? endDay
        let scheduled = h.isScheduled(on: day)
        let done = h.isDone(on: day)
        return ZStack {
            Circle().fill(done ? h.color.main : (scheduled ? h.color.light : Color.clear))
            Circle().stroke(scheduled ? Ink.color.opacity(0.6) : Ink.color.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1.5, dash: scheduled ? [] : [2, 2]))
        }
        .frame(width: 16, height: 16)
    }
}

/// When to auto-show the recap: Sunday from 5 pm, or Monday, once per week.
enum WeeklyRecap {
    private static let key = "recapShownWeek"

    private static var weekID: String {
        let cal = Calendar.current
        // Monday belongs to the week that just ended.
        let ref = cal.component(.weekday, from: Date()) == 2
            ? (cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()) : Date()
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ref)
        return "\(c.yearForWeekOfYear ?? 0)-\(c.weekOfYear ?? 0)"
    }

    static var isDue: Bool {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        let hour = cal.component(.hour, from: Date())
        let inWindow = (weekday == 1 && hour >= 17) || weekday == 2
        return inWindow && UserDefaults.standard.string(forKey: key) != weekID
    }

    static func markShown() {
        UserDefaults.standard.set(weekID, forKey: key)
    }
}

// MARK: - Onboarding

/// First launch: say hi, pick a first habit, optionally turn on a reminder.
struct OnboardingView: View {
    @EnvironmentObject var store: HabitStore
    let onFinish: () -> Void

    @State private var page = 0
    @State private var picked: HabitPreset?
    @State private var remind = true
    @State private var bump = 0

    var body: some View {
        ZStack {
            Paper.color.ignoresSafeArea()
            BackgroundBubbles(color: HabitColor.sunny.main)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.cartoon(16, .bold))
                        .foregroundStyle(Ink.text.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                TabView(selection: $page) {
                    welcome.tag(0)
                    pickHabit.tag(1)
                    reminder.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: page)

                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Ink.color : Ink.color.opacity(0.2))
                            .frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                .animation(.spring, value: page)
                .padding(.bottom, 16)

                Button(action: next) {
                    Text(page == 2 ? "Let's go!" : "Next")
                        .font(.cartoon(20))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                }
                .cartoonCard(radius: 20, fill: page == 1 && picked == nil ? .gray : (picked?.color.main ?? HabitColor.ocean.main))
                .buttonStyle(BouncyButtonStyle())
                .disabled(page == 1 && picked == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .appAppearance()
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            HStack(spacing: -10) {
                BlobMascot(progress: 0.7, color: .ocean, kind: .drop, size: 110)
                BlobMascot(progress: 0.5, color: .mint, kind: .flame, size: 90)
                BlobMascot(progress: 0.9, color: .grape, kind: .sprout, size: 100)
            }
            Text("Hi, we're your habit buddies!")
                .font(.cartoon(28))
                .foregroundStyle(Ink.text)
                .multilineTextAlignment(.center)
            Text("Every habit gets its own little character. Log your progress and watch it fill up, grow, and level up with your streaks.")
                .font(.cartoon(17, .medium))
                .foregroundStyle(Ink.text.opacity(0.6))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var pickHabit: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            if let p = picked {
                BlobMascot(progress: 0.5, color: p.color, kind: p.kind, size: 120, bump: bump, sticker: p.emoji)
            } else {
                BlobMascot(progress: 0.3, color: .ocean, kind: .blob, size: 120, bump: bump)
            }
            Text("Pick your first habit")
                .font(.cartoon(26))
                .foregroundStyle(Ink.text)
            Text("You can add more and change everything later.")
                .font(.cartoon(15, .medium))
                .foregroundStyle(Ink.text.opacity(0.55))
            VStack(spacing: 10) {
                ForEach(HabitPreset.all) { preset in
                    let selected = picked?.name == preset.name
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { picked = preset }
                        bump += 1
                        SoundFX.shared.play(.pop, pitch: preset.kind.popPitch)
                    } label: {
                        HStack {
                            Text("\(preset.emoji)  \(preset.name)")
                                .font(.cartoon(17))
                            Spacer()
                            Text("\(preset.goal.clean) \(preset.unit)")
                                .font(.cartoon(13, .bold))
                                .opacity(0.6)
                        }
                        .foregroundStyle(Ink.text)
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                    }
                    .cartoonCard(radius: 16, fill: selected ? preset.color.light : Card.color)
                    .scaleEffect(selected ? 1.02 : 1)
                    .buttonStyle(BouncyButtonStyle())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    private var reminder: some View {
        VStack(spacing: 18) {
            Spacer()
            if let p = picked {
                BlobMascot(progress: 0.5, color: p.color, kind: p.kind, size: 130, sticker: p.emoji)
            }
            Text("Want a daily nudge?")
                .font(.cartoon(26))
                .foregroundStyle(Ink.text)
            Text("\(picked?.kind.title ?? "Your buddy") can remind you every evening at 18:00. It stays quiet on days you've already finished.")
                .font(.cartoon(16, .medium))
                .foregroundStyle(Ink.text.opacity(0.6))
                .multilineTextAlignment(.center)
            HStack {
                Text("🔔 Remind me")
                    .font(.cartoon(18))
                    .foregroundStyle(Ink.text)
                Spacer()
                CartoonToggle(isOn: $remind, color: picked?.color ?? .ocean)
            }
            .padding(16)
            .cartoonCard(radius: 20)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func next() {
        if page < 2 {
            withAnimation { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        if let p = picked {
            let habit = Habit(name: p.name, emoji: p.emoji, color: p.color, kind: p.kind,
                              goal: p.goal, unit: p.unit, step: p.step,
                              reminderHour: remind ? 18 : nil, reminderMinute: remind ? 0 : nil)
            store.add(habit)
            if remind {
                Task { _ = await Reminders.shared.requestPermission() }
            }
        }
        onFinish()
    }
}
