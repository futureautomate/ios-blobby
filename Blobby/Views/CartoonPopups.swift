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
                BlobMascot(progress: 0.6, color: color, kind: kind, size: 110, sticker: sticker, sad: true)
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

                Spacer()

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
        .presentationDetents([.medium])
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
