import Foundation

enum JobKind: String, Codable, Hashable {
    case dockingScreen = "docking_screen"
    case mdSimulation = "md_simulation"
    case mlSurrogate = "ml_surrogate"
    case other

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = JobKind(rawValue: raw) ?? .other
    }
}

enum JobStatus: String, Codable, Hashable {
    case queued
    case running
    case completed
    case failed
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = JobStatus(rawValue: raw) ?? .unknown
    }
}

/// A single unit of work in a campaign (e.g. one docking screen, one MD
/// triage run), as reported by the BenchTop agent from a job's checkpoint
/// stream.
struct Job: Identifiable, Codable, Hashable {
    var id: String
    var campaignID: String
    var name: String
    var kind: JobKind
    var gpuID: String?
    var status: JobStatus
    var stage: String
    var unitsDone: Double
    var unitsTotal: Double?
    var unitLabel: String
    var throughputPerHour: Double?
    var startedAt: Date
    var lastCheckpointAt: Date
    var errorMessage: String?

    var fractionDone: Double? {
        guard let unitsTotal, unitsTotal > 0 else { return nil }
        return min(max(unitsDone / unitsTotal, 0), 1)
    }

    /// Estimated time remaining, derived from the last-reported throughput.
    var estimatedTimeRemaining: TimeInterval? {
        guard let unitsTotal, let throughputPerHour, throughputPerHour > 0 else { return nil }
        let remainingUnits = max(unitsTotal - unitsDone, 0)
        return (remainingUnits / throughputPerHour) * 3600
    }

    // Explicit, exact mapping to the agent's snake_case JSON keys — see
    // AgentClient's comment on why convertFromSnakeCase isn't used.
    private enum CodingKeys: String, CodingKey {
        case id
        case campaignID = "campaign_id"
        case name, kind
        case gpuID = "gpu_id"
        case status, stage
        case unitsDone = "units_done"
        case unitsTotal = "units_total"
        case unitLabel = "unit_label"
        case throughputPerHour = "throughput_per_hour"
        case startedAt = "started_at"
        case lastCheckpointAt = "last_checkpoint_at"
        case errorMessage = "error_message"
    }
}
