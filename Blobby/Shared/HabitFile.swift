import Foundation
import WidgetKit

/// Where habits are stored on disk. Shared by the app and the Home-screen widget.
///
/// The widget can only see the app's data through an **App Group** container.
/// If the App Group isn't available (e.g. the sideloading tool didn't keep the
/// entitlement), we fall back to the app's own Documents folder: the app keeps
/// working, only the widget can't see the habits. Settings shows which mode is active.
enum HabitFile {
    /// The group we asked for in our entitlements.
    static let requestedGroup = "group.com.futureautomate.blobby"

    /// The group we're actually allowed to use: whatever the embedded provisioning profile
    /// lists (sideloading tools may rename it), falling back to the requested one.
    static let appGroup: String = {
        let groups = ProvisioningInfo.current?.appGroups ?? []
        return groups.first(where: { $0.contains("blobby") }) ?? groups.first ?? requestedGroup
    }()
    private static let fileName = "habits.json"

    static var sharedURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    static var localURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    /// True when the App Group works, i.e. the widget can read the habits.
    static var isShared: Bool { sharedURL != nil }

    static var url: URL { sharedURL ?? localURL }

    static func load() -> [Habit] {
        migrateIfNeeded()
        guard let data = try? Data(contentsOf: url),
              let habits = try? JSONDecoder().decode([Habit].self, from: data) else { return [] }
        return habits
    }

    static func save(_ habits: [Habit]) {
        guard let data = try? JSONEncoder().encode(habits) else { return }
        try? data.write(to: url, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// v0.5 and earlier saved into Documents. Copy that file into the shared container once.
    private static func migrateIfNeeded() {
        guard let shared = sharedURL else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: shared.path), fm.fileExists(atPath: localURL.path) {
            try? fm.copyItem(at: localURL, to: shared)
        }
    }
}
