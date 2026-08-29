import Foundation
import Testing
@testable import LeaguePilotAI

@MainActor
struct LeaguePilotAITests {
    @Test func cloudPodConfigurationRejectsUnsafeOrigins() {
        #expect(LeaguePilotConfig.baseURL(from: "http://example.com") == LeaguePilotConfig.fallbackCloudPodURL)
        #expect(LeaguePilotConfig.baseURL(from: "https://user:pass@example.com") == LeaguePilotConfig.fallbackCloudPodURL)
        #expect(LeaguePilotConfig.baseURL(from: "https://example.com") == URL(string: "https://example.com"))
    }

    @Test func connectionRequestUsesLiveSnakeCaseContract() throws {
        let data = try JSONEncoder().encode(ESPNConnectionRequest(leagueID: 123, teamID: 4, season: 2026, isPublic: true, espnS2: nil, swid: nil))
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["league_id"] as? Int == 123)
        #expect(body["team_id"] as? Int == 4)
        #expect(body["is_public"] as? Bool == true)
        #expect(body.keys.contains("espn_s2"))
        #expect(!body.keys.contains("leagueId"))
    }

    @Test func decodesBootstrapAndNumericRecommendationConfidence() throws {
        let bootstrap = try JSONDecoder().decode(BootstrapResponse.self, from: Data("{\"profile\":{\"id\":\"p\",\"display_name\":\"Manager\",\"plan\":\"free\",\"onboarding_complete\":false,\"timezone\":\"America/New_York\"},\"workspace\":{\"id\":\"w\",\"name\":\"My League\",\"slug\":\"lp-w\",\"plan\":\"free\",\"status\":\"active\"}}".utf8))
        #expect(bootstrap.workspace.id == "w")
        let recommendation = try JSONDecoder().decode(Recommendation.self, from: Data("{\"id\":\"r\",\"workspace\":\"w\",\"snapshot\":\"s\",\"kind\":\"lineup\",\"title\":\"Start A\",\"summary\":\"Reason\",\"confidence\":91.5,\"impact_points\":2.1,\"payload\":{},\"status\":\"proposed\"}".utf8))
        #expect(recommendation.confidence == 91.5)
    }

    @Test func decodesStoredSnapshotAndBackendPowerRankings() throws {
        let snapshot = try JSONDecoder().decode(LeagueSnapshotRecord.self, from: Data("""
        {"id":"snapshot-a","workspace":"workspace-a","connection":"connection-a","week":3,"fetched_at":"2026-08-28T12:00:00Z","payload":{"league_id":123,"league_name":"Sunday League","season":2026,"week":3,"scoring_format":"PPR","my_team_id":1,"roster_slots":["QB","RB"],"teams":[{"id":1,"name":"My Team","owner":"Me","wins":2,"losses":1,"ties":0,"points_for":321.5,"projected_total":110.2,"roster":[{"id":"player-a","name":"Starter","position":"QB","pro_team":"BUF","projected_points":22.4,"season_points":55.2,"average_points":18.4,"injury_status":"ACTIVE","current_slot":"QB","eligible_slots":["QB"],"opponent":"MIA","percent_owned":99}]},{"id":2,"name":"Opponent","owner":"Them","wins":3,"losses":0,"ties":0,"points_for":330.1,"projected_total":108.5,"roster":[]}],"free_agents":[],"matchups":[{"week":3,"home_team_id":1,"away_team_id":2,"home_score":0,"away_score":0,"home_projected":110.2,"away_projected":108.5}],"data_quality_warnings":[],"fetched_at":"2026-08-28T12:00:00Z"}}
        """.utf8))
        #expect(snapshot.payload.myTeam?.name == "My Team")
        #expect(snapshot.payload.currentOpponent?.name == "Opponent")
        #expect(snapshot.payload.myTeam?.starters.count == 1)

        let report = try JSONDecoder().decode(WeeklyReport.self, from: Data("""
        {"id":"report-a","workspace":"workspace-a","snapshot":"snapshot-a","week":3,"title":"Week 3 report","body_markdown":"Facts only","metrics":{"power_rankings":[{"team_id":1,"team":"My Team","score":89.5,"record_score":66.7,"points_score":97.3,"projection_score":100,"projected_total":110.2}]},"narration_mode":"rules"}
        """.utf8))
        #expect(report.powerRankings.first?.teamID == 1)
        #expect(report.powerRankings.first?.score == 89.5)
    }

    @Test func usesProtectedRecommendationReviewContract() throws {
        let request = RecommendationReviewRequest(decision: .approved)
        let requestData = try JSONEncoder().encode(request)
        let body = try #require(JSONSerialization.jsonObject(with: requestData) as? [String: String])
        #expect(body == ["decision": "approved"])

        let response = try JSONDecoder().decode(
            RecommendationReviewResponse.self,
            from: Data("{\"id\":\"recommendation-id\",\"status\":\"approved\",\"espn_action_executed\":false}".utf8)
        )
        #expect(response.id == "recommendation-id")
        #expect(response.status == .approved)
        #expect(!response.espnActionExecuted)
    }

    @Test func allLiveJobStatusesHaveHonestTerminalState() {
        #expect(JobStatus.queued.isPending && JobStatus.running.isPending)
        #expect(JobStatus.succeeded.isTerminal && JobStatus.failed.isTerminal && JobStatus.cancelled.isTerminal && JobStatus.deadLetter.isTerminal)
    }

    @Test func ignoresStaleLeagueDataAfterSelectionChanges() async throws {
        let pocketBase = MockPocketBase()
        pocketBase.snapshotRecords = [TestFixtures.snapshot(id: "snapshot-a", connectionID: "connection-a", teamName: "Alpha"), TestFixtures.snapshot(id: "snapshot-b", connectionID: "connection-b", teamName: "Bravo")]
        pocketBase.recommendationRecords = [TestFixtures.recommendation(id: "recommendation-a", snapshotID: "snapshot-a"), TestFixtures.recommendation(id: "recommendation-b", snapshotID: "snapshot-b")]
        pocketBase.suspendFirstSnapshotRequest = true
        let session = try await TestFixtures.session(pocketBase: pocketBase)
        let viewModel = HomeViewModel(session: session, pollIntervalNanoseconds: 0)

        let firstLoad = Task { await viewModel.load(connectionID: "connection-a") }
        for _ in 0..<20 {
            if pocketBase.isFirstSnapshotRequestSuspended { break }
            await Task.yield()
        }
        #expect(pocketBase.isFirstSnapshotRequestSuspended)

        session.selectConnection("connection-b")
        await viewModel.load(connectionID: "connection-b")
        pocketBase.resumeFirstSnapshotRequest()
        await firstLoad.value

        #expect(viewModel.snapshot?.connection == "connection-b")
        #expect(viewModel.recommendations.map(\.id) == ["recommendation-b"])
    }

    @Test func reviewConflictDoesNotEndTheMobileSession() async throws {
        let leaguePilot = MockLeaguePilot()
        leaguePilot.reviewError = LeaguePilotError(status: 409, message: "Recommendation is no longer reviewable")
        let session = try await TestFixtures.session(leaguePilot: leaguePilot)

        await #expect(throws: LeaguePilotError.self) {
            try await session.reviewRecommendation(id: "recommendation-a", decision: .approved)
        }
        #expect(session.isSignedIn)
    }

    @Test func reviewFailureDoesNotEndTheMobileSession() async throws {
        let leaguePilot = MockLeaguePilot()
        leaguePilot.reviewError = LeaguePilotError(status: 500, message: "The review service is unavailable")
        let session = try await TestFixtures.session(leaguePilot: leaguePilot)

        await #expect(throws: LeaguePilotError.self) {
            try await session.reviewRecommendation(id: "recommendation-a", decision: .dismissed)
        }
        #expect(session.isSignedIn)
    }

    @Test func realtimeEventsInvalidateViewsAndSignOutCleansUpLifecycle() async throws {
        let realtime = MockRealtime()
        let session = try await TestFixtures.session(realtime: realtime)
        for _ in 0..<20 {
            if !realtime.collections.isEmpty { break }
            await Task.yield()
        }
        #expect(session.isReceivingRealtimeUpdates)
        #expect(Set(realtime.collections) == Set(["espn_connections", "job_runs", "recommendations", "reports", "league_snapshots"]))

        realtime.send(PocketBaseRealtimeEvent(action: "update", record: PocketBaseRealtimeRecord(id: "recommendation-a", collectionName: "recommendations")))
        for _ in 0..<20 {
            if session.realtimeRevision == 1 { break }
            await Task.yield()
        }
        #expect(session.realtimeRevision == 1)

        session.signOut()
        #expect(!session.isReceivingRealtimeUpdates)
    }
}

