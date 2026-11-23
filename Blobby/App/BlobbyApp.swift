import SwiftUI

@main
struct BlobbyApp: App {
    @StateObject private var store = HabitStore(demo: LaunchOptions.demo)

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
        }
    }
}
