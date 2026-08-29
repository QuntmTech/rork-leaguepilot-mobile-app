import Foundation

// MARK: - PocketBase authentication and pagination

struct PBUser: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let name: String?
}

struct PBAuthResponse: Decodable, Equatable {
    let token: String
    let record: PBUser
}

struct PBList<Item: Decodable>: Decodable {
    let page: Int?
    let perPage: Int?
    let totalItems: Int?
    let totalPages: Int?
    let items: [Item]
}

// MARK: - Bootstrap

struct Profile: Decodable, Equatable {
    let id: String
    let displayName: String
    let plan: String
    let onboardingComplete: Bool
    let timezone: String

    private enum CodingKeys: String, CodingKey {
        case id, plan, timezone
        case displayName = "display_name"
        case onboardingComplete = "onboarding_complete"
    }
}

/// The live bootstrap route returns only profile and workspace. Connections and dashboard records
/// are intentionally loaded through their owner-scoped collections afterwards.
struct Workspace: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let slug: String
    let plan: String
    let status: String
}

struct BootstrapResponse: Decodable, Equatable {
    let profile: Profile
    let workspace: Workspace
}

// MARK: - ESPN connections

enum ESPNConnectionStatus: String, Codable, CaseIterable, Equatable {
    case pending
    case connected
    case expired
    case error
    case disabled

    var label: String {
        switch self {
        case .pending: "Waiting for sync"
        case .connected: "Connected"
        case .expired: "Connection expired"
        case .error: "Needs attention"
        case .disabled: "Disabled"
        }
    }

    var isSelectable: Bool { self != .disabled }
    var isReadyForAnalysis: Bool { self == .connected }
}

struct ESPNConnection: Decodable, Identifiable, Equatable {
    let id: String
    let workspace: String
    let leagueID: Int
    let teamID: Int
    let season: Int
    let isPublic: Bool
    let leagueName: String
    let status: ESPNConnectionStatus
    let lastError: String
    let lastSyncedAt: String?
    let nextSyncAt: String?
    let syncFailures: Int
    let created: String?
    let updated: String?

    private enum CodingKeys: String, CodingKey {
        case id, workspace, season, status, created, updated
        case leagueID = "league_id"
        case teamID = "team_id"
        case isPublic = "is_public"
        case leagueName = "league_name"
        case lastError = "last_error"
        case lastSyncedAt = "last_synced_at"
        case nextSyncAt = "next_sync_at"
        case syncFailures = "sync_failures"
    }

    var displayName: String {
        leagueName.isEmpty ? "League \(leagueID)" : leagueName
    }

    var selectionDate: String { lastSyncedAt ?? created ?? "" }
}

struct ESPNConnectionRequest: Encodable, Equatable {
    let leagueID: Int
    let teamID: Int
    let season: Int
    let isPublic: Bool
    let espnS2: String?
    let swid: String?

    private enum CodingKeys: String, CodingKey {
        case leagueID = "league_id"
        case teamID = "team_id"
        case season
        case isPublic = "is_public"
        case espnS2 = "espn_s2"
        case swid
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leagueID, forKey: .leagueID)
        try container.encode(teamID, forKey: .teamID)
        try container.encode(season, forKey: .season)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encode(espnS2, forKey: .espnS2)
        try container.encode(swid, forKey: .swid)
    }
}

struct ConnectionSaveResponse: Decodable, Equatable {
    let connection: ESPNConnection
    let jobID: String

    private enum CodingKeys: String, CodingKey {
        case connection
        case jobID = "job_id"
    }
}

struct SyncQueueResponse: Decodable, Equatable {
    let queued: Bool
    let jobID: String
    let status: JobStatus

    private enum CodingKeys: String, CodingKey {
        case queued, status
        case jobID = "job_id"
    }
}

// MARK: - Jobs and recommendations

enum JobStatus: String, Codable, CaseIterable, Equatable {
    case queued
    case running
    case succeeded
    case failed
    case cancelled
    case deadLetter = "dead-letter"

