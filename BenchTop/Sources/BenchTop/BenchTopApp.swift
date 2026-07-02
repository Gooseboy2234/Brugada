import SwiftUI

@main
struct BenchTopApp: App {
    @StateObject private var config: AgentConfig
    @StateObject private var store: BenchTopStore
    private let notifications = NotificationManager()

    init() {
        let config = AgentConfig()
        _config = StateObject(wrappedValue: config)
        _store = StateObject(wrappedValue: BenchTopStore(config: config))
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(config)
                .environmentObject(store)
                .task {
                    notifications.requestAuthorization()
                    store.startPolling()
                }
        }
    }
}
