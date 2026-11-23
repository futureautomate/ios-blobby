import SwiftUI

struct AddHabitView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = "Drink water"
    @State private var emoji = "💧"
    @State private var color: HabitColor = .ocean
    @State private var goal: Double = 2000
    @State private var unit = "ml"
    @State private var step: Double = 250
    @State private var previewBump = 0

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && goal > 0 && step > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Paper.color.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        BlobMascot(progress: min(step / max(goal, 1), 1) * 2, color: color,
                                   size: 130, bump: previewBump)
                            .padding(.top, 8)

                        presets
                        fields
                        colors

                        Button(action: save) {
                            Text("Add habit")
                                .font(.cartoon(20))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                        }
                        .cartoonCard(radius: 20, fill: isValid ? color.main : .gray)
                        .buttonStyle(BouncyButtonStyle())
                        .disabled(!isValid)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.cartoon(16, .bold))
                }
            }
        }
    }

    // MARK: - Sections

    private var presets: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick start").font(.cartoon(16)).foregroundStyle(Ink.color)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HabitPreset.all) { preset in
                        Button { apply(preset) } label: {
                            Text("\(preset.emoji) \(preset.name)")
                                .font(.cartoon(15, .bold))
                                .foregroundStyle(Ink.color)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                        }
                        .cartoonCard(radius: 16, fill: name == preset.name ? preset.color.light : .white)
                        .buttonStyle(BouncyButtonStyle())
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
        }
    }

    private var fields: some View {
        VStack(spacing: 14) {
            row("Name") {
                TextField("e.g. Drink water", text: $name)
            }
            row("Emoji") {
                TextField("💧", text: $emoji)
                    .onChange(of: emoji) {
                        if emoji.count > 1, let last = emoji.last { emoji = String(last) }
                    }
            }
            row("Daily goal") {
                HStack {
                    TextField("2000", value: $goal, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("unit", text: $unit)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                }
            }
            row("Each tap adds") {
                HStack {
                    TextField("250", value: $step, format: .number)
                        .keyboardType(.decimalPad)
                    Text(unit).foregroundStyle(Ink.color.opacity(0.5))
                }
            }
        }
        .font(.cartoon(17, .semibold))
        .padding(16)
        .cartoonCard()
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.cartoon(11, .bold))
                .foregroundStyle(Ink.color.opacity(0.5))
            content()
                .foregroundStyle(Ink.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Paper.color))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.color.opacity(0.25), lineWidth: 1.5))
        }
    }

    private var colors: some View {
        HStack(spacing: 14) {
            ForEach(HabitColor.allCases) { c in
                Button {
                    withAnimation(.spring) { color = c }
                    previewBump += 1
                } label: {
                    Circle()
                        .fill(c.main)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Ink.color, lineWidth: color == c ? 4 : 2))
                        .scaleEffect(color == c ? 1.15 : 1)
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func apply(_ p: HabitPreset) {
        withAnimation(.spring) {
            name = p.name
            emoji = p.emoji
            color = p.color
            goal = p.goal
            unit = p.unit
            step = p.step
        }
        previewBump += 1
    }

    private func save() {
        let habit = Habit(name: name.trimmingCharacters(in: .whitespaces),
                          emoji: emoji.isEmpty ? "⭐️" : emoji,
                          color: color, goal: goal, unit: unit, step: step)
        withAnimation(.spring) { store.add(habit) }
        dismiss()
    }
}
