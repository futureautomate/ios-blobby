import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: HabitStore
    @State private var path: [UUID] = []
    @State private var showingAdd = false
    @State private var showingSettings = false

    // Edit / delete flow
    @State private var editing = false
    @State private var pendingDelete: Habit?
    @State private var poofing: Set<UUID> = []
    @State private var editTick = 0
    @State private var editingHabit: Habit?
    @State private var showingRecap = false
    @State private var showingOnboarding = false
    @State private var levelUp: (habit: Habit, accessory: Accessory)?
    @AppStorage("onboarded") private var onboarded = false

    /// Only habits scheduled for today count towards "x of y done".
    private var todays: [Habit] { store.habits.filter { $0.isScheduled() } }
    private var doneCount: Int { todays.filter { $0.isDone() }.count }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Paper.color.ignoresSafeArea()
                BackgroundBubbles(color: HabitColor.sunny.main)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if store.habits.isEmpty {
                            EmptyStateView { showingAdd = true }
                                .padding(.top, 30)
                        } else {
                            if editing {
                                Text("Tap ✕ to delete a habit")
                                    .font(.cartoon(14, .bold))
                                    .foregroundStyle(Ink.color.opacity(0.55))
                                    .transition(.opacity)
                            }
                            ForEach(store.habits) { habit in
                                HabitCard(
                                    habit: habit,
                                    editing: editing,
                                    poofing: poofing.contains(habit.id),
                                    onOpen: { if !editing { path.append(habit.id) } },
                                    onLevelUp: { acc in
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                            if let h = store.habit(habit.id) {
                                                withAnimation(.spring) { levelUp = (h, acc) }
                                            }
                                        }
                                    },
                                    onDelete: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            pendingDelete = habit
                                        }
                                    }
                                )
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.45).onEnded { _ in startEditing() }
                                )
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                        removal: .opacity))
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                HabitDetailView(habitID: id)
            }
            .overlay {
                if let habit = pendingDelete {
                    CartoonConfirm(
                        title: "Delete \(habit.name)?",
                        message: "\(habit.kind.title) and all of this habit's history will be gone.",
                        color: habit.color,
                        kind: habit.kind,
                        sticker: habit.emoji,
                        confirmTitle: "Delete",
                        onCancel: { withAnimation(.spring) { pendingDelete = nil } },
                        onConfirm: { confirmDelete(habit) }
                    )
                    .transition(.opacity)
                }
            }
        }
        .tint(Ink.color)
        .sensoryFeedback(.impact(weight: .medium), trigger: editTick)
        .sheet(isPresented: $showingAdd) {
            AddHabitView()
                .environmentObject(store)
        }
        .overlay {
            if let lu = levelUp {
                LevelUpPopup(habit: lu.habit, accessory: lu.accessory) {
                    withAnimation(.spring) { levelUp = nil }
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showingRecap) {
            WeeklyRecapView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView {
                onboarded = true
                showingOnboarding = false
            }
            .environmentObject(store)
        }
        .sheet(item: $editingHabit) { habit in
            AddHabitView(existing: habit)
                .environmentObject(store)
        }
        .onChange(of: store.openRequest) {
            // A reminder was tapped: jump straight to that habit.
            if let id = store.openRequest, store.habit(id) != nil {
                showingAdd = false
                showingSettings = false
                editing = false
                path = [id]
            }
            store.openRequest = nil
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .task {
            if let i = LaunchOptions.openIndex, store.habits.indices.contains(i) {
                path = [store.habits[i].id]
            }
            if LaunchOptions.showAdd { showingAdd = true }
            if LaunchOptions.showSettings { showingSettings = true }
            if LaunchOptions.showRecap { showingRecap = true }
            if LaunchOptions.showOnboarding { showingOnboarding = true }
            if LaunchOptions.showToast, let first = store.habits.first {
                store.logStep(first.id)
            }
            // First launch: onboarding. Existing users with habits skip it.
            if LaunchOptions.demo == nil && !onboarded {
                if store.habits.isEmpty { showingOnboarding = true } else { onboarded = true }
            } else if LaunchOptions.demo == nil && WeeklyRecap.isDue && !store.habits.isEmpty {
                showingRecap = true
            }
            if let i = LaunchOptions.editHabitIndex, store.habits.indices.contains(i) {
                editingHabit = store.habits[i]
            }
            if LaunchOptions.editing { editing = true }
            if let i = LaunchOptions.confirmIndex, store.habits.indices.contains(i) {
                editing = true
                pendingDelete = store.habits[i]
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.cartoon(13, .bold))
                    .foregroundStyle(Ink.color.opacity(0.5))
                Text("Today")
                    .font(.cartoon(40))
                    .foregroundStyle(Ink.color)
                if !store.habits.isEmpty {
                    Text("\(doneCount) of \(todays.count) done today")
                        .font(.cartoon(16, .bold))
                        .foregroundStyle(Ink.color.opacity(0.6))
                        .contentTransition(.numericText())
                        .animation(.spring, value: doneCount)
                }
            }
            Spacer()
            if editing {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { editing = false }
                } label: {
                    Text("Done")
                        .font(.cartoon(18))
                        .foregroundStyle(Ink.color)
                        .padding(.horizontal, 20)
                        .frame(height: 50)
                }
                .cartoonCard(radius: 25, fill: HabitColor.mint.main)
                .buttonStyle(BouncyButtonStyle())
                .transition(.scale.combined(with: .opacity))
            } else {
                HStack(spacing: 12) {
                    circleButton("gearshape.fill", fill: .white, size: 46) { showingSettings = true }
                        .accessibilityLabel("Settings")
                    circleButton("plus", fill: HabitColor.sunny.main, size: 56) { showingAdd = true }
                        .accessibilityLabel("Add habit")
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 8)
    }

    private func circleButton(_ symbol: String, fill: Color, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(Ink.color)
                .frame(width: size, height: size)
                .background(Circle().fill(fill))
                .overlay(Circle().stroke(Ink.color, lineWidth: 3))
                .background(Circle().fill(Ink.color).offset(y: 4))
        }
        .buttonStyle(BouncyButtonStyle())
    }

    // MARK: - Delete flow

    private func startEditing() {
        guard !editing else { return }
        editTick += 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { editing = true }
    }

    private func confirmDelete(_ habit: Habit) {
        withAnimation(.spring) { pendingDelete = nil }
        // 1) card shrinks + poof burst  2) remove it and let the others spring into place
        withAnimation(.easeIn(duration: 0.3)) { _ = poofing.insert(habit.id) }
        editTick += 1
        SoundFX.shared.play(.poof)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                store.delete(habit.id)
                poofing.remove(habit.id)
                if store.habits.isEmpty { editing = false }
            }
        }
    }
}