    var isPending: Bool { self == .queued || self == .running }
    var isTerminal: Bool { !isPending }

    var label: String {
        switch self {
        case .queued: "Queued"
        case .running: "Running"
        case .succeeded: "Succeeded"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .deadLetter: "Could not complete"
        }
    }
}

struct AnalysisJob: Decodable, Identifiable, Equatable {
    let id: String
    let workspace: String
    let connection: String?
    let kind: String
    let status: JobStatus
    let attempts: Int?
    let scheduledFor: String?
    let startedAt: String?
    let completedAt: String?
    let lastError: String?
    let created: String?
    let updated: String?

    private enum CodingKeys: String, CodingKey {
        case id, workspace, connection, kind, status, attempts, created, updated
        case scheduledFor = "scheduled_for"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case lastError = "last_error"
    }

    static func queued(from response: AnalysisQueueResponse, workspace: String) -> AnalysisJob {
        AnalysisJob(
            id: response.jobID,
            workspace: workspace,
            connection: response.connectionID,
            kind: "full",
            status: response.status,
            attempts: nil,
            scheduledFor: nil,
            startedAt: nil,
            completedAt: nil,
            lastError: nil,
            created: nil,
            updated: nil
        )
    }

    var summaryTitle: String {
        kind == "full" ? "Full analysis" : "\(kind.capitalized) analysis"
    }
}

struct AnalysisQueueResponse: Decodable, Equatable {
    let queued: Bool
    let jobID: String
    let connectionID: String
    let status: JobStatus

    private enum CodingKeys: String, CodingKey {
        case queued, status
        case jobID = "job_id"
        case connectionID = "connection_id"
    }
}

struct AnalysisRequest: Encodable, Equatable {
    let kind: String = "full"
    let notify: Bool = false
    let connectionID: String

    private enum CodingKeys: String, CodingKey {
        case kind, notify
        case connectionID = "connection_id"
    }
}

enum RecommendationStatus: String, Codable, CaseIterable, Equatable {
    case proposed
    case approved
    case dismissed
    case superseded
    case expired
}

enum RecommendationDecision: String, Encodable, Equatable {
    case approved
    case dismissed
}

struct RecommendationReviewRequest: Encodable, Equatable {
    let decision: RecommendationDecision
}

struct RecommendationReviewResponse: Decodable, Equatable {
    let id: String
    let status: RecommendationStatus
    let espnActionExecuted: Bool

    private enum CodingKeys: String, CodingKey {
        case id, status
        case espnActionExecuted = "espn_action_executed"
    }
}

/// A bounded, Codable representation of arbitrary server JSON. The UI only renders known fields.
indirect enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

extension JSONValue {
    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var numberValue: Double? {
        guard case let .number(value) = self else { return nil }
        return value
    }

    var stringArrayValue: [String]? {
        guard case let .array(values) = self else { return nil }
        let strings = values.compactMap(\.stringValue)
        return strings.count == values.count ? strings : nil
    }

    subscript(key: String) -> JSONValue? {
        guard case let .object(values) = self else { return nil }
        return values[key]
    }

    func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

struct Recommendation: Decodable, Identifiable, Equatable {
    let id: String
    let workspace: String
    let snapshot: String?
    let kind: String
    let title: String
    let summary: String
    let confidence: Double?
    let impactPoints: Double?
    let payload: JSONValue?
    let status: RecommendationStatus
    let expiresAt: String?
    let reviewedAt: String?
    let created: String?
    let updated: String?

    private enum CodingKeys: String, CodingKey {
        case id, workspace, snapshot, kind, title, summary, confidence, payload, status, created, updated
        case impactPoints = "impact_points"
        case expiresAt = "expires_at"
        case reviewedAt = "reviewed_at"
    }

    var confidenceLabel: String? {
        guard let confidence else { return nil }
        return "\(Int(confidence.rounded()))% confidence"
    }

