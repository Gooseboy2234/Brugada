import SwiftUI
import Charts

/// Visualizes a campaign's funnel (e.g. 1.2M docked -> 4,800 passed triage ->
/// 5 shortlisted) as a log-scale bar chart, since the drop-off between
/// stages is usually several orders of magnitude.
struct FunnelChartView: View {
    var stages: [FunnelStage]

    var body: some View {
        Chart(stages) { stage in
            BarMark(
                x: .value("Count", max(stage.count, 1)),
                y: .value("Stage", stage.name)
            )
            .foregroundStyle(Color.accentColor.gradient)
            .annotation(position: .trailing) {
                Text(stage.count.formatted())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .chartXScale(domain: .automatic(includesZero: false), type: .log)
        .chartXAxis(.hidden)
        .frame(height: CGFloat(stages.count) * 44 + 20)
    }
}

#Preview {
    FunnelChartView(stages: [
        FunnelStage(name: "Enamine slice screened", count: 1_200_000),
        FunnelStage(name: "ML surrogate shortlist", count: 6_000),
        FunnelStage(name: "Docked", count: 6_000),
        FunnelStage(name: "Passed MD triage", count: 4_800),
        FunnelStage(name: "Shortlisted", count: 5),
    ])
    .padding()
}
