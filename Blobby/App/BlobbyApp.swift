import SwiftUI
import UserNotifications

@main
struct BlobbyApp: App {
    @StateObject private var store = HabitStore(demo: LaunchOptions.demo)
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Must be set early so tapping a reminder on a cold start still reaches us.
        UNUserNotificationCenter.current().delegate = Reminders.shared
        // CI screenshots: a sample person for the "sample" demo, nobody for the "empty" demo.
        if let demo = LaunchOptions.demo {
            if demo == "sample" && !LaunchOptions.askName { Profile.save(name: "Tejas", kind: .blob, color: .grape) }
            else { Profile.save(name: "", kind: .blob, color: .ocean) }
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .overlay { UndoToast().environmentObject(store) }
                .alert(item: $store.earlyCheckIn) { early in
                    Alert(
                        title: Text("Bit early for \(early.name)?"),
                        message: Text("Check-ins for \(early.name) open at \(early.opens.formatted(date: .omitted, time: .shortened)). Only check in if you've really done it."),
                        primaryButton: .default(Text("Check in anyway")) { store.checkIn(early.habitID) },
                        secondaryButton: .cancel(Text("Not yet"))
                    )
                }
                .appAppearance()   // Auto / Light / Night (Settings)
                .onAppear { Reminders.shared.store = store }
        }
        .onChange(of: scenePhase) {
            // New day / habits done elsewhere: rebuild reminders whenever the app comes back.
            if scenePhase == .active && LaunchOptions.demo == nil {
                store.reloadFromDisk()          // the widget may have logged something
                Reminders.shared.reschedule(store.habits)
            }
        }
    }
}