    func updating(status: RecommendationStatus, reviewedAt: String? = nil) -> Recommendation {
        Recommendation(
            id: id,
            workspace: workspace,
            snapshot: snapshot,
            kind: kind,
            title: title,
            summary: summary,
            confidence: confidence,
            impactPoints: impactPoints,
            payload: payload,
            status: status,
            expiresAt: expiresAt,
            reviewedAt: reviewedAt ?? self.reviewedAt,
            created: created,
            updated: updated
        )
    }
}

// MARK: - League intelligence

struct LeaguePlayer: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let position: String
    let proTeam: String
    let projectedPoints: Double
    let seasonPoints: Double
    let averagePoints: Double
    let injuryStatus: String
    let currentSlot: String
    let eligibleSlots: [String]
    let opponent: String
    let percentOwned: Double

    private enum CodingKeys: String, CodingKey {
        case id, name, position, opponent
        case proTeam = "pro_team"
        case projectedPoints = "projected_points"
        case seasonPoints = "season_points"
        case averagePoints = "average_points"
        case injuryStatus = "injury_status"
        case currentSlot = "current_slot"
        case eligibleSlots = "eligible_slots"
        case percentOwned = "percent_owned"
    }

    /// These defaults mirror the current worker schema. They only cover fields that the backend
    /// itself marks optional, so older snapshots remain readable without inventing new metrics.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        position = try container.decode(String.self, forKey: .position)
        proTeam = try container.decodeIfPresent(String.self, forKey: .proTeam) ?? "FA"
        projectedPoints = try container.decodeIfPresent(Double.self, forKey: .projectedPoints) ?? 0
        seasonPoints = try container.decodeIfPresent(Double.self, forKey: .seasonPoints) ?? 0
        averagePoints = try container.decodeIfPresent(Double.self, forKey: .averagePoints) ?? 0
        injuryStatus = try container.decodeIfPresent(String.self, forKey: .injuryStatus) ?? "ACTIVE"
        currentSlot = try container.decodeIfPresent(String.self, forKey: .currentSlot) ?? "BE"
        eligibleSlots = try container.decodeIfPresent([String].self, forKey: .eligibleSlots) ?? []
        opponent = try container.decodeIfPresent(String.self, forKey: .opponent) ?? ""
        percentOwned = try container.decodeIfPresent(Double.self, forKey: .percentOwned) ?? 0
    }

    init(id: String, name: String, position: String, proTeam: String = "FA", projectedPoints: Double = 0, seasonPoints: Double = 0, averagePoints: Double = 0, injuryStatus: String = "ACTIVE", currentSlot: String = "BE", eligibleSlots: [String] = [], opponent: String = "", percentOwned: Double = 0) {
        self.id = id
        self.name = name
        self.position = position
        self.proTeam = proTeam
        self.projectedPoints = projectedPoints
        self.seasonPoints = seasonPoints
        self.averagePoints = averagePoints
        self.injuryStatus = injuryStatus
        self.currentSlot = currentSlot
        self.eligibleSlots = eligibleSlots
        self.opponent = opponent
        self.percentOwned = percentOwned
    }

    var isStarter: Bool { currentSlot != "BE" && currentSlot != "IR" }
    var projectedPointsLabel: String? { projectedPoints > 0 ? String(format: "%.1f proj", projectedPoints) : nil }
}

struct LeagueTeam: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let owner: String
    let wins: Int
    let losses: Int
    let ties: Int
    let pointsFor: Double
    let projectedTotal: Double
    let roster: [LeaguePlayer]

    private enum CodingKeys: String, CodingKey {
        case id, name, owner, wins, losses, ties, roster
        case pointsFor = "points_for"
        case projectedTotal = "projected_total"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        owner = try container.decodeIfPresent(String.self, forKey: .owner) ?? ""
        wins = try container.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        losses = try container.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        ties = try container.decodeIfPresent(Int.self, forKey: .ties) ?? 0
        pointsFor = try container.decodeIfPresent(Double.self, forKey: .pointsFor) ?? 0
        projectedTotal = try container.decodeIfPresent(Double.self, forKey: .projectedTotal) ?? 0
        roster = try container.decodeIfPresent([LeaguePlayer].self, forKey: .roster) ?? []
    }

    init(id: Int, name: String, owner: String = "", wins: Int = 0, losses: Int = 0, ties: Int = 0, pointsFor: Double = 0, projectedTotal: Double = 0, roster: [LeaguePlayer] = []) {
        self.id = id
        self.name = name
        self.owner = owner
        self.wins = wins
        self.losses = losses
        self.ties = ties
        self.pointsFor = pointsFor
        self.projectedTotal = projectedTotal
        self.roster = roster
    }

    var record: String { ties > 0 ? "\(wins)-\(losses)-\(ties)" : "\(wins)-\(losses)" }
    var starters: [LeaguePlayer] { roster.filter(\.isStarter) }
    var bench: [LeaguePlayer] { roster.filter { !$0.isStarter } }
}

