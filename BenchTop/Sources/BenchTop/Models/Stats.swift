import Foundation

/// Cumulative totals across all currently-known jobs — mirrors
/// agent/benchtop_agent/models.py:Stats. Grouped by whatever unit_label
/// each job reports (ns, molecules, ...) rather than hardcoding
/// pipeline-specific concepts.
struct Stats: Codable, Hashable {
    var totalGPUHours: Double
    var totalCostUSD: Double
    var budgetUSD: Double?
    var budgetCrossed: Bool
    var totalsByUnit: [String: Double]

    // Explicit, exact mapping to the agent's snake_case JSON keys — see
    // AgentClient's comment on why convertFromSnakeCase isn't used.
    private enum CodingKeys: String, CodingKey {
        case totalGPUHours = "total_gpu_hours"
        case totalCostUSD = "total_cost_usd"
        case budgetUSD = "budget_usd"
        case budgetCrossed = "budget_crossed"
        case totalsByUnit = "totals_by_unit"
    }

    var budgetFraction: Double? {
        guard let budgetUSD, budgetUSD > 0 else { return nil }
        return min(totalCostUSD / budgetUSD, 1)
    }
}
