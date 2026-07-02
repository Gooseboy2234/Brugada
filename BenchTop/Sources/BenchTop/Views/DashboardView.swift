import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: BenchTopStore
    @State private var showingSettings = false

    private let columns = [GridItem(.adaptive(minimum: 240), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let stats = store.stats {
                    StatsSummaryView(stats: stats)
                        .padding(.top)
                }

                if store.gpus.isEmpty {
                    ContentUnavailableView(
                        "No GPUs reported yet",
                        systemImage: "cpu",
                        description: Text("Waiting for the BenchTop agent at settings’ configured host.")
                    )
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.gpus) { gpu in
                            GPUTileView(gpu: gpu, job: store.job(runningOn: gpu))
                        }
                    }
                    .padding()
                }

                if !store.campaigns.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Campaigns")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal)

                        ForEach(store.campaigns) { campaign in
                            NavigationLink(value: CampaignRoute(id: campaign.id)) {
                                CampaignRow(campaign: campaign, jobs: store.jobs(in: campaign))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 8)
                }

                if let lastError = store.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding()
                }
            }
            .navigationTitle("BenchTop")
            .navigationDestination(for: CampaignRoute.self) { route in
                CampaignDetailView(campaignID: route.id)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .refreshable {
                await store.refresh()
            }
        }
    }
}

private struct CampaignRow: View {
    var campaign: Campaign
    var jobs: [Job]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(campaign.name)
                .font(.headline)
            Text(campaign.target)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let start = campaign.startCount, let latest = campaign.latestCount {
                Text("\(start.formatted()) → \(latest.formatted())")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let store = BenchTopStore(config: AgentConfig())
    store.seed(
        gpus: [
            GPUStatus(
                id: "gpu-0", index: 0, name: "NVIDIA GeForce RTX 4060 Ti",
                utilizationPercent: 87, memoryUsedMB: 9200, memoryTotalMB: 16384,
                temperatureC: 68, powerWatts: 145, currentJobID: "job-42"
            ),
        ],
        jobs: [
            Job(
                id: "job-42", campaignID: "campaign-r104q", name: "R104Q NTD pocket MD",
                kind: .mdSimulation, gpuID: "gpu-0", status: .running, stage: "Production run",
                unitsDone: 63, unitsTotal: 200, unitLabel: "ns", throughputPerHour: 22.5,
                startedAt: .now, lastCheckpointAt: .now, errorMessage: nil
            ),
        ],
        campaigns: [
            Campaign(
                id: "campaign-r104q", name: "SCN5A-R104Q", target: "SCN5A R104Q NTD pocket",
                funnel: [
                    FunnelStage(name: "Enamine slice screened", count: 1_200_000),
                    FunnelStage(name: "Shortlisted", count: 5),
                ]
            ),
        ],
        stats: Stats(
            totalGPUHours: 55.2, totalCostUSD: 8.28, budgetUSD: 20,
            budgetCrossed: false, totalsByUnit: ["ns": 63, "molecules": 1_202_100]
        )
    )
    return DashboardView()
        .environmentObject(AgentConfig())
        .environmentObject(store)
}
