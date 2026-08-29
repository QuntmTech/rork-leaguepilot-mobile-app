import SwiftUI

struct LeagueIntelligenceView: View {
    let session: SessionStore
    @State private var viewModel: LeagueIntelligenceViewModel

    init(session: SessionStore) {
        self.session = session
        _viewModel = State(initialValue: LeagueIntelligenceViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    title
                    content
                }
                .padding(16)
            }
            .background(Theme.canvas)
            .navigationTitle("League")
            .task(id: loadID) { await viewModel.load(connectionID: session.selectedConnectionID) }
        }
    }

    private var loadID: String { "\(session.selectedConnectionID ?? "none")-\(session.selectedLeagueRevision)-\(session.realtimeRevision)" }

    private var title: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("League Intelligence").font(.largeTitle.weight(.bold)).foregroundStyle(Theme.ink)
            Text(session.selectedConnection?.displayName ?? "Select a league on Home").font(.subheadline).foregroundStyle(Theme.inkSecondary)
        }
    }

    @ViewBuilder private var content: some View {
        if let error = viewModel.errorMessage {
            Text(error).foregroundStyle(Theme.clay).padding(16).leagueCard()
        } else {
            dataWarnings
            if let snapshot = viewModel.data?.snapshot, let payload = snapshot.payload {
                snapshotSummary(snapshot, payload: payload)
                matchup(payload)
                powerRankings
                standings(payload)
                opponentTeams(payload)
                weeklyReports
            } else if viewModel.hasLoadedOnce {
                LPEmptyState(systemImage: "chart.bar", title: "No usable snapshot for this league", message: "Synchronize this ESPN league to load its roster, standings, matchups, and reports.")
            } else {
                ProgressView("Loading league intelligence…").frame(maxWidth: .infinity).padding(.vertical, 36)
            }
        }
    }

    @ViewBuilder private var dataWarnings: some View {
        if let warnings = viewModel.data?.dataWarnings, !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Data notice", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.clay)
                ForEach(warnings, id: \.self) { warning in
                    Text(warning).font(.footnote).foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(16)
            .leagueCard()
            .accessibilityElement(children: .combine)
        }
    }

    private func snapshotSummary(_ snapshot: LeagueSnapshotRecord, payload: LeagueSnapshotPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(payload.leagueName).font(.headline); Spacer(); Text("Week \(payload.week)").font(.caption.weight(.semibold)).foregroundStyle(Theme.emerald) }
            Text("Season \(payload.season) · \(payload.scoringFormat ?? "Unavailable")").font(.subheadline).foregroundStyle(Theme.inkSecondary)
            Text("Synced \(RelativeTime.string(from: snapshot.fetchedAt))").font(.caption).foregroundStyle(Theme.inkSecondary)
            if let expiresAt = snapshot.expiresAt {
                Text("Backend expiry \(RelativeTime.string(from: expiresAt))").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            if let dataQualityWarnings = payload.dataQualityWarnings, !dataQualityWarnings.isEmpty {
                Text(dataQualityWarnings.joined(separator: " · ")).font(.footnote).foregroundStyle(Theme.clay)
            }
        }
        .padding(16)
        .leagueCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func matchup(_ payload: LeagueSnapshotPayload) -> some View {
        if let mine = payload.myTeam,
           let matchup = payload.currentMatchup,
           let opponent = payload.currentOpponent {
            VStack(alignment: .leading, spacing: 12) {
                Text("This week’s matchup").font(.headline)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) { Text(mine.name).font(.subheadline.weight(.semibold)); Text("\(matchup.projectedTotalLabel(for: mine.id)) projected").font(.caption).foregroundStyle(Theme.inkSecondary) }
                    Spacer()
                    Text("vs").font(.caption).foregroundStyle(Theme.inkSecondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) { Text(opponent.name).font(.subheadline.weight(.semibold)); Text("\(matchup.projectedTotalLabel(for: opponent.id)) projected").font(.caption).foregroundStyle(Theme.inkSecondary) }
                }
                Text("Current score: \(matchup.scoreLabel(for: mine.id)) – \(matchup.scoreLabel(for: opponent.id))").font(.footnote).foregroundStyle(Theme.inkSecondary)
            }
            .padding(16)
            .leagueCard()
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var powerRankings: some View {
        if let data = viewModel.data, !data.powerRankings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("Power rankings").font(.headline); Spacer(); Text("Backend report").font(.caption).foregroundStyle(Theme.inkSecondary) }
                ForEach(Array(data.powerRankings.enumerated()), id: \.element.id) { index, ranking in
                    HStack {
                        Text("#\(index + 1)").font(.subheadline.weight(.bold)).foregroundStyle(Theme.emerald).frame(width: 32, alignment: .leading)
                        Text(ranking.team).font(.subheadline)
                        Spacer()
                        Text(ranking.score.formatted(.number.precision(.fractionLength(1)))).font(.subheadline.weight(.semibold))
                    }
                }
            }
            .padding(16)
            .leagueCard()
            .accessibilityElement(children: .combine)
        } else {
            LPEmptyState(systemImage: "list.number", title: "No backend power ranking yet", message: "A weekly report for this snapshot is required before rankings are shown.")
        }
    }

    private func standings(_ payload: LeagueSnapshotPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Standings").font(.headline)
            ForEach(standingsTeams(payload.teams)) { team in
                HStack {
                    Text(team.name).font(.subheadline)
                    Spacer()
                    Text(team.record).font(.subheadline.weight(.semibold))
                    Text(team.pointsForLabel).font(.caption).foregroundStyle(Theme.inkSecondary).frame(width: 80, alignment: .trailing)
                }
            }
            Text("Record · points for").font(.caption2).foregroundStyle(Theme.inkSecondary)
        }
        .padding(16)
        .leagueCard()
    }

    private func opponentTeams(_ payload: LeagueSnapshotPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Opponent rosters").font(.headline)
            ForEach(payload.opponentTeams) { team in
                NavigationLink {
                    OpponentTeamDetailView(team: team)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) { Text(team.name).font(.subheadline.weight(.semibold)); Text("\(team.record) · \(team.rosterCountLabel)").font(.caption).foregroundStyle(Theme.inkSecondary) }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.inkSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Opens \(team.name)’s roster")
            }
        }
        .padding(16)
        .leagueCard()
    }

    @ViewBuilder private var weeklyReports: some View {
        if let reports = viewModel.data?.reports, !reports.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Weekly reports").font(.headline)
                ForEach(reports) { report in
                    NavigationLink {
                        WeeklyReportDetailView(report: report)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) { Text(report.title).font(.subheadline.weight(.semibold)); Text("Week \(report.week)\(report.publishedAt.map { " · \(RelativeTime.string(from: $0))" } ?? "")").font(.caption).foregroundStyle(Theme.inkSecondary) }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.inkSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens this weekly report")
                }
            }
            .padding(16)
            .leagueCard()
        } else {
            LPEmptyState(systemImage: "doc.text", title: "No reports for this league", message: "A completed weekly or full analysis will add a report here.")
        }
    }

    private func standingsTeams(_ teams: [LeagueTeam]) -> [LeagueTeam] {
        guard teams.allSatisfy(\.hasCompleteStanding) else { return teams }
        return teams.sorted {
            guard let leftWins = $0.wins,
                  let rightWins = $1.wins,
                  let leftLosses = $0.losses,
                  let rightLosses = $1.losses,
                  let leftPoints = $0.pointsFor,
                  let rightPoints = $1.pointsFor else {
                return false
            }
            if leftWins != rightWins { return leftWins > rightWins }
            if leftLosses != rightLosses { return leftLosses < rightLosses }
            return leftPoints > rightPoints
        }
    }
}

