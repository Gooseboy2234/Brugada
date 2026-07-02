import SwiftUI

/// Top-level tabs, in the guide's priority order: Home (the glance) →
/// Funnel (how close to the finish line) → Alerts → Settings.
struct RootView: View {
    @EnvironmentObject private var store: BenchTopStore

    private var needsHand: Int {
        store.alerts.filter { $0.severity != .good }.count
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            FunnelView()
                .tabItem { Label("Funnel", systemImage: "arrow.triangle.merge") }

            AlertsView()
                .tabItem { Label("Alerts", systemImage: "bell") }
                .badge(needsHand)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.Palette.signal)
    }
}

#Preview {
    RootView()
        .environmentObject(PreviewData.store())
        .environmentObject(AgentConfig())
}