struct LeagueMatchup: Decodable, Identifiable, Equatable {
    let week: Int
    let homeTeamID: Int
    let awayTeamID: Int
    let homeScore: Double
    let awayScore: Double
    let homeProjected: Double
    let awayProjected: Double

    private enum CodingKeys: String, CodingKey {
        case week
        case homeTeamID = "home_team_id"
        case awayTeamID = "away_team_id"
        case homeScore = "home_score"
        case awayScore = "away_score"
        case homeProjected = "home_projected"
        case awayProjected = "away_projected"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        week = try container.decode(Int.self, forKey: .week)
        homeTeamID = try container.decode(Int.self, forKey: .homeTeamID)
        awayTeamID = try container.decode(Int.self, forKey: .awayTeamID)
        homeScore = try container.decodeIfPresent(Double.self, forKey: .homeScore) ?? 0
        awayScore = try container.decodeIfPresent(Double.self, forKey: .awayScore) ?? 0
        homeProjected = try container.decodeIfPresent(Double.self, forKey: .homeProjected) ?? 0
        awayProjected = try container.decodeIfPresent(Double.self, forKey: .awayProjected) ?? 0
    }

    init(week: Int, homeTeamID: Int, awayTeamID: Int, homeScore: Double = 0, awayScore: Double = 0, homeProjected: Double = 0, awayProjected: Double = 0) {
        self.week = week
        self.homeTeamID = homeTeamID
        self.awayTeamID = awayTeamID
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.homeProjected = homeProjected
        self.awayProjected = awayProjected
    }

    var id: String { "\(week)-\(homeTeamID)-\(awayTeamID)" }

    func opponentID(for teamID: Int) -> Int? {
        homeTeamID == teamID ? awayTeamID : awayTeamID == teamID ? homeTeamID : nil
    }

    func projectedTotal(for teamID: Int) -> Double? {
        homeTeamID == teamID ? homeProjected : awayTeamID == teamID ? awayProjected : nil
    }

    func score(for teamID: Int) -> Double? {
        homeTeamID == teamID ? homeScore : awayTeamID == teamID ? awayScore : nil
    }
}

struct LeagueSnapshotPayload: Decodable, Equatable {
    let leagueID: Int
    let leagueName: String
    let season: Int
    let week: Int
    let scoringFormat: String
    let myTeamID: Int
    let rosterSlots: [String]
    let teams: [LeagueTeam]
    let freeAgents: [LeaguePlayer]
    let matchups: [LeagueMatchup]
    let dataQualityWarnings: [String]
    let fetchedAt: String

