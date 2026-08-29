import Foundation
import Observation

@MainActor @Observable
final class HomeViewModel {
    private(set) var latestJob: AnalysisJob?
    private(set) var recommendations: [Recommendation] = []
    private(set) var snapshot: LeagueSnapshotRecord?
    private(set) var reports: [WeeklyReport] = []
    private(set) var powerRankings: [PowerRanking] = []
    private(set) var dataWarnings: [String] = []
    private(set) var isRunningAnalysis = false
    private(set) var isLoading = false
    private(set) var hasLoadedOnce = false
    var errorMessage: String?
    var pollingMessage: String?

    private let session: SessionStore
    private var pollTask: Task<Void, Never>?
    private let pollIntervalNanoseconds: UInt64
    private let maxPollAttempts: Int
    private var displayedConnectionID: String?
    private var loadGeneration = 0

    init(session: SessionStore, pollIntervalNanoseconds: UInt64 = 3_000_000_000, maxPollAttempts: Int = 40) {
        self.session = session
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
        self.maxPollAttempts = maxPollAttempts
    }

    var selectedConnection: ESPNConnection? { session.selectedConnection }
    var activeConnections: [ESPNConnection] { session.activeConnections }
    var pathToFirst: PathToFirstSummary? {
        PathToFirstSummary.make(snapshot: snapshot, rankings: powerRankings, recommendations: recommendations)
    }

    /// Reloads one explicit league context. The id check means a response from a previous league
    /// can never overwrite the visible context after the user changes the picker.
    func load(connectionID: String?) async {
        loadGeneration &+= 1
        let requestGeneration = loadGeneration
        let selectionRevision = session.selectedLeagueRevision
        isLoading = true
        guard let connectionID else {
            clearLeagueData()
            hasLoadedOnce = true
            isLoading = false
            return
        }
        if displayedConnectionID != connectionID {
            cancelPolling()
            clearLeagueData()
            displayedConnectionID = connectionID
            hasLoadedOnce = false
        }

        do {
            let data = try await session.loadLeagueData(for: connectionID)
            guard isCurrent(requestGeneration, connectionID: connectionID, selectionRevision: selectionRevision) else { return }
            apply(data)
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

    /// Clears the previous league synchronously before SwiftUI begins its replacement task.
    func prepareForSelectionChange() {
        loadGeneration &+= 1
        cancelPolling()
        clearLeagueData()
        displayedConnectionID = nil
        hasLoadedOnce = false
        isLoading = true
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
        guard id != session.selectedConnectionID else { return }
        prepareForSelectionChange()
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
        dataWarnings = data.dataWarnings
    }

    private func clearLeagueData() {
        latestJob = nil
        recommendations = []
        snapshot = nil
        reports = []
        powerRankings = []
        dataWarnings = []
        errorMessage = nil
        pollingMessage = nil
    }

    private func isCurrent(_ requestGeneration: Int, connectionID: String, selectionRevision: Int) -> Bool {
        !Task.isCancelled && loadGeneration == requestGeneration && session.selectedConnectionID == connectionID && session.selectedLeagueRevision == selectionRevision
    }
}
