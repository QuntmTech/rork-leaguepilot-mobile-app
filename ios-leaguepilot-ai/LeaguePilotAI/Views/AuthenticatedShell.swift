import SwiftUI

/// The authenticated command center keeps the selected ESPN connection in SessionStore so every
/// tab shares the same real league context.
struct AuthenticatedShell: View {
    let session: SessionStore
    @State private var tab: Tab = .home

    enum Tab: String, CaseIterable, Identifiable {
        case home, moves, league, alerts, settings
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .home: "house"
            case .moves: "bolt.horizontal.circle"
            case .league: "shield"
            case .alerts: "bell"
            case .settings: "gearshape"
            }
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            HomeView(session: session).tabItem { Label("Home", systemImage: Tab.home.symbol) }.tag(Tab.home)
            MovesView(session: session).tabItem { Label("Moves", systemImage: Tab.moves.symbol) }.tag(Tab.moves)
            LeagueIntelligenceView(session: session).tabItem { Label("League", systemImage: Tab.league.symbol) }.tag(Tab.league)
            AlertsView().tabItem { Label("Alerts", systemImage: Tab.alerts.symbol) }.tag(Tab.alerts)
            SettingsView(session: session).tabItem { Label("Settings", systemImage: Tab.settings.symbol) }.tag(Tab.settings)
        }
        .tint(Theme.forest)
    }
}

private struct MovesView: View {
    let session: SessionStore
    @State private var recommendations: [Recommendation] = []
    @State private var error: String?
    @State private var hasLoaded = false
    @State private var loadGeneration = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text("Moves").font(.largeTitle.weight(.bold)).foregroundStyle(Theme.ink)
                    Text(session.selectedConnection?.displayName ?? "Select a league on Home").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    if let error {
                        Text(error).foregroundStyle(Theme.clay).padding(16).leagueCard()
                    } else if hasLoaded, recommendations.isEmpty {
                        LPEmptyState(systemImage: "sparkles", title: "No moves to review", message: "Run a completed analysis for the selected league to load verified lineup, waiver, and trade guidance.")
                    } else if !hasLoaded {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 36)
                    } else {
                        ForEach(recommendations) { item in
                            NavigationLink {
                                RecommendationDetailView(session: session, recommendation: item) { id, status in
                                    guard let index = recommendations.firstIndex(where: { $0.id == id }) else { return }
                                    recommendations[index] = recommendations[index].updating(status: status)
                                }
                            } label: {
                                recommendationRow(item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityHint("Opens recommendation details and review actions")
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.canvas)
            .navigationTitle("Moves")
            .task(id: loadID) { await load(connectionID: session.selectedConnectionID) }
            .onChange(of: session.selectedConnectionID) { _, _ in
                // Clear synchronously, before the replacement task gets a chance to fetch.
                // Its task identity then cancels the old request and loads the new league.
                recommendations = []
                error = nil
                hasLoaded = false
            }
        }
    }

    private var loadID: String { "\(session.selectedConnectionID ?? "none")-\(session.selectedLeagueRevision)-\(session.realtimeRevision)" }

    private func recommendationRow(_ item: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(item.kind.capitalized, systemImage: "sparkles").font(.caption.weight(.semibold)).foregroundStyle(Theme.emerald)
                Spacer()
                LPStatusPill(text: item.status.rawValue.capitalized, systemImage: item.status == .proposed ? "clock" : "checkmark.circle", kind: item.status == .approved ? .connected : .neutral)
            }
            Text(item.title).font(.headline).foregroundStyle(Theme.ink)
            Text(item.summary).font(.subheadline).foregroundStyle(Theme.inkSecondary).lineLimit(4)
            if let confidence = item.confidenceLabel { Text(confidence).font(.caption.weight(.semibold)).foregroundStyle(Theme.emerald) }
        }
        .padding(16)
        .leagueCard()
    }

    /// SwiftUI cancels this task for a changed id; the explicit id guard also prevents a
    /// non-cooperative network response from the previous league from touching visible state.
    private func load(connectionID: String?) async {
        loadGeneration &+= 1
        let requestGeneration = loadGeneration
        let selectionRevision = session.selectedLeagueRevision
        recommendations = []
        error = nil
        hasLoaded = false
        guard let connectionID else {
            hasLoaded = true
            return
        }
        do {
            let results = try await session.loadRecommendations(for: connectionID)
            guard isCurrent(requestGeneration, connectionID: connectionID, selectionRevision: selectionRevision) else { return }
            recommendations = results
        } catch {
            guard isCurrent(requestGeneration, connectionID: connectionID, selectionRevision: selectionRevision) else { return }
            self.error = FriendlyError.message(for: error)
        }
        if isCurrent(requestGeneration, connectionID: connectionID, selectionRevision: selectionRevision) { hasLoaded = true }
    }

    private func isCurrent(_ requestGeneration: Int, connectionID: String, selectionRevision: Int) -> Bool {
        !Task.isCancelled && loadGeneration == requestGeneration && session.selectedConnectionID == connectionID && session.selectedLeagueRevision == selectionRevision
    }
}

private struct AlertsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                LPEmptyState(systemImage: "bell.badge", title: "Alerts are coming later", message: "Cross-device read state and device registration require an approved backend notification endpoint. No local alert state is being fabricated.")
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.canvas)
            .navigationTitle("Alerts")
        }
    }
}

private struct SettingsView: View {
    let session: SessionStore

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Text(session.user?.email ?? "Signed in")
                    Text("PocketBase session stored securely on this device.").font(.footnote).foregroundStyle(Theme.inkSecondary)
                }
                Section("Connected leagues") { Text("\(session.activeConnections.count) active") }
                Section("Safety") { Text("Read-only ESPN access. LEAGUEPILOT AI never submits moves to ESPN.").font(.footnote) }
                Section { Button("Sign Out", role: .destructive) { session.signOut() } }
            }
            .navigationTitle("Settings")
        }
    }
}
