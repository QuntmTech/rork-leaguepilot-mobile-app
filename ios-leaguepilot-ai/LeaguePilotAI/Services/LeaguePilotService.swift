import Foundation

@MainActor
protocol LeaguePilotServicing {
    func bootstrap(token: String) async throws -> BootstrapResponse
    func runAnalysis(workspaceID: String, connectionID: String, token: String) async throws -> AnalysisQueueResponse
    func saveESPNConnection(workspaceID: String, connection: ESPNConnectionRequest, token: String) async throws -> ConnectionSaveResponse
    func sync(connectionID: String, token: String) async throws -> SyncQueueResponse
    func reviewRecommendation(id: String, decision: RecommendationDecision, token: String) async throws -> RecommendationReviewResponse
}

@MainActor
final class LeaguePilotService: LeaguePilotServicing {
    private let client: APIClient
    init(client: APIClient? = nil) { self.client = client ?? APIClient(baseURL: LeaguePilotConfig.baseURL) }

    func bootstrap(token: String) async throws -> BootstrapResponse {
        try await client.send(BootstrapResponse.self, method: "POST", path: "/api/leaguepilot/bootstrap", body: Data("{}".utf8), token: token)
    }

    func runAnalysis(workspaceID: String, connectionID: String, token: String) async throws -> AnalysisQueueResponse {
        try await client.send(AnalysisQueueResponse.self, method: "POST", path: "/api/leaguepilot/workspaces/\(workspaceID)/analysis", body: try JSONEncoder().encode(AnalysisRequest(connectionID: connectionID)), token: token)
    }

    func saveESPNConnection(workspaceID: String, connection: ESPNConnectionRequest, token: String) async throws -> ConnectionSaveResponse {
        try await client.send(ConnectionSaveResponse.self, method: "PUT", path: "/api/leaguepilot/workspaces/\(workspaceID)/connections/espn", body: try JSONEncoder().encode(connection), token: token)
    }

    func sync(connectionID: String, token: String) async throws -> SyncQueueResponse {
        try await client.send(SyncQueueResponse.self, method: "POST", path: "/api/leaguepilot/connections/\(connectionID)/sync", body: Data("{}".utf8), token: token)
    }

    func reviewRecommendation(id: String, decision: RecommendationDecision, token: String) async throws -> RecommendationReviewResponse {
        try await client.send(
            RecommendationReviewResponse.self,
            method: "POST",
            path: "/api/leaguepilot/recommendations/\(id)/review",
            body: try JSONEncoder().encode(RecommendationReviewRequest(decision: decision)),
            token: token
        )
    }
}
