import Foundation

/// Central observable store: polls the agent on an interval and republishes
/// its state for the views. Also the place that notices state transitions
/// (job finished, job failed, budget crossed) and asks NotificationManager
/// to alert on them.
@MainActor
final class BenchTopStore: ObservableObject {
    @Published private(set) var gpus: [GPUStatus] = []
    @Published private(set) var jobs: [Job] = []
    @Published private(set) var campaigns: [Campaign] = []
    @Published private(set) var stats: Stats?
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    private let config: AgentConfig
    private let notifications: NotificationManaging
    private var previousJobStatus: [String: JobStatus] = [:]
    private var previousBudgetCrossed: Bool?
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

    /// One refresh cycle: fetch everything, update published state, and
    /// raise any alerts warranted by what changed. Returns whether the
    /// refresh succeeded, so callers driving a background task (e.g. iOS
    /// BGTaskScheduler) can decide whether to report new data.
    @discardableResult
    func refresh() async -> Bool {
        let client = AgentClient(config: config)
        do {
            async let gpusFetch = client.fetchGPUs()
            async let jobsFetch = client.fetchJobs()
            async let campaignsFetch = client.fetchCampaigns()
            async let statsFetch = client.fetchStats()
            let (newGPUs, newJobs, newCampaigns, newStats) = try await (gpusFetch, jobsFetch, campaignsFetch, statsFetch)

            noticeJobTransitions(from: newJobs)
            noticeBudgetTransition(from: newStats)

            gpus = newGPUs
            jobs = newJobs
            campaigns = newCampaigns
            stats = newStats
            lastError = nil
            lastUpdated = Date()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func campaign(for job: Job) -> Campaign? {
        campaigns.first { $0.id == job.campaignID }
    }

    func jobs(in campaign: Campaign) -> [Job] {
        jobs.filter { $0.campaignID == campaign.id }
    }

    func job(runningOn gpu: GPUStatus) -> Job? {
        guard let jobID = gpu.currentJobID else { return nil }
        return jobs.first { $0.id == jobID }
    }

    /// Seeds state directly, bypassing the network — for SwiftUI previews
    /// and tests only.
    func seed(gpus: [GPUStatus] = [], jobs: [Job] = [], campaigns: [Campaign] = [], stats: Stats? = nil) {
        self.gpus = gpus
        self.jobs = jobs
        self.campaigns = campaigns
        self.stats = stats
    }

    private func noticeJobTransitions(from newJobs: [Job]) {
        for job in newJobs {
            let previous = previousJobStatus[job.id]
            previousJobStatus[job.id] = job.status

            guard let previous, previous != job.status else { continue }
            switch job.status {
            case .completed:
                notifications.notify(title: "Job complete", body: "\(job.name) finished.")
            case .failed:
                notifications.notify(
                    title: "Job failed",
                    body: job.errorMessage.map { "\(job.name): \($0)" } ?? "\(job.name) failed."
                )
            default:
                break
            }
        }
    }

    private func noticeBudgetTransition(from newStats: Stats) {
        defer { previousBudgetCrossed = newStats.budgetCrossed }

        guard let previous = previousBudgetCrossed else { return }
        guard !previous, newStats.budgetCrossed else { return }

        let costText = newStats.totalCostUSD.formatted(.currency(code: "USD"))
        notifications.notify(title: "Budget crossed", body: "Spend has reached \(costText).")
    }
}
