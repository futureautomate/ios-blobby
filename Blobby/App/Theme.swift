import SwiftUI

extension Color {
    /// A colour that switches between the day (light) and night (dark) theme.
    init(day: UIColor, night: UIColor) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? night : day })
    }
}

private func rgb(_ hex: UInt32) -> UIColor {
    UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// The dark "ink" used for cartoon outlines and hard shadows.
/// Stays dark at night too (darker than the cards) so the sticker look survives.
enum Ink {
    static let color = Color(day: rgb(0x212133), night: rgb(0x0C0A1A))
    /// Text and icons on cards/background: ink by day, warm moon-cream at night.
    static let text = Color(day: rgb(0x212133), night: rgb(0xFFF3DC))
}

/// Background for the whole app: warm paper by day, deep indigo sky at night.
enum Paper {
    static let color = Color(day: rgb(0xFFFAF0), night: rgb(0x1B1733))
}

/// Card / button surface: white by day, lifted plum at night.
enum Card {
    static let color = Color(day: .white, night: rgb(0x2B2550))
}

/// Each habit picks one of these palettes. `main` = body/liquid, `deep` = liquid bottom,
/// `light` = tint for backgrounds and tracks (deep tint at night),
/// `pastel` = the character's own light colour (same day and night, so characters never change).
enum HabitColor: Int, Codable, CaseIterable, Identifiable, Hashable {
    case ocean, mint, sunny, coral, grape

    var id: Int { rawValue }

    var main: Color {
        switch self {
        case .ocean: return Color(day: rgb(0x4094FA), night: rgb(0x5AAEFF))
        case .mint:  return Color(day: rgb(0x38CC9E), night: rgb(0x45DDA9))
        case .sunny: return Color(day: rgb(0xFFC233), night: rgb(0xFFD34D))
        case .coral: return Color(day: rgb(0xFF756B), night: rgb(0xFF8585))
        case .grape: return Color(day: rgb(0x9E75F5), night: rgb(0xB49BFF))
        }
    }

    var deep: Color {
        switch self {
        case .ocean: return Color(rgb(0x1A52B3))
        case .mint:  return Color(rgb(0x0D8061))
        case .sunny: return Color(rgb(0xD98005))
        case .coral: return Color(rgb(0xC23338))
        case .grape: return Color(rgb(0x6138B8))
        }
    }

    /// Coloured text: deep shade by day, bright shade at night (readable on dark cards).
    var tone: Color {
        Color(UIColor { trait in
            switch self {
            case .ocean: return trait.userInterfaceStyle == .dark ? rgb(0x8CC8FF) : rgb(0x1A52B3)
            case .mint:  return trait.userInterfaceStyle == .dark ? rgb(0x6FE8BE) : rgb(0x0D8061)
            case .sunny: return trait.userInterfaceStyle == .dark ? rgb(0xFFD34D) : rgb(0xD98005)
            case .coral: return trait.userInterfaceStyle == .dark ? rgb(0xFF9C9C) : rgb(0xC23338)
            case .grape: return trait.userInterfaceStyle == .dark ? rgb(0xC9B6FF) : rgb(0x6138B8)
            }
        })
    }

    /// Fill for a finished habit's tick: deep shade by day, glowing yellow at night.
    var doneFill: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? rgb(0xFFD34D) : UIColor(self.deep) })
    }
    /// Tick colour on top of `doneFill`.
    static let doneInk = Color(day: .white, night: rgb(0x0C0A1A))

    var pastelUI: UIColor {
        switch self {
        case .ocean: return rgb(0xE0F0FF)
        case .mint:  return rgb(0xDEFAED)
        case .sunny: return rgb(0xFFF5D6)
        case .coral: return rgb(0xFFE8E6)
        case .grape: return rgb(0xF0E8FF)
        }
    }

    var pastel: Color { Color(pastelUI) }

    var light: Color {
        switch self {
        case .ocean: return Color(day: pastelUI, night: rgb(0x1E2F55))
        case .mint:  return Color(day: pastelUI, night: rgb(0x173F3A))
        case .sunny: return Color(day: pastelUI, night: rgb(0x43391C))
        case .coral: return Color(day: pastelUI, night: rgb(0x4A2440))
        case .grape: return Color(day: pastelUI, night: rgb(0x352A63))
        }
    }
}

/// Applies the Light / Night / Auto choice (root view and every sheet).
struct AppAppearance: ViewModifier {
    @AppStorage(Appearance.key) private var appearance = Appearance.auto.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme(LaunchOptions.night ? .dark : (Appearance(rawValue: appearance) ?? .auto).scheme)
    }
}

extension View {
    func appAppearance() -> some View { modifier(AppAppearance()) }
}

/// App appearance chosen in Settings.
enum Appearance: Int, CaseIterable, Identifiable {
    case auto, day, night
    var id: Int { rawValue }
    static let key = "appearance"
    var title: String { ["Auto", "Light", "Night"][rawValue] }
    var emoji: String { ["📱", "☀️", "🌙"][rawValue] }
    var scheme: ColorScheme? { [nil, .light, .dark][rawValue] }
}

extension Font {
    /// Chunky rounded font for the cartoon look.
    /// Scales with the user's text size setting (capped so cards don't break).
    static func cartoon(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        let scaled = min(UIFontMetrics.default.scaledValue(for: size), size * 1.4)
        return .system(size: scaled, weight: weight, design: .rounded)
    }

    /// Fixed size — for share images, which have a fixed canvas.
    static func cartoonFixed(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
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
    var fill: Color = Card.color

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
    func cartoonCard(radius: CGFloat = 26, fill: Color = Card.color) -> some View {
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