@MainActor
private final class MockPocketBase: PocketBaseServicing {
    var connectionsRecords = [TestFixtures.connection(id: "connection-a", name: "Alpha"), TestFixtures.connection(id: "connection-b", name: "Bravo")]
    var snapshotRecords: [LeagueSnapshotRecord] = []
    var recommendationRecords: [Recommendation] = []
    var reportRecords: [WeeklyReport] = []
    var jobsByConnection: [String: [AnalysisJob]] = [:]
    var suspendFirstSnapshotRequest = false
    private var snapshotContinuation: CheckedContinuation<[LeagueSnapshotRecord], Error>?
    private(set) var isFirstSnapshotRequestSuspended = false

    func authWithPassword(email: String, password: String) async throws -> PBAuthResponse { TestFixtures.auth }
    func authRefresh(token: String) async throws -> PBAuthResponse { TestFixtures.auth }
    func createUser(name: String, email: String, password: String) async throws {}
    func connections(workspaceID: String, token: String) async throws -> [ESPNConnection] { connectionsRecords }
    func jobs(workspaceID: String, connectionID: String, token: String) async throws -> [AnalysisJob] { jobsByConnection[connectionID] ?? [] }
    func job(id: String, token: String) async throws -> AnalysisJob { throw LeaguePilotError(status: 404, message: "Not found") }

