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
        #expect(snapshot.payload?.myTeam?.name == "My Team")
        #expect(snapshot.payload?.currentOpponent?.name == "Opponent")
        #expect(snapshot.payload?.myTeam?.starters.count == 1)

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
        #expect(JobStatus.allCases == [.queued, .running, .succeeded, .failed, .cancelled, .deadLetter])
        #expect(JobStatus.queued.isPending && JobStatus.running.isPending)
        #expect(JobStatus.succeeded.isTerminal && JobStatus.failed.isTerminal && JobStatus.cancelled.isTerminal && JobStatus.deadLetter.isTerminal)
        #expect(JobStatus.queued.label == "Queued")
        #expect(JobStatus.running.label == "Running")
        #expect(JobStatus.succeeded.label == "Succeeded")
        #expect(JobStatus.failed.label == "Failed")
        #expect(JobStatus.cancelled.label == "Cancelled")
        #expect(JobStatus.deadLetter.label == "Could not complete")
    }

    @Test func decodesEveryBackendJobStatus() throws {
        for status in JobStatus.allCases {
            let data = Data("""
            {"id":"job-\(status.rawValue)","workspace":"workspace-a","connection":"connection-a","kind":"analysis","status":"\(status.rawValue)"}
            """.utf8)
            #expect(try JSONDecoder().decode(AnalysisJob.self, from: data).status == status)
        }
    }

    @Test func snapshotDecodingKeepsMissingFactsUnavailable() throws {
        let snapshot = try JSONDecoder().decode(LeagueSnapshotRecord.self, from: Data("""
        {"id":"snapshot-a","workspace":"workspace-a","connection":"connection-a","week":3,"schema_version":2,"fetched_at":"2026-08-28T12:00:00Z","payload":{"league_id":123,"league_name":"Sunday League","season":2026,"week":3,"my_team_id":1,"teams":[{"id":1,"name":"My Team","roster":[{"id":"player-a","name":"Starter","position":"QB"}]}],"fetched_at":"2026-08-28T12:00:00Z"}}
        """.utf8))

        let payload = try #require(snapshot.payload)
        let player = try #require(payload.myTeam?.roster?.first)
        #expect(snapshot.schemaVersion == 2)
        #expect(payload.scoringFormat == nil)
        #expect(payload.freeAgents == nil && payload.matchups == nil && payload.dataQualityWarnings == nil)
        #expect(player.proTeam == nil)
        #expect(player.injuryStatus == nil)
        #expect(player.currentSlot == nil)
        #expect(!player.isStarter)
        #expect(!player.isBenchOrIR)
        #expect(player.projectedPoints == nil)
        #expect(player.projectedPointsLabel == "Unavailable")
        #expect(payload.myTeam?.record == "Unavailable")
        #expect(payload.myTeam?.pointsForLabel == "Unavailable")
    }

    @Test func explicitBackendZerosRemainVisibleWhileMissingValuesDoNotBecomeZeros() {
        let player = LeaguePlayer(id: "player-a", name: "Starter", position: "QB", projectedPoints: 0, injuryStatus: "ACTIVE", currentSlot: "QB")
        let team = LeagueTeam(id: 1, name: "My Team", wins: 0, losses: 0, ties: 0, pointsFor: 0, roster: [player])
        #expect(player.projectedPointsLabel == "0.0 proj")
        #expect(team.record == "0-0")
        #expect(team.pointsForLabel == "0.0")
    }

    @Test func snapshotsWithMissingRequiredRelationshipsAreQuarantined() {
        let payload = LeagueSnapshotPayload(
            leagueID: 123,
            leagueName: "Sunday League",
            season: 2026,
            week: 3,
            myTeamID: 99,
            teams: [LeagueTeam(id: 1, name: "Unrelated Team")],
            fetchedAt: "2026-08-28T12:00:00Z"
        )
        let snapshot = LeagueSnapshotRecord(id: "snapshot-invalid", workspace: "workspace-a", connection: "connection-a", week: 3, payload: payload, fetchedAt: "2026-08-28T12:00:00Z")
        #expect(!snapshot.isUsable)
        #expect(snapshot.metadataWarnings.contains { $0.contains("missing the manager team relationship") })
    }

    @Test func malformedAndNewerSnapshotSchemasAreQuarantinedWithHonestWarnings() throws {
        let malformed = try JSONDecoder().decode(LeagueSnapshotRecord.self, from: Data("""
        {"id":"snapshot-bad","workspace":"workspace-a","connection":"connection-a","week":3,"schema_version":2,"fetched_at":"2026-08-28T12:00:00Z","payload":"not a snapshot"}
        """.utf8))
        #expect(!malformed.isUsable)
        #expect(malformed.metadataWarnings.contains { $0.contains("unreadable payload") })

        let newer = LeagueSnapshotRecord(
            id: "snapshot-newer",
            workspace: "workspace-a",
            connection: "connection-a",
            week: 3,
            payload: TestFixtures.snapshotPayload(teamName: "Alpha"),
            schemaVersion: 3,
            fetchedAt: "2026-08-28T12:00:00Z"
        )
        #expect(newer.isUsable)
        #expect(newer.metadataWarnings.contains { $0.contains("outside this app’s verified compatibility range") })
    }

    @Test func backendExpiredSnapshotsRemainVisibleWithAnExplicitWarning() {
        let stale = TestFixtures.snapshot(
            id: "snapshot-stale",
            connectionID: "connection-a",
            teamName: "Alpha",
            expiresAt: "2000-01-01T00:00:00Z"
        )
        #expect(stale.isUsable)
        #expect(stale.isExpired)
        #expect(stale.metadataWarnings.contains { $0.contains("backend marked this snapshot expired") })
    }

    @Test func unreadableExpiryTimestampProducesAnHonestWarning() {
        let snapshot = TestFixtures.snapshot(
            id: "snapshot-bad-expiry",
            connectionID: "connection-a",
            teamName: "Alpha",
            expiresAt: "not-a-timestamp"
        )
        #expect(!snapshot.isExpired)
        #expect(snapshot.metadataWarnings.contains("The backend expiry timestamp could not be read."))
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

    @Test func ignoresOlderSameLeagueReloadAfterANewerRequestStarts() async throws {
        let pocketBase = MockPocketBase()
        pocketBase.snapshotRecords = [TestFixtures.snapshot(id: "snapshot-old", connectionID: "connection-a", teamName: "Old Alpha")]
        pocketBase.suspendFirstSnapshotRequest = true
        let session = try await TestFixtures.session(pocketBase: pocketBase)
        let viewModel = HomeViewModel(session: session, pollIntervalNanoseconds: 0)

        let firstLoad = Task { await viewModel.load(connectionID: "connection-a") }
        for _ in 0..<20 {
            if pocketBase.isFirstSnapshotRequestSuspended { break }
            await Task.yield()
        }
        #expect(pocketBase.isFirstSnapshotRequestSuspended)

        pocketBase.snapshotRecords = [TestFixtures.snapshot(id: "snapshot-new", connectionID: "connection-a", teamName: "New Alpha")]
        await viewModel.load(connectionID: "connection-a")
        pocketBase.resumeFirstSnapshotRequest()
        await firstLoad.value

        #expect(viewModel.snapshot?.id == "snapshot-new")
        #expect(viewModel.snapshot?.payload?.leagueName == "New Alpha")
    }

    @Test func skipsMalformedNewestSnapshotAndShowsTheLatestUsableSnapshot() async throws {
        let pocketBase = MockPocketBase()
        pocketBase.snapshotRecords = [
            LeagueSnapshotRecord(id: "broken", workspace: "workspace-a", connection: "connection-a", week: 3, payload: nil, schemaVersion: 2, fetchedAt: "2026-08-28T13:00:00Z"),
            TestFixtures.snapshot(id: "usable", connectionID: "connection-a", teamName: "Alpha")
        ]
        let session = try await TestFixtures.session(pocketBase: pocketBase)

        let data = try await session.loadLeagueData(for: "connection-a")
        #expect(data.snapshot?.id == "usable")
        #expect(data.dataWarnings.contains { $0.contains("newest stored snapshot could not be read") })
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
        for _ in 0..<20 {
            if await realtime.terminationCount() > 0 { break }
            await Task.yield()
        }
        #expect(await realtime.terminationCount() > 0)
    }

    @Test func aWebReviewEventRefreshesTheSelectedLeagueRecommendationData() async throws {
        let pocketBase = MockPocketBase()
        pocketBase.snapshotRecords = [TestFixtures.snapshot(id: "snapshot-a", connectionID: "connection-a", teamName: "Alpha")]
        pocketBase.recommendationRecords = [TestFixtures.recommendation(id: "recommendation-a", snapshotID: "snapshot-a", status: .proposed)]
        let realtime = MockRealtime()
        let session = try await TestFixtures.session(pocketBase: pocketBase, realtime: realtime)
        let viewModel = HomeViewModel(session: session, pollIntervalNanoseconds: 0)
        await viewModel.load(connectionID: "connection-a")
        #expect(viewModel.recommendations.first?.status == .proposed)

        for _ in 0..<20 {
            if !realtime.collections.isEmpty { break }
            await Task.yield()
        }
        #expect(!realtime.collections.isEmpty)

        pocketBase.recommendationRecords = [TestFixtures.recommendation(id: "recommendation-a", snapshotID: "snapshot-a", status: .approved)]
        realtime.send(PocketBaseRealtimeEvent(action: "update", record: PocketBaseRealtimeRecord(id: "recommendation-a", collectionName: "recommendations")))
        for _ in 0..<20 {
            if session.realtimeRevision > 0 { break }
            await Task.yield()
        }
        await viewModel.load(connectionID: "connection-a")
        #expect(viewModel.recommendations.first?.status == .approved)
    }

    @Test func expiredForegroundAndRealtimeSessionsSignOutWithoutRestartLoops() async throws {
        let pocketBase = MockPocketBase()
        let session = try await TestFixtures.session(pocketBase: pocketBase)
        pocketBase.authRefreshError = LeaguePilotError(status: 401, message: "Expired")
        await session.refreshSessionOnForeground()
        #expect(session.phase == .signedOut)
        #expect(!session.isReceivingRealtimeUpdates)

        let realtime = MockRealtime()
        let realtimeSession = try await TestFixtures.session(realtime: realtime)
        for _ in 0..<20 {
            if !realtime.collections.isEmpty { break }
            await Task.yield()
        }
        #expect(!realtime.collections.isEmpty)
        realtime.finish(throwing: LeaguePilotError(status: 401, message: "Expired"))
        for _ in 0..<20 {
            if realtimeSession.phase == .signedOut { break }
            await Task.yield()
        }
        #expect(realtimeSession.phase == .signedOut)
        #expect(!realtimeSession.isReceivingRealtimeUpdates)
    }

    @Test func anIsolatedRealtime403KeepsAConfirmedValidSession() async throws {
        let pocketBase = MockPocketBase()
        let realtime = MockRealtime()
        let session = try await TestFixtures.session(pocketBase: pocketBase, realtime: realtime)
        for _ in 0..<20 {
            if !realtime.collections.isEmpty { break }
            await Task.yield()
        }
        realtime.finish(throwing: LeaguePilotError(status: 403, message: "Subscription forbidden"))
        for _ in 0..<20 {
            if session.realtimeErrorMessage != nil { break }
            await Task.yield()
        }
        #expect(session.isSignedIn)
        #expect(session.phase == .ready)
        #expect(!session.isReceivingRealtimeUpdates)
        #expect(session.realtimeErrorMessage?.contains("does not have permission") == true)
        #expect(pocketBase.authRefreshCount == 1)
    }

    @Test func realtimeRetryBackoffIsBoundedAndResetsAfterAHealthyConnection() {
        var backoff = RealtimeReconnectBackoff()
        #expect(backoff.nextDelayNanoseconds(afterHealthyConnection: false, randomUnit: 0) == 500_000_000)
        backoff.reset()
        #expect(backoff.nextDelayNanoseconds(afterHealthyConnection: false, randomUnit: 1) == 1_000_000_000)
        #expect(backoff.nextDelayNanoseconds(afterHealthyConnection: false, randomUnit: 1) == 2_000_000_000)
        for _ in 0..<10 {
            #expect(backoff.nextDelayNanoseconds(afterHealthyConnection: false, randomUnit: 1) <= RealtimeReconnectBackoff.maximumDelayNanoseconds)
        }
        #expect(backoff.nextDelayNanoseconds(afterHealthyConnection: true, randomUnit: 1) == 1_000_000_000)
        #expect(backoff.consecutiveFailures == 1)
    }

    @Test func reportsRankingsAndPathToFirstStayBoundToTheSelectedSnapshot() {
        let snapshot = TestFixtures.snapshot(id: "snapshot-a", connectionID: "connection-a", teamName: "Alpha")
        let currentReport = TestFixtures.report(id: "report-a", snapshotID: "snapshot-a", rankings: [
            PowerRanking(teamID: 2, team: "Opponent", score: 90, recordScore: 90, pointsScore: 90, projectionScore: 90, projectedTotal: 110),
            PowerRanking(teamID: 1, team: "Alpha", score: 80, recordScore: 80, pointsScore: 80, projectionScore: 80, projectedTotal: 100)
        ])
        let otherReport = TestFixtures.report(id: "report-b", snapshotID: "other", rankings: [PowerRanking(teamID: 1, team: "Alpha", score: 100, recordScore: 100, pointsScore: 100, projectionScore: 100, projectedTotal: 120)])
        let data = SelectedLeagueData(connectionID: "connection-a", snapshot: snapshot, recommendations: [TestFixtures.recommendation(id: "rec-a", snapshotID: "snapshot-a", status: .proposed)], reports: [otherReport, currentReport], jobs: [], dataWarnings: [])

        #expect(data.powerRankings == currentReport.powerRankings)
        let path = PathToFirstSummary.make(snapshot: snapshot, rankings: data.powerRankings, recommendations: data.recommendations)
        #expect(path?.rank == 2)
        #expect(path?.leaderGap == 10)
        #expect(path?.proposedRecommendationCount == 1)
        #expect(path?.positiveImpactPoints == 1)
        #expect(PathToFirstSummary.make(snapshot: snapshot, rankings: [], recommendations: data.recommendations) == nil)

        let missingImpact = TestFixtures.recommendation(id: "rec-no-impact", snapshotID: "snapshot-a", status: .proposed, impactPoints: nil)
        let missingImpactPath = PathToFirstSummary.make(snapshot: snapshot, rankings: data.powerRankings, recommendations: [missingImpact])
        #expect(missingImpactPath?.positiveImpactPoints == nil)
    }

    @Test func opponentRosterDataExcludesTheManagerTeam() {
        let payload = TestFixtures.snapshotPayload(teamName: "Alpha")
        #expect(payload.currentOpponent?.name == "Opponent")
        #expect(payload.opponentTeams.map(\.name) == ["Opponent"])
    }
}

