import Foundation
import Observation

@MainActor @Observable
final class SessionStore {
    enum Phase: Equatable { case restoring, signedOut, authenticating, loadingWorkspace, loadingDashboard, ready, failed(String) }
    private(set) var phase: Phase = .restoring
    private(set) var user: PBUser?
    private(set) var workspace: Workspace?
    private(set) var connections: [ESPNConnection] = []
    private(set) var selectedConnectionID: String?
    private(set) var authToken: String?
    private var didRestore = false
    private let pocketBase: any PocketBaseServicing
    private let leaguePilot: any LeaguePilotServicing
    private let keychain: any KeychainStoring

    init(pocketBase: (any PocketBaseServicing)? = nil, leaguePilot: (any LeaguePilotServicing)? = nil, keychain: (any KeychainStoring)? = nil) {
        self.pocketBase = pocketBase ?? PocketBaseService(); self.leaguePilot = leaguePilot ?? LeaguePilotService(); self.keychain = keychain ?? KeychainStore()
    }

    var isRestoringSession: Bool { phase == .restoring }
    var isSignedIn: Bool { if case .ready = phase { true } else { false } }
    var workspaceName: String { workspace?.name ?? "My League" }
    var activeConnections: [ESPNConnection] { connections.filter(\.status.isSelectable) }
    var selectedConnection: ESPNConnection? { connections.first { $0.id == selectedConnectionID } }

    func restoreSession() async {
        guard !didRestore else { return }; didRestore = true
        do {
            guard let token = try keychain.string(for: .authToken) else { phase = .signedOut; return }
            let auth = try await pocketBase.authRefresh(token: token)
            try apply(auth)
            try await bootstrapAndLoad()
        } catch {
            handle(error)
        }
    }

    func signIn(email: String, password: String) async throws {
        phase = .authenticating
        do { let auth = try await pocketBase.authWithPassword(email: email, password: password); try apply(auth); try await bootstrapAndLoad() }
        catch { handle(error); throw error }
    }

    func signUp(name: String, email: String, password: String) async throws {
        try await pocketBase.createUser(name: name, email: email, password: password)
        try await signIn(email: email, password: password)
    }

    func retry() async { guard authToken != nil else { phase = .signedOut; return }; do { try await bootstrapAndLoad() } catch { handle(error) } }

    /// Mobile sessions are independent of the web's HttpOnly cookie. Refresh the Keychain-backed
    /// PocketBase token whenever the application returns to the foreground.
    func refreshSessionOnForeground() async {
        guard let token = authToken, phase == .ready else { return }
        do {
            let auth = try await pocketBase.authRefresh(token: token)
            try apply(auth)
            try await bootstrapAndLoad()
        } catch {
            handle(error)
        }
    }

    func refreshConnections() async throws {
        guard let workspace, let authToken else { return }
        do { connections = try await pocketBase.connections(workspaceID: workspace.id, token: authToken); selectPreferredConnection() }
        catch { handleAuthenticatedError(error); throw error }
    }

    func selectConnection(_ id: String) { guard connections.contains(where: { $0.id == id && $0.status.isSelectable }) else { return }; selectedConnectionID = id }

    func loadLatestJob() async throws -> AnalysisJob? {
        guard let workspace, let authToken, let connectionID = selectedConnectionID else { return nil }
        do { return try await pocketBase.jobs(workspaceID: workspace.id, connectionID: connectionID, token: authToken).first }
        catch { handleAuthenticatedError(error); throw error }
    }

    func loadJob(id: String) async throws -> AnalysisJob { guard let authToken else { throw LeaguePilotError(status: nil, message: "Your session has ended.") }; do { return try await pocketBase.job(id: id, token: authToken) } catch { handleAuthenticatedError(error); throw error } }

    func loadRecommendations() async throws -> [Recommendation] {
        guard let workspace, let authToken, let connectionID = selectedConnectionID else { return [] }
        do {
            async let snapshots = pocketBase.snapshots(workspaceID: workspace.id, token: authToken)
            async let recommendations = pocketBase.recommendations(workspaceID: workspace.id, token: authToken)
            let snapshotIDs = Set(try await snapshots.filter { $0.connection == connectionID }.map(\.id))
            return try await recommendations.filter { guard let snapshot = $0.snapshot else { return false }; return snapshotIDs.contains(snapshot) }
        } catch { handleAuthenticatedError(error); throw error }
    }

    func saveESPNConnection(_ request: ESPNConnectionRequest) async throws -> ConnectionSaveResponse {
        guard let workspace, let authToken else { throw LeaguePilotError(status: nil, message: "Your session has ended.") }
        do { let response = try await leaguePilot.saveESPNConnection(workspaceID: workspace.id, connection: request, token: authToken); try await refreshConnections(); selectedConnectionID = response.connection.id; return response }
        catch { handleAuthenticatedError(error); throw error }
    }

    func runAnalysis() async throws -> AnalysisQueueResponse {
        guard let workspace, let authToken, let connectionID = selectedConnectionID else { throw LeaguePilotError(status: nil, message: "Select an ESPN league first.") }
        do { return try await leaguePilot.runAnalysis(workspaceID: workspace.id, connectionID: connectionID, token: authToken) }
        catch { handleAuthenticatedError(error); throw error }
    }

    func syncSelectedConnection() async throws -> SyncQueueResponse { guard let authToken, let connectionID = selectedConnectionID else { throw LeaguePilotError(status: nil, message: "Select an ESPN league first.") }; return try await leaguePilot.sync(connectionID: connectionID, token: authToken) }

    func signOut() { try? keychain.removeAll(); user = nil; workspace = nil; connections = []; selectedConnectionID = nil; authToken = nil; phase = .signedOut }

    private func apply(_ auth: PBAuthResponse) throws { try keychain.set(auth.token, for: .authToken); user = auth.record; authToken = auth.token }
    private func bootstrapAndLoad() async throws { guard let authToken else { throw LeaguePilotError(status: nil, message: "Your session has ended.") }; phase = .loadingWorkspace; let response = try await leaguePilot.bootstrap(token: authToken); workspace = response.workspace; phase = .loadingDashboard; try await refreshConnections(); phase = .ready }
    private func selectPreferredConnection() { if let id = selectedConnectionID, activeConnections.contains(where: { $0.id == id }) { return }; selectedConnectionID = activeConnections.sorted { $0.selectionDate > $1.selectionDate }.first?.id }
    private func handle(_ error: Error) { if (error as? LeaguePilotError)?.isSessionExpired == true { signOut() } else { phase = .failed(FriendlyError.message(for: error)) } }
    private func handleAuthenticatedError(_ error: Error) { if (error as? LeaguePilotError)?.isSessionExpired == true { signOut() } }
}
