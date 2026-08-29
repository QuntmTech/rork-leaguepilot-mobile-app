import Foundation
import Observation

/// Holds the signed-in user, session token and workspace.
/// The session token lives in the Keychain; nothing secret is logged or persisted elsewhere.
@MainActor
@Observable
final class SessionStore {
    private(set) var user: PBUser?
    private(set) var workspace: Workspace?
    private(set) var authToken: String?
    private(set) var isRestoringSession = true

    var isSignedIn: Bool { user != nil && authToken != nil }
    var workspaceName: String { workspace?.name ?? "My League" }

    private let pocketBase = PocketBaseService()
    private let leaguePilot = LeaguePilotService()

    init() {
        Task { await restoreSession() }
    }

    /// Restores a persisted session on launch and bootstraps the workspace.
    func restoreSession() async {
        if let token = KeychainStore.string(for: .authToken) {
            do {
                let auth = try await pocketBase.authRefresh(token: token)
                applySession(auth)
                workspace = try? await leaguePilot.bootstrap(token: auth.token)
            } catch {
                KeychainStore.removeAll()
            }
        }
        isRestoringSession = false
    }

    /// Signs in with email and password, then bootstraps the workspace.
    func signIn(email: String, password: String) async throws {
        let auth = try await pocketBase.authWithPassword(email: email, password: password)
        applySession(auth)
        workspace = try? await leaguePilot.bootstrap(token: auth.token)
    }

    /// Creates a PocketBase account, then signs in.
    func signUp(name: String, email: String, password: String) async throws {
        try await pocketBase.createUser(name: name, email: email, password: password)
        try await signIn(email: email, password: password)
    }

    /// Re-reads the workspace so ESPN connection state stays fresh.
    func refreshWorkspace() async throws {
        guard let authToken else { return }
        workspace = try await leaguePilot.bootstrap(token: authToken)
    }

    /// Newest analysis job for the workspace, or nil when none exists.
    func loadLatestJob() async throws -> AnalysisJob? {
        guard let authToken, let workspace else { return nil }
        return try await pocketBase.latestJob(workspaceID: workspace.id, token: authToken)
    }

    /// Newest recommendations for the workspace.
    func loadRecommendations() async throws -> [Recommendation] {
        guard let authToken, let workspace else { return [] }
        return try await pocketBase.recommendations(workspaceID: workspace.id, token: authToken)
    }

    /// Clears the local session. Server-side records stay intact.
    func signOut() {
        KeychainStore.removeAll()
        user = nil
        authToken = nil
        workspace = nil
    }

    private func applySession(_ auth: PBAuthResponse) {
        authToken = auth.token
        user = auth.record
        KeychainStore.set(auth.token, for: .authToken)
        KeychainStore.set(auth.record.id, for: .userID)
        KeychainStore.set(auth.record.email, for: .email)
    }
}