@MainActor
private final class MockPocketBase: PocketBaseServicing {
    var connectionsRecords = [TestFixtures.connection(id: "connection-a", name: "Alpha"), TestFixtures.connection(id: "connection-b", name: "Bravo")]
    var snapshotRecords: [LeagueSnapshotRecord] = []
    var recommendationRecords: [Recommendation] = []
    var reportRecords: [WeeklyReport] = []
    var jobsByConnection: [String: [AnalysisJob]] = [:]
    var authRefreshError: Error?
    private(set) var authRefreshCount = 0
    var suspendFirstSnapshotRequest = false
    private var snapshotContinuation: CheckedContinuation<[LeagueSnapshotRecord], Error>?
    private var suspendedSnapshotResult: [LeagueSnapshotRecord] = []
    private(set) var isFirstSnapshotRequestSuspended = false

    func authWithPassword(email: String, password: String) async throws -> PBAuthResponse { TestFixtures.auth }
    func authRefresh(token: String) async throws -> PBAuthResponse {
        authRefreshCount += 1
        if let authRefreshError { throw authRefreshError }
        return TestFixtures.auth
    }
    func createUser(name: String, email: String, password: String) async throws {}
    func connections(workspaceID: String, token: String) async throws -> [ESPNConnection] { connectionsRecords }
    func jobs(workspaceID: String, connectionID: String, token: String) async throws -> [AnalysisJob] { jobsByConnection[connectionID] ?? [] }
    func job(id: String, token: String) async throws -> AnalysisJob { throw LeaguePilotError(status: 404, message: "Not found") }

