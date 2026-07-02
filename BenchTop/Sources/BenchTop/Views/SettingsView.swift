import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var config: AgentConfig
    @EnvironmentObject private var store: BenchTopStore
    @Environment(\.dismiss) private var dismiss

    @State private var hostDraft: String = ""
    @State private var portDraft: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Agent") {
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
                } footer: {
                    Text("The BenchTop agent runs on the rig itself and serves its status over your local network. Defaults match `benchtop_agent` run with its default port.")
                }

                if let lastUpdated = store.lastUpdated {
                    Section {
                        LabeledContent("Last updated", value: lastUpdated.formatted(date: .omitted, time: .standard))
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        config.host = hostDraft.trimmingCharacters(in: .whitespaces)
                        config.port = Int(portDraft) ?? config.port
                        dismiss()
                        Task { await store.refresh() }
                    }
                }
            }
            .onAppear {
                hostDraft = config.host
                portDraft = String(config.port)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AgentConfig())
        .environmentObject(BenchTopStore(config: AgentConfig()))
}
