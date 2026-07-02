import Foundation

/// Connection settings for the BenchTop agent running on the rig, persisted
/// locally. There's no discovery yet (v0) — the user types in the host.
@MainActor
final class AgentConfig: ObservableObject {
    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: Keys.host) }
    }
    @Published var port: Int {
        didSet { UserDefaults.standard.set(port, forKey: Keys.port) }
    }

    private enum Keys {
        static let host = "benchtop.agent.host"
        static let port = "benchtop.agent.port"
    }

    init() {
        let defaults = UserDefaults.standard
        self.host = defaults.string(forKey: Keys.host) ?? "benchtop.local"
        let storedPort = defaults.integer(forKey: Keys.port)
        self.port = storedPort > 0 ? storedPort : 8420
    }

    var baseURL: URL? {
        URL(string: "http://\(host):\(port)")
    }
}
