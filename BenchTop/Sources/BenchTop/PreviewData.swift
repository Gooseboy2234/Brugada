import Foundation

/// Sample data mirroring the agent's mock mode (the R104Q journey), for
/// SwiftUI previews.
enum PreviewData {
    static let homeRig = Rig(from: [
        "id": "home", "name": "Home Rig", "gpu_model": "RTX 4060 Ti 16 GB",
        "vram_gb": 16, "vram_used_gb": 11.2, "temp_c": 61, "util_percent": 94, "power_w": 168,
        "dollars_per_hour": 0, "is_cloud": false, "uptime_hours": 34.5,
        "cost_this_week": 0, "energy_kwh_this_week": 5.8, "budget_usd": nil,
    ])

    static let modalRig = Rig(from: [
        "id": "modal", "name": "Modal L4", "gpu_model": "NVIDIA L4 24 GB",
        "vram_gb": 24, "vram_used_gb": 0.4, "temp_c": 33, "util_percent": 0, "power_w": 28,
        "dollars_per_hour": 0.8, "is_cloud": true, "uptime_hours": 0,
        "cost_this_week": 25, "energy_kwh_this_week": 0, "budget_usd": 30,
    ])

    static let wtSeed2 = Job(
        id: "wt-s2", campaignID: "r104q-replicates", tag: "WT · seed 2", kind: .md, status: .running,
        unitsDone: 72, unitsTotal: 100, unitLabel: "ns", ratePerDay: 611, rateWindowMinutes: 20,
        metric: JobMetric(label: "R104–D84 min distance", value: 3.1, unit: "Å",
                          note: "58% occupancy <4 Å", sparkline: [3.4, 3.0, 3.6, 4.8, 3.1, 2.9, 3.2, 4.1, 3.0, 3.1]),
        tempSpark: [58, 59, 60, 60, 61, 61, 61], utilSpark: [95, 96, 94, 97, 96, 95, 94],
        logTail: ["step 3600000  pot -512843 kJ/mol", "salt-bridge R104–D84: 3.1 Å",
                  "wrote frame 720 (72.0 ns)", "ns/day 611.2  temp 61C  util 94%",
                  "checkpoint saved wt_seed2_72ns.chk"])

    static let mutSeed3Failed = Job(
        id: "mut-s3", campaignID: "r104q-replicates", tag: "R104Q · seed 3", kind: .md, status: .failed,
        unitsDone: 8, unitsTotal: 100, unitLabel: "ns",
        errorMessage: "CUDA OOM at 8 ns — reduce nonbonded cutoff or free VRAM")

    static let wtSeed1Done = Job(
        id: "wt-s1", campaignID: "r104q-replicates", tag: "WT · seed 1", kind: .md, status: .done,
        unitsDone: 100, unitsTotal: 100, unitLabel: "ns")

    static let campaign = Campaign(
        id: "r104q-replicates", rigID: "home", title: "R104Q · MD replicates",
        hypothesis: "R104Q destabilizes the NTD core; D84N rescues it.",
        funnel: [
            Stage(index: 1, label: "Structure & mechanism", status: .done, detail: "8VYJ · R104–D84 3.79 Å", caveat: "A crystal structure is a static snapshot."),
            Stage(index: 4, label: "Flagship MD (n=1)", status: .done, detail: "core RMSF 3.98 → 5.46 → 3.09 ✓", caveat: "A single replicate can be a lucky trajectory."),
            Stage(index: 5, label: "MD replicates (n=3)", status: .active, detail: "error bars — the current gap", caveat: "Where a real signal separates from noise."),
            Stage(index: 6, label: "FEP ΔΔG_fold", status: .upcoming, detail: "thermodynamic number", caveat: "Rigorous, but convergence must be checked."),
            Stage(index: 8, label: "SIMULATION WALL", status: .upcoming, isWall: true, caveat: "Everything above is what a GPU can tell you. Nothing below is."),
            Stage(index: 9, label: "Wet-lab: patch-clamp", status: .upcoming, caveat: "Only a wet lab can confirm function."),
        ],
        liveResult: LiveResult(metricLabel: "core RMSF (res 55–85)", unit: "Å", series: [
            ResultSeries(name: "WT", value: 3.9, unit: "Å", note: "n=1 so far", sparkline: [3.6, 3.7, 3.8, 3.9, 3.9]),
            ResultSeries(name: "R104Q", value: 5.4, unit: "Å", note: "+37% vs WT", sparkline: [4.6, 4.9, 5.2, 5.3, 5.4]),
            ResultSeries(name: "rescued", value: 3.1, unit: "Å", note: "most rigid", sparkline: [3.2, 3.1, 3.05, 3.1, 3.1]),
        ]),
        soWhat: "±error bars pending — need all 3 seeds.",
        percentComplete: 0.58)

    static let alerts = [
        Alert(id: "fail-mut-s3", kind: .jobFailed, severity: .critical, title: "R104Q · seed 3 failed", detail: "CUDA OOM at 8 ns", rigID: "home"),
        Alert(id: "budget-modal", kind: .budget, severity: .warning, title: "Modal L4 approaching cap", detail: "$25 of $30 — $5 left.", rigID: "modal"),
        Alert(id: "done-wt-s1", kind: .jobDone, severity: .good, title: "WT · seed 1 done", detail: "100 ns complete.", rigID: "home"),
    ]

    @MainActor
    static func store() -> BenchTopStore {
        let store = BenchTopStore(config: AgentConfig())
        store.seed(rigs: [homeRig, modalRig], campaigns: [campaign],
                   jobs: [wtSeed1Done, wtSeed2, mutSeed3Failed], alerts: alerts)
        return store
    }
}

/// Tiny helper so previews can build a `Rig` from a JSON-ish dictionary,
/// matching the agent's snake_case keys without a hand-written memberwise init.
extension Rig {
    init(from dict: [String: Any?]) {
        let data = try! JSONSerialization.data(withJSONObject: dict.compactMapValues { $0 })
        // `budget_usd: nil` is dropped by compactMapValues, which decodes as absent → nil. OK.
        self = try! AgentClient.makeDecoder().decode(Rig.self, from: data)
    }
}
