#if os(macOS)
import SwiftUI

/// Compact content for the macOS menu bar extra — lets a Mac left running
/// near the rig act as an ambient monitor without keeping the full window
/// open. Deliberately minimal: GPU utilization + current job progress and
/// the stats line, no navigation.
struct MenuBarSummaryView: View {
    @EnvironmentObject private var store: BenchTopStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.gpus.isEmpty {
                Text("No GPUs reported")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.gpus) { gpu in
                    let job = store.job(runningOn: gpu)
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(gpu.name)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Text(job?.stage ?? "Idle")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if let fraction = job?.fractionDone {
                            Text(fraction, format: .percent.precision(.fractionLength(0)))
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
            }

            if let stats = store.stats {
                Divider()
                Text("\(stats.totalGPUHours.formatted(.number.precision(.fractionLength(1)))) GPU-hrs · \(stats.totalCostUSD.formatted(.currency(code: "USD")))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let lastError = store.lastError {
                Divider()
                Text(lastError)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(width: 220)
    }
}
#endif
