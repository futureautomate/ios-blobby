import SwiftUI

/// A habit's cartoon character. Every kind shares the same personality
/// (blinks, smiles more as progress grows, squashes on tap, jumps when celebrating)
/// but shows progress its own way:
/// - Droplet / Apple / Blobby: fill with liquid, bubbles rise
/// - Sprout: a plant grows out of its pot, leaves pop, a flower blooms at 100%
/// - Sunny: rays grow and spin, glow gets stronger
/// - Flame: grows taller and brighter, flickers
struct BlobMascot: View {
    var progress: Double
    var color: HabitColor
    var kind: MascotKind = .blob
    var size: CGFloat = 220
    var bump: Int = 0
    var celebrate: Bool = false

    @State private var fill: Double = 0
    @State private var squash: Bool = false

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let jump = celebrate ? CGFloat(abs(sin(t * 5.0))) * size * 0.16 : 0
            let breathe = 1.0 + 0.015 * CGFloat(sin(t * 2.0))

            ZStack {
                // Ground shadow — shrinks while jumping.
                Ellipse()
                    .fill(Ink.color.opacity(0.13))
                    .frame(width: size * 0.72 * (1 - jump / size), height: size * 0.10)
                    .offset(y: size * 0.47)

                character(t: t)
                    .frame(width: size, height: size)
                    .scaleEffect(x: (squash ? 1.18 : 1.0) / breathe, y: (squash ? 0.82 : 1.0) * breathe, anchor: .bottom)
                    .offset(y: -jump)
            }
            .frame(width: size, height: size * 1.05)
        }
        .onAppear { fill = progress }
        .onChange(of: progress) {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.55)) {
                fill = progress
            }
        }
        .onChange(of: bump) {
            withAnimation(.easeOut(duration: 0.08)) { squash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.32)) { squash = false }
            }
        }
    }

    @ViewBuilder
    private func character(t: Double) -> some View {
        switch kind {
        case .blob:
            liquidBody(BlobShape(phase: t * 2.2), t: t, faceY: 0, faceScale: 1, gloss: CGPoint(x: -0.27, y: -0.16))
        case .drop:
            liquidBody(DropShape(phase: t * 2.2), t: t, faceY: size * 0.15, faceScale: 0.82, gloss: CGPoint(x: -0.2, y: 0.05))
        case .apple:
            ZStack {
                // Stem behind the body
                Capsule()
                    .fill(Color(red: 0.45, green: 0.28, blue: 0.15))
                    .overlay(Capsule().stroke(Ink.color, lineWidth: max(1.5, size * 0.02)))
                    .frame(width: size * 0.05, height: size * 0.17)
                    .rotationEffect(.degrees(12))
                    .offset(x: size * 0.02, y: -size * 0.34)
                liquidBody(AppleShape(phase: t * 2.0), t: t, faceY: size * 0.10, faceScale: 0.9, gloss: CGPoint(x: -0.24, y: -0.05))
                // Leaf swaying in the breeze
                LeafShape()
                    .fill(HabitColor.mint.main)
                    .overlay(LeafShape().stroke(Ink.color, lineWidth: max(1.5, size * 0.02)))
                    .frame(width: size * 0.2, height: size * 0.1)
                    .rotationEffect(.degrees(-25 + sin(t * 1.8) * 10), anchor: .leading)
                    .offset(x: size * 0.13, y: -size * 0.38)
            }
        case .sprout:
            SproutCharacter(progress: fill, color: color, size: size, t: t, celebrate: celebrate)
        case .sun:
            SunCharacter(progress: fill, color: color, size: size, t: t, celebrate: celebrate)
        case .flame:
            FlameCharacter(progress: fill, color: color, size: size, t: t, celebrate: celebrate)
        }
    }

    /// Shared "container fills with liquid" body used by Blobby, Droplet and Apple.
    private func liquidBody<S: Shape>(_ shape: S, t: Double, faceY: CGFloat, faceScale: CGFloat, gloss: CGPoint) -> some View {
        let line = max(2.5, size * 0.03)
        return ZStack {
            shape.fill(color.light)

            LiquidWave(level: fill, phase: t * 2.0 + 1.6, amplitude: size * 0.03)
                .fill(color.main.opacity(0.45))
                .mask(shape)

            LiquidWave(level: fill, phase: t * 2.6, amplitude: size * 0.035)
                .fill(LinearGradient(colors: [color.main, color.deep], startPoint: .top, endPoint: .bottom))
                .mask(shape)

            BubblesView(t: t, level: fill, size: size)
                .mask(shape)

            Ellipse()
                .fill(Color.white.opacity(0.6))
                .frame(width: size * 0.12, height: size * 0.22)
                .rotationEffect(.degrees(-28))
                .offset(x: gloss.x * size, y: gloss.y * size)

            shape.stroke(Ink.color, style: StrokeStyle(lineWidth: line, lineJoin: .round))

            BlobFace(progress: fill, size: size * faceScale, t: t, celebrate: celebrate)
                .offset(y: faceY)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Sprout

/// A pot with a face. The stem grows with progress, leaves pop out, a flower blooms at 100%.
private struct SproutCharacter: View {
    let progress: Double
    let color: HabitColor
    let size: CGFloat
    let t: Double
    let celebrate: Bool

    private let leafGreen = Color(red: 0.30, green: 0.74, blue: 0.36)

    var body: some View {
        let line = max(2, size * 0.026)
        let maxStem = size * 0.44
        let p = CGFloat(min(max(progress, 0), 1))
        let stemH = max(size * 0.05, maxStem * p)
        let sway = Angle.degrees(sin(t * 1.6) * 5)

        ZStack(alignment: .bottom) {
            // Plant
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(leafGreen)
                    .overlay(Capsule().stroke(Ink.color, lineWidth: line * 0.7))
                    .frame(width: size * 0.05, height: stemH)

                ForEach(0..<4, id: \.self) { i in
                    leaf(i, maxStem: maxStem, line: line)
                }

                flower(line: line)
                    .offset(y: -stemH + size * 0.02)
            }
            .frame(width: size, height: maxStem + size * 0.2, alignment: .bottom)
            .rotationEffect(sway, anchor: .bottom)
            .offset(y: -size * 0.46)

            // Pot with soil and face
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.36, green: 0.24, blue: 0.16))
                    .frame(width: size * 0.66, height: size * 0.08)
                    .offset(y: -size * 0.215)
                PotShape().fill(LinearGradient(colors: [color.main, color.deep], startPoint: .top, endPoint: .bottom))
                PotShape().stroke(Ink.color, style: StrokeStyle(lineWidth: line, lineJoin: .round))
                BlobFace(progress: progress, size: size * 0.58, t: t, celebrate: celebrate)
                    .offset(y: size * 0.07)
            }
            .frame(width: size * 0.78, height: size * 0.5)
        }
        .frame(width: size, height: size)
    }

    private func leaf(_ i: Int, maxStem: CGFloat, line: CGFloat) -> some View {
        let heights: [CGFloat] = [0.22, 0.42, 0.62, 0.80]
        let f = heights[i]
        let grow = CGFloat(min(max((progress - Double(f)) * 5.0, 0), 1))
        let left = i % 2 == 0
        let flutter = sin(t * 2.4 + Double(i)) * 6
        return LeafShape()
            .fill(leafGreen)
            .overlay(LeafShape().stroke(Ink.color, lineWidth: line * 0.7))
            .frame(width: size * 0.2, height: size * 0.1)
            .rotationEffect(.degrees((left ? 200 : -20) + flutter), anchor: .leading)
            .scaleEffect(grow, anchor: .leading)
            .offset(x: size * 0.1, y: -f * maxStem)
            .opacity(grow > 0.01 ? 1 : 0)
    }

    private func flower(line: CGFloat) -> some View {
        let bloom = CGFloat(min(max((progress - 0.97) * 33.0, 0), 1))
        let petal = size * 0.09
        return ZStack {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(HabitColor.coral.main)
                    .overlay(Circle().stroke(Ink.color, lineWidth: line * 0.6))
                    .frame(width: petal, height: petal)
                    .offset(y: -petal * 0.62)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
            Circle()
                .fill(HabitColor.sunny.main)
                .overlay(Circle().stroke(Ink.color, lineWidth: line * 0.6))
                .frame(width: petal * 0.85, height: petal * 0.85)
        }
        .rotationEffect(.radians(t * 0.6))
        .scaleEffect(bloom)
        .opacity(bloom > 0.01 ? 1 : 0)
    }
}

