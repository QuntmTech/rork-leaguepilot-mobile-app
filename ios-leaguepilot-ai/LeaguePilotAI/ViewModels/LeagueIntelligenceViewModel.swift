import Foundation
import Observation

@MainActor @Observable
final class LeagueIntelligenceViewModel {
    private(set) var data: SelectedLeagueData?
    private(set) var hasLoadedOnce = false
    var errorMessage: String?
    private let session: SessionStore
    private var displayedConnectionID: String?

    init(session: SessionStore) {
        self.session = session
    }

    func load(connectionID: String?) async {
        guard let connectionID else {
            data = nil
            errorMessage = nil
            hasLoadedOnce = true
            return
        }
        if displayedConnectionID != connectionID {
            data = nil
            errorMessage = nil
            displayedConnectionID = connectionID
        }

        do {
            let result = try await session.loadLeagueData(for: connectionID)
            guard !Task.isCancelled, session.selectedConnectionID == connectionID else { return }
            data = result
            errorMessage = nil
        } catch {
            guard !Task.isCancelled, session.selectedConnectionID == connectionID else { return }
            errorMessage = FriendlyError.message(for: error)
        }
        if !Task.isCancelled, session.selectedConnectionID == connectionID { hasLoadedOnce = true }
    }
}
