import SwiftUI
import UniformTypeIdentifiers

/// "About you": a nickname and a buddy. Stored on this phone only (no account, nothing uploaded).
enum Profile {
    static let nameKey = "profileName"
    static let kindKey = "profileKind"
    static let colorKey = "profileColor"

    static var name: String {
        (UserDefaults.standard.string(forKey: nameKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static var kind: MascotKind {
        MascotKind(rawValue: UserDefaults.standard.string(forKey: kindKey) ?? "") ?? .blob
    }
    static var color: HabitColor {
        HabitColor(rawValue: UserDefaults.standard.integer(forKey: colorKey)) ?? .ocean
    }

    /// "Tejas's" / "Riya's" / "My"
    static func possessive(_ name: String = Profile.name) -> String {
        name.isEmpty ? "My" : "\(name)'s"
    }

    /// "Good evening, Tejas"
    static func greeting(_ name: String = Profile.name, at date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let hello: String
        switch hour {
        case 5..<12: hello = "Good morning"
        case 12..<17: hello = "Good afternoon"
        case 17..<22: hello = "Good evening"
        default: hello = "Hello, night owl"
        }
        return name.isEmpty ? hello : "\(hello), \(name)"
    }

    static func save(name: String, kind: MascotKind, color: HabitColor) {
        let d = UserDefaults.standard
        d.set(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: nameKey)
        d.set(kind.rawValue, forKey: kindKey)
        d.set(color.rawValue, forKey: colorKey)
    }
}

// MARK: - Form

/// Nickname field + buddy picker, shared by onboarding, the first-launch popup and Settings.
struct AboutYouForm: View {
    @Binding var name: String
    @Binding var kind: MascotKind
    @Binding var color: HabitColor
    var bump: Int = 0
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 14) {
            BlobMascot(progress: 0.65, color: color, kind: kind, size: 110, bump: bump)
            TextField("", text: $name, prompt: Text("Your name or nickname").foregroundStyle(Ink.text.opacity(0.35)))
                .font(.cartoon(20))
                .foregroundStyle(Ink.text)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .cartoonCard(radius: 18)
                .onChange(of: name) { if name.count > 20 { name = String(name.prefix(20)) } }

            Text("Your buddy")
                .font(.cartoon(14, .bold))
                .foregroundStyle(Ink.text.opacity(0.55))
            HStack(spacing: 6) {
                ForEach(MascotKind.allCases) { k in
                    let selected = kind == k
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { kind = k }
                        SoundFX.shared.play(.pop, pitch: k.popPitch)
                    } label: {
                        BlobMascot(progress: 0.6, color: color, kind: k, size: 40, animated: false)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .cartoonCard(radius: 14, fill: selected ? color.light : Card.color)
                            .scaleEffect(selected ? 1.06 : 1)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .accessibilityLabel(k.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            HStack(spacing: 12) {
                ForEach(HabitColor.allCases) { c in
                    let selected = color == c
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { color = c }
                    } label: {
                        Circle().fill(c.main)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(Ink.color, lineWidth: selected ? 3.5 : 2))
                            .scaleEffect(selected ? 1.15 : 1)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .accessibilityLabel("Colour \(c.rawValue + 1)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

/// Cartoon popup asking for the nickname. Used once for people who already had the app,
/// and from Settings (with Cancel) to change it.
struct AboutYouPopup: View {
    var onCancel: (() -> Void)? = nil
    let onSave: () -> Void

    @State private var name = Profile.name
    @State private var kind = Profile.kind
    @State private var color = Profile.color
    @State private var shown = false

    private var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            Ink.color.opacity(shown ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { onCancel?() }

            VStack(spacing: 14) {
                Text(onCancel == nil ? "What should Blobby call you?" : "About you")
                    .font(.cartoon(22))
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)
                AboutYouForm(name: $name, kind: $kind, color: $color)
                Text("Stays on this phone. No account needed.")
                    .font(.cartoon(12, .bold))
                    .foregroundStyle(Ink.text.opacity(0.45))
                HStack(spacing: 12) {
                    if let cancel = onCancel {
                        Button(action: cancel) {
                            Text("Cancel").font(.cartoon(18)).foregroundStyle(Ink.text)
                                .frame(maxWidth: .infinity).frame(height: 52)
                        }
                        .cartoonCard(radius: 18)
                        .buttonStyle(BouncyButtonStyle())
                    }
                    Button {
                        Profile.save(name: name, kind: kind, color: color)
                        SoundFX.shared.play(.chime)
                        onSave()
                    } label: {
                        Text("Save").font(.cartoon(18)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .cartoonCard(radius: 18, fill: valid ? color.main : .gray)
                    .buttonStyle(BouncyButtonStyle())
                    .disabled(!valid)
                }
            }
            .padding(20)
            .cartoonCard(radius: 30, fill: Paper.color)
            .padding(.horizontal, 20)
            .scaleEffect(shown ? 1 : 0.8)
            .opacity(shown ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { shown = true } }
    }
}

// MARK: - Backup

/// One JSON file with the profile and every habit (with full history).
struct Backup: Codable {
    var version = 1
    var exportedAt = Date()
    var name: String
    var kind: String
    var color: Int
    var habits: [Habit]

    static func current(_ habits: [Habit]) -> Backup {
        Backup(name: Profile.name, kind: Profile.kind.rawValue, color: Profile.color.rawValue, habits: habits)
    }

    func encoded() -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return (try? e.encode(self)) ?? Data()
    }

    /// Accepts a Blobby backup, or a bare habits list.
    static func decode(_ data: Data) -> Backup? {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        if let b = try? d.decode(Backup.self, from: data) { return b }
        if let habits = try? d.decode([Habit].self, from: data) {
            return Backup(name: Profile.name, kind: Profile.kind.rawValue, color: Profile.color.rawValue, habits: habits)
        }
        return nil
    }

    static var fileName: String {
        "Blobby backup \(Date().formatted(.iso8601.year().month().day()))"
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
