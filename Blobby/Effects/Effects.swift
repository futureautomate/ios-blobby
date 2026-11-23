import SwiftUI

/// Deterministic pseudo-random 0..<1 from an integer seed.
private func rand(_ n: Int) -> Double {
    let x = sin(Double(n) * 12.9898 + 78.233) * 43758.5453
    return x - floor(x)
}

/// Confetti burst drawn with Canvas. `loop` keeps it going (used for screenshots).
struct ConfettiView: View {
    let start: Date
    var loop: Bool = false
    var colors: [Color] = [.pink, .yellow, .mint, .blue, .orange, .purple]

    private let count = 80
    private let life: Double = 2.6

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for i in 0..<count {
                    draw(i, elapsed: elapsed, in: size, ctx: ctx)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func draw(_ i: Int, elapsed: Double, in size: CGSize, ctx: GraphicsContext) {
        let delay = rand(i * 7) * 0.25
        var age = elapsed - delay
        if loop { age = (elapsed + rand(i * 5) * life).truncatingRemainder(dividingBy: life) }
        guard age >= 0, age < life else { return }

        let vx = (rand(i) - 0.5) * 2.0 * 330.0
        let vy = -(380.0 + rand(i * 3) * 420.0)
        let gravity = 900.0
        let x = Double(size.width) * 0.5 + vx * age
        let y = Double(size.height) * 0.40 + vy * age + 0.5 * gravity * age * age
        let spin = (rand(i * 11) - 0.5) * 14.0
        let fade = age > life - 0.6 ? (life - age) / 0.6 : 1.0
        let wobble = 0.5 + 0.5 * abs(sin(age * 8.0 + Double(i)))   // flutter

        var c = ctx
        c.translateBy(x: x, y: y)
        c.rotate(by: .radians(spin * age))
        c.scaleBy(x: wobble, y: 1)
        let rect = CGRect(x: -4.5, y: -7, width: 9, height: 14)
        let color = colors[i % colors.count]
        if i % 3 == 0 {
            c.fill(Path(ellipseIn: CGRect(x: -5, y: -5, width: 10, height: 10)), with: .color(color.opacity(fade)))
        } else {
            c.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color.opacity(fade)))
        }
    }
}

/// The habit's emoji falls into Blobby from above, then calls `onLand`.
struct FallingEmoji: View {
    let emoji: String
    let onLand: () -> Void
    @State private var fallen = false

    var body: some View {
        Text(emoji)
            .font(.system(size: 46))
            .rotationEffect(.degrees(fallen ? 0 : -25))
            .offset(y: fallen ? -40 : -300)
            .onAppear {
                withAnimation(.easeIn(duration: 0.42)) { fallen = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { onLand() }
            }
    }
}

/// "+250 ml" text that floats up and fades.
struct FloatingLabel: View {
    let text: String
    let color: Color
    @State private var up = false

    var body: some View {
        Text(text)
            .font(.cartoon(26))
            .foregroundStyle(color)
            .shadow(color: .white, radius: 0, x: 2, y: 2)
            .offset(x: 70, y: up ? -190 : -110)
            .opacity(up ? 0 : 1)
            .scaleEffect(up ? 1.2 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) { up = true }
            }
    }
}

/// Soft floating circles behind screens.
struct BackgroundBubbles: View {
    var color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    ForEach(0..<6, id: \.self) { i in
                        let d = CGFloat(60 + rand(i * 13) * 140)
                        let x = CGFloat(rand(i * 17)) * geo.size.width
                        let y = CGFloat(rand(i * 19)) * geo.size.height + CGFloat(sin(t * 0.4 + Double(i))) * 18
                        Circle()
                            .fill(color.opacity(0.10 + rand(i) * 0.08))
                            .frame(width: d, height: d)
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
