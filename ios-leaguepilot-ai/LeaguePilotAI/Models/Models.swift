import Foundation

// MARK: - Auth

/// Authenticated PocketBase user record.
struct PBUser: Codable, Identifiable {
    let id: String
    let email: String
    var name: String?
}

/// PocketBase auth-with-password / auth-refresh response.
struct PBAuthResponse: Decodable {
    let token: String
    let record: PBUser
}

/// Generic PocketBase list response envelope.
struct PBList<Item: Decodable>: Decodable {
    let items: [Item]
}

// MARK: - Workspace

/// League workspace returned by the bootstrap endpoint.
/// Field decoding is tolerant so schema variations still render.
struct Workspace: Decodable, Identifiable {
    let id: String
    var name: String
    var espnConnected: Bool
    var espnLeagueID: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = ((try? container.decodeIfPresent(String.self, forKey: .id)) ?? nil) ?? ""
        name = ((try? container.decodeIfPresent(String.self, forKey: .name)) ?? nil) ?? "My League"
        espnConnected = ((try? container.decodeIfPresent(Bool.self, forKey: .espnConnected)) ?? nil)
            ?? ((try? container.decodeIfPresent(Bool.self, forKey: .espnConnectedSnake)) ?? nil)
            ?? false
        espnLeagueID = ((try? container.decodeIfPresent(String.self, forKey: .espnLeagueID)) ?? nil)
            ?? ((try? container.decodeIfPresent(String.self, forKey: .leagueID)) ?? nil)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
        case espnConnected
        case espnConnectedSnake = "espn_connected"
        case espnLeagueID = "espnLeagueId"
        case leagueID = "leagueId"
    }
}

// MARK: - Home data

/// Latest analysis job for a workspace.
struct AnalysisJob: Decodable, Identifiable {
    let id: String
    var kind: String
    var status: String
    var created: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = ((try? container.decodeIfPresent(String.self, forKey: .id)) ?? nil) ?? ""
        kind = ((try? container.decodeIfPresent(String.self, forKey: .kind)) ?? nil) ?? "full"
        status = ((try? container.decodeIfPresent(String.self, forKey: .status)) ?? nil) ?? "unknown"
        created = (try? container.decodeIfPresent(String.self, forKey: .created)) ?? nil
    }

    private enum CodingKeys: String, CodingKey { case id, kind, status, created }

    var isPending: Bool {
        ["queued", "pending", "running", "in_progress", "processing"].contains(status.lowercased())
    }

    var statusLabel: String {
        switch status.lowercased() {
        case "queued", "pending": return "Queued"
        case "running", "in_progress", "processing": return "Running"
        case "done", "completed", "success": return "Done"
        case "failed", "error": return "Failed"
        default: return status.capitalized
        }
    }

    var summaryTitle: String {
        kind.lowercased() == "full" ? "Full analysis" : "\(kind.capitalized) analysis"
    }
}

/// One actionable recommendation row shown on Home.
struct Recommendation: Decodable, Identifiable {
    let id: String
    var title: String
    var subtitle: String?
    var confidence: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = ((try? container.decodeIfPresent(String.self, forKey: .id)) ?? nil) ?? ""
        title = (((try? container.decodeIfPresent(String.self, forKey: .title)) ?? nil)
            ?? ((try? container.decodeIfPresent(String.self, forKey: .summary)) ?? nil)) ?? "Recommendation"
        subtitle = ((try? container.decodeIfPresent(String.self, forKey: .matchup)) ?? nil)
            ?? ((try? container.decodeIfPresent(String.self, forKey: .detail)) ?? nil)
        confidence = (try? container.decodeIfPresent(String.self, forKey: .confidence)) ?? nil
    }

    private enum CodingKeys: String, CodingKey { case id, title, summary, matchup, detail, confidence }

    var subtitleLine: String? {
        var parts: [String] = []
        if let subtitle, !subtitle.isEmpty { parts.append(subtitle) }
        if let confidence, !confidence.isEmpty { parts.append("confidence \(confidence)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Requests

/// Body for POST /api/leaguepilot/workspaces/{id}/analysis.
struct AnalysisRequest: Encodable {
    let kind = "full"
    let notify = false
}

/// Body for PUT /api/leaguepilot/workspaces/{id}/connections/espn.
/// Cookie values are optional on purpose so public leagues never send them.
struct ESPNConnectionRequest: Encodable {
    let leagueId: String
    let teamId: String
    let season: Int
    let isPrivate: Bool
    let espnS2: String?
    let swid: String?
}

/// Body for creating a PocketBase user.
struct SignUpRequest: Encodable {
    let name: String
    let email: String
    let password: String
    let passwordConfirm: String
}
