import SwiftUI

struct HomeView: View {
    let session: SessionStore
    @State private var viewModel: HomeViewModel
    @State private var isShowingConnectESPN = false

    init(session: SessionStore) {
        self.session = session
        _viewModel = State(initialValue: HomeViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    leagueCard
                    jobCard
                    pathToFirst
                    recommendations
                    footer
                }
                .padding(16)
            }
            .background(Theme.canvas)
            .refreshable { await viewModel.refresh() }
            .navigationDestination(isPresented: $isShowingConnectESPN) { ConnectESPNView(session: session) }
            .task(id: session.selectedConnectionID) {
                await viewModel.load(connectionID: session.selectedConnectionID)
            }
            .onChange(of: session.realtimeRevision) {
                Task { await viewModel.refreshCurrentLeague() }
            }
            .onDisappear { viewModel.cancelPolling() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("LEAGUEPILOT AI").font(.footnote.weight(.bold)).foregroundStyle(Theme.emerald).tracking(1)
            Text(session.workspaceName).font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            if let snapshot = viewModel.snapshot {
                Text("Week \(snapshot.payload.week) · \(snapshot.payload.scoringFormat)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    @ViewBuilder private var leagueCard: some View {
        if viewModel.activeConnections.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Connect your ESPN league").font(.headline)
                Text("Link a league to synchronize read-only fantasy data.").foregroundStyle(Theme.inkSecondary)
                Button("Connect ESPN") { isShowingConnectESPN = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("connectESPNButton")
            }
            .padding(16)
            .leagueCard()
        } else if let connection = viewModel.selectedConnection {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.activeConnections.count > 1 {
                    Picker("League", selection: Binding(get: { connection.id }, set: viewModel.selectConnection)) {
                        ForEach(viewModel.activeConnections) { Text($0.displayName).tag($0.id) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Select ESPN league")
                }
                HStack {
                    Circle().fill(connection.status == .connected ? Theme.emerald : Theme.clay).frame(width: 10, height: 10)
                    VStack(alignment: .leading) {
                        Text(connection.displayName).font(.headline)
                        Text(connection.status.label).font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                }
                if connection.status.isReadyForAnalysis {
                    Button(viewModel.isRunningAnalysis ? "Queuing…" : "Run Analysis") { Task { await viewModel.runAnalysis() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(viewModel.isRunningAnalysis)
                        .accessibilityIdentifier("runAnalysisButton")
                } else {
                    Text(connection.lastError.isEmpty ? "Analysis will be available after the initial sync completes." : connection.lastError)
                        .font(.footnote)
                        .foregroundStyle(Theme.clay)
                    Button("Retry Sync") { Task { await viewModel.sync() } }.buttonStyle(OutlineButtonStyle())
                }
            }
            .padding(16)
            .leagueCard()
        }
    }

    @ViewBuilder private var jobCard: some View {
        if let job = viewModel.latestJob {
            HStack(spacing: 12) {
                Image(systemName: jobSymbol(job.status)).foregroundStyle(jobColor(job.status))
                VStack(alignment: .leading, spacing: 3) {
                    Text(job.summaryTitle).font(.headline)
                    Text(job.status.label).font(.caption.weight(.semibold)).foregroundStyle(jobColor(job.status))
                    if let error = job.lastError, !error.isEmpty {
                        Text(error).font(.caption).foregroundStyle(Theme.clay).lineLimit(3)
                    } else if let timestamp = job.completedAt ?? job.startedAt ?? job.scheduledFor ?? job.created {
                        Text(jobTimeLabel(for: job.status, timestamp: timestamp)).font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                }
                Spacer()
                if job.status.isPending { ProgressView().tint(Theme.forest) }
            }
            .padding(16)
            .leagueCard()
        }
    }

    @ViewBuilder private var pathToFirst: some View {
        if let snapshot = viewModel.snapshot,
           let myTeam = snapshot.payload.myTeam,
           let currentRank = viewModel.powerRankings.firstIndex(where: { $0.teamID == myTeam.id }).map({ $0 + 1 }),
           let currentScore = viewModel.powerRankings.first(where: { $0.teamID == myTeam.id }),
           let leader = viewModel.powerRankings.first {
            let proposed = viewModel.recommendations.filter { $0.snapshot == snapshot.id && $0.status == .proposed }
            let projectedImpact = proposed.reduce(0) { $0 + max(0, $1.impactPoints ?? 0) }
            VStack(alignment: .leading, spacing: 10) {
                HStack { Label("Path to #1", systemImage: "flag.checkered").font(.headline).foregroundStyle(Theme.ink); Spacer(); Text("#\(currentRank) of \(viewModel.powerRankings.count)").font(.caption.weight(.semibold)).foregroundStyle(Theme.emerald) }
                Text("Backend power-ranking score: \(currentScore.score.formatted(.number.precision(.fractionLength(1))))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                if leader.teamID != myTeam.id {
                    Text("Leader: \(leader.team) · \((leader.score - currentScore.score).formatted(.number.precision(.fractionLength(1)))) score points ahead")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Text(proposed.isEmpty ? "No proposed moves are awaiting review." : "\(proposed.count) proposed move\(proposed.count == 1 ? "" : "s") list \(projectedImpact.formatted(.number.precision(.fractionLength(1)))) projected points of positive impact.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(16)
            .leagueCard()
        } else if viewModel.snapshot != nil, viewModel.hasLoadedOnce {
            LPEmptyState(systemImage: "flag.checkered", title: "Path to #1 awaits a weekly report", message: "Power rankings appear when the backend has stored a weekly report for this league snapshot.")
        }
    }

    @ViewBuilder private var recommendations: some View {
        if !viewModel.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Latest recommendations").font(.headline)
                ForEach(viewModel.recommendations.prefix(5)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.subheadline.weight(.semibold))
                        Text(item.summary).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(3)
                        if let confidence = item.confidenceLabel { Text(confidence).font(.caption2.weight(.semibold)).foregroundStyle(Theme.emerald) }
                    }
                    .padding(14)
                    .leagueCard()
                }
            }
        } else if viewModel.hasLoadedOnce, viewModel.selectedConnection != nil {
            Text("No recommendations for this league yet.").font(.caption).foregroundStyle(Theme.inkSecondary)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if let error = viewModel.errorMessage {
                Text(error).font(.footnote).foregroundStyle(Theme.clay).multilineTextAlignment(.center)
                Button("Retry") { Task { await viewModel.refresh() } }.buttonStyle(OutlineButtonStyle())
            }
            if let message = viewModel.pollingMessage { Text(message).font(.caption).foregroundStyle(Theme.inkSecondary) }
            Text("Pull down to refresh").font(.caption).foregroundStyle(Theme.inkSecondary)
            Button("Sign Out") { session.signOut() }.foregroundStyle(Theme.forest)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func jobSymbol(_ status: JobStatus) -> String {
        switch status {
        case .queued: "clock.fill"
        case .running: "arrow.triangle.2.circlepath"
        case .succeeded: "checkmark.seal.fill"
        case .failed, .cancelled, .deadLetter: "exclamationmark.triangle.fill"
        }
    }

    private func jobColor(_ status: JobStatus) -> Color {
        switch status {
        case .succeeded: Theme.emerald
        case .queued, .running: Theme.forest
        case .failed, .cancelled, .deadLetter: Theme.clay
        }
    }

    private func jobTimeLabel(for status: JobStatus, timestamp: String) -> String {
        "\(status == .succeeded ? "Completed" : status == .running ? "Started" : "Updated") \(RelativeTime.string(from: timestamp))"
    }
}
