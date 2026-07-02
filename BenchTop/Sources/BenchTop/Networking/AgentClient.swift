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

    // Deliberately NOT using .convertFromSnakeCase: it only capitalizes the
    // first letter of each segment (memory_used_mb -> memoryUsedMb, not
    // memoryUsedMB), which mismatches acronym-bearing Swift property names
    // like memoryUsedMB/gpuID/campaignID. Every model instead declares an
    // explicit CodingKeys enum with the exact snake_case JSON key, so this
    // decoder does no key transformation at all.
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func fetchGPUs() async throws -> [GPUStatus] {
        try await get("/api/gpus")
    }

    func fetchJobs() async throws -> [Job] {
        try await get("/api/jobs")
    }

    func fetchCampaigns() async throws -> [Campaign] {
        try await get("/api/campaigns")
    }

    func fetchStats() async throws -> Stats {
        try await get("/api/stats")
    }

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
