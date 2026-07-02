import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: BenchTopStore
    @State private var showingSettings = false

    private let columns = [GridItem(.adaptive(minimum: 240), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
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
                            NavigationLink(value: campaign) {
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
            .navigationDestination(for: Campaign.self) { campaign in
                CampaignDetailView(campaign: campaign)
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
    DashboardView()
        .environmentObject(AgentConfig())
        .environmentObject(BenchTopStore(config: AgentConfig()))
}