    private enum CodingKeys: String, CodingKey {
        case season, week, teams, matchups
        case leagueID = "league_id"
        case leagueName = "league_name"
        case scoringFormat = "scoring_format"
        case myTeamID = "my_team_id"
        case rosterSlots = "roster_slots"
        case freeAgents = "free_agents"
        case dataQualityWarnings = "data_quality_warnings"
        case fetchedAt = "fetched_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leagueID = try container.decode(Int.self, forKey: .leagueID)
        leagueName = try container.decode(String.self, forKey: .leagueName)
        season = try container.decode(Int.self, forKey: .season)
        week = try container.decode(Int.self, forKey: .week)
        scoringFormat = try container.decodeIfPresent(String.self, forKey: .scoringFormat) ?? "Custom"
        myTeamID = try container.decode(Int.self, forKey: .myTeamID)
        rosterSlots = try container.decodeIfPresent([String].self, forKey: .rosterSlots) ?? []
        teams = try container.decode([LeagueTeam].self, forKey: .teams)
        freeAgents = try container.decodeIfPresent([LeaguePlayer].self, forKey: .freeAgents) ?? []
        matchups = try container.decodeIfPresent([LeagueMatchup].self, forKey: .matchups) ?? []
        dataQualityWarnings = try container.decodeIfPresent([String].self, forKey: .dataQualityWarnings) ?? []
        fetchedAt = try container.decode(String.self, forKey: .fetchedAt)
    }

    init(leagueID: Int, leagueName: String, season: Int, week: Int, scoringFormat: String = "Custom", myTeamID: Int, rosterSlots: [String] = [], teams: [LeagueTeam], freeAgents: [LeaguePlayer] = [], matchups: [LeagueMatchup] = [], dataQualityWarnings: [String] = [], fetchedAt: String) {
        self.leagueID = leagueID
        self.leagueName = leagueName
        self.season = season
        self.week = week
        self.scoringFormat = scoringFormat
        self.myTeamID = myTeamID
        self.rosterSlots = rosterSlots
        self.teams = teams
        self.freeAgents = freeAgents
        self.matchups = matchups
        self.dataQualityWarnings = dataQualityWarnings
        self.fetchedAt = fetchedAt
    }

    var myTeam: LeagueTeam? { teams.first { $0.id == myTeamID } }
    var currentMatchup: LeagueMatchup? { matchups.first { $0.week == week && $0.opponentID(for: myTeamID) != nil } }
    var currentOpponent: LeagueTeam? {
        guard let opponentID = currentMatchup?.opponentID(for: myTeamID) else { return nil }
        return teams.first { $0.id == opponentID }
    }

    var opponentTeams: [LeagueTeam] { teams.filter { $0.id != myTeamID } }
}

struct LeagueSnapshotRecord: Decodable, Identifiable, Equatable {
    let id: String
    let workspace: String
    let connection: String?
    let week: Int
    let payload: LeagueSnapshotPayload?
    let contentHash: String?
    let schemaVersion: Int?
    let fetchedAt: String
    let expiresAt: String?
    let created: String?

    private enum CodingKeys: String, CodingKey {
        case id, workspace, connection, week, payload, created
        case contentHash = "content_hash"
        case schemaVersion = "schema_version"
        case fetchedAt = "fetched_at"
        case expiresAt = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        workspace = try container.decode(String.self, forKey: .workspace)
        connection = try container.decodeIfPresent(String.self, forKey: .connection)
        week = try container.decode(Int.self, forKey: .week)
        contentHash = try container.decodeIfPresent(String.self, forKey: .contentHash)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
        fetchedAt = try container.decode(String.self, forKey: .fetchedAt)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
        created = try container.decodeIfPresent(String.self, forKey: .created)

        if let rawPayload = try container.decodeIfPresent(JSONValue.self, forKey: .payload) {
            payload = rawPayload.decode(LeagueSnapshotPayload.self)
        } else {
            payload = nil
        }
    }

    init(id: String, workspace: String, connection: String?, week: Int, payload: LeagueSnapshotPayload?, contentHash: String? = nil, schemaVersion: Int? = nil, fetchedAt: String, expiresAt: String? = nil, created: String? = nil) {
        self.id = id
        self.workspace = workspace
        self.connection = connection
        self.week = week
        self.payload = payload
        self.contentHash = contentHash
        self.schemaVersion = schemaVersion
        self.fetchedAt = fetchedAt
        self.expiresAt = expiresAt
        self.created = created
    }

    var isUsable: Bool { payload != nil }

