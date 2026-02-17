import SwiftUI

@main
struct GolfLaunchMonitorApp: App {
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .preferredColorScheme(.dark)
        }
    }
}
