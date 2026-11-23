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

            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text(habit.name)
                            .font(.cartoon(30))
                            .foregroundStyle(Ink.color)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 8) {
                            Text(habit.streak > 0 ? "🔥 \(habit.streak) day streak" : "Start your streak today")
                                .font(.cartoon(15, .bold))
                                .foregroundStyle(Ink.color)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .cartoonCard(radius: 14, fill: HabitColor.sunny.light)
                            if let time = habit.reminderText {
                                Label(time, systemImage: "bell.fill")
                                    .font(.cartoon(15, .bold))
                                    .foregroundStyle(Ink.color)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .cartoonCard(radius: 14, fill: habit.color.light)
                            }
                        }
                    }

                    // Blobby + falling emoji + floating labels
                    ZStack {
                        BlobMascot(progress: habit.progress(), color: habit.color, kind: habit.kind,
                                   size: 230, bump: bump, celebrate: celebrating, sticker: habit.emoji)
                            .onTapGesture { addStep(habit) }

                        ForEach(drops, id: \.self) { id in
                            FallingEmoji(emoji: habit.emoji) { land(id) }
                        }
                        ForEach(labels, id: \.self) { id in
                            FloatingLabel(text: "+\(habit.step.clean) \(habit.unitLabel(for: habit.step))", color: habit.color.deep)
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
                    VStack(spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(habit.amount().clean)
                                .font(.cartoon(44))
                                .contentTransition(.numericText())
                            Text("/ \(habit.goal.clean) \(habit.unit)")
                                .font(.cartoon(18, .bold))
                                .foregroundStyle(Ink.color.opacity(0.55))
                        }
                        .foregroundStyle(Ink.color)

                        ProgressPill(progress: habit.progress(), color: habit.color, height: 16)
                            .padding(.horizontal, 30)

                        Text(habit.isDone() ? "Goal reached! \(habit.kind.title) is so happy 🎉" : "\((habit.goal - habit.amount()).clean) \(habit.unitLabel(for: habit.goal - habit.amount())) to go")
                            .font(.cartoon(16, .bold))
                            .foregroundStyle(habit.isDone() ? habit.color.deep : Ink.color.opacity(0.6))
                            .contentTransition(.numericText())
                    }

                    // Buttons
                    HStack(spacing: 14) {
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                store.log(habitID, delta: -habit.step)
                            }
                            bump += 1
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(Ink.color)
                                .frame(width: 60, height: 60)
                        }
                        .cartoonCard(radius: 20)
                        .buttonStyle(BouncyButtonStyle())
                        .disabled(habit.amount() <= 0)
                        .opacity(habit.amount() <= 0 ? 0.5 : 1)

                        Button { addStep(habit) } label: {
                            Label("Add \(habit.step.clean) \(habit.unitLabel(for: habit.step))", systemImage: "plus")
                                .font(.cartoon(20))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                        }
                        .cartoonCard(radius: 20, fill: habit.color.main)
                        .buttonStyle(BouncyButtonStyle())
                    }
                    .padding(.horizontal, 20)

                    WeekStrip(habit: habit)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                }
                .padding(.bottom, 40)
            }

            if let start = confettiStart {
                ConfettiView(start: start, loop: confettiLoop,
                             colors: [habit.color.main, HabitColor.sunny.main, HabitColor.coral.main,
                                      HabitColor.mint.main, HabitColor.grape.main])
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingEdit = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Ink.color)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().stroke(Ink.color, lineWidth: 2.5))
                }
                .accessibilityLabel("Edit habit")
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddHabitView(existing: habit)
                .environmentObject(store)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: bump)
        .sensoryFeedback(.success, trigger: successTick)
        .task {
            if LaunchOptions.celebrate {
                startCelebration(loop: true)
            }
            if LaunchOptions.autolog {
                for _ in 0..<4 {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if let h = store.habit(habitID) { addStep(h) }
                }
            }
        }
    }

    // MARK: - Actions

    private func addStep(_ habit: Habit) {
        drops.append(UUID())
    }

    private func land(_ dropID: UUID) {
        drops.removeAll { $0 == dropID }
        guard let habit = store.habit(habitID) else { return }
        let wasDone = habit.isDone()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            store.log(habitID, delta: habit.step)
        }
        bump += 1
        labels.append(UUID())
        if !wasDone, store.habit(habitID)?.isDone() == true {
            startCelebration(loop: false)
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
                .foregroundStyle(Ink.color)
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
        return VStack(spacing: 6) {
            ZStack {
                Circle().fill(done ? habit.color.main : habit.color.light)
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
                .foregroundStyle(offset == 0 ? Ink.color : Ink.color.opacity(0.45))
        }
    }
}
