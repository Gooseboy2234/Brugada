import Foundation

/// Central observable store: polls the agent on an interval and republishes
/// Rig / Campaign / Job / Alert state. Also raises local notifications when a
/// new alert appears (job done, job failed, thermal, budget) — rare and
/// meaningful, never "FYI util is high".
@MainActor
final class BenchTopStore: ObservableObject {
    @Published private(set) var rigs: [Rig] = []
    @Published private(set) var campaigns: [Campaign] = []
    @Published private(set) var jobs: [Job] = []
    @Published private(set) var alerts: [Alert] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    private let config: AgentConfig
    private let notifications: NotificationManaging
    private var knownAlertIDs: Set<String> = []
    private var seededAlertBaseline = false
    private var pollTask: Task<Void, Never>?

    init(config: AgentConfig, notifications: NotificationManaging = NotificationManager()) {
        self.config = config
        self.notifications = notifications
    }

    func startPolling(interval: TimeInterval = 5) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    @discardableResult
    func refresh() async -> Bool {
        let client = AgentClient(config: config)
        do {
            async let rigsFetch = client.fetchRigs()
            async let campaignsFetch = client.fetchCampaigns()
            async let jobsFetch = client.fetchJobs()
            async let alertsFetch = client.fetchAlerts()
            let (newRigs, newCampaigns, newJobs, newAlerts) =
                try await (rigsFetch, campaignsFetch, jobsFetch, alertsFetch)

            noticeNewAlerts(newAlerts)

            rigs = newRigs
            campaigns = newCampaigns
            jobs = newJobs
            alerts = newAlerts
            lastError = nil
            lastUpdated = Date()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Lookups

    func campaigns(on rig: Rig) -> [Campaign] { campaigns.filter { $0.rigID == rig.id } }
    func alerts(on rig: Rig) -> [Alert] { alerts.filter { $0.rigID == rig.id } }
    func rig(id: String) -> Rig? { rigs.first { $0.id == id } }
    func campaign(id: String) -> Campaign? { campaigns.first { $0.id == id } }
    func jobs(in campaign: Campaign) -> [Job] { jobs.filter { $0.campaignID == campaign.id } }

    /// The campaign a rig is actively working, else its first campaign.
    func activeCampaign(on rig: Rig) -> Campaign? {
        let mine = campaigns(on: rig)
        return mine.first { $0.percentComplete ?? 0 < 1 && !jobsRunning(in: $0).isEmpty } ?? mine.first
    }

    func jobsRunning(in campaign: Campaign) -> [Job] {
        jobs(in: campaign).filter { $0.status == .running }
    }

    /// Best ETA across a campaign's running jobs (the batch finishes when its
    /// slowest live job does).
    func batchETA(for campaign: Campaign) -> (remaining: TimeInterval, windowMinutes: Int?)? {
        jobsRunning(in: campaign).compactMap(\.eta).max { $0.remaining < $1.remaining }
    }

    func seed(rigs: [Rig] = [], campaigns: [Campaign] = [], jobs: [Job] = [], alerts: [Alert] = []) {
        self.rigs = rigs
        self.campaigns = campaigns
        self.jobs = jobs
        self.alerts = alerts
    }

    private func noticeNewAlerts(_ newAlerts: [Alert]) {
        // The first successful poll establishes a baseline so we don't fire a
        // notification for every already-standing alert on launch.
        defer {
            knownAlertIDs = Set(newAlerts.map(\.id))
            seededAlertBaseline = true
        }
        guard seededAlertBaseline else { return }
        for alert in newAlerts where !knownAlertIDs.contains(alert.id) {
            notifications.notify(title: alert.title, body: alert.detail ?? "")
        }
    }
}
