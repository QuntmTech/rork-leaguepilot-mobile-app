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
                    loadingState
                    dataWarnings
                    realtimeNotice
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
            .task(id: loadID) {
                await viewModel.load(connectionID: session.selectedConnectionID)
            }
            .onDisappear { viewModel.cancelPolling() }
        }
    }

    private var loadID: String { "\(session.selectedConnectionID ?? "none")-\(session.selectedLeagueRevision)-\(session.realtimeRevision)" }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("LEAGUEPILOT AI").font(.footnote.weight(.bold)).foregroundStyle(Theme.emerald).tracking(1)
            Text(session.workspaceName).font(.largeTitle.weight(.heavy)).foregroundStyle(Theme.ink)
            if let payload = viewModel.snapshot?.payload {
                Text("Week \(payload.week) · \(payload.scoringFormat ?? "Unavailable")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    @ViewBuilder private var loadingState: some View {
        if viewModel.isLoading, viewModel.selectedConnection != nil {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading selected league data…").font(.footnote).foregroundStyle(Theme.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .leagueCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading selected league data")
        }
    }

    @ViewBuilder private var dataWarnings: some View {
        if !viewModel.dataWarnings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Data notice", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.clay)
                ForEach(viewModel.dataWarnings, id: \.self) { warning in
                    Text(warning).font(.footnote).foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(16)
            .leagueCard()
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var realtimeNotice: some View {
        if let message = session.realtimeErrorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Theme.clay)
                .padding(16)
                .leagueCard()
                .accessibilityElement(children: .combine)
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(job.summaryTitle), \(job.status.label)\(job.lastError.map { ", \($0)" } ?? "")")
        }
    }

    @ViewBuilder private var pathToFirst: some View {
        if let summary = viewModel.pathToFirst {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Label("Path to #1", systemImage: "flag.checkered").font(.headline).foregroundStyle(Theme.ink); Spacer(); Text("#\(summary.rank) of \(summary.teamCount)").font(.caption.weight(.semibold)).foregroundStyle(Theme.emerald) }
                Text("Backend power-ranking score: \(summary.currentScore.formatted(.number.precision(.fractionLength(1))))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                if summary.leaderGap > 0 {
                    Text("Leader: \(summary.leaderTeam) · \(summary.leaderGap.formatted(.number.precision(.fractionLength(1)))) score points ahead")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Group {
                    if summary.proposedRecommendationCount == 0 {
                        Text("No proposed moves are awaiting review.")
                    } else if let impact = summary.positiveImpactPoints {
                        Text("\(summary.proposedRecommendationCount) proposed move\(summary.proposedRecommendationCount == 1 ? "" : "s") list \(impact.formatted(.number.precision(.fractionLength(1)))) projected points of positive impact.")
                    } else {
                        Text("\(summary.proposedRecommendationCount) proposed move\(summary.proposedRecommendationCount == 1 ? "" : "s") await review; projected impact is unavailable.")
                    }
                }
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
            }
            .padding(16)
            .leagueCard()
            .accessibilityElement(children: .combine)
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
                    .accessibilityElement(children: .combine)
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