// MARK: - Sun

/// A sun whose rays grow and spin faster as progress rises; glows when complete.
private struct SunCharacter: View {
    let progress: Double
    let color: HabitColor
    let size: CGFloat
    let t: Double
    let celebrate: Bool

    var body: some View {
        let line = max(2, size * 0.026)
        let p = CGFloat(min(max(progress, 0), 1))
        let core = size * 0.56
        let rayLen = size * (0.06 + 0.11 * p)
        let done = progress >= 0.999 || celebrate
        let spin = Angle.radians(t * (done ? 0.9 : 0.25))
        let pulse = done ? 1.0 + 0.06 * CGFloat(sin(t * 4.0)) : 1.0

        ZStack {
            Circle()
                .fill(color.main.opacity(0.15 + 0.35 * Double(p)))
                .frame(width: core * 1.55 * pulse, height: core * 1.55 * pulse)
                .blur(radius: size * 0.05)

            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    Capsule()
                        .fill(i % 2 == 0 ? color.main : color.deep)
                        .overlay(Capsule().stroke(Ink.color, lineWidth: line * 0.7))
                        .frame(width: size * 0.065, height: rayLen)
                        .offset(y: -(core / 2 + size * 0.035 + rayLen / 2))
                        .rotationEffect(.degrees(Double(i) * 30))
                }
            }
            .rotationEffect(spin)

