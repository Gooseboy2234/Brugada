#if os(iOS)
import BackgroundTasks
import Foundation

/// Best-effort background polling so a job finishing or failing can raise a
/// notification even when the app isn't open. "Best effort" is doing real
/// work in that sentence: iOS decides if/when BGAppRefreshTask actually
/// runs based on usage patterns, battery, and charging state, and in
/// practice that can mean anywhere from ~15 minutes to several hours later,
/// or not at all if the app is rarely opened. There's no way around that
/// without a push-notification relay server, which the whole point of this
/// app's local-network-only design was to avoid. This is the honest ceiling
/// on "push alerts" for v0 — see docs/BENCHTOP_SPEC.md.
enum BackgroundRefresh {
    static let taskIdentifier = "com.benchtop.app.refresh"

    /// Requests iOS run another refresh no sooner than 15 minutes from now.
    /// Call once at launch and again at the end of each background refresh
    /// so there's always a next one queued.
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    static func handle(store: BenchTopStore) async {
        _ = await store.refresh()
        scheduleNext()
    }
}
#endif
