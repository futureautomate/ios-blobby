import SwiftUI

/// Cartoon confirmation popup (replaces the system alert / context menu).
/// Shows the habit's character looking sad, with "Keep it" and a destructive button.
struct CartoonConfirm: View {
    let title: String
    let message: String
    let color: HabitColor
    let kind: MascotKind
    var sticker: String? = nil
    let confirmTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack {
            Ink.color.opacity(shown ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 12) {
                BlobMascot(progress: 0.6, color: color, kind: kind, size: 150, sticker: sticker, sad: true)
                    .allowsHitTesting(false)
                Text(title)
                    .font(.cartoon(22))
                    .foregroundStyle(Ink.color)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.cartoon(15, .medium))
                    .foregroundStyle(Ink.color.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Keep it")
                            .font(.cartoon(17))
                            .foregroundStyle(Ink.color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .cartoonCard(radius: 16)
                    .buttonStyle(BouncyButtonStyle())

                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .font(.cartoon(17))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .cartoonCard(radius: 16, fill: HabitColor.coral.main)
                    .buttonStyle(BouncyButtonStyle())
                }
                .padding(.top, 6)
            }
            .padding(22)
            .cartoonCard(radius: 28)
            .padding(.horizontal, 32)
            .scaleEffect(shown ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) { shown = true }
        }
    }
}

/// "Poof!" burst of dots shown where a card disappears.
struct PoofView: View {
    let color: Color
    @State private var go = false

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                dot(i)
            }
            Text("poof!")
                .font(.cartoon(24))
                .foregroundStyle(Ink.color)
                .scaleEffect(go ? 1.3 : 0.5)
                .opacity(go ? 0 : 1)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { go = true }
        }
    }

    private func dot(_ i: Int) -> some View {
        let a = Double(i) / 12.0 * 2.0 * Double.pi
        let d: CGFloat = i % 3 == 0 ? 20 : 14
        return Circle()
            .fill(i % 2 == 0 ? color : Color.white)
            .overlay(Circle().stroke(Ink.color, lineWidth: 2))
            .frame(width: d, height: d)
            .scaleEffect(go ? 0.3 : 1)
            .offset(x: go ? CGFloat(cos(a)) * 150 : 0, y: go ? CGFloat(sin(a)) * 70 : 0)
            .opacity(go ? 0 : 1)
    }
}

/// Small settings sheet: reset data, load demo habits, version.
struct SettingsView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    private enum Pending { case reset, sample }
    @State private var pending: Pending?
    @State private var showingRecap = false
    @State private var showSigning = false
    @AppStorage(SoundFX.settingKey) private var soundOn = true

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        ZStack {
            Paper.color.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Settings")
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
                }

                row(emoji: "🧹", title: "Reset all data",
                    subtitle: "Delete every habit and its history") {
                    withAnimation(.spring) { pending = .reset }
                }
                row(emoji: "✨", title: "Load sample habits",
                    subtitle: "Replace everything with 5 demo habits (for testing)") {
                    withAnimation(.spring) { pending = .sample }
                }
                row(emoji: "📅", title: "Weekly recap",
                    subtitle: "Your buddies' report card for the last 7 days") {
                    showingRecap = true
                }

                HStack(spacing: 14) {
                    Text("🔊").font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sound effects").font(.cartoon(18)).foregroundStyle(Ink.color)
                        Text("Pops, chimes and fanfares (follows the silent switch)")
                            .font(.cartoon(13, .medium)).foregroundStyle(Ink.color.opacity(0.55))
                    }
                    Spacer()
                    CartoonToggle(isOn: $soundOn, color: .mint)
                }
                .padding(16)
                .cartoonCard(radius: 22)

                Spacer(minLength: 10)

                // Signing details (useful when debugging sideloaded builds). Tap to expand.
                Button { withAnimation(.spring) { showSigning.toggle() } } label: {
                    Label(showSigning ? "Hide signing info" : "Signing info",
                          systemImage: showSigning ? "chevron.up" : "info.circle")
                        .font(.cartoon(12, .bold))
                        .foregroundStyle(Ink.color.opacity(0.45))
                }
                .frame(maxWidth: .infinity)
                if showSigning {
                    Text(ProvisioningInfo.report)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Ink.color.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.7)))
                }

                Text("Blobby v\(version) · built on Windows")
                    .font(.cartoon(13, .bold))
                    .foregroundStyle(Ink.color.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
            .padding(.top, 8)

            if let p = pending {
                CartoonConfirm(
                    title: p == .reset ? "Reset everything?" : "Load sample habits?",
                    message: p == .reset
                        ? "All habits and their history will be deleted. This can't be undone."
                        : "Your current habits will be replaced by 5 demo habits.",
                    color: p == .reset ? .coral : .grape,
                    kind: p == .reset ? .blob : .sprout,
                    confirmTitle: p == .reset ? "Reset" : "Replace",
                    onCancel: { withAnimation(.spring) { pending = nil } },
                    onConfirm: {
                        withAnimation(.spring) {
                            if p == .reset { store.reset() } else { store.loadSample() }
                            pending = nil
                        }
                        dismiss()
                    })
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showingRecap) {
            WeeklyRecapView()
                .environmentObject(store)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Paper.color)
        .preferredColorScheme(.light)
    }

    private func row(emoji: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.cartoon(18)).foregroundStyle(Ink.color)
                    Text(subtitle).font(.cartoon(13, .medium)).foregroundStyle(Ink.color.opacity(0.55))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Ink.color.opacity(0.4))
            }
            .padding(16)
        }
        .cartoonCard(radius: 22)
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Habit action menu

/// Cartoon action menu for one habit. Opened by long-pressing a card on Today,
/// or from the "•••" button on the habit's screen. Most frequent actions first
/// (Apple HIG: context menus hold the commands people most likely need, frequent first).
/// It slides up from the bottom, where it's easiest to reach with a thumb.
struct HabitActionMenu: View {
    struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        var subtitle: String? = nil
        var destructive = false
        let action: () -> Void
    }

    let habit: Habit
    let items: [Item]
    let onClose: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Ink.color.opacity(shown ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    BlobMascot(progress: habit.progress(), color: habit.color, kind: habit.kind, size: 58,
                               sticker: habit.emoji, accessories: habit.unlocked, sleepy: habit.isPaused)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name)
                            .font(.cartoon(20))
                            .foregroundStyle(Ink.color)
                        Text(habit.isPaused ? "Paused" : "\(habit.amount().clean) / \(habit.goal.clean) \(habit.unit) today")
                            .font(.cartoon(13, .semibold))
                            .foregroundStyle(Ink.color.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(.bottom, 4)

                ForEach(items) { item in
                    Button {
                        close()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { item.action() }
                    } label: {
                        HStack(spacing: 12) {
                            Text(item.icon)
                                .font(.system(size: 22))
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.cartoon(17))
                                    .foregroundStyle(item.destructive ? HabitColor.coral.deep : Ink.color)
                                if let sub = item.subtitle {
                                    Text(sub)
                                        .font(.cartoon(12, .semibold))
                                        .foregroundStyle(Ink.color.opacity(0.5))
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .cartoonCard(radius: 16, fill: item.destructive ? HabitColor.coral.light : .white)
                    .buttonStyle(BouncyButtonStyle())
                    .accessibilityLabel(item.title)
                    .accessibilityHint(item.subtitle ?? "")
                }
            }
            .padding(18)
            .padding(.bottom, 8)
            .cartoonCard(radius: 30, fill: Paper.color)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .offset(y: shown ? 0 : 500)
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { shown = true }
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onClose() }
    }
}