// MARK: - Habit card

struct HabitCard: View {
    let habit: Habit
    var editing: Bool = false
    var poofing: Bool = false
    let onOpen: () -> Void
    var onLevelUp: (Accessory) -> Void = { _ in }
    var onDelete: () -> Void = {}

    @EnvironmentObject var store: HabitStore
    @State private var bump = 0
    @State private var wiggle = false

    /// Slightly different wiggle speed per card so they don't move in lockstep.
    private var wiggleSpeed: Double {
        0.12 + Double(abs(habit.id.hashValue % 4)) * 0.012
    }

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 14) {
                BlobMascot(progress: habit.progress(), color: habit.color, kind: habit.kind, size: 78, bump: bump,
                           sticker: habit.emoji, accessories: habit.unlocked)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(habit.name)
                            .font(.cartoon(19))
                            .foregroundStyle(Ink.color)
                            .lineLimit(1)
                        if !habit.isScheduled() {
                            Text("Rest day 😴")
                                .font(.cartoon(11, .bold))
                                .foregroundStyle(Ink.color.opacity(0.6))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Ink.color.opacity(0.08)))
                        } else if let time = habit.reminderText {
                            Label(time, systemImage: "bell.fill")
                                .font(.cartoon(11, .bold))
                                .foregroundStyle(habit.color.deep)
                                .labelStyle(.titleAndIcon)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(habit.color.light))
                        }
                    }
                    Text("\(habit.amount().clean) / \(habit.goal.clean) \(habit.unit)")
                        .font(.cartoon(14, .semibold))
                        .foregroundStyle(Ink.color.opacity(0.6))
                        .contentTransition(.numericText())
                    ProgressPill(progress: habit.progress(), color: habit.color, height: 12)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            Button {
                let wasDone = habit.isDone()
                let levelBefore = habit.unlocked.count
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    store.logStep(habit.id)
                }
                bump += 1
                if !wasDone, let updated = store.habit(habit.id), updated.isDone() {
                    SoundFX.shared.play(.chime)
                    if updated.unlocked.count > levelBefore, let acc = updated.unlocked.last {
                        onLevelUp(acc)
                    }
                } else {
                    SoundFX.shared.play(.pop, pitch: habit.kind.popPitch)
                }
            } label: {
                Image(systemName: habit.isDone() ? "checkmark" : "plus")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(habit.isDone() ? habit.color.deep : habit.color.main))
                    .overlay(Circle().stroke(Ink.color, lineWidth: 3))
            }
            .buttonStyle(BouncyButtonStyle())
            .opacity(editing ? 0.25 : 1)
            .disabled(editing)
            .accessibilityLabel("Log \(habit.step.clean) \(habit.unitLabel(for: habit.step))")
        }
        .padding(14)
        .cartoonCard()
        .opacity(habit.isScheduled() || editing ? 1 : 0.7)
        // Jiggle while editing
        .rotationEffect(.degrees(editing && !poofing ? (wiggle ? 1.2 : -1.2) : 0))
        .animation(editing ? .easeInOut(duration: wiggleSpeed).repeatForever(autoreverses: true) : .spring,
                   value: wiggle)
        // Red ✕ badge
        .overlay(alignment: .topLeading) {
            if editing && !poofing {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(HabitColor.coral.deep))
                        .overlay(Circle().stroke(Ink.color, lineWidth: 2.5))
                }
                .buttonStyle(BouncyButtonStyle())
                .offset(x: -8, y: -10)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Delete \(habit.name)")
            }
        }
        // Poof away
        .scaleEffect(poofing ? 0.15 : 1)
        .rotationEffect(.degrees(poofing ? -14 : 0))
        .opacity(poofing ? 0 : 1)
        .overlay {
            if poofing { PoofView(color: habit.color.main) }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: bump)
        .onAppear { if editing { wiggle.toggle() } }
        .onChange(of: editing) {
            if editing { wiggle.toggle() } else { wiggle = false }
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            BlobMascot(progress: 0.35, color: .ocean, kind: .drop, size: 170)
            Text("No habits yet")
                .font(.cartoon(26))
                .foregroundStyle(Ink.color)
            Text("Add your first one — like drinking 2 L of water a day — and watch your buddy fill up.")
                .font(.cartoon(16, .medium))
                .foregroundStyle(Ink.color.opacity(0.6))
                .multilineTextAlignment(.center)
            Button(action: onAdd) {
                Text("Add a habit")
                    .font(.cartoon(19))
                    .foregroundStyle(Ink.color)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
            }
            .cartoonCard(radius: 20, fill: HabitColor.sunny.main)
            .buttonStyle(BouncyButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
