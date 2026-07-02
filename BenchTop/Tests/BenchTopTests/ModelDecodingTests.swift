import XCTest
@testable import BenchTop

/// These decode the exact JSON the agent emits (see agent/tests/test_api.py),
/// through the same decoder the app uses — so they fail if the wire contract
/// or the CodingKeys ever drift apart.
final class ModelDecodingTests: XCTestCase {
    private func makeDecoder() -> JSONDecoder { AgentClient.makeDecoder() }

    func testDecodeRigHonestCost() throws {
        let json = """
        {
          "id": "home", "name": "Home Rig", "gpu_model": "RTX 4060 Ti 16 GB",
          "vram_gb": 16, "vram_used_gb": 11.2, "temp_c": 61, "util_percent": 94, "power_w": 168,
          "dollars_per_hour": 0, "is_cloud": false, "uptime_hours": 34.5,
          "cost_this_week": 0, "energy_kwh_this_week": 5.8, "budget_usd": null
        }
        """.data(using: .utf8)!
        let rig = try makeDecoder().decode(Rig.self, from: json)
        XCTAssertEqual(rig.gpuModel, "RTX 4060 Ti 16 GB")
        XCTAssertFalse(rig.isCloud)
        XCTAssertNil(rig.budgetUSD)
        XCTAssertTrue(rig.spendSummary.contains("home = free"))
        XCTAssertNil(rig.budgetFraction)
    }

    func testDecodeCloudRigBudgetFraction() throws {
        let json = """
        {
          "id": "modal", "name": "Modal L4", "gpu_model": "NVIDIA L4 24 GB",
          "vram_gb": 24, "vram_used_gb": 0.4, "temp_c": 33, "util_percent": 0, "power_w": 28,
          "dollars_per_hour": 0.8, "is_cloud": true, "uptime_hours": 0,
          "cost_this_week": 25, "energy_kwh_this_week": 0, "budget_usd": 30
        }
        """.data(using: .utf8)!
        let rig = try makeDecoder().decode(Rig.self, from: json)
        XCTAssertTrue(rig.isCloud)
        XCTAssertEqual(rig.budgetFraction ?? 0, 25.0 / 30.0, accuracy: 0.001)
        XCTAssertTrue(rig.spendSummary.contains("$25"))
    }

    func testDecodeCampaignWithFunnelWallAndLiveResult() throws {
        let json = """
        {
          "id": "r104q-replicates", "rig_id": "home", "title": "R104Q · MD replicates",
          "hypothesis": "R104Q destabilizes the NTD core; D84N rescues it.",
          "funnel": [
            {"index": 4, "label": "Flagship MD (n=1)", "status": "done", "detail": "mechanism"},
            {"index": 5, "label": "MD replicates (n=3)", "status": "active", "caveat": "signal vs noise"},
            {"index": 8, "label": "SIMULATION WALL", "status": "upcoming", "is_wall": true, "caveat": "nothing below is GPU-knowable"}
          ],
          "live_result": {
            "metric_label": "core RMSF (res 55–85)", "unit": "Å",
            "series": [
              {"name": "WT", "value": 3.9, "unit": "Å", "note": "n=1", "sparkline": [3.6, 3.9]},
              {"name": "R104Q", "value": 5.4, "unit": "Å", "note": "+37% vs WT", "sparkline": [4.6, 5.4]},
              {"name": "rescued", "value": 3.1, "unit": "Å", "note": "most rigid", "sparkline": [3.2, 3.1]}
            ]
          },
          "so_what": "±error bars pending — need all 3 seeds.",
          "percent_complete": 0.58
        }
        """.data(using: .utf8)!
        let campaign = try makeDecoder().decode(Campaign.self, from: json)
        XCTAssertEqual(campaign.hypothesis.hasPrefix("R104Q"), true)
        XCTAssertEqual(campaign.activeStage?.label, "MD replicates (n=3)")
        XCTAssertTrue(campaign.funnel.contains { $0.isWall })
        XCTAssertEqual(campaign.liveResult?.series.map(\.name), ["WT", "R104Q", "rescued"])
        XCTAssertEqual(campaign.percentComplete ?? 0, 0.58, accuracy: 0.001)
    }

    func testDecodeMDJobMetricAndETA() throws {
        let json = """
        {
          "id": "wt-s2", "campaign_id": "r104q-replicates", "tag": "WT · seed 2", "kind": "md",
          "status": "running", "units_done": 72, "units_total": 100, "unit_label": "ns",
          "rate_per_day": 611, "rate_window_minutes": 20, "cost_so_far": 0,
          "metric": {"label": "R104–D84 min distance", "value": 3.1, "unit": "Å",
                     "note": "58% occupancy <4 Å", "sparkline": [3.4, 3.0, 3.1]},
          "temp_spark": [60, 61], "util_spark": [95, 94],
          "log_tail": ["salt-bridge 3.1 Å", "wrote frame 720"]
        }
        """.data(using: .utf8)!
        let job = try makeDecoder().decode(Job.self, from: json)
        XCTAssertEqual(job.kind, .md)
        XCTAssertEqual(job.fractionDone ?? 0, 0.72, accuracy: 0.001)
        XCTAssertEqual(job.metric?.note, "58% occupancy <4 Å")
        XCTAssertEqual(job.logTail.count, 2)

        let eta = try XCTUnwrap(job.eta)
        // 28 ns left at 611 ns/day ≈ 0.0458 day ≈ 3,958 s.
        XCTAssertEqual(eta.remaining, 28.0 / 611.0 * 86_400, accuracy: 1)
        XCTAssertEqual(eta.windowMinutes, 20)
    }

    func testUnknownEnumsFallBackGracefully() throws {
        let json = """
        {
          "id": "x", "campaign_id": "c", "tag": "t", "kind": "quantum", "status": "vibing",
          "units_done": 0, "unit_label": "ns"
        }
        """.data(using: .utf8)!
        let job = try makeDecoder().decode(Job.self, from: json)
        XCTAssertEqual(job.kind, .other)
        XCTAssertEqual(job.status, .unknown)
        XCTAssertNil(job.metric)
        XCTAssertTrue(job.logTail.isEmpty)
    }

    func testDecodeAlert() throws {
        let json = """
        [{"id": "fail-mut-s3", "kind": "job_failed", "severity": "critical",
          "title": "R104Q · seed 3 failed", "detail": "CUDA OOM at 8 ns", "rig_id": "home"}]
        """.data(using: .utf8)!
        let alerts = try makeDecoder().decode([Alert].self, from: json)
        XCTAssertEqual(alerts.first?.kind, .jobFailed)
        XCTAssertEqual(alerts.first?.severity, .critical)
        XCTAssertEqual(alerts.first?.rigID, "home")
    }
}
