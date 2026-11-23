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

// MARK: - Character shapes

/// Helper: point in unit coordinates of `r`.
private func pt(_ r: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
}

/// Water droplet that sways slightly.
struct DropShape: Shape {
    var phase: Double

    func path(in rect: CGRect) -> Path {
        let s = CGFloat(sin(phase)) * 0.025
        // Squash/stretch around the bottom centre.
        let r = CGRect(x: rect.minX + rect.width * s / 2, y: rect.minY - rect.height * s,
                       width: rect.width * (1 - s), height: rect.height * (1 + s))
        var p = Path()
        p.move(to: pt(r, 0.5 + s, 0.03))
        p.addCurve(to: pt(r, 0.88, 0.62), control1: pt(r, 0.58, 0.20), control2: pt(r, 0.88, 0.40))
        p.addCurve(to: pt(r, 0.5, 0.97), control1: pt(r, 0.88, 0.82), control2: pt(r, 0.72, 0.97))
        p.addCurve(to: pt(r, 0.12, 0.62), control1: pt(r, 0.28, 0.97), control2: pt(r, 0.12, 0.82))
        p.addCurve(to: pt(r, 0.5 + s, 0.03), control1: pt(r, 0.12, 0.40), control2: pt(r, 0.42, 0.20))
        p.closeSubpath()
        return p
    }
}

/// Apple body (two lobes on top).
struct AppleShape: Shape {
    var phase: Double

    func path(in rect: CGRect) -> Path {
        let w = CGFloat(sin(phase)) * 0.015
        var p = Path()
        p.move(to: pt(rect, 0.5, 0.24))
        p.addCurve(to: pt(rect, 0.94 + w, 0.47), control1: pt(rect, 0.62, 0.10), control2: pt(rect, 0.94 + w, 0.13))
        p.addCurve(to: pt(rect, 0.5, 0.97), control1: pt(rect, 0.94 + w, 0.80), control2: pt(rect, 0.70, 0.99))
        p.addCurve(to: pt(rect, 0.06 - w, 0.47), control1: pt(rect, 0.30, 0.99), control2: pt(rect, 0.06 - w, 0.80))
        p.addCurve(to: pt(rect, 0.5, 0.24), control1: pt(rect, 0.06 - w, 0.13), control2: pt(rect, 0.38, 0.10))
        p.closeSubpath()
        return p
    }
}

/// Flickering flame.
struct FlameShape: Shape {
    var phase: Double

    func path(in rect: CGRect) -> Path {
        let f = CGFloat(sin(phase))
        let g = CGFloat(sin(phase * 1.7 + 1.0))
        var p = Path()
        p.move(to: pt(rect, 0.5, 1.0))
        p.addCurve(to: pt(rect, 0.95, 0.62), control1: pt(rect, 0.80, 1.0), control2: pt(rect, 0.97, 0.84))
        p.addCurve(to: pt(rect, 0.5 + 0.09 * f, 0.0), control1: pt(rect, 0.93 + 0.03 * g, 0.40), control2: pt(rect, 0.64 + 0.05 * f, 0.18))
        p.addCurve(to: pt(rect, 0.05, 0.62), control1: pt(rect, 0.38 + 0.05 * f, 0.22), control2: pt(rect, 0.07 - 0.03 * g, 0.42))
        p.addCurve(to: pt(rect, 0.5, 1.0), control1: pt(rect, 0.03, 0.84), control2: pt(rect, 0.20, 1.0))
        p.closeSubpath()
        return p
    }
}

/// Flower pot: rim on top, tapered body.
struct PotShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let rimH = rect.height * 0.24
        p.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rimH),
                         cornerSize: CGSize(width: rimH * 0.35, height: rimH * 0.35))
        p.move(to: pt(rect, 0.08, 0.24))
        p.addLine(to: pt(rect, 0.92, 0.24))
        p.addLine(to: pt(rect, 0.80, 0.94))
        p.addQuadCurve(to: pt(rect, 0.74, 1.0), control: pt(rect, 0.79, 1.0))
        p.addLine(to: pt(rect, 0.26, 1.0))
        p.addQuadCurve(to: pt(rect, 0.20, 0.94), control: pt(rect, 0.21, 1.0))
        p.closeSubpath()
        return p
    }
}

/// Leaf: pointed ellipse.
struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0, 0.5))
        p.addQuadCurve(to: pt(rect, 1, 0.5), control: pt(rect, 0.5, -0.35))
        p.addQuadCurve(to: pt(rect, 0, 0.5), control: pt(rect, 0.5, 1.35))
        p.closeSubpath()
        return p
    }
}
