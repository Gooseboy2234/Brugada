import Foundation

/// Central observable store: polls the agent on an interval and republishes
/// its state for the views. Also the place that notices state transitions
/// (job finished, job failed) and asks NotificationManager to alert on them.
@MainActor
final class BenchTopStore: ObservableObject {
    @Published private(set) var gpus: [GPUStatus] = []
    @Published private(set) var jobs: [Job] = []
    @Published private(set) var campaigns: [Campaign] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    private let config: AgentConfig
    private let notifications: NotificationManaging
    private var previousJobStatus: [String: JobStatus] = [:]
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

    func refresh() async {
        let client = AgentClient(config: config)
        do {
            async let gpusFetch = client.fetchGPUs()
            async let jobsFetch = client.fetchJobs()
            async let campaignsFetch = client.fetchCampaigns()
            let (newGPUs, newJobs, newCampaigns) = try await (gpusFetch, jobsFetch, campaignsFetch)

            noticeTransitions(from: newJobs)

            gpus = newGPUs
            jobs = newJobs
            campaigns = newCampaigns
            lastError = nil
            lastUpdated = Date()
        } catch {
            lastError = error.localizedDescription
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

    private func noticeTransitions(from newJobs: [Job]) {
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
}
