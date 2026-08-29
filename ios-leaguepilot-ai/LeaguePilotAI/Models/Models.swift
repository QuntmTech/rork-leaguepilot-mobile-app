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
}

struct LeagueSnapshotReference: Decodable, Identifiable, Equatable {
    let id: String
    let workspace: String
    let connection: String
    let created: String?
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