    func snapshots(workspaceID: String, token: String) async throws -> [LeagueSnapshotRecord] {
        if suspendFirstSnapshotRequest, !isFirstSnapshotRequestSuspended {
            isFirstSnapshotRequestSuspended = true
            return try await withCheckedThrowingContinuation { continuation in
                snapshotContinuation = continuation
            }
        }
        return snapshotRecords
    }

    func resumeFirstSnapshotRequest() {
        snapshotContinuation?.resume(returning: snapshotRecords)
        snapshotContinuation = nil
    }

    func recommendations(workspaceID: String, token: String) async throws -> [Recommendation] { recommendationRecords }
    func reports(workspaceID: String, token: String) async throws -> [WeeklyReport] { reportRecords }
}

@MainActor
private final class MockLeaguePilot: LeaguePilotServicing {
    var reviewError: Error?

    func bootstrap(token: String) async throws -> BootstrapResponse { TestFixtures.bootstrap }
    func runAnalysis(workspaceID: String, connectionID: String, token: String) async throws -> AnalysisQueueResponse { throw LeaguePilotError(status: nil, message: "Not used") }
    func saveESPNConnection(workspaceID: String, connection: ESPNConnectionRequest, token: String) async throws -> ConnectionSaveResponse { throw LeaguePilotError(status: nil, message: "Not used") }
    func sync(connectionID: String, token: String) async throws -> SyncQueueResponse { throw LeaguePilotError(status: nil, message: "Not used") }
    func reviewRecommendation(id: String, decision: RecommendationDecision, token: String) async throws -> RecommendationReviewResponse {
        if let reviewError { throw reviewError }
        return RecommendationReviewResponse(id: id, status: decision == .approved ? .approved : .dismissed, espnActionExecuted: false)
    }
}

