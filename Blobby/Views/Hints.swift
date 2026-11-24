import SwiftUI

/// First-time hints: shown once each, at the moment they're useful (not an upfront tutorial).
/// Order: 1. tap + to log  →  2. tap the card to open  →  3. press and hold for options (the tip pill).
enum Hints {
    static let logKey = "hintLogDone"
    static let openKey = "hintOpenDone"

    /// Demo/CI runs only show hints when asked (-hints), so normal screenshots stay clean.
    static var enabled: Bool { LaunchOptions.demo == nil || LaunchOptions.args.contains("-hints") }
}

/// A cartoon speech bubble with a bouncing pointing finger.
struct HintBubble: View {
    let text: String
    var color: HabitColor = .sunny
    /// Where the finger points, relative to the bubble.
    var fingerAlignment: HorizontalAlignment = .trailing
    var onClose: () -> Void

    @State private var shown = false
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: fingerAlignment, spacing: -4) {
            HStack(spacing: 10) {
                Text(text)
                    .font(.cartoon(15, .heavy))
                    .foregroundStyle(Ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Ink.color.opacity(0.55))
                        .frame(width: 26, height: 26)
                }
                .accessibilityLabel("Dismiss hint")
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color.main))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Ink.color, lineWidth: 2.5))
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ink.color).offset(y: 4))

            Text("👇")
                .font(.system(size: 30))
                .offset(y: bob ? 6 : -2)
                .padding(.horizontal, 18)
                .accessibilityHidden(true)
        }
        .scaleEffect(shown ? 1 : 0.6, anchor: .bottom)
        .opacity(shown ? 1 : 0)
        .offset(y: (bob && !reduceMotion) ? -3 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.5)) { shown = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(0.9)) { bob = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hint: \(text)")
        .allowsHitTesting(true)
    }
}
