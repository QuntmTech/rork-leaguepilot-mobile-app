import SwiftUI

/// The authenticated command center keeps the selected ESPN connection in SessionStore so every
/// tab shares the same real league context.
struct AuthenticatedShell: View {
    let session: SessionStore
    @State private var tab: Tab = .home

    enum Tab: String, CaseIterable, Identifiable { case home, moves, league, alerts, settings
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var symbol: String { switch self { case .home: "house"; case .moves: "bolt.horizontal.circle"; case .league: "shield"; case .alerts: "bell"; case .settings: "gearshape" } }
    }

    var body: some View {
        TabView(selection: $tab) {
            HomeView(session: session).tabItem { Label("Home", systemImage: Tab.home.symbol) }.tag(Tab.home)
            MovesView(session: session).tabItem { Label("Moves", systemImage: Tab.moves.symbol) }.tag(Tab.moves)
            LeagueView(session: session).tabItem { Label("League", systemImage: Tab.league.symbol) }.tag(Tab.league)
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
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("Moves").font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.ink)
            Text(session.selectedConnection?.displayName ?? "Select a league on Home").font(.subheadline).foregroundStyle(Theme.inkSecondary)
            if let error { Text(error).foregroundStyle(Theme.clay).leagueCard() }
            else if recommendations.isEmpty { LPEmptyState(systemImage: "sparkles", title: "No moves to review", message: "Run a completed analysis for the selected league to load verified lineup, waiver, and trade guidance.") }
            else { ForEach(recommendations) { item in VStack(alignment: .leading, spacing: 6) { Label(item.kind.capitalized, systemImage: "sparkles").font(.caption.weight(.semibold)).foregroundStyle(Theme.emerald); Text(item.title).font(.headline); Text(item.summary).font(.subheadline).foregroundStyle(Theme.inkSecondary).lineLimit(4); if let confidence = item.confidenceLabel { Text(confidence).font(.caption.weight(.semibold)).foregroundStyle(Theme.emerald) }; Text(item.status.rawValue.capitalized).font(.caption).foregroundStyle(Theme.inkSecondary) }.padding(16).leagueCard() } }
        }.padding(16) }.background(Theme.canvas).navigationTitle("Moves").task { do { recommendations = try await session.loadRecommendations() } catch { self.error = FriendlyError.message(for: error) } } }
    }
}

private struct LeagueView: View {
    let session: SessionStore
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) {
        Text("My League").font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.ink)
        if let connection = session.selectedConnection { VStack(alignment: .leading, spacing: 10) { Text(connection.displayName).font(.headline); Text("Season \(connection.season) · Team \(connection.teamID)").foregroundStyle(Theme.inkSecondary); LPStatusPill(text: connection.status.label, systemImage: connection.status == .connected ? "checkmark.circle" : "exclamationmark.triangle", kind: connection.status == .connected ? .connected : .warning); if let last = connection.lastSyncedAt { Text("Last sync \(RelativeTime.string(from: last))").font(.caption).foregroundStyle(Theme.inkSecondary) } }.padding(16).leagueCard() } else { LPEmptyState(systemImage: "shield", title: "No league selected", message: "Connect an ESPN league from Home to load its verified roster and matchup data.") }
        LPEmptyState(systemImage: "chart.bar", title: "League intelligence awaits a sync", message: "Standings, roster strength, and matchup details appear only when a completed backend snapshot supplies them.")
    }.padding(16) }.background(Theme.canvas).navigationTitle("League") } }
}

private struct AlertsView: View {
    var body: some View { NavigationStack { VStack(spacing: 16) { LPEmptyState(systemImage: "bell.badge", title: "Alerts are coming later", message: "Cross-device read state and device registration require an approved backend notification endpoint. No local alert state is being fabricated.") }.padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.canvas).navigationTitle("Alerts") } }
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
            }.navigationTitle("Settings")
        }
    }
}
