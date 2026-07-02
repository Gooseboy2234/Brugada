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
}
