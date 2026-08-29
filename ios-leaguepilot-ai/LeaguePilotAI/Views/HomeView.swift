import SwiftUI

struct HomeView: View {
    let session: SessionStore
    @State private var viewModel: HomeViewModel
    @State private var isShowingConnectESPN = false
    init(session: SessionStore) { self.session = session; _viewModel = State(initialValue: HomeViewModel(session: session)) }
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 16) { header; leagueCard; jobCard; recommendations; footer }.padding(16) }
                .background(Theme.canvas).refreshable { await viewModel.refresh() }
                .navigationDestination(isPresented: $isShowingConnectESPN) { ConnectESPNView(session: session) }
                .task { if !viewModel.hasLoadedOnce { await viewModel.refresh() } }
                .onDisappear { viewModel.cancelPolling() }
        }
    }
    private var header: some View { VStack(alignment: .leading, spacing: 5) { Text("LEAGUEPILOT AI").font(.footnote.weight(.bold)).foregroundStyle(Theme.emerald).tracking(1); Text(session.workspaceName).font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink) } }
    @ViewBuilder private var leagueCard: some View {
        if viewModel.activeConnections.isEmpty { VStack(alignment: .leading, spacing: 12) { Text("Connect your ESPN league").font(.headline); Text("Link a league to synchronize read-only fantasy data.").foregroundStyle(Theme.inkSecondary); Button("Connect ESPN") { isShowingConnectESPN = true }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("connectESPNButton") }.padding(16).leagueCard() }
        else if let connection = viewModel.selectedConnection { VStack(alignment: .leading, spacing: 12) {
            if viewModel.activeConnections.count > 1 { Picker("League", selection: Binding(get: { connection.id }, set: { id in Task { await viewModel.selectConnection(id) } })) { ForEach(viewModel.activeConnections) { Text($0.displayName).tag($0.id) } }.pickerStyle(.menu).accessibilityLabel("Select ESPN league") }
            HStack { Circle().fill(connection.status == .connected ? Theme.emerald : Theme.clay).frame(width: 10, height: 10); VStack(alignment: .leading) { Text(connection.displayName).font(.headline); Text(connection.status.label).font(.caption).foregroundStyle(Theme.inkSecondary) }; Spacer() }
            if connection.status.isReadyForAnalysis { Button(viewModel.isRunningAnalysis ? "Queuing…" : "Run Analysis") { Task { await viewModel.runAnalysis() } }.buttonStyle(PrimaryButtonStyle()).disabled(viewModel.isRunningAnalysis).accessibilityIdentifier("runAnalysisButton") }
            else { Text(connection.lastError.isEmpty ? "Analysis will be available after the initial sync completes." : connection.lastError).font(.footnote).foregroundStyle(Theme.clay); Button("Retry Sync") { Task { await viewModel.sync() } }.buttonStyle(OutlineButtonStyle()) }
        }.padding(16).leagueCard() }
    }
    @ViewBuilder private var jobCard: some View { if let job = viewModel.latestJob { HStack(spacing: 12) { Image(systemName: job.status == .succeeded ? "checkmark.seal.fill" : job.status.isPending ? "clock.fill" : "exclamationmark.triangle.fill").foregroundStyle(job.status == .succeeded ? Theme.emerald : job.status.isPending ? Theme.forest : Theme.clay); VStack(alignment: .leading) { Text(job.summaryTitle).font(.headline); Text(job.status.label).font(.caption).foregroundStyle(Theme.inkSecondary); if let error = job.lastError, !error.isEmpty { Text(error).font(.caption).foregroundStyle(Theme.clay).lineLimit(2) } }; Spacer(); if job.status.isPending { ProgressView().tint(Theme.forest) } }.padding(16).leagueCard() } }
    @ViewBuilder private var recommendations: some View { if !viewModel.recommendations.isEmpty { VStack(alignment: .leading, spacing: 10) { Text("Latest recommendations").font(.headline); ForEach(viewModel.recommendations.prefix(5)) { item in VStack(alignment: .leading, spacing: 4) { Text(item.title).font(.subheadline.weight(.semibold)); Text(item.summary).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(3); if let confidence = item.confidenceLabel { Text(confidence).font(.caption2.weight(.semibold)).foregroundStyle(Theme.emerald) } }.padding(14).leagueCard() } } } else if viewModel.hasLoadedOnce, viewModel.selectedConnection != nil { Text("No recommendations for this league yet.").font(.caption).foregroundStyle(Theme.inkSecondary) } }
    private var footer: some View { VStack(spacing: 10) { if let error = viewModel.errorMessage { Text(error).font(.footnote).foregroundStyle(Theme.clay).multilineTextAlignment(.center); Button("Retry") { Task { await viewModel.refresh() } }.buttonStyle(OutlineButtonStyle()) }; if let message = viewModel.pollingMessage { Text(message).font(.caption).foregroundStyle(Theme.inkSecondary) }; Text("Pull down to refresh").font(.caption).foregroundStyle(Theme.inkSecondary); Button("Sign Out") { session.signOut() }.foregroundStyle(Theme.forest) }.frame(maxWidth: .infinity).padding(.vertical, 12) }
}
