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

    enum Mode: String, CaseIterable { case week = "Week", month = "Month" }
    @State private var mode: Mode = .week
    /// 0 = latest week/month, 1 = the one before, ...
    @State private var offset = 0

    private let cal = Calendar.current

    /// Latest week ends today on Sunday, otherwise yesterday (the last complete day).
    private var latestWeekEnd: Date {
        if cal.component(.weekday, from: Date()) == 1 { return Date() }
        return cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }

    private var range: (start: Date, end: Date) {
        switch mode {
        case .week:
            let end = cal.date(byAdding: .day, value: -7 * offset, to: latestWeekEnd) ?? latestWeekEnd
            return (cal.date(byAdding: .day, value: -6, to: end) ?? end, end)
        case .month:
            let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
            let start = cal.date(byAdding: .month, value: -offset, to: thisMonth) ?? thisMonth
            let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start
            return (start, end)
        }
    }

    /// Earliest day with any log, so we know how far back the ‹ arrow can go.
    private var earliest: Date? { store.habits.compactMap(\.firstLogDay).min() }

    private var canGoBack: Bool {
        guard let e = earliest else { return false }
        return range.start > cal.startOfDay(for: e)
    }

    private var stats: [(habit: Habit, done: Int, scheduled: Int, amount: Double)] {
        let r = range
        return store.habits.compactMap { h in
            let s = h.stats(from: r.start, to: r.end)
            // Latest week keeps the old rule (active habits); older periods show anything that had days.
            if offset == 0 && mode == .week && h.isPaused { return nil }
            if offset > 0 || mode == .month, s.scheduled == 0 && s.amount == 0 { return nil }
            return (h, s.done, s.scheduled, s.amount)
        }
    }

    private var totalDone: Int { stats.reduce(0) { $0 + $1.done } }
    private var totalScheduled: Int { stats.reduce(0) { $0 + $1.scheduled } }

    private var star: Habit? {
        stats.filter { $0.scheduled > 0 && $0.done > 0 }
            .max { Double($0.done) / Double($0.scheduled) < Double($1.done) / Double($1.scheduled) }?
            .habit
    }

    private var title: String {
        switch mode {
        case .week: return offset == 0 ? "Your week" : (offset == 1 ? "Last week" : "\(offset) weeks ago")
        case .month: return range.start.formatted(.dateTime.month(.wide).year())
        }
    }

    private var subtitle: String {
        let r = range
        switch mode {
        case .week: return "\(r.start.formatted(.dateTime.day().month())) – \(r.end.formatted(.dateTime.day().month()))"
        case .month: return offset == 0 ? "This month so far" : "Whole month"
        }
    }

    var body: some View {
        ZStack {
            Paper.color.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Text("Reports")
                            .font(.cartoon(30))
                            .foregroundStyle(Ink.text)
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
                        .accessibilityLabel("Close")
                    }

                    modePicker
                    periodBar

                    // Headline
                    VStack(spacing: 6) {
                        if let star = star {
                            BlobMascot(progress: 1, color: star.color, kind: star.kind, size: 110,
                                       celebrate: offset == 0, sticker: star.emoji, accessories: star.unlocked)
                            Text("Star of the \(mode == .week ? "week" : "month"): \(star.name)")
                                .font(.cartoon(18))
                                .foregroundStyle(Ink.text)
                                .multilineTextAlignment(.center)
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

                    if mode == .month {
                        MonthOverview(habits: stats.map(\.habit), month: range.start)
                    }

                    let rows = stats
                    if rows.isEmpty {
                        Text("Nothing logged in this period.")
                            .font(.cartoon(15, .semibold))
                            .foregroundStyle(Ink.text.opacity(0.55))
                            .padding(.vertical, 20)
                    }
                    ForEach(rows.indices, id: \.self) { i in
                        recapRow(rows[i].habit, done: rows[i].done, scheduled: rows[i].scheduled, amount: rows[i].amount)
                    }

                    if mode == .week {
                        ShareCardButton(title: "\(Profile.possessive()) week on Blobby",
                                        card: WeekShareCard(habits: store.habits, endDay: range.end))
                            .padding(.top, 4)
                    }
                }
                .padding(20)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: offset)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mode)
            }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Paper.color)
        .appAppearance()
        .onAppear {
            WeeklyRecap.markShown()
            if LaunchOptions.reportMonth { mode = .month }
        }
    }

    private var modePicker: some View {
        HStack(spacing: 10) {
            ForEach(Mode.allCases, id: \.self) { m in
                let selected = mode == m
                Button {
                    mode = m
                    offset = 0
                } label: {
                    Text(m.rawValue)
                        .font(.cartoon(16))
                        .foregroundStyle(selected ? Ink.color : Ink.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .cartoonCard(radius: 16, fill: selected ? HabitColor.sunny.main : Card.color)
                }
                .buttonStyle(BouncyButtonStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var periodBar: some View {
        HStack(spacing: 12) {
            arrow("chevron.left", enabled: canGoBack, label: "Previous \(mode == .week ? "week" : "month")") { offset += 1 }
            VStack(spacing: 2) {
                Text(title)
                    .font(.cartoon(20))
                    .foregroundStyle(Ink.text)
                Text(subtitle)
                    .font(.cartoon(13, .bold))
                    .foregroundStyle(Ink.text.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            arrow("chevron.right", enabled: offset > 0, label: "Next \(mode == .week ? "week" : "month")") { offset -= 1 }
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Ink.text)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Card.color))
                .overlay(Circle().stroke(Ink.color, lineWidth: 2.5))
                .background(Circle().fill(Ink.color).offset(y: 3))
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }

    private var headline: String {
        guard totalScheduled > 0 else { return offset == 0 ? "Add a habit to start your first week." : "No goals in this period." }
        let ratio = Double(totalDone) / Double(totalScheduled)
        let period = mode == .week ? "week" : "month"
        switch ratio {
        case 1: return "A perfect \(period). Your buddies are throwing a party! 🎉"
        case 0.75...: return "Great \(period)! Just a few slips. 🌟"
        case 0.4...: return "Solid going. Small steps add up. 💪"
        default: return "Fresh start next time. Your buddies believe in you. 🌱"
        }
    }

    private func recapRow(_ h: Habit, done: Int, scheduled: Int, amount: Double) -> some View {
        let ratio = scheduled > 0 ? Double(done) / Double(scheduled) : 0
        let badge = scheduled == 0 ? "😴" : (ratio >= 1 ? "🏆" : (ratio >= 0.7 ? "🌟" : "💪"))
        return HStack(spacing: 12) {
            BlobMascot(progress: ratio, color: h.color, kind: h.kind, size: 58, sticker: h.emoji,
                       sad: scheduled > 0 && ratio < 0.4, accessories: h.unlocked, animated: false)
            VStack(alignment: .leading, spacing: 6) {
                Text(h.name)
                    .font(.cartoon(17))
                    .foregroundStyle(Ink.text)
                if mode == .week {
                    HStack(spacing: 5) {
                        ForEach(0..<7, id: \.self) { i in
                            dayDot(h, offset: 6 - i)
                        }
                    }
                }
                Text(scheduled == 0 ? "No days scheduled" : "\(done) of \(scheduled) days · \(h.formatTotal(amount))")
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
        let end = range.end
        let day = cal.date(byAdding: .day, value: -offset, to: end) ?? end
        let scheduled = h.isScheduled(on: day)
        let done = h.isDone(on: day)
        return ZStack {
            Circle().fill(done ? h.color.main : (scheduled ? h.color.light : Color.clear))
            Circle().stroke(scheduled ? Ink.text.opacity(0.6) : Ink.text.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1.5, dash: scheduled ? [] : [2, 2]))
        }
        .frame(width: 16, height: 16)
    }
}

/// All habits on one month calendar: each day's ring fills with the share of goals done.
struct MonthOverview: View {
    let habits: [Habit]
    let month: Date
    private let cal = Calendar.current

    private var days: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let dates = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: month) }
        return Array(repeating: nil, count: lead) + dates.map { Optional($0) }
    }

    private func ratio(_ day: Date) -> Double? {
        guard day <= Date() else { return nil }
        var done = 0, scheduled = 0
        for h in habits {
            let s = h.stats(from: day, to: day)
            done += s.done; scheduled += s.scheduled
        }
        return scheduled == 0 ? nil : Double(done) / Double(scheduled)
    }

    var body: some View {
        let symbols = cal.veryShortWeekdaySymbols
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 }
        VStack(spacing: 10) {
            HStack {
                ForEach(Array(order.enumerated()), id: \.offset) { _, i in
                    Text(symbols[i]).font(.cartoon(12, .bold)).foregroundStyle(Ink.text.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day = day {
                        cell(day)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
            HStack(spacing: 14) {
                legend(HabitColor.sunny.main, "All done")
                legend(HabitColor.sunny.main.opacity(0.45), "Some")
                legend(Color.clear, "None / rest", dashed: true)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .cartoonCard()
    }

    private func cell(_ day: Date) -> some View {
        let r = ratio(day)
        let n = cal.component(.day, from: day)
        let isToday = cal.isDateInToday(day)
        return ZStack {
            Circle().fill(Card.color)
            if let r = r, r > 0 {
                Circle().trim(from: 0, to: r)
                    .stroke(HabitColor.sunny.main, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                if r >= 1 { Circle().fill(HabitColor.sunny.main).padding(5) }
            }
            Circle().stroke(Ink.text.opacity(r == nil ? 0.15 : 0.5),
                            style: StrokeStyle(lineWidth: isToday ? 2.5 : 1.2, dash: r == nil ? [2, 2] : []))
            Text("\(n)")
                .font(.cartoon(12, .bold))
                .foregroundStyle(r.map { $0 >= 1 } == true ? Ink.color : Ink.text.opacity(day > Date() ? 0.3 : 0.85))
        }
        .frame(height: 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.formatted(.dateTime.day().month(.wide)))
        .accessibilityValue(r.map { "\(Int(($0 * 100).rounded())) percent of goals done" } ?? "No goals")
    }

    private func legend(_ color: Color, _ text: String, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 12, height: 12)
                .overlay(Circle().stroke(Ink.text.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: dashed ? [2, 2] : [])))
            Text(text).font(.cartoon(11, .bold)).foregroundStyle(Ink.text.opacity(0.6))
        }
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

    @State private var page = LaunchOptions.onboardingPage
    @State private var picked: HabitPreset?
    @State private var name = Profile.name
    @State private var buddyKind = Profile.kind
    @State private var buddyColor = Profile.color

    private var nameOK: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private let lastPage = 3
    @State private var remind = true
    @State private var bump = 0

    var body: some View {
        ZStack {
            Paper.color.ignoresSafeArea()
            BackgroundBubbles(color: HabitColor.sunny.main)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    // Skip still needs a name: jump to "About you" first.
                    Button("Skip") { if nameOK { finish() } else { withAnimation { page = 1 } } }
                        .font(.cartoon(16, .bold))
                        .foregroundStyle(Ink.text.opacity(0.5))
                        .opacity(page == 1 && !nameOK ? 0 : 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                TabView(selection: $page) {
                    welcome.tag(0)
                    aboutYou.tag(1)
                    pickHabit.tag(2)
                    reminder.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: page)
                .onChange(of: page) { old, new in
                    if new > 1 && !nameOK { withAnimation { page = 1 } }
                    if old == 1 && nameOK { Profile.save(name: name, kind: buddyKind, color: buddyColor) }
                }

                // Dots
                HStack(spacing: 8) {
                    ForEach(0...lastPage, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Ink.text : Ink.text.opacity(0.2))
                            .frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                .animation(.spring, value: page)
                .padding(.bottom, 16)

                Button(action: next) {
                    Text(page == lastPage ? "Let's go!" : "Next")
                        .font(.cartoon(20))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                }
                .cartoonCard(radius: 20, fill: blocked ? .gray : (page == 1 ? buddyColor.main : (picked?.color.main ?? HabitColor.ocean.main)))
                .buttonStyle(BouncyButtonStyle())
                .disabled(blocked)
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

    /// Next is blocked until there's a name (page 1) and a habit (page 2).
    private var blocked: Bool { (page == 1 && !nameOK) || (page == 2 && picked == nil) }

    private var aboutYou: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("What should Blobby call you?")
                    .font(.cartoon(26))
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                Text("And pick a buddy to be you. It shows up next to your name and on cards you share.")
                    .font(.cartoon(15, .medium))
                    .foregroundStyle(Ink.text.opacity(0.55))
                    .multilineTextAlignment(.center)
                AboutYouForm(name: $name, kind: $buddyKind, color: $buddyColor, bump: bump)
                Text("Stays on this phone. No account needed.")
                    .font(.cartoon(12, .bold))
                    .foregroundStyle(Ink.text.opacity(0.45))
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
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
                            Text(preset.summary)
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
        if page == 1 { Profile.save(name: name, kind: buddyKind, color: buddyColor) }
        if page < lastPage {
            withAnimation { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        if nameOK { Profile.save(name: name, kind: buddyKind, color: buddyColor) }
        if let p = picked {
            let habit = Habit(name: p.name, emoji: p.emoji, color: p.color, kind: p.kind,
                              goal: p.goal, unit: p.unit, step: p.step,
                              reminderHour: remind ? 18 : nil, reminderMinute: remind ? 0 : nil,
                              type: p.type, deadlineHour: p.deadline?.0, deadlineMinute: p.deadline?.1)
            store.add(habit)
            if remind {
                Task { _ = await Reminders.shared.requestPermission() }
            }
        }
        onFinish()
    }
}
