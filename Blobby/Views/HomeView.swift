import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: HabitStore
    @State private var path: [UUID] = []
    @State private var showingAdd = false

    private var doneCount: Int {
        store.habits.filter { $0.isDone() }.count
    }

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
                            ForEach(store.habits) { habit in
                                HabitCard(habit: habit) {
                                    path.append(habit.id)
                                }
                                .transition(.scale.combined(with: .opacity))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation(.spring) { store.delete(habit.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
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
        }
        .tint(Ink.color)
        .sheet(isPresented: $showingAdd) {
            AddHabitView()
                .environmentObject(store)
        }
        .task {
            if let i = LaunchOptions.openIndex, store.habits.indices.contains(i) {
                path = [store.habits[i].id]
            }
            if LaunchOptions.showAdd { showingAdd = true }
        }
    }

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
                    Text("\(doneCount) of \(store.habits.count) done")
                        .font(.cartoon(16, .bold))
                        .foregroundStyle(Ink.color.opacity(0.6))
                        .contentTransition(.numericText())
                        .animation(.spring, value: doneCount)
                }
            }
            Spacer()
            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Ink.color)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(HabitColor.sunny.main))
                    .overlay(Circle().stroke(Ink.color, lineWidth: 3))
                    .background(Circle().fill(Ink.color).offset(y: 4))
            }
            .buttonStyle(BouncyButtonStyle())
            .accessibilityLabel("Add habit")
        }
        .padding(.top, 8)
    }
}

struct HabitCard: View {
    let habit: Habit
    let onOpen: () -> Void
    @EnvironmentObject var store: HabitStore
    @State private var bump = 0

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 14) {
                BlobMascot(progress: habit.progress(), color: habit.color, kind: habit.kind, size: 78, bump: bump)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(habit.emoji) \(habit.name)")
                        .font(.cartoon(19))
                        .foregroundStyle(Ink.color)
                        .lineLimit(1)
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
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    store.log(habit.id, delta: habit.step)
                }
                bump += 1
            } label: {
                Image(systemName: habit.isDone() ? "checkmark" : "plus")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(habit.isDone() ? habit.color.deep : habit.color.main))
                    .overlay(Circle().stroke(Ink.color, lineWidth: 3))
            }
            .buttonStyle(BouncyButtonStyle())
            .accessibilityLabel("Log \(habit.step.clean) \(habit.unit)")
        }
        .padding(14)
        .cartoonCard()
        .sensoryFeedback(.impact(flexibility: .soft), trigger: bump)
    }
}

struct EmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            BlobMascot(progress: 0.35, color: .ocean, kind: .drop, size: 170)
            Text("No habits yet")
                .font(.cartoon(26))
                .foregroundStyle(Ink.color)
            Text("Add your first one — like drinking 2 L of water a day — and watch Blobby fill up.")
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