            Circle().fill(color.light).frame(width: core, height: core)
            Circle()
                .fill(RadialGradient(colors: [color.main.opacity(0.7), color.main],
                                     center: .center, startRadius: 0, endRadius: core / 2))
                .frame(width: core, height: core)
                .opacity(0.25 + 0.75 * Double(p))
            Ellipse()
                .fill(Color.white.opacity(0.55))
                .frame(width: core * 0.16, height: core * 0.28)
                .rotationEffect(.degrees(-30))
                .offset(x: -core * 0.28, y: -core * 0.2)
            Circle().stroke(Ink.color, lineWidth: line).frame(width: core, height: core)

            BlobFace(progress: progress, size: core * 1.05, t: t, celebrate: celebrate)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Flame

/// A flame that grows taller and wider with progress and flickers constantly.
private struct FlameCharacter: View {
    let progress: Double
    let color: HabitColor
    let size: CGFloat
    let t: Double
    let celebrate: Bool

    var body: some View {
        let line = max(2.5, size * 0.03)
        let p = CGFloat(min(max(progress, 0), 1))
        let phase = t * 6.0

        ZStack(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                FlameShape(phase: phase)
                    .fill(LinearGradient(colors: [color.main, color.deep], startPoint: .top, endPoint: .bottom))
                FlameShape(phase: phase + 1.7)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.9), HabitColor.sunny.main.opacity(0.9)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.42, height: size * 0.5)
                    .offset(y: -size * 0.04)
                    .opacity(0.35 + 0.65 * Double(p))
                FlameShape(phase: phase)
                    .stroke(Ink.color, style: StrokeStyle(lineWidth: line, lineJoin: .round))
            }
            .frame(width: size * 0.84, height: size * 0.96)
            .scaleEffect(x: 0.82 + 0.18 * p, y: 0.55 + 0.45 * p, anchor: .bottom)

