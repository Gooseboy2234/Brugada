import SwiftUI

@main
struct BenchTopApp: App {
    @StateObject private var config: AgentConfig
    @StateObject private var store: BenchTopStore
    private let notifications = NotificationManager()

    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #endif

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
                    #if os(iOS)
                    BackgroundRefresh.scheduleNext()
                    #endif
                }
                #if os(iOS)
                .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) {
                    await BackgroundRefresh.handle(store: store)
                }
                #endif
        }
        #if os(macOS)
        MenuBarExtra("BenchTop", systemImage: "cpu") {
            MenuBarSummaryView()
                .environmentObject(config)
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