    var metadataWarnings: [String] {
        var warnings: [String] = []
        if payload == nil {
            warnings.append("This stored snapshot has an unreadable payload and cannot be shown.")
        }
        if let schemaVersion, !(1...2).contains(schemaVersion) {
            warnings.append("Snapshot schema version \(schemaVersion) is outside this app’s verified compatibility range (1–2).")
        }
        if let expiresAt, RelativeTime.date(from: expiresAt) == nil {
            warnings.append("The backend expiry timestamp could not be read.")
        } else if isExpired {
            warnings.append("The backend marked this snapshot expired \(expiresAt.map(RelativeTime.string(from:)) ?? "earlier"). Refresh it before relying on it.")
        }
        return warnings
    }

    var isExpired: Bool {
        guard let expiresAt, let expiration = RelativeTime.date(from: expiresAt) else { return false }
        return expiration <= Date()
    }
}

struct PowerRanking: Decodable, Identifiable, Equatable {
    let teamID: Int
    let team: String
    let score: Double
    let recordScore: Double
    let pointsScore: Double
    let projectionScore: Double
    let projectedTotal: Double

    private enum CodingKeys: String, CodingKey {
        case team, score
        case teamID = "team_id"
        case recordScore = "record_score"
        case pointsScore = "points_score"
        case projectionScore = "projection_score"
        case projectedTotal = "projected_total"
    }

    var id: Int { teamID }
}

struct WeeklyReport: Decodable, Identifiable, Equatable {
    let id: String
    let workspace: String
    let snapshot: String?
    let week: Int
    let title: String
    let bodyMarkdown: String
    let metrics: JSONValue
    let narrationMode: String
    let publishedAt: String?
    let created: String?

    private enum CodingKeys: String, CodingKey {
        case id, workspace, snapshot, week, title, metrics, created
        case bodyMarkdown = "body_markdown"
        case narrationMode = "narration_mode"
        case publishedAt = "published_at"
    }

    var powerRankings: [PowerRanking] { metrics["power_rankings"]?.decode([PowerRanking].self) ?? [] }
}

struct SelectedLeagueData: Equatable {
    let connectionID: String
    let snapshot: LeagueSnapshotRecord?
    let recommendations: [Recommendation]
    let reports: [WeeklyReport]
    let jobs: [AnalysisJob]
    let dataWarnings: [String]

    var powerRankings: [PowerRanking] {
        guard let snapshot else { return [] }
        return reports.first(where: { $0.snapshot == snapshot.id })?.powerRankings ?? []
    }
}

/// A presentation-ready summary built solely from the selected snapshot, its stored report, and
/// recommendations attached to that exact snapshot. A missing report intentionally produces nil.
struct PathToFirstSummary: Equatable {
    let rank: Int
    let teamCount: Int
    let currentScore: Double
    let leaderTeam: String
    let leaderGap: Double
    let proposedRecommendationCount: Int
    let positiveImpactPoints: Double

    static func make(snapshot: LeagueSnapshotRecord?, rankings: [PowerRanking], recommendations: [Recommendation]) -> PathToFirstSummary? {
        guard let snapshot,
              let myTeam = snapshot.payload?.myTeam,
              let rank = rankings.firstIndex(where: { $0.teamID == myTeam.id }).map({ $0 + 1 }),
              let current = rankings.first(where: { $0.teamID == myTeam.id }),
              let leader = rankings.first else {
            return nil
        }
        let proposed = recommendations.filter { $0.snapshot == snapshot.id && $0.status == .proposed }
        return PathToFirstSummary(
            rank: rank,
            teamCount: rankings.count,
            currentScore: current.score,
            leaderTeam: leader.team,
            leaderGap: max(0, leader.score - current.score),
            proposedRecommendationCount: proposed.count,
            positiveImpactPoints: proposed.reduce(0) { $0 + max(0, $1.impactPoints ?? 0) }
        )
    }
}

// MARK: - Account creation

struct SignUpRequest: Encodable, Equatable {
    let name: String
    let email: String
    let password: String
    let passwordConfirm: String

    private enum CodingKeys: String, CodingKey {
        case name, email, password
        case passwordConfirm = "passwordConfirm"
    }
}
