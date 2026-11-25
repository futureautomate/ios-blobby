import SwiftUI
import UIKit

struct AddHabitView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = "Drink water"
    @State private var emoji = "💧"
    @State private var color: HabitColor = .ocean
    @State private var kind: MascotKind = .drop
    @State private var kindPicked = false      // once the user picks a character, stop auto-suggesting
    @State private var goal: Double = 2000
    @State private var unit = "ml"
    @State private var step: Double = 250
    @State private var previewBump = 0
    @State private var remind = false
    @State private var reminderTime = Date()
    @State private var notifDenied = false
    @State private var repeatDays: Set<Int> = Set(1...7)   // Calendar weekdays, 1 = Sunday
    @State private var type: HabitType = .count
    @State private var useDeadline = false
    @State private var deadline = AddHabitView.time(6, 30)
    @FocusState private var focused: Bool

    /// nil = creating a new habit, otherwise editing this one.
    private let existing: Habit?

    init(existing: Habit? = nil) {
        self.existing = existing
        guard let h = existing else {
            _reminderTime = State(initialValue: AddHabitView.time(9, 0))
            return
        }
        _name = State(initialValue: h.name)
        _emoji = State(initialValue: h.emoji)
        _color = State(initialValue: h.color)
        _kind = State(initialValue: h.kind)
        _kindPicked = State(initialValue: true)
        _goal = State(initialValue: h.goal)
        _unit = State(initialValue: h.unit)
        _step = State(initialValue: h.step)
        _remind = State(initialValue: h.hasReminder)
        _reminderTime = State(initialValue: AddHabitView.time(h.reminderHour ?? 9, h.reminderMinute ?? 0))
        _repeatDays = State(initialValue: Set(h.days ?? Array(1...7)))
        _type = State(initialValue: h.type)
        _useDeadline = State(initialValue: h.deadlineHour != nil)
        _deadline = State(initialValue: AddHabitView.time(h.deadlineHour ?? 6, h.deadlineMinute ?? 30))
    }

    private static func time(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private let emojis = ["💧", "🥤", "🍵", "☕️", "🍎", "🥗", "🥦", "🍌",
                          "👟", "🏃", "🚴", "🏋️", "🧘", "😴", "🌙", "☀️",
                          "📖", "✍️", "💻", "🎸", "🎨", "🌿", "💊", "🦷"]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && goal > 0 && step > 0 && !repeatDays.isEmpty
    }

    var body: some View {
        ZStack {
            Paper.color.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    preview
                    if existing == nil {
                        section("Quick picks") { presets }
                    }
                    section("Pick a buddy") { characters }
                    section("Name") { nameField }
                    section("Sticker") { emojiGrid }
                    section("Type") { typePicker }
                    if type == .checkIn {
                        section("Deadline") { deadlineSection }
                    } else {
                        section(type == .limit ? "Daily limit" : "Daily goal") {
                            stepper(value: $goal, by: step > 0 ? step : 1, trailing: AnyView(unitField))
                        }
                        section("Each tap adds") {
                            stepper(value: $step, by: niceIncrement(step), trailing: AnyView(unitLabel))
                        }
                    }
                    section("Repeat") { repeatSection }
                    section("Colour") { colors }
                    section("Reminder") { reminderSection }
                    if let h = existing {
                        pauseButton(h)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) { addButton }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Paper.color)
        .appAppearance()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }.font(.cartoon(16, .bold))
            }
        }
    }

    // MARK: - Header & preview

    private var header: some View {
        HStack {
            Text(existing == nil ? "New habit" : "Edit habit")
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
    }

    private var preview: some View {
        HStack(spacing: 16) {
            BlobMascot(progress: 0.6, color: color, kind: kind, size: 116, bump: previewBump, sticker: emoji)
                .onTapGesture { previewBump += 1 }
            VStack(alignment: .leading, spacing: 6) {
                Text(name.isEmpty ? "Your habit" : name)
                    .font(.cartoon(20))
                    .foregroundStyle(Ink.text)
                    .lineLimit(2)
                Text(previewLine)
                    .font(.cartoon(15, .bold))
                    .foregroundStyle(Ink.text.opacity(0.65))
                Text("\(kind.title) \(kind.hint)")
                    .font(.cartoon(13, .semibold))
                    .foregroundStyle(color.tone)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .cartoonCard(fill: color.light)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: color)
    }

    // MARK: - Sections

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.cartoon(17))
                .foregroundStyle(Ink.text)
            content()
        }
    }

    private var presets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(HabitPreset.all) { preset in
                    let selected = name == preset.name
                    Button { apply(preset) } label: {
                        Text("\(preset.emoji) \(preset.name)")
                            .font(.cartoon(15, .bold))
                            .foregroundStyle(Ink.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .cartoonCard(radius: 16, fill: selected ? preset.color.light : Card.color)
                    .buttonStyle(BouncyButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, -20)   // let chips scroll edge to edge
    }

    private var characters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MascotKind.allCases) { k in
                    let selected = kind == k
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            kind = k
                            kindPicked = true
                        }
                        previewBump += 1
                    } label: {
                        VStack(spacing: 2) {
                            BlobMascot(progress: 0.6, color: color, kind: k, size: 60)
                                .allowsHitTesting(false)
                            Text(k.title)
                                .font(.cartoon(13, .bold))
                                .foregroundStyle(Ink.text)
                        }
                        .frame(width: 86, height: 100)
                    }
                    .cartoonCard(radius: 20, fill: selected ? color.light : Card.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(color.deep, lineWidth: selected ? 3 : 0)
                            .padding(4)
                    )
                    .scaleEffect(selected ? 1.04 : 1)
                    .buttonStyle(BouncyButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .padding(.horizontal, -20)
    }

    private var nameField: some View {
        TextField("e.g. Drink water", text: $name)
            .font(.cartoon(19, .bold))
            .foregroundStyle(Ink.text)
            .focused($focused)
            .submitLabel(.done)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .cartoonCard(radius: 18)
            .onChange(of: name) { autoSuggestKind() }
    }

    private var emojiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
            ForEach(emojis, id: \.self) { e in
                let selected = emoji == e
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { emoji = e }
                    autoSuggestKind()
                    previewBump += 1
                } label: {
                    Text(e)
                        .font(.system(size: 22))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected ? color.light : Card.color)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selected ? Ink.color : Ink.color.opacity(0.15), lineWidth: selected ? 2.5 : 1.5)
                        )
                        .scaleEffect(selected ? 1.08 : 1)
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
        .padding(12)
        .cartoonCard(radius: 22)
    }

    private var unitField: some View {
        TextField("unit", text: $unit)
            .font(.cartoon(15, .bold))
            .foregroundStyle(Ink.text)
            .multilineTextAlignment(.center)
            .focused($focused)
            .frame(width: 74, height: 34)
            .background(Capsule().fill(color.light))
            .overlay(Capsule().stroke(Ink.color.opacity(0.3), lineWidth: 1.5))
    }

    private var unitLabel: some View {
        Text(unit.isEmpty ? "—" : unit)
            .font(.cartoon(15, .bold))
            .foregroundStyle(Ink.text.opacity(0.55))
            .frame(width: 74, height: 34)
    }

    /// [ − ]  2,000  [ + ]  unit
    private func stepper(value: Binding<Double>, by amount: Double, trailing: AnyView) -> some View {
        HStack(spacing: 10) {
            roundButton("minus") {
                value.wrappedValue = max(amount, value.wrappedValue - amount)
            }
            TextField("0", value: value, format: .number)
                .font(.cartoon(26))
                .foregroundStyle(Ink.text)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($focused)
                .frame(maxWidth: .infinity)
            roundButton("plus") {
                value.wrappedValue += amount
            }
            trailing
        }
        .padding(10)
        .cartoonCard(radius: 22)
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
            previewBump += 1
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Ink.text)
                .frame(width: 44, height: 44)
                .background(Circle().fill(color.light))
                .overlay(Circle().stroke(Ink.color, lineWidth: 2.5))
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private var colors: some View {
        HStack(spacing: 0) {
            ForEach(HabitColor.allCases) { c in
                let selected = color == c
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { color = c }
                    previewBump += 1
                } label: {
                    Circle()
                        .fill(c.main)
                        .frame(width: 46, height: 46)
                        .overlay(Circle().stroke(Ink.color, lineWidth: selected ? 4 : 2.5))
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.white)
                                .opacity(selected ? 1 : 0)
                        )
                        .scaleEffect(selected ? 1.12 : 1)
                }
                .buttonStyle(BouncyButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .cartoonCard(radius: 22)
    }

    private var addButton: some View {
        Button(action: save) {
            Label(existing == nil ? "Add habit" : "Save changes",
                  systemImage: existing == nil ? "plus" : "checkmark")
                .font(.cartoon(20))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
        }
        .cartoonCard(radius: 20, fill: isValid ? color.main : Color.gray)
        .buttonStyle(BouncyButtonStyle())
        .disabled(!isValid)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [Paper.color.opacity(0), Paper.color, Paper.color],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var repeatSection: some View {
        let cal = Calendar.current
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 }
        let letters = cal.veryShortStandaloneWeekdaySymbols
        return VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(order, id: \.self) { day in
                    let on = repeatDays.contains(day)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                            if on { repeatDays.remove(day) } else { repeatDays.insert(day) }
                        }
                    } label: {
                        Text(letters[day - 1])
                            .font(.cartoon(15))
                            .foregroundStyle(on ? .white : Ink.text.opacity(0.5))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(on ? color.main : Card.color))
                            .overlay(Circle().stroke(on ? Ink.color : Ink.color.opacity(0.25), lineWidth: 2.5))
                            .scaleEffect(on ? 1.05 : 1)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 8) {
                repeatPreset("Every day", Set(1...7))
                repeatPreset("Weekdays", [2, 3, 4, 5, 6])
                repeatPreset("Weekends", [1, 7])
            }
            Text(repeatDays.isEmpty ? "Pick at least one day."
                 : "Days off are rest days: they don't break your streak.")
                .font(.cartoon(12, .semibold))
                .foregroundStyle(repeatDays.isEmpty ? HabitColor.coral.tone : Ink.text.opacity(0.5))
        }
        .padding(14)
        .cartoonCard(radius: 22)
    }

    private func repeatPreset(_ title: String, _ days: Set<Int>) -> some View {
        let selected = repeatDays == days
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { repeatDays = days }
        } label: {
            Text(title)
                .font(.cartoon(13, .bold))
                .foregroundStyle(Ink.text)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? color.light : Card.color))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Ink.color : Ink.color.opacity(0.2), lineWidth: selected ? 2.5 : 1.5))
        }
        .buttonStyle(BouncyButtonStyle())
    }

    /// Pause keeps the habit and its streak but hides it from Today and silences reminders.
    private func pauseButton(_ h: Habit) -> some View {
        let paused = store.habit(h.id)?.isPaused ?? h.isPaused
        return Button {
            withAnimation(.spring) { store.setPaused(h.id, !paused) }
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(paused ? "▶️" : "⏸️").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(paused ? "Resume this habit" : "Pause this habit")
                        .font(.cartoon(17))
                        .foregroundStyle(Ink.text)
                    Text(paused ? "Back to Today, reminders on again"
                                : "Hide it from Today and stop reminders. Your streak is kept.")
                        .font(.cartoon(12, .semibold))
                        .foregroundStyle(Ink.text.opacity(0.55))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(16)
        }
        .cartoonCard(radius: 22, fill: Paper.color)
        .buttonStyle(BouncyButtonStyle())
    }

    private var previewLine: String {
        switch type {
        case .count: return "\(goal.clean) \(unit) a day"
        case .checkIn: return useDeadline ? "Check in by \(deadline.formatted(date: .omitted, time: .shortened))" : "Check in once a day"
        case .limit: return "Max \(goal.clean) \(unit) a day"
        }
    }

    /// Build up / Check in / Cut down.
    private var typePicker: some View {
        HStack(spacing: 10) {
            ForEach(HabitType.allCases) { t in
                let selected = type == t
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        type = t
                        if t == .limit && unit == "days" { unit = "min"; goal = 120; step = 15 }
                        if t == .count && unit == "days" { unit = "times"; goal = 1; step = 1 }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(t.emoji).font(.system(size: 24))
                        Text(t.title).font(.cartoon(15)).foregroundStyle(selected ? Ink.color : Ink.text)
                        Text(t.hint).font(.cartoon(11, .semibold))
                            .foregroundStyle((selected ? Ink.color : Ink.text).opacity(0.6))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
                    .cartoonCard(radius: 16, fill: selected ? color.main : Card.color)
                }
                .buttonStyle(BouncyButtonStyle())
                .accessibilityLabel("\(t.title): \(t.hint)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    /// Check-in deadline: "by 6:30" (late check-ins are logged but don't keep the streak).
    private var deadlineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("⏰").font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Must be done by")
                        .font(.cartoon(17))
                        .foregroundStyle(Ink.text)
                    Text(useDeadline ? "Later check-ins are logged but don't keep the streak"
                                     : "Off — any time that day counts")
                        .font(.cartoon(13, .medium))
                        .foregroundStyle(Ink.text.opacity(0.55))
                }
                Spacer()
                CartoonToggle(isOn: $useDeadline, color: color)
            }
            if useDeadline {
                HStack(spacing: 8) {
                    deadlineChip("🌅", 6, 30)
                    deadlineChip("☀️", 8, 0)
                    deadlineChip("🌙", 22, 30)
                    deadlineChip("😴", 23, 0)
                }
                DatePicker("Deadline", selection: $deadline, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                Text("Bedtime habits: checking in just after midnight still counts for the night before.")
                    .font(.cartoon(12, .semibold))
                    .foregroundStyle(Ink.text.opacity(0.5))
            }
        }
        .padding(16)
        .cartoonCard(radius: 22)
    }

    private func deadlineChip(_ icon: String, _ h: Int, _ m: Int) -> some View {
        let t = AddHabitView.time(h, m)
        let selected = Calendar.current.dateComponents([.hour, .minute], from: deadline) == DateComponents(hour: h, minute: m)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { deadline = t }
        } label: {
            Text("\(icon) \(t.formatted(date: .omitted, time: .shortened))")
                .font(.cartoon(13, .bold))
                .foregroundStyle(Ink.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .cartoonCard(radius: 12, fill: selected ? color.light : Card.color)
        .buttonStyle(BouncyButtonStyle())
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("🔔").font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily reminder")
                        .font(.cartoon(17))
                        .foregroundStyle(Ink.text)
                    Text(remind ? "\(kind.title) will nudge you at \(reminderTime.formatted(date: .omitted, time: .shortened))"
                                : "Off — no nudges")
                        .font(.cartoon(13, .medium))
                        .foregroundStyle(Ink.text.opacity(0.55))
                }
                Spacer()
                CartoonToggle(isOn: $remind, color: color)
            }

            if remind {
                HStack(spacing: 8) {
                    quickTime("☀️", 8, 0)
                    quickTime("🌤", 12, 30)
                    quickTime("🌇", 18, 0)
                    quickTime("🌙", 21, 0)
                }
                DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                Text("Skipped automatically on days you've already finished.")
                    .font(.cartoon(12, .semibold))
                    .foregroundStyle(Ink.text.opacity(0.5))
            }

            if remind && notifDenied {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notifications are turned off for Blobby, so reminders can't show.")
                        .font(.cartoon(13, .bold))
                        .foregroundStyle(HabitColor.coral.tone)
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.cartoon(14, .bold))
                    .foregroundStyle(Ink.text)
                }
            }
        }
        .padding(16)
        .cartoonCard(radius: 22)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: remind)
        .onChange(of: remind) {
            guard remind else { return }
            Task {
                let ok = await Reminders.shared.requestPermission()
                notifDenied = !ok
            }
        }
        .task {
            if remind { notifDenied = await Reminders.shared.isDenied() }
        }
    }

    private func quickTime(_ icon: String, _ hour: Int, _ minute: Int) -> some View {
        let value = AddHabitView.time(hour, minute)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let selected = comps.hour == hour && comps.minute == minute
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { reminderTime = value }
        } label: {
            Text("\(icon) \(String(format: "%02d:%02d", hour, minute))")
                .font(.cartoon(13, .bold))
                .foregroundStyle(Ink.text)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? color.light : Card.color))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Ink.color : Ink.color.opacity(0.2), lineWidth: selected ? 2.5 : 1.5))
        }
        .buttonStyle(BouncyButtonStyle())
    }

    // MARK: - Logic

    private func niceIncrement(_ v: Double) -> Double {
        if v >= 1000 { return 500 }
        if v >= 100 { return 50 }
        if v >= 10 { return 5 }
        return 1
    }

    private func autoSuggestKind() {
        guard !kindPicked else { return }
        let suggestion = MascotKind.suggested(emoji: emoji, name: name)
        if suggestion != kind {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { kind = suggestion }
        }
    }

    private func apply(_ p: HabitPreset) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            name = p.name
            emoji = p.emoji
            color = p.color
            kind = p.kind
            goal = p.goal
            unit = p.unit
            step = p.step
            type = p.type
            useDeadline = p.deadline != nil
            if let d = p.deadline { deadline = AddHabitView.time(d.0, d.1) }
        }
        kindPicked = false
        previewBump += 1
    }

    private func save() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        var habit = existing ?? Habit(name: "", emoji: "", color: color, goal: 1, unit: "", step: 1)
        habit.name = name.trimmingCharacters(in: .whitespaces)
        habit.emoji = emoji.isEmpty ? "⭐️" : emoji
        habit.color = color
        habit.kind = kind
        habit.type = type
        if type == .checkIn {
            habit.goal = 1
            habit.step = 1
            habit.unit = "days"
            let d = Calendar.current.dateComponents([.hour, .minute], from: deadline)
            habit.deadlineHour = useDeadline ? d.hour : nil
            habit.deadlineMinute = useDeadline ? d.minute : nil
        } else {
            habit.goal = goal
            habit.unit = unit
            habit.step = step
            habit.deadlineHour = nil
            habit.deadlineMinute = nil
        }
        habit.reminderHour = remind ? comps.hour : nil
        habit.reminderMinute = remind ? comps.minute : nil
        habit.days = repeatDays.count == 7 ? nil : repeatDays.sorted()

        withAnimation(.spring) {
            if existing != nil { store.update(habit) } else { store.add(habit) }
        }
        dismiss()
    }
}

/// Chunky on/off switch in the cartoon style.
struct CartoonToggle: View {
    @Binding var isOn: Bool
    var color: HabitColor

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? color.main : Card.color)
                Capsule()
                    .stroke(Ink.color, lineWidth: 2.5)
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Ink.color, lineWidth: 2.5))
                    .frame(width: 26, height: 26)
                    .padding(.horizontal, 4)
            }
            .frame(width: 58, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Daily reminder")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
