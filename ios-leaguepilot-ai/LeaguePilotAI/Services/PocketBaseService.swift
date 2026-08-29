import Foundation

/// PocketBase auth and record access for the `users` collection and Home reads.
@MainActor
final class PocketBaseService {
    private let client: APIClient

    init(client: APIClient? = nil) {
        self.client = client ?? APIClient(baseURL: LeaguePilotConfig.baseURL)
    }

    /// Signs a user in against the PocketBase `users` collection.
    func authWithPassword(email: String, password: String) async throws -> PBAuthResponse {
        struct Credentials: Encodable {
            let identity: String
            let password: String
        }
        let body = try JSONEncoder().encode(Credentials(identity: email, password: password))
        return try await client.send(
            PBAuthResponse.self,
            method: "POST",
            path: "/api/collections/users/auth-with-password",
            body: body
        )
    }

    /// Validates a stored session token and returns a fresh one.
    func authRefresh(token: String) async throws -> PBAuthResponse {
        try await client.send(
            PBAuthResponse.self,
            method: "POST",
            path: "/api/collections/users/auth-refresh",
            body: Data("{}".utf8),
            token: token
        )
    }

    /// Creates a new user account.
    func createUser(name: String, email: String, password: String) async throws {
        let payload = SignUpRequest(name: name, email: email, password: password, passwordConfirm: password)
        let body = try JSONEncoder().encode(payload)
        _ = try await client.send("POST", "/api/collections/users/records", body: body)
    }

    /// Newest analysis job for a workspace, or nil when none exist.
    func latestJob(workspaceID: String, token: String) async throws -> AnalysisJob? {
        let jobs: [AnalysisJob] = try await list(
            collection: LeaguePilotConfig.jobsCollection,
            workspaceID: workspaceID,
            sort: "-created",
            limit: 1,
            token: token
        )
        return jobs.first
    }

    /// Newest recommendations for a workspace.
    func recommendations(workspaceID: String, token: String, limit: Int = 5) async throws -> [Recommendation] {
        try await list(
            collection: LeaguePilotConfig.recommendationsCollection,
            workspaceID: workspaceID,
            sort: "-created",
            limit: limit,
            token: token
        )
    }

    /// Lists records filtered by workspace. A missing collection reads as empty.
    private func list<Item: Decodable>(
        collection: String,
        workspaceID: String,
        sort: String,
        limit: Int,
        token: String
    ) async throws -> [Item] {
        let query = [
            "filter": "workspace=\"\(workspaceID)\"",
            "sort": sort,
            "limit": String(limit),
        ]
        do {
            let page: PBList<Item> = try await client.send(
                PBList<Item>.self,
                method: "GET",
                path: "/api/collections/\(collection)/records",
                query: query,
                token: token
            )
            return page.items
        } catch let error as LeaguePilotError where error.status == 404 {
            return []
        }
    }
}
