import SwiftUI

/// The "dent being made" summary: cumulative GPU-hours, $ spent (against a
/// budget if one's configured), and totals grouped by whatever unit each
/// job reports (ns simulated, molecules screened, ...). Deliberately a
/// single compact card, not a dedicated screen — this is a glance metric,
/// not something that needs its own navigation destination.
struct StatsSummaryView: View {
    var stats: Stats

    private var sortedUnitTotals: [(label: String, total: Double)] {
        stats.totalsByUnit
            .map { (label: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                metric("GPU-hours", formatted(stats.totalGPUHours, decimals: 1))
                if stats.totalCostUSD > 0 || stats.budgetUSD != nil {
                    metric("Spent", stats.totalCostUSD.formatted(.currency(code: "USD")))
                }
                ForEach(sortedUnitTotals.prefix(2), id: \.label) { entry in
                    metric(entry.label, formatted(entry.total, decimals: 0))
                }
                Spacer()
            }

            if let budgetUSD = stats.budgetUSD {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: stats.budgetFraction ?? 0)
                        .tint(stats.budgetCrossed ? .red : .accentColor)
                    Text("\(stats.totalCostUSD.formatted(.currency(code: "USD"))) of \(budgetUSD.formatted(.currency(code: "USD"))) budget")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.callout.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func formatted(_ value: Double, decimals: Int) -> String {
        value.formatted(.number.precision(.fractionLength(decimals)).notation(.compactName))
    }
}

#Preview {
    VStack(spacing: 16) {
        StatsSummaryView(stats: Stats(
            totalGPUHours: 55.2,
            totalCostUSD: 8.28,
            budgetUSD: 20,
            budgetCrossed: false,
            totalsByUnit: ["ns": 63, "molecules": 1_202_100]
        ))
        StatsSummaryView(stats: Stats(
            totalGPUHours: 340,
            totalCostUSD: 51,
            budgetUSD: 50,
            budgetCrossed: true,
            totalsByUnit: ["ns": 900, "molecules": 4_800_000]
        ))
    }
    .padding(.vertical)
}
