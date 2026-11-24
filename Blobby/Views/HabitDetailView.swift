import SwiftUI

struct HabitDetailView: View {
    let habitID: UUID
    @EnvironmentObject var store: HabitStore

    @State private var bump = 0
    @State private var drops: [UUID] = []
    @State private var labels: [UUID] = []
    @State private var celebrating = false
    @State private var confettiStart: Date? = nil
    @State private var confettiLoop = false
    @State private var successTick = 0
    @State private var showingEdit = false
    @State private var levelUp: Accessory?
    @State private var showingMore = false
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let habit = store.habit(habitID) {
            content(habit)
        } else {
            Text("This habit was deleted.")
                .font(.cartoon(18, .bold))
        }
    }

    private func content(_ habit: Habit) -> some View {
        ZStack {
            LinearGradient(colors: [habit.color.light, Paper.color],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            BackgroundBubbles(color: habit.color.main)

            VStack(spacing: 0) {
            header(habit)
            ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: 18) {
                    if habit.isPaused {
                        HStack(spacing: 10) {
                            Text("😴 Paused: no reminders, streak kept")
                                .font(.cartoon(14, .bold))
                                .foregroundStyle(Ink.text.opacity(0.7))
                            Spacer()
                            Button("Resume") {
                                withAnimation(.spring) { store.setPaused(habitID, false) }
                            }
                            .font(.cartoon(14))
                            .foregroundStyle(habit.color.tone)
                        }
                        .padding(12)
                        .cartoonCard(radius: 16, fill: Paper.color)
                        .padding(.horizontal, 20)
                    }
                    VStack(spacing: 6) {
                        Text(habit.name)
                            .font(.cartoon(30))
                            .foregroundStyle(Ink.text)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 8) {
                            Text(habit.streak > 0 ? "🔥 \(habit.streak) day streak" : "Start your streak today")
                                .font(.cartoon(15, .bold))
                                .foregroundStyle(Ink.text)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .cartoonCard(radius: 14, fill: HabitColor.sunny.light)
                            if let time = habit.reminderText {
                                Label(time, systemImage: "bell.fill")
                                    .font(.cartoon(15, .bold))
                                    .foregroundStyle(Ink.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .cartoonCard(radius: 14, fill: habit.color.light)
                            }
                        }
                    }

                    // Blobby + falling emoji + floating labels
                    ZStack {
                        BlobMascot(progress: habit.progress(), color: habit.color, kind: habit.kind,
                                   size: 230, bump: bump, celebrate: celebrating, sticker: habit.emoji,
                                   sad: habit.isOver(), accessories: habit.unlocked, sleepy: habit.isPaused)
                            .onTapGesture { addStep(habit) }

                        ForEach(drops, id: \.self) { id in
                            FallingEmoji(emoji: habit.emoji) { land(id) }
                        }
                        ForEach(labels, id: \.self) { id in
                            FloatingLabel(text: habit.type == .checkIn ? "✓" : "+\(habit.step.clean) \(habit.unitLabel(for: habit.step))",
                                          color: habit.isOver() ? HabitColor.coral.tone : habit.color.tone)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                                        labels.removeAll { $0 == id }
                                    }
                                }
                        }
                    }
                    .frame(height: 290)
                    .padding(.top, 10)

                    // Amount
                    if habit.type == .checkIn {
                        checkInStatus(habit)
                    } else {
                    VStack(spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(habit.amount().clean)
                                .font(.cartoon(44))
                                .contentTransition(.numericText())
                            Text("/ \(habit.goal.clean) \(habit.unit)\(habit.type == .limit ? " limit" : "")")
                                .font(.cartoon(18, .bold))
                                .foregroundStyle(Ink.text.opacity(0.55))
                        }
                        .foregroundStyle(Ink.text)

                        ProgressPill(progress: habit.barProgress, color: habit.isOver() ? .coral : habit.color, height: 16)
                            .padding(.horizontal, 30)

                        Text(amountMessage(habit))
                            .font(.cartoon(16, .bold))
                            .foregroundStyle(habit.isOver() ? HabitColor.coral.tone
                                             : (habit.isDone() ? habit.color.tone : Ink.text.opacity(0.6)))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .contentTransition(.numericText())
                    }
                    }

                    // Buttons
                    if habit.type == .checkIn {
                        checkInButton(habit)
                            .padding(.horizontal, 20)
                    } else {
                    HStack(spacing: 14) {
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                store.log(habitID, delta: -habit.step)
                            }
                            bump += 1
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(Ink.text)
                                .frame(width: 60, height: 60)
                        }
                        .accessibilityLabel("Remove \(habit.step.clean) \(habit.unitLabel(for: habit.step))")
                        .cartoonCard(radius: 20)
                        .buttonStyle(BouncyButtonStyle())
                        .disabled(habit.amount() <= 0)
                        .opacity(habit.amount() <= 0 ? 0.5 : 1)

                        Button { addStep(habit) } label: {
                            Label("Add \(habit.step.clean) \(habit.unitLabel(for: habit.step))", systemImage: "plus")
                                .font(.cartoon(20))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 60)
                                .padding(.horizontal, 6)
                        }
                        .accessibilityValue("\(habit.amount().clean) of \(habit.goal.clean) \(habit.unit)")
                        .cartoonCard(radius: 20, fill: habit.isOver() ? HabitColor.coral.main : habit.color.main)
                        .buttonStyle(BouncyButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    }

                    WeekStrip(habit: habit)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)

                    LevelCard(habit: habit)
                        .padding(.horizontal, 20)
                        .id("level")

                    HistoryCard(habit: habit)
                        .padding(.horizontal, 20)
                        .id("history")
                }
                .padding(.bottom, 40)
            }
            .task {
                if LaunchOptions.scrollToHistory {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    withAnimation { scroller.scrollTo("level", anchor: .top) }
                }
            }
            }
            }

            if let start = confettiStart {
                ConfettiView(start: start, loop: confettiLoop,
                             colors: [habit.color.main, HabitColor.sunny.main, HabitColor.coral.main,
                                      HabitColor.mint.main, HabitColor.grape.main])
            }

            if showingMore {
                HabitActionMenu(habit: habit, items: moreItems(habit)) { showingMore = false }
                    .zIndex(9)
            }

            if confirmDelete {
                CartoonConfirm(
                    title: "Delete \(habit.name)?",
                    message: "\(habit.kind.title) and all of this habit's history will be gone.",
                    color: habit.color, kind: habit.kind, sticker: habit.emoji,
                    confirmTitle: "Delete",
                    onCancel: { withAnimation(.spring) { confirmDelete = false } },
                    onConfirm: {
                        SoundFX.shared.play(.poof)
                        confirmDelete = false
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation(.spring) { store.delete(habitID) }
                        }
                    })
                .zIndex(11)
            }

            if let acc = levelUp {
                LevelUpPopup(habit: habit, accessory: acc) {
                    withAnimation(.spring) { levelUp = nil }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        // Cartoon header instead of the standard iOS navigation bar.
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingEdit) {
            AddHabitView(existing: habit)
                .environmentObject(store)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: bump)
        .sensoryFeedback(.success, trigger: successTick)
        .task {
            if LaunchOptions.celebrate {
                startCelebration(loop: true)
            }
            if LaunchOptions.showMore { showingMore = true }
            if LaunchOptions.showLevelUp, let acc = store.habit(habitID)?.unlocked.last {
                levelUp = acc
            }
            if LaunchOptions.autolog {
                for _ in 0..<4 {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if let h = store.habit(habitID) { addStep(h) }
                }
            }
        }
    }

    // MARK: - Header

    private func header(_ habit: Habit) -> some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Ink.text)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Card.color))
                    .overlay(Circle().stroke(Ink.color, lineWidth: 2.5))
                    .background(Circle().fill(Ink.color).offset(y: 3))
            }
            .buttonStyle(BouncyButtonStyle())
            .accessibilityLabel("Back to Today")

            Spacer()

            ShareCardButton(title: "\(habit.name) on Blobby", card: HabitShareCard(habit: habit), compact: true)

            Button { showingMore = true } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Ink.color)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(HabitColor.sunny.main))
                    .overlay(Circle().stroke(Ink.color, lineWidth: 2.5))
                    .background(Circle().fill(Ink.color).offset(y: 3))
            }
            .buttonStyle(BouncyButtonStyle())
            .accessibilityLabel("More actions")
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(habit.color.light.ignoresSafeArea(edges: .top))
    }

    // MARK: - Actions

    /// Same menu as long-press on Today, minus Log/Arrange (Log is the big button here).
    private func moreItems(_ habit: Habit) -> [HabitActionMenu.Item] {
        [
            .init(icon: "✏️", title: "Edit", subtitle: "Name, goal, buddy, repeat days, reminder") {
                showingEdit = true
            },
            .init(icon: habit.isPaused ? "▶️" : "⏸️",
                  title: habit.isPaused ? "Resume" : "Pause",
                  subtitle: habit.isPaused ? "Back to Today" : "Hide from Today, stop reminders, keep the streak") {
                withAnimation(.spring) { store.setPaused(habitID, !habit.isPaused) }
            },
            .init(icon: "🗑️", title: "Delete", destructive: true) {
                withAnimation(.spring) { confirmDelete = true }
            },
        ]
    }

    private func addStep(_ habit: Habit) {
        if habit.type == .checkIn && habit.checkedToday { bump += 1; return }
        drops.append(UUID())
    }

    private func amountMessage(_ habit: Habit) -> String {
        if habit.type == .limit {
            if habit.isOver() {
                let over = habit.amount() - habit.goal
                return "Over by \(over.clean) \(habit.unitLabel(for: over)). Tomorrow's a fresh start 💪"
            }
            let left = habit.remaining()
            return "\(left.clean) \(habit.unitLabel(for: left)) left today · the day counts at midnight"
        }
        if habit.isDone() { return "Goal reached! \(habit.kind.title) is so happy 🎉" }
        let left = habit.goal - habit.amount()
        return "\(left.clean) \(habit.unitLabel(for: left)) to go"
    }

    @ViewBuilder
    private func checkInStatus(_ habit: Habit) -> some View {
        let day = habit.checkInDay(for: Date())
        let checked = habit.amount(on: day) >= 1
        let late = habit.lateDays.contains(Habit.key(day))
        VStack(spacing: 8) {
            Text(checked ? (late ? "Checked in late 😅" : "Done for today! 🎉") : "Not yet today")
                .font(.cartoon(32))
                .foregroundStyle(Ink.text)
            Text(checked
                 ? (late ? "Logged, but after \(habit.deadlineText ?? "the deadline"), so it doesn't count toward the streak."
                         : "\(habit.kind.title) is proud of you.")
                 : (habit.deadlineText.map { "Check in by \($0) to keep your streak." } ?? "Tap the button when you've done it."))
                .font(.cartoon(16, .bold))
                .foregroundStyle(late ? HabitColor.coral.tone : Ink.text.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }

    @ViewBuilder
    private func checkInButton(_ habit: Habit) -> some View {
        let day = habit.checkInDay(for: Date())
        if habit.amount(on: day) >= 1 {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { store.uncheck(habitID, day: day) }
                bump += 1
            } label: {
                Label("Undo check-in", systemImage: "arrow.uturn.backward")
                    .font(.cartoon(18))
                    .foregroundStyle(Ink.text)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
            }
            .cartoonCard(radius: 20)
            .buttonStyle(BouncyButtonStyle())
        } else {
            Button { addStep(habit) } label: {
                Label("I did it!", systemImage: "checkmark")
                    .font(.cartoon(22))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 64)
            }
            .cartoonCard(radius: 20, fill: habit.color.main)
            .buttonStyle(BouncyButtonStyle())
            .accessibilityLabel("Check in \(habit.name)")
        }
    }

    private func land(_ dropID: UUID) {
        drops.removeAll { $0 == dropID }
        guard let habit = store.habit(habitID) else { return }
        let wasDone = habit.isDone()
        let levelBefore = habit.unlocked.count
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            store.logStep(habitID)
        }
        bump += 1
        labels.append(UUID())
        if wasDone || store.habit(habitID)?.isDone() != true {
            SoundFX.shared.play(.pop, pitch: habit.kind.popPitch)
        }
        if !wasDone, let updated = store.habit(habitID), updated.isDone() {
            SoundFX.shared.play(.chime)
            startCelebration(loop: false)
            // Finishing today can extend the streak past an accessory threshold.
            if updated.unlocked.count > levelBefore, let acc = updated.unlocked.last {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation(.spring) { levelUp = acc }
                }
            }
        }
    }

    private func startCelebration(loop: Bool) {
        successTick += 1
        confettiLoop = loop
        confettiStart = Date()
        withAnimation(.spring) { celebrating = true }
        guard !loop else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.spring) { celebrating = false }
            confettiStart = nil
        }
    }
}

/// Last 7 days as little progress rings.
struct WeekStrip: View {
    let habit: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This week")
                .font(.cartoon(16))
                .foregroundStyle(Ink.text)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    dayView(offset: i - 6)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .cartoonCard()
    }

    private func dayView(offset: Int) -> some View {
        let day = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        let p = habit.progress(on: day)
        let done = habit.isDone(on: day)
        let rest = !habit.isScheduled(on: day) && !done
        return VStack(spacing: 6) {
            ZStack {
                Circle().fill(done ? habit.color.main : (rest ? Paper.color : habit.color.light))
                if rest {
                    Text("z").font(.cartoon(13, .bold)).foregroundStyle(Ink.text.opacity(0.3))
                }
                Circle()
                    .trim(from: 0, to: CGFloat(p))
                    .stroke(habit.color.main, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4)
                    .opacity(done ? 0 : 1)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                }
                Circle().stroke(Ink.color, lineWidth: 2.5)
            }
            .frame(width: 36, height: 36)
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.cartoon(12, .bold))
                .foregroundStyle(offset == 0 ? Ink.text : Ink.text.opacity(0.45))
        }
    }
}
