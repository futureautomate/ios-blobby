import SwiftUI

// MARK: - Level card

/// Level, progress to the next accessory, and the accessory collection.
struct LevelCard: View {
    let habit: Habit

    var body: some View {
        let best = habit.bestStreak
        let next = habit.nextAccessory
        let previousDays = habit.unlocked.last?.days ?? 0
        let progress: Double = next.map { n in
            Double(best - previousDays) / Double(max(n.days - previousDays, 1))
        } ?? 1

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("LV \(habit.level)")
                    .font(.cartoon(16))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(habit.color.main))
                    .overlay(Circle().stroke(Ink.color, lineWidth: 3))
                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.levelTitle)
                        .font(.cartoon(20))
                        .foregroundStyle(Ink.color)
                    Text("Best streak: \(best) day\(best == 1 ? "" : "s")")
                        .font(.cartoon(13, .semibold))
                        .foregroundStyle(Ink.color.opacity(0.55))
                }
                Spacer()
            }

            ProgressPill(progress: progress, color: habit.color, height: 12)

            Text(next.map { "\(max($0.days - best, 0)) more day\($0.days - best == 1 ? "" : "s") in a row to unlock \($0.emoji) \($0.title)" }
                 ?? "Max level! \(habit.kind.title) is royalty 👑")
                .font(.cartoon(13, .bold))
                .foregroundStyle(habit.color.deep)

            HStack(spacing: 0) {
                ForEach(Accessory.allCases) { acc in
                    slot(acc, unlocked: habit.unlocked.contains(acc))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .cartoonCard()
    }

    private func slot(_ acc: Accessory, unlocked: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(unlocked ? habit.color.light : Paper.color)
                if unlocked {
                    Text(acc.emoji).font(.system(size: 22))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Ink.color.opacity(0.3))
                }
                Circle().stroke(unlocked ? Ink.color : Ink.color.opacity(0.25),
                                style: StrokeStyle(lineWidth: 2.5, dash: unlocked ? [] : [4, 3]))
            }
            .frame(width: 46, height: 46)
            Text(unlocked ? acc.title : "\(acc.days) days")
                .font(.cartoon(11, .bold))
                .foregroundStyle(Ink.color.opacity(unlocked ? 0.8 : 0.4))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Level-up popup

struct LevelUpPopup: View {
    let habit: Habit
    let accessory: Accessory
    let onClose: () -> Void

    @State private var shown = false
    @State private var bump = 0

    var body: some View {
        ZStack {
            Ink.color.opacity(shown ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            ConfettiView(start: Date(), loop: true,
                         colors: [habit.color.main, HabitColor.sunny.main, HabitColor.coral.main, HabitColor.mint.main])

            VStack(spacing: 10) {
                Text("LEVEL UP!")
                    .font(.cartoon(34))
                    .foregroundStyle(HabitColor.sunny.main)
                    .shadow(color: Ink.color, radius: 0, x: 2, y: 3)
                BlobMascot(progress: 1, color: habit.color, kind: habit.kind, size: 150, bump: bump,
                           celebrate: true, sticker: habit.emoji, accessories: habit.unlocked)
                    .allowsHitTesting(false)
                    .padding(.top, 34)   // room for the hat / crown above the character
                Text("\(habit.kind.title) earned \(accessory.emoji) \(accessory.title)")
                    .font(.cartoon(20))
                    .foregroundStyle(Ink.color)
                    .multilineTextAlignment(.center)
                Text("\(accessory.days) days in a row of \(habit.name.lowercased()). Level \(habit.level) · \(accessory.levelTitle)")
                    .font(.cartoon(14, .semibold))
                    .foregroundStyle(Ink.color.opacity(0.6))
                    .multilineTextAlignment(.center)
                Button(action: onClose) {
                    Text("Yay!")
                        .font(.cartoon(19))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .cartoonCard(radius: 18, fill: habit.color.main)
                .buttonStyle(BouncyButtonStyle())
                .padding(.top, 6)
            }
            .padding(22)
            .cartoonCard(radius: 30, fill: habit.color.light)
            .padding(.horizontal, 30)
            .scaleEffect(shown ? 1 : 0.5)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { shown = true }
            bump += 1
            SoundFX.shared.play(.fanfare)
        }
        .sensoryFeedback(.success, trigger: shown)
    }
}

// MARK: - History calendar

/// Month grid of daily progress rings plus all-time stats.
struct HistoryCard: View {
    let habit: Habit
    @State private var month: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()

    private var cal: Calendar { Calendar.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("History")
                    .font(.cartoon(18))
                    .foregroundStyle(Ink.color)
                Spacer()
                monthButton("chevron.left") { shift(-1) }
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.cartoon(15, .bold))
                    .foregroundStyle(Ink.color)
                    .frame(minWidth: 120)
                    .contentTransition(.numericText())
                monthButton("chevron.right") { shift(1) }
                    .opacity(isCurrentMonth ? 0.3 : 1)
                    .disabled(isCurrentMonth)
            }

            // Weekday header
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, d in
                    Text(d)
                        .font(.cartoon(11, .bold))
                        .foregroundStyle(Ink.color.opacity(0.45))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day = day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
            .id(month)
            .transition(.opacity)

            Divider().overlay(Ink.color.opacity(0.15))

            HStack(spacing: 0) {
                stat("🔥", "\(habit.bestStreak)", "best streak")
                stat("✅", "\(habit.daysCompleted)", "days done")
                stat(habit.emoji, habit.formatTotal(habit.totalLogged), "logged")
            }
        }
        .padding(16)
        .cartoonCard()
    }

    // MARK: Parts

    private func dayCell(_ day: Date) -> some View {
        let p = habit.progress(on: day)
        let done = habit.isDone(on: day)
        let future = day > Date()
        let today = cal.isDateInToday(day)
        let rest = !habit.isScheduled(on: day) && !done
        return ZStack {
            Circle().fill(done ? habit.color.main
                          : (rest ? Color.clear : habit.color.light.opacity(future ? 0.4 : 1)))
            if rest {
                Circle().stroke(Ink.color.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
            if !done && p > 0 {
                Circle()
                    .trim(from: 0, to: CGFloat(p))
                    .stroke(habit.color.main, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
            }
            Text("\(cal.component(.day, from: day))")
                .font(.cartoon(12, done ? .heavy : .bold))
                .foregroundStyle(done ? Color.white : Ink.color.opacity(future ? 0.25 : 0.7))
            if today {
                Circle().stroke(Ink.color, lineWidth: 2.5)
            }
        }
        .frame(width: 36, height: 36)
        .frame(maxWidth: .infinity)
    }

    private func stat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(icon).font(.system(size: 18))
            Text(value)
                .font(.cartoon(16))
                .foregroundStyle(Ink.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.cartoon(11, .semibold))
                .foregroundStyle(Ink.color.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func monthButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Ink.color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(habit.color.light))
                .overlay(Circle().stroke(Ink.color, lineWidth: 2))
        }
        .buttonStyle(BouncyButtonStyle())
    }

    // MARK: Calendar maths

    private var isCurrentMonth: Bool {
        cal.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private func shift(_ months: Int) {
        guard let m = cal.date(byAdding: .month, value: months, to: month) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { month = m }
    }

    /// Short weekday names starting at the user's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Days of the month with leading blanks so the 1st lands on the right weekday.
    private var cells: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = cal.component(.weekday, from: month)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            result.append(cal.date(byAdding: .day, value: d - 1, to: month))
        }
        return result
    }
}
