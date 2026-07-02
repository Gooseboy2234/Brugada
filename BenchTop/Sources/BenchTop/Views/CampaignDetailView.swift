import SwiftUI

struct CampaignDetailView: View {
    @EnvironmentObject private var store: BenchTopStore
    var campaign: Campaign

    private var jobs: [Job] {
        store.jobs(in: campaign)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(campaign.target)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(campaign.name)
                        .font(.largeTitle.weight(.bold))
                }

                if !campaign.funnel.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Funnel")
                            .font(.headline)
                        FunnelChartView(stages: campaign.funnel)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Jobs")
                        .font(.headline)

                    if jobs.isEmpty {
                        Text("No jobs reported for this campaign yet.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(jobs) { job in
                            JobRow(job: job)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(campaign.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct JobRow: View {
    var job: Job

    var body: some View {
        HStack(spacing: 16) {
            ProgressRing(fraction: job.fractionDone, lineWidth: 5, tint: tint)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.name)
                    .font(.callout.weight(.medium))
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var tint: Color {
        switch job.status {
        case .failed: return .red
        case .completed: return .green
        default: return .accentColor
        }
    }

    private var statusLine: String {
        if let error = job.errorMessage, job.status == .failed {
            return error
        }
        let unitsText = job.unitsTotal.map { "\(Int(job.unitsDone))/\(Int($0)) \(job.unitLabel)" }
            ?? "\(Int(job.unitsDone)) \(job.unitLabel)"
        return "\(job.stage) · \(unitsText)"
    }
}

#Preview {
    NavigationStack {
        CampaignDetailView(
            campaign: Campaign(
                id: "campaign-r104q", name: "SCN5A-R104Q", target: "SCN5A R104Q NTD pocket",
                funnel: [
                    FunnelStage(name: "Enamine slice screened", count: 1_200_000),
                    FunnelStage(name: "Passed MD triage", count: 4_800),
                    FunnelStage(name: "Shortlisted", count: 5),
                ]
            )
        )
        .environmentObject(BenchTopStore(config: AgentConfig()))
    }
}
