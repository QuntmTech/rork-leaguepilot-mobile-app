import Foundation
import Observation

@MainActor @Observable
final class LeagueIntelligenceViewModel {
    private(set) var data: SelectedLeagueData?
    private(set) var hasLoadedOnce = false
    private(set) var isLoading = false
    var errorMessage: String?
    private let session: SessionStore
    private var displayedConnectionID: String?
    private var loadGeneration = 0

    init(session: SessionStore) {
        self.session = session
    }

    func load(connectionID: String?) async {
        loadGeneration &+= 1
        let requestGeneration = loadGeneration
        let selectionRevision = session.selectedLeagueRevision
        isLoading = true
        guard let connectionID else {
            data = nil
            errorMessage = nil
            hasLoadedOnce = true
            isLoading = false
            return
        }
        if displayedConnectionID != connectionID {
            data = nil
            errorMessage = nil
            displayedConnectionID = connectionID
            hasLoadedOnce = false
        }

        do {
            let result = try await session.loadLeagueData(for: connectionID)
            guard isCurrent(requestGeneration, connectionID: connectionID, selectionRevision: selectionRevision) else { return }
            data = result
            errorMessage = nil
        } catch {
            guard isCurrent(requestGeneration, connectionID: connectionID, selectionRevision: selectionRevision) else { return }
            errorMessage = FriendlyError.message(for: error)
        }
        if isCurrent(requestGeneration, connectionID: connectionID, selectionRevision: selectionRevision) {
            hasLoadedOnce = true
            isLoading = false
        }
    }

    private func isCurrent(_ requestGeneration: Int, connectionID: String, selectionRevision: Int) -> Bool {
        !Task.isCancelled && loadGeneration == requestGeneration && session.selectedConnectionID == connectionID && session.selectedLeagueRevision == selectionRevision
    }
}
