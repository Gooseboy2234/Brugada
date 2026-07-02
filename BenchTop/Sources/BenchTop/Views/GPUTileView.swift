import SwiftUI

struct GPUTileView: View {
    var gpu: GPUStatus
    var job: Job?

    private static let etaFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }()

    private var etaText: String {
        guard let remaining = job?.estimatedTimeRemaining else { return "ETA —" }
        return Self.etaFormatter.string(from: remaining).map { "ETA \($0)" } ?? "ETA —"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GPU \(gpu.index)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(gpu.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(alignment: .center, spacing: 16) {
                ProgressRing(fraction: job?.fractionDone, lineWidth: 6)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(job?.stage ?? "Idle")
                        .font(.callout)
                        .lineLimit(1)
                    Text(etaText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                statLabel("Util", "\(Int(gpu.utilizationPercent))%")
                Spacer()
                statLabel("Mem", "\(Int(gpu.memoryUsedFraction * 100))%")
                Spacer()
                statLabel("Temp", "\(Int(gpu.temperatureC))°C")
                Spacer()
                statLabel("Power", "\(Int(gpu.powerWatts))W")
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statLabel(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.monospacedDigit())
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    GPUTileView(
        gpu: GPUStatus(
            id: "gpu-0", index: 0, name: "NVIDIA GeForce RTX 4060 Ti",
            utilizationPercent: 87, memoryUsedMB: 9200, memoryTotalMB: 16384,
            temperatureC: 68, powerWatts: 145, currentJobID: "job-42"
        ),
        job: Job(
            id: "job-42", campaignID: "campaign-r104q", name: "R104Q NTD pocket MD",
            kind: .mdSimulation, gpuID: "gpu-0", status: .running, stage: "Production run",
            unitsDone: 63, unitsTotal: 200, unitLabel: "ns", throughputPerHour: 22.5,
            startedAt: .now, lastCheckpointAt: .now, errorMessage: nil
        )
    )
    .frame(width: 260)
    .padding()
}
