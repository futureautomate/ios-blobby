import SwiftUI

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
    @FocusState private var focused: Bool

    private let emojis = ["💧", "🥤", "🍵", "☕️", "🍎", "🥗", "🥦", "🍌",
                          "👟", "🏃", "🚴", "🏋️", "🧘", "😴", "🌙", "☀️",
                          "📖", "✍️", "💻", "🎸", "🎨", "🌿", "💊", "🦷"]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && goal > 0 && step > 0
    }

    var body: some View {
        ZStack {
            Paper.color.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    preview
                    section("Quick picks") { presets }
                    section("Pick a buddy") { characters }
                    section("Name") { nameField }
                    section("Icon") { emojiGrid }
                    section("Daily goal") {
                        stepper(value: $goal, by: step > 0 ? step : 1, trailing: AnyView(unitField))
                    }
                    section("Each tap adds") {
                        stepper(value: $step, by: niceIncrement(step), trailing: AnyView(unitLabel))
                    }
                    section("Colour") { colors }
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
        .preferredColorScheme(.light)
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
            Text("New habit")
                .font(.cartoon(30))
                .foregroundStyle(Ink.color)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Ink.color)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().stroke(Ink.color, lineWidth: 2.5))
            }
            .buttonStyle(BouncyButtonStyle())
            .accessibilityLabel("Close")
        }
    }

    private var preview: some View {
        HStack(spacing: 16) {
            BlobMascot(progress: 0.6, color: color, kind: kind, size: 116, bump: previewBump)
                .onTapGesture { previewBump += 1 }
            VStack(alignment: .leading, spacing: 6) {
                Text("\(emoji) \(name.isEmpty ? "Your habit" : name)")
                    .font(.cartoon(20))
                    .foregroundStyle(Ink.color)
                    .lineLimit(2)
                Text("\(goal.clean) \(unit) a day")
                    .font(.cartoon(15, .bold))
                    .foregroundStyle(Ink.color.opacity(0.65))
                Text("\(kind.title) \(kind.hint)")
                    .font(.cartoon(13, .semibold))
                    .foregroundStyle(color.deep)
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
                .foregroundStyle(Ink.color)
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
                            .foregroundStyle(Ink.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .cartoonCard(radius: 16, fill: selected ? preset.color.light : .white)
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
                                .foregroundStyle(Ink.color)
                        }
                        .frame(width: 86, height: 100)
                    }
                    .cartoonCard(radius: 20, fill: selected ? color.light : .white)
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
            .foregroundStyle(Ink.color)
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
                                .fill(selected ? color.light : Color.white)
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
            .foregroundStyle(Ink.color)
            .multilineTextAlignment(.center)
            .focused($focused)
            .frame(width: 74, height: 34)
            .background(Capsule().fill(color.light))
            .overlay(Capsule().stroke(Ink.color.opacity(0.3), lineWidth: 1.5))
    }

    private var unitLabel: some View {
        Text(unit.isEmpty ? "—" : unit)
            .font(.cartoon(15, .bold))
            .foregroundStyle(Ink.color.opacity(0.55))
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
                .foregroundStyle(Ink.color)
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
                .foregroundStyle(Ink.color)
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
            Label("Add habit", systemImage: "plus")
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
        }
        kindPicked = false
        previewBump += 1
    }

    private func save() {
        let habit = Habit(name: name.trimmingCharacters(in: .whitespaces),
                          emoji: emoji.isEmpty ? "⭐️" : emoji,
                          color: color, kind: kind,
                          goal: goal, unit: unit, step: step)
        withAnimation(.spring) { store.add(habit) }
        dismiss()
    }
}
