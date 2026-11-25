import SwiftUI
import UniformTypeIdentifiers

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
    @AppStorage(Profile.nameKey) private var profileName = ""
    @AppStorage(Profile.kindKey) private var profileKind = MascotKind.blob.rawValue
    @AppStorage(Profile.colorKey) private var profileColor = HabitColor.ocean.rawValue
    @State private var askName = false
    @State private var levelUp: (habit: Habit, accessory: Accessory)?
    @AppStorage("onboarded") private var onboarded = false
    @State private var dragging: UUID?
    @State private var showPaused = false
    @State private var showingShare = false
    @State private var menuFor: Habit?
    /// When the long-press menu last opened: the finger lifting right after must not also open the habit.
    @State private var lastLongPress = Date.distantPast
    @AppStorage("tipLongPressSeen") private var tipSeen = false
    @AppStorage(Hints.logKey) private var hintLogDone = false
    @AppStorage(Hints.openKey) private var hintOpenDone = false

    /// The first habit that can be logged today gets the first-time hints.
    private var hintHabit: Habit? {
        guard Hints.enabled, !editing else { return nil }
        // Only the first card, so the hint row above the list points at the right habit.
        guard let first = active.first, first.isScheduled(on: Date()), !first.finishedToday,
              first.type != .limit else { return nil }
        return first
    }
    private var hintStage: Int? {   // 1 = tap +, 2 = tap card
        if !hintLogDone { return 1 }
        if !hintOpenDone { return 2 }
        return nil
    }

    private var active: [Habit] { store.habits.filter { !$0.isPaused } }
    private var paused: [Habit] { store.habits.filter { $0.isPaused } }

    /// Only habits scheduled for today count towards "x of y done".
    private var todays: [Habit] { store.habits.filter { $0.isScheduled() } }
    private var doneCount: Int { todays.filter { $0.goodToday }.count }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Paper.color.ignoresSafeArea()
                BackgroundBubbles(color: HabitColor.sunny.main)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if store.habits.isEmpty {
                            EmptyStateView { showingAdd = true }
                                .padding(.top, 30)
                        } else {
                            if !tipSeen && !editing && hintStage == nil {
                                HStack(spacing: 8) {
                                    Text("💡 Tip: press and hold a habit for more options")
                                        .font(.cartoon(13, .bold))
                                        .foregroundStyle(Ink.text.opacity(0.7))
                                    Spacer()
                                    Button { withAnimation(.spring) { tipSeen = true } } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .black))
                                            .foregroundStyle(Ink.text.opacity(0.5))
                                    }
                                    .accessibilityLabel("Dismiss tip")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(HabitColor.sunny.light))
                                .overlay(Capsule().stroke(Ink.color.opacity(0.2), lineWidth: 1.5))
                                .transition(.opacity)
                            }
                            if editing {
                                Text("Drag to reorder · tap ✕ to delete")
                                    .font(.cartoon(14, .bold))
                                    .foregroundStyle(Ink.text.opacity(0.55))
                                    .transition(.opacity)
                            }
                            // First-time hint sits in its own row above the first card, finger dipping onto it.
                            if let stage = hintStage, let habit = hintHabit {
                                HStack(spacing: 0) {
                                    if stage == 1 { Spacer(minLength: 0) }
                                    HintBubble(
                                        text: stage == 1
                                            ? (habit.type == .checkIn ? "Tap ✓ when you've done it!" : "Tap + to give \(habit.kind.title) a sip!")
                                            : "Tap the card to see \(habit.kind.title) up close",
                                        color: stage == 1 ? .sunny : .mint,
                                        fingerAlignment: stage == 1 ? .trailing : .leading,
                                        onClose: { withAnimation(.spring) { if stage == 1 { hintLogDone = true } else { hintOpenDone = true } } })
                                    if stage == 2 { Spacer(minLength: 0) }
                                }
                                .padding(.leading, stage == 2 ? 24 : 0)
                                .padding(.trailing, stage == 1 ? 4 : 0)
                                .padding(.bottom, -30)
                                .zIndex(2)
                                .id(stage)
                                .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                            }
                            ForEach(active) { habit in
                                HabitCard(
                                    habit: habit,
                                    editing: editing,
                                    poofing: poofing.contains(habit.id),
                                    onOpen: {
                                        guard !editing, menuFor == nil,
                                              Date().timeIntervalSince(lastLongPress) > 0.8 else { return }
                                        path.append(habit.id)
                                    },
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
                                    LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                                        if !editing { openMenu(habit) }
                                    }
                                )
                                .modifier(ReorderModifier(habit: habit, enabled: editing,
                                                          dragging: $dragging, store: store))
                                .opacity(dragging == habit.id ? 0.4 : 1)
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                        removal: .opacity))
                            }

                            if !paused.isEmpty {
                                pausedSection
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: store.lastLog?.id) { if store.lastLog != nil && !hintLogDone { withAnimation(.spring) { hintLogDone = true } } }
            .onChange(of: path) { if !path.isEmpty && hintLogDone { hintOpenDone = true } }
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
            if let habit = menuFor {
                HabitActionMenu(habit: habit, items: menuItems(for: habit)) {
                    menuFor = nil
                }
                .transition(.opacity)
            }
        }
        .overlay {
            if askName {
                AboutYouPopup { withAnimation(.spring) { askName = false } }
                    .transition(.opacity)
            }
        }
        .overlay {
            if let lu = levelUp {
                LevelUpPopup(habit: lu.habit, accessory: lu.accessory) {
                    withAnimation(.spring) { levelUp = nil }
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showingShare) {
            ShareCardPreview(habits: store.habits)
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
            if LaunchOptions.showShare { showingShare = true; showPaused = true }
            if let i = LaunchOptions.menuIndex, store.habits.indices.contains(i) { menuFor = store.habits[i] }
            if LaunchOptions.editing { showPaused = true }
            if LaunchOptions.showToast, let first = store.habits.first {
                store.logStep(first.id)
            }
            // First launch: onboarding. Existing users with habits skip it.
            if LaunchOptions.demo == nil && !onboarded {
                if store.habits.isEmpty { showingOnboarding = true } else { onboarded = true }
            }
            // People who had the app before names existed: ask once.
            if (LaunchOptions.demo == nil && onboarded && !showingOnboarding && Profile.name.isEmpty)
                || LaunchOptions.askName {
                askName = true
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

    // MARK: - Paused

    private var pausedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showPaused.toggle() }
            } label: {
                HStack {
                    Text("😴 Paused (\(paused.count))")
                        .font(.cartoon(16))
                        .foregroundStyle(Ink.text.opacity(0.6))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Ink.text.opacity(0.4))
                        .rotationEffect(.degrees(showPaused ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 10)

            if showPaused {
                ForEach(paused) { habit in
                    HStack(spacing: 12) {
                        BlobMascot(progress: 0.4, color: habit.color, kind: habit.kind, size: 56,
                                   sticker: habit.emoji, accessories: habit.unlocked, sleepy: true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(habit.name)
                                .font(.cartoon(17))
                                .foregroundStyle(Ink.text)
                            Text("Paused · streak kept at \(habit.streak)")
                                .font(.cartoon(12, .semibold))
                                .foregroundStyle(Ink.text.opacity(0.5))
                        }
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                store.setPaused(habit.id, false)
                            }
                            SoundFX.shared.play(.pop, pitch: habit.kind.popPitch)
                        } label: {
                            Text("Resume")
                                .font(.cartoon(14))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                        }
                        .cartoonCard(radius: 14, fill: habit.color.main)
                        .buttonStyle(BouncyButtonStyle())
                    }
                    .padding(12)
                    .cartoonCard(fill: Paper.color)
                    .contentShape(Rectangle())
                    .onTapGesture { path.append(habit.id) }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if !profileName.isEmpty {
                        BlobMascot(progress: 0.65, color: HabitColor(rawValue: profileColor) ?? .ocean,
                                   kind: MascotKind(rawValue: profileKind) ?? .blob, size: 26, animated: false)
                    }
                    Text(Profile.greeting(profileName.trimmingCharacters(in: .whitespaces)))
                        .font(.cartoon(15, .bold))
                        .foregroundStyle((HabitColor(rawValue: profileColor) ?? .ocean).tone)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.cartoon(12, .bold))
                    .foregroundStyle(Ink.text.opacity(0.45))
                Text("Today")
                    .font(.cartoon(40))
                    .foregroundStyle(Ink.text)
                if !store.habits.isEmpty {
                    Text("\(doneCount) of \(todays.count) done today")
                        .font(.cartoon(16, .bold))
                        .foregroundStyle(Ink.text.opacity(0.6))
                        .contentTransition(.numericText())
                        .animation(.spring, value: doneCount)
                }
            }
            Spacer()
            if editing {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { editing = false }
                    dragging = nil
                    store.commitOrder()
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
                    circleButton("chart.bar.fill", fill: Card.color, size: 46) { showingRecap = true }
                        .accessibilityLabel("Reports")
                    circleButton("gearshape.fill", fill: Card.color, size: 46) { showingSettings = true }
                        .accessibilityLabel("Settings")
                    circleButton("plus", fill: HabitColor.sunny.main, ink: Ink.color, size: 56) { showingAdd = true }
                        .accessibilityLabel("Add habit")
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 8)
    }

    private func circleButton(_ symbol: String, fill: Color, ink: Color = Ink.text, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(ink)
                .frame(width: size, height: size)
                .background(Circle().fill(fill))
                .overlay(Circle().stroke(Ink.color, lineWidth: 3))
                .background(Circle().fill(Ink.color).offset(y: 4))
        }
        .buttonStyle(BouncyButtonStyle())
    }

    // MARK: - Long-press menu

    private func openMenu(_ habit: Habit) {
        lastLongPress = Date()
        editTick += 1                    // haptic
        withAnimation(.spring) { tipSeen = true }
        menuFor = habit
    }

    private func menuItems(for habit: Habit) -> [HabitActionMenu.Item] {
        var items: [HabitActionMenu.Item] = []
        if !habit.isPaused {
            items.append(.init(icon: habit.emoji, title: "Log +\(habit.step.clean) \(habit.unitLabel(for: habit.step))") {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { store.logStep(habit.id) }
                SoundFX.shared.play(.pop, pitch: habit.kind.popPitch)
            })
        }
        items.append(.init(icon: "✏️", title: "Edit", subtitle: "Name, goal, buddy, repeat days, reminder") {
            editingHabit = store.habit(habit.id)
        })
        items.append(.init(icon: habit.isPaused ? "▶️" : "⏸️",
                           title: habit.isPaused ? "Resume" : "Pause",
                           subtitle: habit.isPaused ? "Back to Today" : "Hide from Today, stop reminders, keep the streak") {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                store.setPaused(habit.id, !habit.isPaused)
            }
        })
        items.append(.init(icon: "↕️", title: "Arrange habits", subtitle: "Drag cards into your own order") {
            startEditing()
        })
        items.append(.init(icon: "🗑️", title: "Delete", destructive: true) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { pendingDelete = habit }
        })
        return items
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

    /// + button colour: done = deep/yellow, late check-in = grey, over the limit = coral.
    private var buttonFill: Color {
        if habit.finishedToday {
            if habit.type == .checkIn && !habit.isDone(on: habit.checkInDay(for: Date())) { return Color.gray }
            return habit.color.doneFill
        }
        return habit.isOver() ? HabitColor.coral.main : habit.color.main
    }


    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 14) {
                BlobMascot(progress: habit.progress(), color: habit.color, kind: habit.kind, size: 78, bump: bump,
                           sticker: habit.emoji, sad: habit.isOver(), accessories: habit.unlocked,
                           animated: !editing)          // hold still while arranging
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(habit.name)
                            .font(.cartoon(19))
                            .foregroundStyle(Ink.text)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        if !habit.isScheduled() {
                            Text("Rest day 😴")
                                .font(.cartoon(11, .bold))
                                .foregroundStyle(Ink.text.opacity(0.6))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Ink.color.opacity(0.08)))
                        } else if let time = habit.reminderText {
                            Label(time, systemImage: "bell.fill")
                                .font(.cartoon(11, .bold))
                                .foregroundStyle(habit.color.tone)
                                .labelStyle(.titleAndIcon)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(habit.color.light))
                        }
                    }
                    Text(habit.statusText())
                        .font(.cartoon(14, .semibold))
                        .foregroundStyle(habit.isOver() ? HabitColor.coral.tone : Ink.text.opacity(0.6))
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    ProgressPill(progress: habit.barProgress, color: habit.isOver() ? .coral : habit.color, height: 12)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            Button {
                if habit.type == .checkIn && habit.checkedToday {
                    bump += 1          // already checked in: just a happy wiggle
                    return
                }
                let wasOver = habit.isOver()
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
                } else if !wasOver, store.habit(habit.id)?.isOver() == true {
                    SoundFX.shared.play(.poof)     // just went over the limit
                } else {
                    SoundFX.shared.play(.pop, pitch: habit.kind.popPitch)
                }
            } label: {
                Image(systemName: habit.finishedToday ? "checkmark" : (habit.type == .checkIn ? "checkmark.circle" : "plus"))
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(habit.finishedToday ? HabitColor.doneInk : .white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(buttonFill))
                    .overlay(Circle().stroke(Ink.color, lineWidth: 3))
            }
            .buttonStyle(BouncyButtonStyle())
            .opacity(editing ? 0 : 1)
            .disabled(editing)
            .accessibilityLabel(habit.type == .checkIn ? "Check in \(habit.name)"
                                : "Log \(habit.step.clean) \(habit.unitLabel(for: habit.step)) for \(habit.name)")
            .accessibilityValue(habit.statusText())
        }
        .padding(14)
        .cartoonCard()
        .opacity(habit.isScheduled() || editing ? 1 : 0.7)
        // Arranging: no jiggle; a drag handle replaces the + button instead
        .overlay(alignment: .trailing) {
            if editing && !poofing {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Ink.text.opacity(0.7))
                    .frame(width: 46, height: 46)
                    .padding(.trailing, 14)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
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
                .foregroundStyle(Ink.text)
            Text("Add your first one — like drinking 2 L of water a day — and watch your buddy fill up.")
                .font(.cartoon(16, .medium))
                .foregroundStyle(Ink.text.opacity(0.6))
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

// MARK: - Drag to reorder (edit mode only)

private struct ReorderModifier: ViewModifier {
    let habit: Habit
    let enabled: Bool
    @Binding var dragging: UUID?
    let store: HabitStore

    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    dragging = habit.id
                    return NSItemProvider(object: habit.id.uuidString as NSString)
                }
                .onDrop(of: [UTType.text], delegate: ReorderDropDelegate(target: habit.id, dragging: $dragging, store: store))
        } else {
            content
        }
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let target: UUID
    @Binding var dragging: UUID?
    let store: HabitStore

    func dropEntered(info: DropInfo) {
        guard let id = dragging, id != target else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            store.move(id, before: target)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        store.commitOrder()
        return true
    }
}