@MainActor
private final class MockRealtime: PocketBaseRealtimeServicing {
    private var continuation: AsyncThrowingStream<PocketBaseRealtimeEvent, Error>.Continuation?
    private(set) var collections: [String] = []

    func events(token: String, collections: [String]) -> AsyncThrowingStream<PocketBaseRealtimeEvent, Error> {
        self.collections = collections
        return AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    func send(_ event: PocketBaseRealtimeEvent) {
        continuation?.yield(event)
    }
}

@MainActor
private final class MockKeychain: KeychainStoring {
    private var token: String?
    func set(_ value: String, for key: KeychainStore.Key) throws { token = value }
    func string(for key: KeychainStore.Key) throws -> String? { token }
    func removeAll() throws { token = nil }
}

@MainActor
private enum TestFixtures {
    static let auth = PBAuthResponse(token: "test-token", record: PBUser(id: "user-a", email: "manager@example.com", name: "Manager"))
    static let bootstrap = BootstrapResponse(profile: Profile(id: "profile-a", displayName: "Manager", plan: "free", onboardingComplete: true, timezone: "America/New_York"), workspace: Workspace(id: "workspace-a", name: "My League", slug: "my-league", plan: "free", status: "active"))

    static func session(pocketBase: MockPocketBase? = nil, leaguePilot: MockLeaguePilot? = nil, realtime: MockRealtime? = nil) async throws -> SessionStore {
        let session = SessionStore(
            pocketBase: pocketBase ?? MockPocketBase(),
            leaguePilot: leaguePilot ?? MockLeaguePilot(),
            keychain: MockKeychain(),
            realtime: realtime ?? MockRealtime()
        )
        try await session.signIn(email: "manager@example.com", password: "password")
        return session
    }

    static func connection(id: String, name: String) -> ESPNConnection {
        ESPNConnection(id: id, workspace: "workspace-a", leagueID: 123, teamID: 1, season: 2026, isPublic: true, leagueName: name, status: .connected, lastError: "", lastSyncedAt: "2026-08-28T12:00:00Z", nextSyncAt: nil, syncFailures: 0, created: "2026-08-28T11:00:00Z", updated: nil)
    }

    static func snapshot(id: String, connectionID: String, teamName: String) -> LeagueSnapshotRecord {
        let player = LeaguePlayer(id: "player-\(id)", name: "Player", position: "QB", proTeam: "BUF", projectedPoints: 20, seasonPoints: 60, averagePoints: 20, injuryStatus: "ACTIVE", currentSlot: "QB", eligibleSlots: ["QB"], opponent: "MIA", percentOwned: 90)
        let mine = LeagueTeam(id: 1, name: teamName, owner: "Me", wins: 2, losses: 1, ties: 0, pointsFor: 300, projectedTotal: 110, roster: [player])
        let opponent = LeagueTeam(id: 2, name: "Opponent", owner: "Them", wins: 3, losses: 0, ties: 0, pointsFor: 320, projectedTotal: 105, roster: [])
        let payload = LeagueSnapshotPayload(leagueID: 123, leagueName: teamName, season: 2026, week: 3, scoringFormat: "PPR", myTeamID: 1, rosterSlots: ["QB"], teams: [mine, opponent], freeAgents: [], matchups: [LeagueMatchup(week: 3, homeTeamID: 1, awayTeamID: 2, homeScore: 0, awayScore: 0, homeProjected: 110, awayProjected: 105)], dataQualityWarnings: [], fetchedAt: "2026-08-28T12:00:00Z")
        return LeagueSnapshotRecord(id: id, workspace: "workspace-a", connection: connectionID, week: 3, payload: payload, fetchedAt: "2026-08-28T12:00:00Z", expiresAt: nil, created: nil)
    }

    static func recommendation(id: String, snapshotID: String) -> Recommendation {
        Recommendation(id: id, workspace: "workspace-a", snapshot: snapshotID, kind: "lineup", title: id, summary: "Summary", confidence: 90, impactPoints: 1, payload: nil, status: .proposed, expiresAt: nil, reviewedAt: nil, created: nil, updated: nil)
    }
}
