import SwiftUI

/// Blobby: a jelly character that fills with "liquid" as the habit progresses.
/// - wobbles and breathes all the time
/// - blinks every few seconds, eyes drift around
/// - smile grows with progress, big open grin at 100%
/// - squashes & stretches whenever `bump` changes
/// - jumps while `celebrate` is true
struct BlobMascot: View {
    var progress: Double
    var color: HabitColor
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

                jelly(t: t)
                    .scaleEffect(x: (squash ? 1.18 : 1.0) / breathe, y: (squash ? 0.82 : 1.0) * breathe, anchor: .bottom)
                    .offset(y: -jump)
            }
            .frame(width: size, height: size * 1.05)
        }
        .onAppear {
            fill = progress
        }
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

    // MARK: - Body

    @ViewBuilder
    private func jelly(t: Double) -> some View {
        let phase = t * 2.2
        let outline = BlobShape(phase: phase)
        let line = max(2.5, size * 0.03)

        ZStack {
            outline.fill(color.light)

            // Back wave (lighter, offset) for depth.
            LiquidWave(level: fill, phase: t * 2.0 + 1.6, amplitude: size * 0.03)
                .fill(color.main.opacity(0.45))
                .mask(outline)

            // Front wave.
            LiquidWave(level: fill, phase: t * 2.6, amplitude: size * 0.035)
                .fill(LinearGradient(colors: [color.main, color.deep],
                                     startPoint: .top, endPoint: .bottom))
                .mask(outline)

            BubblesView(t: t, level: fill, size: size)
                .mask(outline)

            // Glossy highlight.
            Ellipse()
                .fill(Color.white.opacity(0.6))
                .frame(width: size * 0.13, height: size * 0.24)
                .rotationEffect(.degrees(-28))
                .offset(x: -size * 0.27, y: -size * 0.16)

            outline.stroke(Ink.color, style: StrokeStyle(lineWidth: line, lineJoin: .round))

            BlobFace(progress: fill, size: size, t: t, celebrate: celebrate)
        }
        .frame(width: size, height: size)
    }
}

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

/// Eyes, mouth and cheeks.
private struct BlobFace: View {
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
                if done || celebrate {
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