            BlobFace(progress: progress, size: size * 0.6, t: t, celebrate: celebrate)
                .offset(y: -size * 0.13)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Shared parts

/// Bubbles rising through the liquid.
private struct BubblesView: View {
    let t: Double
    let level: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                bubble(i)
            }
        }
        .frame(width: size, height: size)
    }

    private func bubble(_ i: Int) -> some View {
        let speed: Double = 0.22 + Double(i % 3) * 0.09
        let rise: Double = (t * speed + Double(i) * 0.37).truncatingRemainder(dividingBy: 1.0)
        let liquidHeight: CGFloat = size * 0.86 * CGFloat(min(max(level, 0), 1))
        let x: CGFloat = (CGFloat(i) / 7.0 - 0.43) * size * 0.8 + CGFloat(sin(t * 2.0 + Double(i))) * size * 0.02
        let y: CGFloat = size * 0.44 - CGFloat(rise) * liquidHeight
        let d: CGFloat = size * (0.03 + 0.018 * CGFloat(i % 2))
        let visible: Double = level > 0.06 ? (1.0 - rise) : 0

        return Circle()
            .fill(Color.white.opacity(0.28))
            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: max(1, size * 0.007)))
            .frame(width: d, height: d)
            .offset(x: x, y: y)
            .opacity(visible)
    }
}

/// Eyes, mouth and cheeks — shared by every character.
struct BlobFace: View {
    let progress: Double
    let size: CGFloat
    let t: Double
    let celebrate: Bool

    var body: some View {
        let blink = t.truncatingRemainder(dividingBy: 3.7) < 0.13
        let look = CGFloat(sin(t * 0.8)) * size * 0.012
        let done = progress >= 0.999
        let happy = celebrate || done

        VStack(spacing: size * 0.035) {
            HStack(spacing: size * 0.15) {
                eye(blink: blink, look: look, happy: happy)
                eye(blink: blink, look: look, happy: happy)
            }
            ZStack {
                if happy {
                    OpenMouthShape()
                        .fill(Ink.color)
                        .overlay(
                            Ellipse()
                                .fill(Color(red: 1.0, green: 0.45, blue: 0.5))
                                .frame(width: size * 0.12, height: size * 0.05)
                                .offset(y: size * 0.045)
                        )
                        .clipShape(OpenMouthShape())
                        .frame(width: size * 0.26, height: size * 0.09)
                } else {
                    MouthShape(curve: -0.25 + progress * 1.1)
                        .stroke(Ink.color, style: StrokeStyle(lineWidth: max(2, size * 0.028), lineCap: .round))
                        .frame(width: size * 0.22, height: size * 0.09)
                }
            }
            .frame(height: size * 0.12)
        }
        .overlay(cheeks.opacity(progress > 0.45 || happy ? 1 : 0))
        .offset(y: -size * 0.02)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: done)
    }

    @ViewBuilder
    private func eye(blink: Bool, look: CGFloat, happy: Bool) -> some View {
        let w = size * 0.12
        let h = size * 0.16
        if happy {
            // Happy "^" eyes.
            MouthShape(curve: -0.9)
                .stroke(Ink.color, style: StrokeStyle(lineWidth: max(2, size * 0.03), lineCap: .round))
                .frame(width: w, height: h * 0.45)
                .frame(width: w, height: h)
        } else {
            ZStack {
                Ellipse().fill(Color.white)
                Ellipse().stroke(Ink.color, lineWidth: max(1.5, size * 0.018))
                Circle()
                    .fill(Ink.color)
                    .frame(width: w * 0.55, height: w * 0.55)
                    .offset(x: look, y: h * 0.1)
                Circle()
                    .fill(Color.white)
                    .frame(width: w * 0.18, height: w * 0.18)
                    .offset(x: look + w * 0.1, y: -h * 0.02)
            }
            .frame(width: w, height: h)
            .scaleEffect(x: 1, y: blink ? 0.1 : 1)
        }
    }

    private var cheeks: some View {
        HStack(spacing: size * 0.36) {
            Ellipse().fill(Color(red: 1.0, green: 0.5, blue: 0.55).opacity(0.45))
                .frame(width: size * 0.1, height: size * 0.055)
            Ellipse().fill(Color(red: 1.0, green: 0.5, blue: 0.55).opacity(0.45))
                .frame(width: size * 0.1, height: size * 0.055)
        }
        .offset(y: size * 0.05)
    }
}
