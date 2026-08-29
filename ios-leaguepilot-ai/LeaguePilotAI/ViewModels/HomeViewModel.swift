import Foundation
import Observation

/// Drives Home: pull-to-refresh, latest job, newest recommendations, run analysis.
@MainActor
@Observable
final class HomeViewModel {
    private(set) var latestJob: AnalysisJob?
    private(set) var recommendations: [Recommendation] = []
    private(set) var isRefreshing = false
    private(set) var isRunningAnalysis = false
    private(set) var hasLoadedOnce = false

    var errorMessage: String?

    private let session: SessionStore
    private let leaguePilot = LeaguePilotService()

    init(session: SessionStore) {
        self.session = session
    }

    /// Pull-to-refresh: workspace state, latest job, newest recommendations.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await session.refreshWorkspace()
            async let job = session.loadLatestJob()
            async let items = session.loadRecommendations()
            latestJob = try await job
            recommendations = try await items
            errorMessage = nil
        } catch {
            errorMessage = FriendlyError.message(for: error)
        }
        hasLoadedOnce = true
    }

    /// Queues a full analysis run, then refreshes the visible job state.
    func runAnalysis() async {
        guard let workspace = session.workspace,
              let token = session.authToken,
              !isRunningAnalysis else { return }
        isRunningAnalysis = true
        defer { isRunningAnalysis = false }
        do {
            try await leaguePilot.runAnalysis(workspaceID: workspace.id, token: token)
            latestJob = try? await session.loadLatestJob()
            errorMessage = nil
        } catch {
            errorMessage = FriendlyError.message(for: error)
        }
    }
}
