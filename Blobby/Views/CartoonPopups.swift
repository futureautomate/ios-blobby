import SwiftUI
import UniformTypeIdentifiers

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
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.cartoon(15, .medium))
                    .foregroundStyle(Ink.text.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Keep it")
                            .font(.cartoon(17))
                            .foregroundStyle(Ink.text)
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
                .foregroundStyle(Ink.text)
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

    private enum Pending: Equatable { case reset, sample, restore }
    @State private var pending: Pending?
    @State private var showingAbout = false
    @State private var exporting = false
    @State private var importing = false
    @State private var restoreFrom: Backup?
    @State private var backupMessage: String?
    @AppStorage(Profile.nameKey) private var profileName = ""
    @State private var showingRecap = false
    @State private var showSigning = false
    @AppStorage(SoundFX.settingKey) private var soundOn = true
    @AppStorage(Appearance.key) private var appearance = Appearance.auto.rawValue

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        ZStack {
            Paper.color.ignoresSafeArea()

            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Settings")
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
                }

                row(emoji: "🙂", title: profileName.isEmpty ? "About you" : profileName,
                    subtitle: "Change your name or buddy") {
                    withAnimation(.spring) { showingAbout = true }
                }

                appearancePicker

                row(emoji: "📤", title: "Export backup",
                    subtitle: "Save all habits and history to a file (Files, iCloud Drive, WhatsApp…)") {
                    exporting = true
                }
                row(emoji: "📥", title: "Import backup",
                    subtitle: "Restore from a Blobby backup file") {
                    importing = true
                }
                if let msg = backupMessage {
                    Text(msg)
                        .font(.cartoon(13, .bold))
                        .foregroundStyle(Ink.text.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }

                row(emoji: "🧹", title: "Reset all data",
                    subtitle: "Delete every habit and its history") {
                    withAnimation(.spring) { pending = .reset }
                }
                row(emoji: "✨", title: "Load sample habits",
                    subtitle: "Replace everything with 5 demo habits (for testing)") {
                    withAnimation(.spring) { pending = .sample }
                }
                row(emoji: "📊", title: "Reports",
                    subtitle: "Week and month report cards, all habits together") {
                    showingRecap = true
                }

                HStack(spacing: 14) {
                    Text("🔊").font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sound effects").font(.cartoon(18)).foregroundStyle(Ink.text)
                        Text("Pops, chimes and fanfares (follows the silent switch)")
                            .font(.cartoon(13, .medium)).foregroundStyle(Ink.text.opacity(0.55))
                    }
                    Spacer()
                    CartoonToggle(isOn: $soundOn, color: .mint)
                }
                .padding(16)
                .cartoonCard(radius: 22)

                Color.clear.frame(height: 10)

                // Signing details (useful when debugging sideloaded builds). Tap to expand.
                Button { withAnimation(.spring) { showSigning.toggle() } } label: {
                    Label(showSigning ? "Hide signing info" : "Signing info",
                          systemImage: showSigning ? "chevron.up" : "info.circle")
                        .font(.cartoon(12, .bold))
                        .foregroundStyle(Ink.text.opacity(0.45))
                }
                .frame(maxWidth: .infinity)
                if showSigning {
                    Text(ProvisioningInfo.report)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Ink.text.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Card.color.opacity(0.7)))
                }

                HStack(spacing: 18) {
                    Link("Privacy policy", destination: URL(string: "https://futureautomate.github.io/ios-blobby/privacy.html")!)
                    Link("Support", destination: URL(string: "https://futureautomate.github.io/ios-blobby/support.html")!)
                }
                .font(.cartoon(14, .bold))
                .foregroundStyle(HabitColor.ocean.tone)
                .frame(maxWidth: .infinity)

                Text("Blobby v\(version) · built on Windows")
                    .font(.cartoon(13, .bold))
                    .foregroundStyle(Ink.text.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
            .padding(.top, 8)
            }
            .scrollBounceBehavior(.basedOnSize)

            if let p = pending {
                CartoonConfirm(
                    title: p == .reset ? "Reset everything?" : (p == .sample ? "Load sample habits?" : "Restore this backup?"),
                    message: p == .reset
                        ? "All habits and their history will be deleted. This can't be undone."
                        : (p == .sample ? "Your current habits will be replaced by 5 demo habits."
                           : "Your current habits will be replaced by the \(restoreFrom?.habits.count ?? 0) habits in the backup."),
                    color: p == .reset ? .coral : (p == .sample ? .grape : .ocean),
                    kind: p == .reset ? .blob : (p == .sample ? .sprout : .drop),
                    confirmTitle: p == .reset ? "Reset" : (p == .sample ? "Replace" : "Restore"),
                    onCancel: { withAnimation(.spring) { pending = nil; restoreFrom = nil } },
                    onConfirm: {
                        withAnimation(.spring) {
                            switch p {
                            case .reset: store.reset()
                            case .sample: store.loadSample()
                            case .restore:
                                if let b = restoreFrom {
                                    store.replaceAll(b.habits)
                                    if !b.name.isEmpty {
                                        Profile.save(name: b.name, kind: MascotKind(rawValue: b.kind) ?? .blob,
                                                     color: HabitColor(rawValue: b.color) ?? .ocean)
                                        profileName = b.name
                                    }
                                }
                                restoreFrom = nil
                            }
                            pending = nil
                        }
                        dismiss()
                    })
                .transition(.opacity)
            }

            if showingAbout {
                AboutYouPopup(onCancel: { withAnimation(.spring) { showingAbout = false } },
                              onSave: {
                                  profileName = Profile.name
                                  withAnimation(.spring) { showingAbout = false }
                              })
                .transition(.opacity)
            }
        }
        .fileExporter(isPresented: $exporting,
                      document: BackupDocument(data: Backup.current(store.habits).encoded()),
                      contentType: .json,
                      defaultFilename: Backup.fileName) { result in
            withAnimation {
                if case .success = result { backupMessage = "✅ Backup saved" }
                else { backupMessage = nil }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let backup = Backup.decode(data) {
                restoreFrom = backup
                withAnimation(.spring) { pending = .restore }
            } else {
                withAnimation { backupMessage = "😕 That file isn't a Blobby backup" }
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
        .appAppearance()
    }

    /// Auto / Light / Night chips.
    private var appearancePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Text("🌗").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Look").font(.cartoon(18)).foregroundStyle(Ink.text)
                    Text("Auto follows your iPhone's dark mode")
                        .font(.cartoon(13, .medium)).foregroundStyle(Ink.text.opacity(0.55))
                }
            }
            HStack(spacing: 10) {
                ForEach(Appearance.allCases) { option in
                    let selected = appearance == option.rawValue
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { appearance = option.rawValue }
                    } label: {
                        VStack(spacing: 2) {
                            Text(option.emoji).font(.system(size: 22))
                            Text(option.title).font(.cartoon(14)).foregroundStyle(selected ? Ink.color : Ink.text)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .cartoonCard(radius: 16, fill: selected ? HabitColor.sunny.main : Card.color)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .accessibilityLabel("\(option.title) look")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(16)
        .cartoonCard(radius: 22)
    }

    private func row(emoji: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.cartoon(18)).foregroundStyle(Ink.text)
                    Text(subtitle).font(.cartoon(13, .medium)).foregroundStyle(Ink.text.opacity(0.55))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Ink.text.opacity(0.4))
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
                            .foregroundStyle(Ink.text)
                        Text(habit.isPaused ? "Paused" : "\(habit.amount().clean) / \(habit.goal.clean) \(habit.unit) today")
                            .font(.cartoon(13, .semibold))
                            .foregroundStyle(Ink.text.opacity(0.55))
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
                                    .foregroundStyle(item.destructive ? HabitColor.coral.tone : Ink.text)
                                if let sub = item.subtitle {
                                    Text(sub)
                                        .font(.cartoon(12, .semibold))
                                        .foregroundStyle(Ink.text.opacity(0.5))
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .cartoonCard(radius: 16, fill: item.destructive ? HabitColor.coral.light : Card.color)
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
