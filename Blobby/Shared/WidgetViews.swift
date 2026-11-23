import SwiftUI
import WidgetKit
import AppIntents

/// Widget layouts. Shared by the widget extension and the in-app "Widget preview".
struct BlobbyWidgetView: View {
    let habits: [Habit]
    /// Pass a family explicitly in the in-app preview; the widget reads it from the environment.
    var family: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var envFamily

    private var size: WidgetFamily { family ?? envFamily }

    /// Unfinished habits first, so the widget shows what still needs doing.
    private var ordered: [Habit] {
        habits.filter { !$0.isDone() } + habits.filter { $0.isDone() }
    }

    var body: some View {
        if habits.isEmpty {
            empty
        } else {
            switch size {
            case .systemMedium: medium
            case .systemLarge: large
            default: small
            }
        }
    }

    // MARK: Small: one buddy

    private var small: some View {
        let h = ordered[0]
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 0) {
                mascot(h, size: 74)
                    .padding(.top, 8)
                Spacer(minLength: 0)
                logButton(h, diameter: 34)
            }
            Spacer(minLength: 0)
            Text(h.name)
                .font(.cartoon(15))
                .foregroundStyle(Ink.color)
                .lineLimit(1)
            Text("\(h.amount().clean) / \(h.goal.clean) \(h.unit)")
                .font(.cartoon(11, .semibold))
                .foregroundStyle(Ink.color.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ProgressPill(progress: h.progress(), color: h.color, height: 8)
                .padding(.top, 3)
        }
    }

    // MARK: Medium: three buddies side by side

    private var medium: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(ordered.prefix(3))) { h in
                VStack(spacing: 3) {
                    ZStack(alignment: .topTrailing) {
                        mascot(h, size: 58)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                        logButton(h, diameter: 26)
                    }
                    Text(h.name)
                        .font(.cartoon(12))
                        .foregroundStyle(Ink.color)
                        .lineLimit(1)
                    Text("\(h.amount().clean)/\(h.goal.clean)")
                        .font(.cartoon(10, .semibold))
                        .foregroundStyle(Ink.color.opacity(0.6))
                        .lineLimit(1)
                    ProgressPill(progress: h.progress(), color: h.color, height: 6)
                }
                .frame(maxWidth: .infinity)
            }
            if habits.count < 3 {
                ForEach(0..<(3 - habits.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Large: header + up to five rows

    private var large: some View {
        let done = habits.filter { $0.isDone() }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today")
                    .font(.cartoon(22))
                    .foregroundStyle(Ink.color)
                Spacer()
                Text("\(done) of \(habits.count) done")
                    .font(.cartoon(12, .bold))
                    .foregroundStyle(Ink.color.opacity(0.6))
            }
            ForEach(Array(ordered.prefix(5))) { h in
                HStack(spacing: 10) {
                    mascot(h, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(h.name)
                                .font(.cartoon(14))
                                .foregroundStyle(Ink.color)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(h.amount().clean) / \(h.goal.clean) \(h.unit)")
                                .font(.cartoon(10, .semibold))
                                .foregroundStyle(Ink.color.opacity(0.55))
                                .lineLimit(1)
                        }
                        ProgressPill(progress: h.progress(), color: h.color, height: 7)
                    }
                    logButton(h, diameter: 30)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            BlobMascot(progress: 0.3, color: .ocean, kind: .drop, size: 64, animated: false)
            Text("Add a habit in Blobby")
                .font(.cartoon(13, .bold))
                .foregroundStyle(Ink.color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Parts

    private func mascot(_ h: Habit, size: CGFloat) -> some View {
        BlobMascot(progress: h.progress(), color: h.color, kind: h.kind, size: size,
                   sticker: h.emoji, accessories: h.unlocked, animated: false)
    }

    private func logButton(_ h: Habit, diameter: CGFloat) -> some View {
        Button(intent: LogHabitIntent(habitID: h.id)) {
            Image(systemName: h.isDone() ? "checkmark" : "plus")
                .font(.system(size: diameter * 0.42, weight: .black))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(h.isDone() ? h.color.deep : h.color.main))
                .overlay(Circle().stroke(Ink.color, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log \(h.step.clean) \(h.unitLabel(for: h.step)) of \(h.name)")
    }
}

/// In-app gallery showing all three widget sizes with the real habits (Settings → Widget preview).
struct WidgetPreviewGallery: View {
    let habits: [Habit]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                frame(.systemSmall, width: 170, height: 170)
                frame(.systemMedium, width: 360, height: 170)
                frame(.systemLarge, width: 360, height: 376)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
    }

    private func frame(_ family: WidgetFamily, width: CGFloat, height: CGFloat) -> some View {
        BlobbyWidgetView(habits: habits, family: family)
            .padding(16)
            .frame(width: width, height: height)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Paper.color))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Ink.color.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
