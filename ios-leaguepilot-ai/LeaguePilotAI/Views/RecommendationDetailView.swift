import SwiftUI

struct RecommendationDetailView: View {
    let session: SessionStore
    let recommendation: Recommendation
    let onReviewed: (String, RecommendationStatus) -> Void

    @State private var status: RecommendationStatus
    @State private var isReviewing = false
    @State private var error: String?

    init(session: SessionStore, recommendation: Recommendation, onReviewed: @escaping (String, RecommendationStatus) -> Void) {
        self.session = session
        self.recommendation = recommendation
        self.onReviewed = onReviewed
        _status = State(initialValue: recommendation.status)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summary
                details
                if let pitch = value("copy_paste_pitch") { tradePitch(pitch) }
                if let evidence = value("evidence_source") { labeledCard(title: "Evidence", value: evidence, icon: "doc.text") }
                if let flags = values("risk_flags"), !flags.isEmpty { risks(flags) }
                reviewControls
                Text("Reviewing a recommendation records your decision in LEAGUEPILOT AI. It does not submit any ESPN transaction.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("Move detail")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn’t record decision", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "Please try again.") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Label(recommendation.kind.capitalized, systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.emerald)
                Spacer()
                LPStatusPill(text: status.rawValue.capitalized, systemImage: status == .proposed ? "clock" : "checkmark.circle", kind: status == .approved ? .connected : .neutral)
            }
            Text(recommendation.title).font(.title.weight(.bold)).foregroundStyle(Theme.ink)
            if let created = recommendation.created { Text("Generated \(RelativeTime.string(from: created))").font(.caption).foregroundStyle(Theme.inkSecondary) }
        }
        .padding(16)
        .leagueCard()
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendation").font(.headline).foregroundStyle(Theme.ink)
            Text(recommendation.summary).font(.body).foregroundStyle(Theme.inkSecondary)
        }
        .padding(16)
        .leagueCard()
    }

    @ViewBuilder private var details: some View {
        if !detailFields.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Move details").font(.headline).foregroundStyle(Theme.ink)
                ForEach(detailFields, id: \.0) { field in
                    HStack(alignment: .firstTextBaseline) { Text(field.0).font(.subheadline).foregroundStyle(Theme.inkSecondary); Spacer(); Text(field.1).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.trailing) }
                }
            }
            .padding(16)
            .leagueCard()
        }
    }

    @ViewBuilder private var reviewControls: some View {
        if status == .proposed {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your decision").font(.headline).foregroundStyle(Theme.ink)
                HStack(spacing: 12) {
                    Button { review(.dismissed) } label: { Label("Dismiss", systemImage: "xmark").frame(maxWidth: .infinity) }
                        .buttonStyle(OutlineButtonStyle(stroke: Theme.clay.opacity(0.5), textColor: Theme.clay))
                        .accessibilityHint("Records that you dismissed this recommendation")
                    Button { review(.approved) } label: { Label("Approve", systemImage: "checkmark").frame(maxWidth: .infinity) }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityHint("Records that you approved this recommendation")
                }
                .disabled(isReviewing)
                if isReviewing { ProgressView("Saving decision…").font(.footnote) }
            }
            .padding(16)
            .leagueCard()
        } else if let reviewedAt = recommendation.reviewedAt {
            labeledCard(title: "Decision recorded", value: "\(status.rawValue.capitalized) \(RelativeTime.string(from: reviewedAt))", icon: "checkmark.seal")
        } else {
            labeledCard(title: "Decision recorded", value: status.rawValue.capitalized, icon: "checkmark.seal")
        }
    }

    private func tradePitch(_ pitch: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Label("Trade pitch", systemImage: "quote.bubble").font(.headline).foregroundStyle(Theme.ink); Spacer(); ShareLink(item: pitch) { Label("Share", systemImage: "square.and.arrow.up").font(.subheadline.weight(.semibold)) } }
            Text(pitch).font(.body).foregroundStyle(Theme.inkSecondary).textSelection(.enabled)
        }
        .padding(16)
        .leagueCard()
    }

    private func risks(_ flags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Risk flags", systemImage: "exclamationmark.triangle").font(.headline).foregroundStyle(Theme.ink)
            ForEach(flags, id: \.self) { Text("• \($0)").font(.subheadline).foregroundStyle(Theme.inkSecondary) }
        }
        .padding(16)
        .leagueCard()
    }

    private func labeledCard(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.emerald)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline).foregroundStyle(Theme.ink); Text(value).font(.subheadline).foregroundStyle(Theme.inkSecondary).textSelection(.enabled) }
            Spacer(minLength: 0)
        }
        .padding(16)
        .leagueCard()
    }

    private func value(_ key: String) -> String? {
        guard let raw = recommendation.payload?[key] else { return nil }
        if let string = raw.stringValue, !string.isEmpty { return string }
        if let number = raw.numberValue { return String(format: "%g", number) }
        return nil
    }

    private func values(_ key: String) -> [String]? { recommendation.payload?[key]?.stringArrayValue }

    private func percent(value key: String) -> String? {
        guard let number = recommendation.payload?[key]?.numberValue else { return nil }
        return "\(Int(number.rounded()))%"
    }

    private func score(value key: String, suffix: String) -> String? {
        guard let number = recommendation.payload?[key]?.numberValue else { return nil }
        return "\(number.formatted(.number.precision(.fractionLength(0 ... 1))))\(suffix)"
    }

    private func points(value key: String) -> String? {
        guard let number = recommendation.payload?[key]?.numberValue else { return nil }
        return String(format: "%+.1f points", number)
    }

    private var detailFields: [(String, String)] {
        var fields: [(String, String)] = []
        appendDetail("Start", value("start_player_name") ?? value("start_player"), to: &fields)
        appendDetail("Sit", value("sit_player_name") ?? value("sit_player"), to: &fields)
        appendDetail("Add", value("add_player_name") ?? value("add_player"), to: &fields)
        appendDetail("Drop", value("drop_player_name") ?? value("drop_player"), to: &fields)
        appendDetail("Offer", value("offer_player_name") ?? value("offer_player"), to: &fields)
        appendDetail("Target", value("target_player_name") ?? value("target_player"), to: &fields)
        appendDetail("Trade partner", value("partner_team") ?? value("partner"), to: &fields)
        appendDetail("Suggested FAAB", percent(value: "suggested_faab_percent"), to: &fields)
        appendDetail("Trade fairness", score(value: "fairness_score", suffix: "/100"), to: &fields)
        appendDetail("Mutual roster fit", score(value: "mutual_fit_score", suffix: ""), to: &fields)
        appendDetail("Your lineup gain", points(value: "my_estimated_lineup_gain"), to: &fields)
        appendDetail("Partner lineup gain", points(value: "partner_estimated_lineup_gain"), to: &fields)
        appendDetail("Projected impact", recommendation.impactPoints.map { String(format: "%+.1f points", $0) }, to: &fields)
        appendDetail("Confidence", recommendation.confidenceLabel, to: &fields)
        return fields
    }

    private func appendDetail(_ label: String, _ value: String?, to fields: inout [(String, String)]) {
        guard let value else { return }
        fields.append((label, value))
    }

    private func review(_ decision: RecommendationDecision) {
        guard !isReviewing else { return }
        isReviewing = true
        Task {
            do {
                let response = try await session.reviewRecommendation(id: recommendation.id, decision: decision)
                status = response.status
                onReviewed(response.id, response.status)
            } catch {
                self.error = FriendlyError.message(for: error)
            }
            isReviewing = false
        }
    }
}
