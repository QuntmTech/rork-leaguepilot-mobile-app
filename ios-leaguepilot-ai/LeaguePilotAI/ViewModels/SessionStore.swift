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
    /// Changes synchronously with the selected connection, allowing every asynchronous consumer
    /// to reject an older request even before SwiftUI has started its replacement task.
    private(set) var selectedLeagueRevision = 0
    private(set) var authToken: String?
    /// Increments only for owner-scoped PocketBase events that can change an authenticated screen.
    private(set) var realtimeRevision = 0
    private(set) var isReceivingRealtimeUpdates = false
    private var didRestore = false
    private var realtimeTask: Task<Void, Never>?
    private var realtimeGeneration = 0
    private let pocketBase: any PocketBaseServicing
    private let leaguePilot: any LeaguePilotServicing
    private let keychain: any KeychainStoring
    private let realtime: any PocketBaseRealtimeServicing

    init(
        pocketBase: (any PocketBaseServicing)? = nil,
        leaguePilot: (any LeaguePilotServicing)? = nil,
        keychain: (any KeychainStoring)? = nil,
        realtime: (any PocketBaseRealtimeServicing)? = nil
    ) {
        self.pocketBase = pocketBase ?? PocketBaseService()
        self.leaguePilot = leaguePilot ?? LeaguePilotService()
        self.keychain = keychain ?? KeychainStore()
        self.realtime = realtime ?? PocketBaseRealtimeService()
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

    func selectConnection(_ id: String) {
        guard connections.contains(where: { $0.id == id && $0.status.isSelectable }) else { return }
        setSelectedConnectionID(id)
    }

    func loadLatestJob(for connectionID: String? = nil) async throws -> AnalysisJob? {
        (try await loadJobs(for: connectionID)).first
    }

    func loadJobs(for connectionID: String? = nil) async throws -> [AnalysisJob] {
        guard let workspace, let authToken, let connectionID = connectionID ?? selectedConnectionID else { return [] }
        do { return try await pocketBase.jobs(workspaceID: workspace.id, connectionID: connectionID, token: authToken) }
        catch { handleAuthenticatedError(error); throw error }
    }

    func loadJob(id: String) async throws -> AnalysisJob { guard let authToken else { throw LeaguePilotError(status: nil, message: "Your session has ended.") }; do { return try await pocketBase.job(id: id, token: authToken) } catch { handleAuthenticatedError(error); throw error } }

    func loadRecommendations(for connectionID: String? = nil) async throws -> [Recommendation] {
        guard let workspace, let authToken, let connectionID = connectionID ?? selectedConnectionID else { return [] }
        do {
            async let snapshots = pocketBase.snapshots(workspaceID: workspace.id, token: authToken)
            async let recommendations = pocketBase.recommendations(workspaceID: workspace.id, token: authToken)
            let snapshotIDs = Set(try await snapshots.filter { $0.connection == connectionID && $0.isUsable }.map(\.id))
            return try await recommendations.filter { guard let snapshot = $0.snapshot else { return false }; return snapshotIDs.contains(snapshot) }
        } catch { handleAuthenticatedError(error); throw error }
    }

    func loadLeagueData(for connectionID: String) async throws -> SelectedLeagueData {
        guard let workspace, let authToken else {
            return SelectedLeagueData(connectionID: connectionID, snapshot: nil, recommendations: [], reports: [], jobs: [], dataWarnings: [])
        }
        do {
            async let snapshotsTask = pocketBase.snapshots(workspaceID: workspace.id, token: authToken)
            async let recommendationsTask = pocketBase.recommendations(workspaceID: workspace.id, token: authToken)
            async let reportsTask = pocketBase.reports(workspaceID: workspace.id, token: authToken)
            async let jobsTask = pocketBase.jobs(workspaceID: workspace.id, connectionID: connectionID, token: authToken)

            let snapshots = try await snapshotsTask
            let selectedSnapshots = snapshots.filter { $0.connection == connectionID }
            let usableSnapshots = selectedSnapshots.filter(\.isUsable)
            let snapshot = usableSnapshots.first
            let snapshotIDs = Set(usableSnapshots.map(\.id))
            var dataWarnings = snapshot?.metadataWarnings ?? []
            if let latest = selectedSnapshots.first, latest.id != snapshot?.id, !latest.isUsable {
                dataWarnings.insert("The newest stored snapshot could not be read; showing the latest usable snapshot instead.", at: 0)
            }
            let recommendations = try await recommendationsTask.filter { recommendation in
                guard let snapshot = recommendation.snapshot else { return false }
                return snapshotIDs.contains(snapshot)
            }
            let reports = try await reportsTask.filter { report in
                guard let snapshot = report.snapshot else { return false }
                return snapshotIDs.contains(snapshot)
            }
            return SelectedLeagueData(
                connectionID: connectionID,
                snapshot: snapshot,
                recommendations: recommendations,
                reports: reports,
                jobs: try await jobsTask,
                dataWarnings: dataWarnings
            )
        } catch {
            handleAuthenticatedError(error)
            throw error
        }
    }

    func saveESPNConnection(_ request: ESPNConnectionRequest) async throws -> ConnectionSaveResponse {
        guard let workspace, let authToken else { throw LeaguePilotError(status: nil, message: "Your session has ended.") }
        do { let response = try await leaguePilot.saveESPNConnection(workspaceID: workspace.id, connection: request, token: authToken); try await refreshConnections(); setSelectedConnectionID(response.connection.id); return response }
        catch { handleAuthenticatedError(error); throw error }
    }

    func runAnalysis() async throws -> AnalysisQueueResponse {
        guard let workspace, let authToken, let connectionID = selectedConnectionID else { throw LeaguePilotError(status: nil, message: "Select an ESPN league first.") }
        do { return try await leaguePilot.runAnalysis(workspaceID: workspace.id, connectionID: connectionID, token: authToken) }
        catch { handleAuthenticatedError(error); throw error }
    }

    func reviewRecommendation(id: String, decision: RecommendationDecision) async throws -> RecommendationReviewResponse {
        guard let authToken else { throw LeaguePilotError(status: nil, message: "Your session has ended.") }
        do { return try await leaguePilot.reviewRecommendation(id: id, decision: decision, token: authToken) }
        catch { handleAuthenticatedError(error); throw error }
    }

    func syncSelectedConnection() async throws -> SyncQueueResponse { guard let authToken, let connectionID = selectedConnectionID else { throw LeaguePilotError(status: nil, message: "Select an ESPN league first.") }; do { return try await leaguePilot.sync(connectionID: connectionID, token: authToken) } catch { handleAuthenticatedError(error); throw error } }

    func signOut() { stopRealtime(); try? keychain.removeAll(); user = nil; workspace = nil; connections = []; setSelectedConnectionID(nil); authToken = nil; realtimeRevision = 0; phase = .signedOut }

    private func apply(_ auth: PBAuthResponse) throws { try keychain.set(auth.token, for: .authToken); user = auth.record; authToken = auth.token }
    private func bootstrapAndLoad() async throws { guard let authToken else { throw LeaguePilotError(status: nil, message: "Your session has ended.") }; phase = .loadingWorkspace; let response = try await leaguePilot.bootstrap(token: authToken); workspace = response.workspace; phase = .loadingDashboard; try await refreshConnections(); phase = .ready; startRealtime() }
    private func selectPreferredConnection() {
        if let id = selectedConnectionID, activeConnections.contains(where: { $0.id == id }) { return }
        setSelectedConnectionID(activeConnections.sorted { $0.selectionDate > $1.selectionDate }.first?.id)
    }
    private func setSelectedConnectionID(_ id: String?) {
        guard selectedConnectionID != id else { return }
        selectedConnectionID = id
        selectedLeagueRevision &+= 1
    }
    private func handle(_ error: Error) { if (error as? LeaguePilotError)?.isSessionExpired == true { signOut() } else { phase = .failed(FriendlyError.message(for: error)) } }
    private func handleAuthenticatedError(_ error: Error) { if (error as? LeaguePilotError)?.isSessionExpired == true { signOut() } }

    private func startRealtime() {
        stopRealtime()
        guard let authToken else { return }
        let collections = [
            LeaguePilotConfig.connectionsCollection,
            LeaguePilotConfig.jobsCollection,
            LeaguePilotConfig.recommendationsCollection,
            LeaguePilotConfig.reportsCollection,
            LeaguePilotConfig.snapshotsCollection,
        ]
        realtimeGeneration &+= 1
        let generation = realtimeGeneration
        isReceivingRealtimeUpdates = true
        let realtime = realtime
        realtimeTask = Task { [weak self, realtime] in
            do {
                for try await event in realtime.events(token: authToken, collections: collections) {
                    guard !Task.isCancelled else { return }
                    guard let self else { return }
                    self.receiveRealtime(event)
                }
            } catch is CancellationError {
                // Session changes intentionally end the stream.
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.handleAuthenticatedError(error)
            }
            guard let self else { return }
            self.finishRealtime(generation: generation)
        }
    }

    private func stopRealtime() {
        realtimeGeneration &+= 1
        realtimeTask?.cancel()
        realtimeTask = nil
        isReceivingRealtimeUpdates = false
    }

    private func finishRealtime(generation: Int) {
        guard realtimeGeneration == generation else { return }
        realtimeTask = nil
        isReceivingRealtimeUpdates = false
    }

    private func receiveRealtime(_ event: PocketBaseRealtimeEvent) {
        let supportedCollections = [
            LeaguePilotConfig.connectionsCollection,
            LeaguePilotConfig.jobsCollection,
            LeaguePilotConfig.recommendationsCollection,
            LeaguePilotConfig.reportsCollection,
            LeaguePilotConfig.snapshotsCollection,
        ]
        guard let collection = event.record.collectionName, supportedCollections.contains(collection) else { return }
        realtimeRevision &+= 1
    }
}
