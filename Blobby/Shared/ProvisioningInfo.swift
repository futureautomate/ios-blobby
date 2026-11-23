import Foundation

/// Reads the provisioning profile that the signing tool (Sideloadly) embedded in this bundle.
/// Used to discover the App Group we're *actually* allowed to use — sideloading tools may
/// rename or drop it when they re-sign with a free Apple ID.
enum ProvisioningInfo {
    struct Profile {
        let name: String
        let teamID: String
        let appGroups: [String]
        let appID: String
    }

    /// nil on the simulator (no embedded profile) or if it can't be parsed.
    static let current: Profile? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }

        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = (try? PropertyListSerialization.propertyList(from: plistData, format: nil)) as? [String: Any]
        else { return nil }

        let ent = plist["Entitlements"] as? [String: Any] ?? [:]
        return Profile(
            name: plist["Name"] as? String ?? "?",
            teamID: (plist["TeamIdentifier"] as? [String])?.first ?? "?",
            appGroups: ent["com.apple.security.application-groups"] as? [String] ?? [],
            appID: ent["application-identifier"] as? String ?? "?"
        )
    }()

    /// One-paragraph report for Settings (lets us debug sideloading without a Mac).
    static var report: String {
        guard let p = current else { return "No provisioning profile (simulator build)." }
        let groups = p.appGroups.isEmpty ? "none" : p.appGroups.joined(separator: ", ")
        return "App ID: \(p.appID)\nTeam: \(p.teamID)\nApp Groups in profile: \(groups)\nGroup in use: \(HabitFile.appGroup)\nShared container: \(HabitFile.isShared ? "OK" : "not available")"
    }
}