    func snapshots(workspaceID: String, token: String) async throws -> [LeagueSnapshotRecord] {
        if suspendFirstSnapshotRequest, !isFirstSnapshotRequestSuspended {
            isFirstSnapshotRequestSuspended = true
            suspendedSnapshotResult = snapshotRecords
            return try await withCheckedThrowingContinuation { continuation in
                snapshotContinuation = continuation
            }
        }
        return snapshotRecords
    }

    func resumeFirstSnapshotRequest() {
        snapshotContinuation?.resume(returning: suspendedSnapshotResult)
        snapshotContinuation = nil
        suspendedSnapshotResult = []
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
    private let lifecycle = RealtimeLifecycle()

    func events(token: String, collections: [String]) -> AsyncThrowingStream<PocketBaseRealtimeEvent, Error> {
        self.collections = collections
        return AsyncThrowingStream { continuation in
            self.continuation = continuation
            let lifecycle = self.lifecycle
            continuation.onTermination = { _ in
                Task { await lifecycle.recordTermination() }
            }
        }
    }

    func send(_ event: PocketBaseRealtimeEvent) {
        continuation?.yield(event)
    }

    func finish(throwing error: Error? = nil) {
        if let error {
            continuation?.finish(throwing: error)
        } else {
            continuation?.finish()
        }
        continuation = nil
    }

    func terminationCount() async -> Int { await lifecycle.terminationCount() }
}

private actor RealtimeLifecycle {
    private var count = 0
    func recordTermination() { count += 1 }
    func terminationCount() -> Int { count }
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

    static func snapshotPayload(teamName: String) -> LeagueSnapshotPayload {
        let player = LeaguePlayer(id: "player-\(teamName)", name: "Player", position: "QB", proTeam: "BUF", projectedPoints: 20, seasonPoints: 60, averagePoints: 20, injuryStatus: "ACTIVE", currentSlot: "QB", eligibleSlots: ["QB"], opponent: "MIA", percentOwned: 90)
        let mine = LeagueTeam(id: 1, name: teamName, owner: "Me", wins: 2, losses: 1, ties: 0, pointsFor: 300, projectedTotal: 110, roster: [player])
        let opponent = LeagueTeam(id: 2, name: "Opponent", owner: "Them", wins: 3, losses: 0, ties: 0, pointsFor: 320, projectedTotal: 105, roster: [])
        return LeagueSnapshotPayload(leagueID: 123, leagueName: teamName, season: 2026, week: 3, scoringFormat: "PPR", myTeamID: 1, rosterSlots: ["QB"], teams: [mine, opponent], freeAgents: [], matchups: [LeagueMatchup(week: 3, homeTeamID: 1, awayTeamID: 2, homeScore: 0, awayScore: 0, homeProjected: 110, awayProjected: 105)], dataQualityWarnings: [], fetchedAt: "2026-08-28T12:00:00Z")
    }

    static func snapshot(id: String, connectionID: String, teamName: String, expiresAt: String? = nil, schemaVersion: Int? = 2) -> LeagueSnapshotRecord {
        LeagueSnapshotRecord(id: id, workspace: "workspace-a", connection: connectionID, week: 3, payload: snapshotPayload(teamName: teamName), schemaVersion: schemaVersion, fetchedAt: "2026-08-28T12:00:00Z", expiresAt: expiresAt, created: nil)
    }

    static func recommendation(id: String, snapshotID: String, status: RecommendationStatus = .proposed, impactPoints: Double? = 1) -> Recommendation {
        Recommendation(id: id, workspace: "workspace-a", snapshot: snapshotID, kind: "lineup", title: id, summary: "Summary", confidence: 90, impactPoints: impactPoints, payload: nil, status: status, expiresAt: nil, reviewedAt: nil, created: nil, updated: nil)
    }

    static func report(id: String, snapshotID: String, rankings: [PowerRanking]) -> WeeklyReport {
        WeeklyReport(id: id, workspace: "workspace-a", snapshot: snapshotID, week: 3, title: "Week 3", bodyMarkdown: "Facts only", metrics: .object(["power_rankings": .array(rankings.map { ranking in
            .object([
                "team_id": .number(Double(ranking.teamID)),
                "team": .string(ranking.team),
                "score": .number(ranking.score),
                "record_score": .number(ranking.recordScore),
                "points_score": .number(ranking.pointsScore),
                "projection_score": .number(ranking.projectionScore),
                "projected_total": .number(ranking.projectedTotal),
            ])
        })]), narrationMode: "rules", publishedAt: nil, created: nil)
    }
}
