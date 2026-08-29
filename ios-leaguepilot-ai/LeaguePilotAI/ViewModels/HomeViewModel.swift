import Foundation
import Observation

@MainActor @Observable
final class HomeViewModel {
    private(set) var latestJob: AnalysisJob?
    private(set) var recommendations: [Recommendation] = []
    private(set) var snapshot: LeagueSnapshotRecord?
    private(set) var reports: [WeeklyReport] = []
    private(set) var powerRankings: [PowerRanking] = []
    private(set) var isRunningAnalysis = false
    private(set) var hasLoadedOnce = false
    var errorMessage: String?
    var pollingMessage: String?

    private let session: SessionStore
    private var pollTask: Task<Void, Never>?
    private let pollIntervalNanoseconds: UInt64
    private let maxPollAttempts: Int
    private var displayedConnectionID: String?

    init(session: SessionStore, pollIntervalNanoseconds: UInt64 = 3_000_000_000, maxPollAttempts: Int = 40) {
        self.session = session
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
        self.maxPollAttempts = maxPollAttempts
    }

    var selectedConnection: ESPNConnection? { session.selectedConnection }
    var activeConnections: [ESPNConnection] { session.activeConnections }

    /// Reloads one explicit league context. The id check means a response from a previous league
    /// can never overwrite the visible context after the user changes the picker.
    func load(connectionID: String?) async {
        guard let connectionID else {
            clearLeagueData()
            hasLoadedOnce = true
            return
        }
        if displayedConnectionID != connectionID {
            cancelPolling()
            clearLeagueData()
            displayedConnectionID = connectionID
        }

        do {
            let data = try await session.loadLeagueData(for: connectionID)
            guard !Task.isCancelled, session.selectedConnectionID == connectionID else { return }
            apply(data)
            errorMessage = nil
        } catch {
            guard !Task.isCancelled, session.selectedConnectionID == connectionID else { return }
            errorMessage = FriendlyError.message(for: error)
        }
        if !Task.isCancelled, session.selectedConnectionID == connectionID { hasLoadedOnce = true }
    }

    func refresh() async {
        do {
            try await session.refreshConnections()
            await load(connectionID: session.selectedConnectionID)
        } catch {
            errorMessage = FriendlyError.message(for: error)
            hasLoadedOnce = true
        }
    }

    func refreshCurrentLeague() async {
        await load(connectionID: session.selectedConnectionID)
    }

    func selectConnection(_ id: String) {
        session.selectConnection(id)
    }

    func runAnalysis() async {
        guard !isRunningAnalysis, let connectionID = session.selectedConnectionID else { return }
        isRunningAnalysis = true
        defer { isRunningAnalysis = false }
        do {
            let response = try await session.runAnalysis()
            guard !Task.isCancelled, session.selectedConnectionID == connectionID else { return }
            latestJob = AnalysisJob.queued(from: response, workspace: session.workspace?.id ?? "")
            errorMessage = nil
            startPolling(jobID: response.jobID, connectionID: connectionID)
        } catch {
            guard !Task.isCancelled, session.selectedConnectionID == connectionID else { return }
            errorMessage = FriendlyError.message(for: error)
        }
    }

    func sync() async {
        guard let connectionID = session.selectedConnectionID else { return }
        do {
            let response = try await session.syncSelectedConnection()
            guard !Task.isCancelled, session.selectedConnectionID == connectionID else { return }
            latestJob = AnalysisJob(
                id: response.jobID,
                workspace: session.workspace?.id ?? "",
                connection: connectionID,
                kind: "sync",
                status: response.status,
                attempts: nil,
                scheduledFor: nil,
                startedAt: nil,
                completedAt: nil,
                lastError: nil,
                created: nil,
                updated: nil
            )
            startPolling(jobID: response.jobID, connectionID: connectionID)
        } catch {
            guard !Task.isCancelled, session.selectedConnectionID == connectionID else { return }
            errorMessage = FriendlyError.message(for: error)
        }
    }

    func cancelPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func startPolling(jobID: String, connectionID: String) {
        cancelPolling()
        pollTask = Task { [weak self] in
            await self?.poll(jobID: jobID, connectionID: connectionID)
        }
    }

    private func poll(jobID: String, connectionID: String) async {
        pollingMessage = nil
        for _ in 0..<maxPollAttempts {
            guard !Task.isCancelled, session.selectedConnectionID == connectionID else { return }
            do {
                let job = try await session.loadJob(id: jobID)
                guard !Task.isCancelled, session.selectedConnectionID == connectionID else { return }
                latestJob = job
                if job.status.isTerminal {
                    if job.status == .succeeded { await load(connectionID: connectionID) }
                    return
                }
            } catch {
                guard !Task.isCancelled, session.selectedConnectionID == connectionID else { return }
                errorMessage = FriendlyError.message(for: error)
                return
            }
            if pollIntervalNanoseconds > 0 { try? await Task.sleep(nanoseconds: pollIntervalNanoseconds) }
        }
        if !Task.isCancelled, session.selectedConnectionID == connectionID {
            pollingMessage = "Still waiting for the worker. Pull down to refresh."
        }
    }

    private func apply(_ data: SelectedLeagueData) {
        displayedConnectionID = data.connectionID
        snapshot = data.snapshot
        recommendations = data.recommendations
        reports = data.reports
        powerRankings = data.powerRankings
        latestJob = data.jobs.first
    }

    private func clearLeagueData() {
        latestJob = nil
        recommendations = []
        snapshot = nil
        reports = []
        powerRankings = []
        errorMessage = nil
        pollingMessage = nil
    }
}
