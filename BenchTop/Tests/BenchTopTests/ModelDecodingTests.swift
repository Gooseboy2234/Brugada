import XCTest
@testable import BenchTop

final class ModelDecodingTests: XCTestCase {
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func testDecodeGPUStatus() throws {
        let json = """
        {
          "id": "gpu-0",
          "index": 0,
          "name": "NVIDIA GeForce RTX 4060 Ti",
          "utilization_percent": 87,
          "memory_used_mb": 9200,
          "memory_total_mb": 16384,
          "temperature_c": 68,
          "power_watts": 145,
          "current_job_id": "job-42"
        }
        """.data(using: .utf8)!

        let gpu = try makeDecoder().decode(GPUStatus.self, from: json)
        XCTAssertEqual(gpu.id, "gpu-0")
        XCTAssertEqual(gpu.currentJobID, "job-42")
        XCTAssertEqual(gpu.memoryUsedFraction, 9200.0 / 16384.0, accuracy: 0.0001)
    }

    func testDecodeJobAndDerivedProgress() throws {
        let json = """
        {
          "id": "job-42",
          "campaign_id": "campaign-r104q",
          "name": "R104Q NTD pocket MD",
          "kind": "md_simulation",
          "gpu_id": "gpu-0",
          "status": "running",
          "stage": "Production run",
          "units_done": 63,
          "units_total": 200,
          "unit_label": "ns",
          "throughput_per_hour": 22.5,
          "started_at": "2026-06-30T12:00:00Z",
          "last_checkpoint_at": "2026-07-02T08:00:00Z",
          "error_message": null
        }
        """.data(using: .utf8)!

        let job = try makeDecoder().decode(Job.self, from: json)
        XCTAssertEqual(job.kind, .mdSimulation)
        XCTAssertEqual(job.status, .running)
        XCTAssertEqual(job.fractionDone ?? 0, 63.0 / 200.0, accuracy: 0.0001)

        let remainingUnits = 200.0 - 63.0
        let expectedSeconds = (remainingUnits / 22.5) * 3600
        XCTAssertEqual(job.estimatedTimeRemaining ?? 0, expectedSeconds, accuracy: 1)
    }

    func testUnknownJobKindAndStatusFallBackGracefully() throws {
        let json = """
        {
          "id": "job-1",
          "campaign_id": "campaign-x",
          "name": "Mystery job",
          "kind": "quantum_annealing",
          "status": "vibing",
          "stage": "?",
          "units_done": 0,
          "unit_label": "steps",
          "started_at": "2026-06-30T12:00:00Z",
          "last_checkpoint_at": "2026-06-30T12:00:00Z"
        }
        """.data(using: .utf8)!

        let job = try makeDecoder().decode(Job.self, from: json)
        XCTAssertEqual(job.kind, .other)
        XCTAssertEqual(job.status, .unknown)
        XCTAssertNil(job.fractionDone)
        XCTAssertNil(job.estimatedTimeRemaining)
    }

    func testDecodeCampaignFunnel() throws {
        let json = """
        {
          "id": "campaign-r104q",
          "name": "SCN5A-R104Q",
          "target": "SCN5A R104Q NTD pocket",
          "funnel": [
            {"name": "Enamine slice screened", "count": 1200000},
            {"name": "Passed MD triage", "count": 4800},
            {"name": "Shortlisted", "count": 5}
          ]
        }
        """.data(using: .utf8)!

        let campaign = try makeDecoder().decode(Campaign.self, from: json)
        XCTAssertEqual(campaign.startCount, 1_200_000)
        XCTAssertEqual(campaign.latestCount, 5)
    }
}
