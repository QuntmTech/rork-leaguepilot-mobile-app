import SwiftUI

/// Main screen: workspace, ESPN connection, latest job, newest recommendations.
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
                VStack(alignment: .leading, spacing: 16) {
                    header
                    connectionCard
                    jobCard
                    recommendationsSection
                    footer
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .refreshable { await viewModel.refresh() }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.canvas)
            .navigationDestination(isPresented: $isShowingConnectESPN) {
                ConnectESPNView(session: session)
            }
            .task {
                if !viewModel.hasLoadedOnce {
                    await viewModel.refresh()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LEAGUEPILOT AI")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.emerald)
                .tracking(1)
            Text(session.workspaceName)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            StatusPill(text: "Active", color: Theme.emerald)
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isConnected ? Theme.emerald : Theme.clay)
                    .frame(width: 10, height: 10)
                Text("ESPN connection")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
            }
            Text(connectionText)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)

            if isConnected {
                Button {
                    Task { await viewModel.runAnalysis() }
                } label: {
                    if viewModel.isRunningAnalysis {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("Queuing…")
                        }
                    } else {
                        Text("Run Analysis")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isRunningAnalysis)
            } else {
                Button {
                    isShowingConnectESPN = true
                } label: {
                    Text("Connect ESPN")
                }
                .buttonStyle(OutlineButtonStyle(stroke: Theme.clay.opacity(0.5), textColor: Theme.clay))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .leagueCard()
    }

    @ViewBuilder
    private var jobCard: some View {
        if let job = viewModel.latestJob {
            HStack(spacing: 12) {
                Image(systemName: job.isPending ? "sparkles" : "checkmark.seal")
                    .font(.title3)
                    .foregroundStyle(Theme.forest)
                    .frame(width: 38, height: 38)
                    .background(Theme.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.summaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(job.created.map { "Started " + RelativeTime.string(from: $0) } ?? "Recent")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                StatusPill(text: job.statusLabel, color: job.statusColor)
                if job.isPending {
                    ProgressView()
                        .tint(Theme.forest)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .leagueCard()
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        if !viewModel.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Latest recommendations")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recommendations.enumerated()), id: \.element.id) { index, recommendation in
                        recommendationRow(recommendation, rank: index + 1)
                        if index < viewModel.recommendations.count - 1 {
                            Divider().background(Theme.border)
                        }
                    }
                }
                .leagueCard()
            }
        } else if viewModel.hasLoadedOnce && isConnected {
            Text("No recommendations yet — run an analysis to get your first plays.")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    private func recommendationRow(_ recommendation: Recommendation, rank: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.emerald)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(recommendation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                if let line = recommendation.subtitleLine {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.clay)
                    .multilineTextAlignment(.center)
            }
            Text("Pull down to refresh")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
            Button("Sign Out") { session.signOut() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.forest)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var isConnected: Bool {
        session.workspace?.espnConnected ?? false
    }

    private var connectionText: String {
        if let workspace = session.workspace, workspace.espnConnected {
            if let leagueID = workspace.espnLeagueID {
                return "Connected · League ID \(leagueID)"
            }
            return "Connected to your ESPN league"
        }
        return "Not connected — link your league to start"
    }
}

private extension AnalysisJob {
    var statusColor: Color {
        switch statusLabel {
        case "Done": return Theme.emerald
        case "Failed": return Theme.clay
        case "Queued", "Running": return Theme.forest
        default: return Theme.inkSecondary
        }
    }
}
