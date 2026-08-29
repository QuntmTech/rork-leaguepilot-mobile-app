import Foundation

@MainActor
protocol PocketBaseServicing {
    func authWithPassword(email: String, password: String) async throws -> PBAuthResponse
    func authRefresh(token: String) async throws -> PBAuthResponse
    func createUser(name: String, email: String, password: String) async throws
    func connections(workspaceID: String, token: String) async throws -> [ESPNConnection]
    func jobs(workspaceID: String, connectionID: String, token: String) async throws -> [AnalysisJob]
    func job(id: String, token: String) async throws -> AnalysisJob
    func snapshots(workspaceID: String, token: String) async throws -> [LeagueSnapshotRecord]
    func recommendations(workspaceID: String, token: String) async throws -> [Recommendation]
    func reports(workspaceID: String, token: String) async throws -> [WeeklyReport]
}

@MainActor
final class PocketBaseService: PocketBaseServicing {
    private let client: APIClient
    init(client: APIClient? = nil) { self.client = client ?? APIClient(baseURL: LeaguePilotConfig.baseURL) }

    func authWithPassword(email: String, password: String) async throws -> PBAuthResponse {
        struct Credentials: Encodable { let identity: String; let password: String }
        return try await client.send(PBAuthResponse.self, method: "POST", path: "/api/collections/users/auth-with-password", body: try JSONEncoder().encode(Credentials(identity: email, password: password)))
    }

    func authRefresh(token: String) async throws -> PBAuthResponse {
        try await client.send(PBAuthResponse.self, method: "POST", path: "/api/collections/users/auth-refresh", body: Data("{}".utf8), token: token)
    }

    func createUser(name: String, email: String, password: String) async throws {
        let body = try JSONEncoder().encode(SignUpRequest(name: name, email: email, password: password, passwordConfirm: password))
        _ = try await client.send("POST", "/api/collections/users/records", body: body)
    }

    func connections(workspaceID: String, token: String) async throws -> [ESPNConnection] {
        try await list(ESPNConnection.self, collection: LeaguePilotConfig.connectionsCollection, filter: "workspace = \(PBFilter.value(workspaceID))", sort: "-last_synced_at", token: token)
    }

    func jobs(workspaceID: String, connectionID: String, token: String) async throws -> [AnalysisJob] {
        try await list(AnalysisJob.self, collection: LeaguePilotConfig.jobsCollection, filter: "workspace = \(PBFilter.value(workspaceID)) && connection = \(PBFilter.value(connectionID))", sort: "-created", token: token, limit: 10)
    }

    func job(id: String, token: String) async throws -> AnalysisJob {
        try await client.send(AnalysisJob.self, method: "GET", path: "/api/collections/\(LeaguePilotConfig.jobsCollection)/records/\(id)", token: token)
    }

    func snapshots(workspaceID: String, token: String) async throws -> [LeagueSnapshotRecord] {
        try await list(LeagueSnapshotRecord.self, collection: LeaguePilotConfig.snapshotsCollection, filter: "workspace = \(PBFilter.value(workspaceID))", sort: "-fetched_at", token: token, limit: 100)
    }

    func recommendations(workspaceID: String, token: String) async throws -> [Recommendation] {
        try await list(Recommendation.self, collection: LeaguePilotConfig.recommendationsCollection, filter: "workspace = \(PBFilter.value(workspaceID))", sort: "-created", token: token, limit: 100)
    }

    func reports(workspaceID: String, token: String) async throws -> [WeeklyReport] {
        try await list(WeeklyReport.self, collection: LeaguePilotConfig.reportsCollection, filter: "workspace = \(PBFilter.value(workspaceID))", sort: "-published_at,-created", token: token, limit: 100)
    }

    private func list<T: Decodable>(_ type: T.Type, collection: String, filter: String, sort: String, token: String, limit: Int = 50) async throws -> [T] {
        let page: PBList<T> = try await client.send(PBList<T>.self, method: "GET", path: "/api/collections/\(collection)/records", query: ["filter": filter, "sort": sort, "perPage": String(limit)], token: token)
        return page.items
    }
}

private enum PBFilter {
    static func value(_ raw: String) -> String {
        "\"\(raw.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
