import SwiftUI

/// A jelly blob outline: a slightly flat-bottomed circle whose edge wobbles with `phase`.
struct BlobShape: Shape {
    var phase: Double
    var wobble: Double = 0.035

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY + rect.height * 0.04
        let rx = rect.width * 0.46
        let ry = rect.height * 0.44
        let n = 72
        var path = Path()
        for i in 0...n {
            let a = Double(i) / Double(n) * 2.0 * Double.pi
            let w = 1.0 + wobble * sin(a * 3.0 + phase) + wobble * 0.6 * sin(a * 2.0 - phase * 1.3)
            let s = sin(a)
            // Fuller, flatter bottom half (like a sitting jelly).
            let ys = s > 0 ? pow(s, 0.75) : s
            let x = cx + CGFloat(cos(a) * w) * rx
            let y = cy + CGFloat(ys * w) * ry
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

/// Liquid with a wavy surface. `level` 0...1 is animatable so the fill springs up.
struct LiquidWave: Shape {
    var level: Double
    var phase: Double
    var amplitude: CGFloat

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let lv = min(max(level, 0), 1)
        if lv <= 0.001 { return Path() }

        let top = rect.minY + rect.height * 0.08
        let bottom = rect.maxY - rect.height * 0.02
        let surface: CGFloat = lv >= 0.999
            ? rect.minY - amplitude * 2
            : bottom - (bottom - top) * CGFloat(lv)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let steps = 48
        for i in 0...steps {
            let rel = Double(i) / Double(steps)
            let x = rect.minX + rect.width * CGFloat(rel)
            let y = surface + amplitude * CGFloat(sin(rel * 2.0 * Double.pi * 1.5 + phase))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Smile curve. `curve` < 0 frowns, > 0 smiles.
struct MouthShape: Shape {
    var curve: Double

    var animatableData: Double {
        get { curve }
        set { curve = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let baseY = rect.minY + rect.height * 0.3
        p.move(to: CGPoint(x: rect.minX, y: baseY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: baseY),
            control: CGPoint(x: rect.midX, y: baseY + rect.height * 1.4 * CGFloat(curve))
        )
        return p
    }
}

/// Big open "D" mouth for when the goal is reached.
struct OpenMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.minY + rect.height * 0.1
        p.move(to: CGPoint(x: rect.minX, y: y))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: y),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.9)
        )
        p.closeSubpath()
        return p
    }
}
