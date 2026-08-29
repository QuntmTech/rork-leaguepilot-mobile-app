import Foundation
import Observation

@MainActor @Observable
final class ConnectESPNViewModel {
    var leagueID = ""; var teamID = ""; var season = LeaguePilotConfig.defaultSeason; var isPrivate = false
    var espnS2 = ""; var swid = ""
    private(set) var isSaving = false; private(set) var didSave = false
    var errorMessage: String?
    private let session: SessionStore
    init(session: SessionStore) { self.session = session }
    var canSave: Bool {
        guard positive(leagueID) != nil, positive(teamID) != nil, let year = Int(season.trimmingCharacters(in: .whitespacesAndNewlines)), (2019...2100).contains(year) else { return false }
        return !isPrivate || (!espnS2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !swid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    func save() async {
        guard canSave, !isSaving, let league = positive(leagueID), let team = positive(teamID), let year = Int(season.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        isSaving = true; errorMessage = nil; defer { isSaving = false; clearSensitiveFields() }
        do { _ = try await session.saveESPNConnection(ESPNConnectionRequest(leagueID: league, teamID: team, season: year, isPublic: !isPrivate, espnS2: isPrivate ? espnS2.trimmingCharacters(in: .whitespacesAndNewlines) : nil, swid: isPrivate ? swid.trimmingCharacters(in: .whitespacesAndNewlines) : nil)); didSave = true }
        catch { errorMessage = FriendlyError.message(for: error) }
    }
    func clearSensitiveFields() { espnS2 = ""; swid = "" }
    private func positive(_ value: String) -> Int? { guard let number = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)), number > 0 else { return nil }; return number }
}
