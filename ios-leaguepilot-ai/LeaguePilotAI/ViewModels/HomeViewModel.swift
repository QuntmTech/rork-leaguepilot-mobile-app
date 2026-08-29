import Foundation
import Observation

@MainActor @Observable
final class HomeViewModel {
    private(set) var latestJob: AnalysisJob?
    private(set) var recommendations: [Recommendation] = []
    private(set) var isRunningAnalysis = false
    private(set) var hasLoadedOnce = false
    var errorMessage: String?
    var pollingMessage: String?
    private let session: SessionStore
    private var pollTask: Task<Void, Never>?
    private let pollIntervalNanoseconds: UInt64
    private let maxPollAttempts: Int

    init(session: SessionStore, pollIntervalNanoseconds: UInt64 = 3_000_000_000, maxPollAttempts: Int = 40) {
        self.session = session; self.pollIntervalNanoseconds = pollIntervalNanoseconds; self.maxPollAttempts = maxPollAttempts
    }
    var selectedConnection: ESPNConnection? { session.selectedConnection }
    var activeConnections: [ESPNConnection] { session.activeConnections }

    func refresh() async {
        do { try await session.refreshConnections(); latestJob = try await session.loadLatestJob(); recommendations = try await session.loadRecommendations(); errorMessage = nil }
        catch { errorMessage = FriendlyError.message(for: error) }
        hasLoadedOnce = true
    }
    func selectConnection(_ id: String) async { session.selectConnection(id); await refresh() }
    func runAnalysis() async {
        guard !isRunningAnalysis else { return }; isRunningAnalysis = true; defer { isRunningAnalysis = false }
        do { let response = try await session.runAnalysis(); latestJob = AnalysisJob.queued(from: response, workspace: session.workspace?.id ?? ""); errorMessage = nil; startPolling(jobID: response.jobID) }
        catch { errorMessage = FriendlyError.message(for: error) }
    }
    func sync() async { do { let response = try await session.syncSelectedConnection(); latestJob = AnalysisJob(id: response.jobID, workspace: session.workspace?.id ?? "", connection: session.selectedConnectionID, kind: "sync", status: response.status, attempts: nil, scheduledFor: nil, startedAt: nil, completedAt: nil, lastError: nil, created: nil, updated: nil); startPolling(jobID: response.jobID) } catch { errorMessage = FriendlyError.message(for: error) } }
    func cancelPolling() { pollTask?.cancel(); pollTask = nil }
    func startPolling(jobID: String) { cancelPolling(); pollTask = Task { [weak self] in await self?.poll(jobID: jobID) } }
    func poll(jobID: String) async {
        pollingMessage = nil
        for _ in 0..<maxPollAttempts {
            guard !Task.isCancelled else { return }
            do { let job = try await session.loadJob(id: jobID); latestJob = job; if job.status.isTerminal { if job.status == .succeeded { recommendations = try await session.loadRecommendations() }; return } }
            catch { if !Task.isCancelled { errorMessage = FriendlyError.message(for: error) }; return }
            if pollIntervalNanoseconds > 0 { try? await Task.sleep(nanoseconds: pollIntervalNanoseconds) }
        }
        if !Task.isCancelled { pollingMessage = "Still waiting for the worker. Pull down to refresh." }
    }
}
