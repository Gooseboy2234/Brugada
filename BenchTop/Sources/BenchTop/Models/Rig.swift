import Foundation

/// One physical machine — a home GPU box or a cloud/Modal sandbox. Mirrors
/// agent/benchtop_agent/models.py:Rig. The honesty rule lives in `isCloud`:
/// cloud rigs show real dollars, home rigs show "free" + kWh.
struct Rig: Identifiable, Decodable, Hashable {
    var id: String
    var name: String
    var gpuModel: String
    var vramGB: Double
    var vramUsedGB: Double
    var tempC: Double
    var utilPercent: Double
    var powerW: Double
    var dollarsPerHour: Double
    var isCloud: Bool
    var uptimeHours: Double
    var costThisWeek: Double
    var energyKWhThisWeek: Double
    var budgetUSD: Double?

    var vramUsedFraction: Double { vramGB > 0 ? vramUsedGB / vramGB : 0 }

    /// The honest spend line: cloud rigs cost money, home rigs never do.
    var spendSummary: String {
        if isCloud {
            let spent = costThisWeek.formatted(.currency(code: "USD"))
            if let budget = budgetUSD {
                return "\(spent) / \(budget.formatted(.currency(code: "USD")))"
            }
            return spent
        }
        return "$0.00 · home = free (\(energyKWhThisWeek.formatted(.number.precision(.fractionLength(1)))) kWh)"
    }

    var budgetFraction: Double? {
        guard isCloud, let budget = budgetUSD, budget > 0 else { return nil }
        return min(costThisWeek / budget, 1)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
        case gpuModel = "gpu_model"
        case vramGB = "vram_gb"
        case vramUsedGB = "vram_used_gb"
        case tempC = "temp_c"
        case utilPercent = "util_percent"
        case powerW = "power_w"
        case dollarsPerHour = "dollars_per_hour"
        case isCloud = "is_cloud"
        case uptimeHours = "uptime_hours"
        case costThisWeek = "cost_this_week"
        case energyKWhThisWeek = "energy_kwh_this_week"
        case budgetUSD = "budget_usd"
    }
}
