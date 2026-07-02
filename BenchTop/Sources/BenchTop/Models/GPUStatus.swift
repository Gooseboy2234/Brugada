import Foundation

/// A snapshot of one GPU on the rig, as reported by the BenchTop agent.
struct GPUStatus: Identifiable, Codable, Hashable {
    var id: String
    var index: Int
    var name: String
    var utilizationPercent: Double
    var memoryUsedMB: Double
    var memoryTotalMB: Double
    var temperatureC: Double
    var powerWatts: Double
    var currentJobID: String?

    var memoryUsedFraction: Double {
        guard memoryTotalMB > 0 else { return 0 }
        return memoryUsedMB / memoryTotalMB
    }

    // Explicit, exact mapping to the agent's snake_case JSON keys — see
    // AgentClient's comment on why convertFromSnakeCase isn't used.
    private enum CodingKeys: String, CodingKey {
        case id, index, name
        case utilizationPercent = "utilization_percent"
        case memoryUsedMB = "memory_used_mb"
        case memoryTotalMB = "memory_total_mb"
        case temperatureC = "temperature_c"
        case powerWatts = "power_watts"
        case currentJobID = "current_job_id"
    }
}
