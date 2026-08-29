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

    @Test func allLiveJobStatusesHaveHonestTerminalState() {
        #expect(JobStatus.queued.isPending && JobStatus.running.isPending)
        #expect(JobStatus.succeeded.isTerminal && JobStatus.failed.isTerminal && JobStatus.cancelled.isTerminal && JobStatus.deadLetter.isTerminal)
    }
}
