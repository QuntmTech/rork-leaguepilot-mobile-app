import Foundation
import Observation

/// Drives the Connect ESPN form.
/// espn_s2 / SWID live only in these fields and are wiped right after submit.
@MainActor
@Observable
final class ConnectESPNViewModel {
    var leagueID = ""
    var teamID = ""
    var season = LeaguePilotConfig.defaultSeason
    var isPrivate = false
    var espnS2 = ""
    var swid = ""

    private(set) var isSaving = false
    private(set) var didSave = false
    var errorMessage: String?

    var canSave: Bool {
        !trimmed(leagueID).isEmpty
            && !trimmed(teamID).isEmpty
            && Int(season) != nil
    }

    private let session: SessionStore
    private let leaguePilot = LeaguePilotService()

    init(session: SessionStore) {
        self.session = session
    }

    /// PUTs the connection, clears sensitive inputs, and signals success.
    func save() async {
        guard canSave, !isSaving,
              let workspace = session.workspace,
              let token = session.authToken else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let connection = ESPNConnectionRequest(
            leagueId: trimmed(leagueID),
            teamId: trimmed(teamID),
            season: Int(season) ?? 0,
            isPrivate: isPrivate,
            espnS2: isPrivate ? espnS2 : nil,
            swid: isPrivate ? swid : nil
        )
        do {
            try await leaguePilot.saveESPNConnection(workspaceID: workspace.id, connection: connection, token: token)
            espnS2 = ""
            swid = ""
            try? await session.refreshWorkspace()
            didSave = true
        } catch {
            errorMessage = FriendlyError.message(for: error)
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
