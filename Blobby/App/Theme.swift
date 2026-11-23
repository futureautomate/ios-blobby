import SwiftUI

/// The dark "ink" used for cartoon outlines and text.
enum Ink {
    static let color = Color(red: 0.13, green: 0.13, blue: 0.20)
}

/// Warm paper background for the whole app.
enum Paper {
    static let color = Color(red: 1.0, green: 0.98, blue: 0.94)
}

/// Each habit picks one of these palettes. `main` = body/liquid, `deep` = liquid bottom,
/// `light` = empty blob + background tint.
enum HabitColor: Int, Codable, CaseIterable, Identifiable, Hashable {
    case ocean, mint, sunny, coral, grape

    var id: Int { rawValue }

    var main: Color {
        switch self {
        case .ocean: return Color(red: 0.25, green: 0.58, blue: 0.98)
        case .mint:  return Color(red: 0.22, green: 0.80, blue: 0.62)
        case .sunny: return Color(red: 1.00, green: 0.76, blue: 0.20)
        case .coral: return Color(red: 1.00, green: 0.46, blue: 0.42)
        case .grape: return Color(red: 0.62, green: 0.46, blue: 0.96)
        }
    }

    var deep: Color {
        switch self {
        case .ocean: return Color(red: 0.10, green: 0.32, blue: 0.70)
        case .mint:  return Color(red: 0.05, green: 0.50, blue: 0.38)
        case .sunny: return Color(red: 0.85, green: 0.50, blue: 0.02)
        case .coral: return Color(red: 0.76, green: 0.20, blue: 0.22)
        case .grape: return Color(red: 0.38, green: 0.22, blue: 0.72)
        }
    }

    var light: Color {
        switch self {
        case .ocean: return Color(red: 0.88, green: 0.94, blue: 1.00)
        case .mint:  return Color(red: 0.87, green: 0.98, blue: 0.93)
        case .sunny: return Color(red: 1.00, green: 0.96, blue: 0.84)
        case .coral: return Color(red: 1.00, green: 0.91, blue: 0.90)
        case .grape: return Color(red: 0.94, green: 0.91, blue: 1.00)
        }
    }
}

extension Font {
    /// Chunky rounded font for the cartoon look.
    static func cartoon(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Double {
    /// 2000 -> "2,000", 1.5 -> "1.5"
    var clean: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: self)) ?? String(self)
    }
}

/// White card with a thick ink outline and a hard drop shadow (sticker look).
struct CartoonCard: ViewModifier {
    var radius: CGFloat = 26
    var fill: Color = .white

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Ink.color, lineWidth: 3)
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Ink.color)
                    .offset(y: 5)
            )
    }
}

extension View {
    func cartoonCard(radius: CGFloat = 26, fill: Color = .white) -> some View {
        modifier(CartoonCard(radius: radius, fill: fill))
    }
}

/// Buttons squish when pressed and spring back.
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.45), value: configuration.isPressed)
    }
}

/// Rounded progress bar with an ink outline.
struct ProgressPill: View {
    var progress: Double
    var color: HabitColor
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.light)
                Capsule()
                    .fill(color.main)
                    .frame(width: max(height, geo.size.width * CGFloat(min(max(progress, 0), 1))))
                    .opacity(progress > 0 ? 1 : 0)
                Capsule().stroke(Ink.color, lineWidth: 2.5)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
    }
}
