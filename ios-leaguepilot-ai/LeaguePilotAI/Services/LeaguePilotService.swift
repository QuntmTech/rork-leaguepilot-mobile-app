import Foundation

/// LeaguePilot workspace endpoints served by the cloudpod PocketBase instance.
@MainActor
final class LeaguePilotService {
    private let client: APIClient

    init(client: APIClient? = nil) {
        self.client = client ?? APIClient(baseURL: LeaguePilotConfig.baseURL)
    }

    private struct BootstrapEnvelope: Decodable {
        let workspace: Workspace?
    }

    /// POST /api/leaguepilot/bootstrap — ensures a workspace exists and returns it.
    func bootstrap(token: String) async throws -> Workspace {
        let data = try await client.send("POST", "/api/leaguepilot/bootstrap", body: Data("{}".utf8), token: token)
        if let envelope = try? JSONDecoder().decode(BootstrapEnvelope.self, from: data),
           let workspace = envelope.workspace {
            return workspace
        }
        return try JSONDecoder().decode(Workspace.self, from: data)
    }

    /// POST /api/leaguepilot/workspaces/{id}/analysis — queues a full analysis run.
    func runAnalysis(workspaceID: String, token: String) async throws {
        let body = try JSONEncoder().encode(AnalysisRequest())
        _ = try await client.send(
            "POST",
            "/api/leaguepilot/workspaces/\(workspaceID)/analysis",
            body: body,
            token: token
        )
    }

    /// PUT /api/leaguepilot/workspaces/{id}/connections/espn — links an ESPN league.
    func saveESPNConnection(workspaceID: String, connection: ESPNConnectionRequest, token: String) async throws {
        let body = try JSONEncoder().encode(connection)
        _ = try await client.send(
            "PUT",
            "/api/leaguepilot/workspaces/\(workspaceID)/connections/espn",
            body: body,
            token: token
        )
    }
}
