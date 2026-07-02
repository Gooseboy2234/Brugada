import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var config: AgentConfig
    @EnvironmentObject private var store: BenchTopStore
    @StateObject private var discovery = AgentDiscovery()

    @State private var hostDraft: String = ""
    @State private var portDraft: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Host or IP", text: $hostDraft)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    TextField("Port", text: $portDraft)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    Button("Connect") { applyAndRefresh() }
                        .disabled(hostDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Agent")
                } footer: {
                    Text("The agent runs on the rig and serves status over your local network. It advertises itself automatically — pick it below, or enter the address by hand.")
                }

                if !discovery.discovered.isEmpty {
                    Section("Found on this network") {
                        ForEach(discovery.discovered) { agent in
                            Button {
                                hostDraft = agent.host
                                portDraft = String(agent.port)
                                applyAndRefresh()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(agent.name).foregroundStyle(Theme.Palette.textPrimary)
                                        Text("\(agent.host):\(String(agent.port))")
                                            .font(.btData(11)).foregroundStyle(Theme.Palette.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "wifi").foregroundStyle(Theme.Palette.signal)
                                }
                            }
                        }
                    }
                }

                Section("Connection") {
                    LabeledContent("Status") {
                        if store.lastError == nil, store.lastUpdated != nil {
                            Pill(tint: Theme.Palette.statusDone, symbol: "checkmark", text: "Connected")
                        } else if store.lastError != nil {
                            Pill(tint: Theme.Palette.statusFailed, symbol: "xmark", text: "No response")
                        } else {
                            Pill(tint: Theme.Palette.statusIdle, symbol: "clock", text: "Waiting")
                        }
                    }
                    if let lastUpdated = store.lastUpdated {
                        LabeledContent("Last updated",
                                       value: lastUpdated.formatted(date: .omitted, time: .standard))
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                hostDraft = config.host
                portDraft = String(config.port)
                discovery.start()
            }
            .onDisappear { discovery.stop() }
        }
    }

    private func applyAndRefresh() {
        config.host = hostDraft.trimmingCharacters(in: .whitespaces)
        config.port = Int(portDraft) ?? config.port
        Task { await store.refresh() }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AgentConfig())
        .environmentObject(PreviewData.store())
}