struct OpponentTeamDetailView: View {
    let team: LeagueTeam

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(team.name).font(.largeTitle.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("\(team.record) · \(team.pointsForLabel) points for").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    if let owner = team.owner, !owner.isEmpty { Text(owner).font(.caption).foregroundStyle(Theme.inkSecondary) }
                }
                .padding(16)
                .leagueCard()
                if team.roster == nil {
                    LPEmptyState(systemImage: "person.3", title: "Roster unavailable", message: "The backend did not provide a roster for this opponent.")
                } else {
                    rosterSection(title: "Starting lineup", players: team.starters)
                    rosterSection(title: "Bench and IR", players: team.bench)
                    if !team.playersWithUnavailableSlots.isEmpty {
                        rosterSection(title: "Slot unavailable", players: team.playersWithUnavailableSlots)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("Opponent")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rosterSection(title: String, players: [LeaguePlayer]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            if players.isEmpty {
                Text("No rostered players in this group.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
            } else {
                ForEach(players.sorted { $0.position == $1.position ? $0.name < $1.name : $0.position < $1.position }) { player in
                    HStack(alignment: .firstTextBaseline) {
                        Text(player.position).font(.caption.weight(.bold)).foregroundStyle(Theme.emerald).frame(width: 28, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) { Text(player.name).font(.subheadline.weight(.semibold)); Text(player.rosterMetadataLabel).font(.caption).foregroundStyle(Theme.inkSecondary) }
                        Spacer()
                        Text(player.projectedPointsLabel).font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .leagueCard()
    }
}

struct WeeklyReportDetailView: View {
    let report: WeeklyReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(report.title).font(.title.weight(.bold)).foregroundStyle(Theme.ink)
                Text("Week \(report.week)\(report.publishedAt.map { " · \(RelativeTime.string(from: $0))" } ?? "")").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                Text(report.bodyMarkdown).font(.body).foregroundStyle(Theme.ink).textSelection(.enabled)
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("Weekly report")
        .navigationBarTitleDisplayMode(.inline)
    }
}
