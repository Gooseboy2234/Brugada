import Foundation

enum AgentClientError: Error {
    case notConfigured
    case badResponse
}

/// Talks to the BenchTop agent's REST API over the local network.
/// See agent/benchtop_agent/main.py for the endpoints this expects.
struct AgentClient {
    var config: AgentConfig
    var session: URLSession = .shared

    private var decoder: JSONDecoder { Self.makeDecoder() }

    /// Shared decoder — also used by tests so they decode exactly as the app
    /// does. No `.convertFromSnakeCase`: it capitalizes only the first letter
    /// of each segment (gpu_model -> gpuModel is fine, but vram_gb -> vramGb,
    /// not vramGB), which breaks acronym-bearing names. Every model instead
    /// declares explicit CodingKeys with the exact snake_case key.
    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    func fetchRigs() async throws -> [Rig] { try await get("/api/rigs") }
    func fetchCampaigns() async throws -> [Campaign] { try await get("/api/campaigns") }
    func fetchJobs() async throws -> [Job] { try await get("/api/jobs") }
    func fetchAlerts() async throws -> [Alert] { try await get("/api/alerts") }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let base = config.baseURL else { throw AgentClientError.notConfigured }
        let url = base.appendingPathComponent(path)
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AgentClientError.badResponse
        }
        return try decoder.decode(T.self, from: data)
    }
}
