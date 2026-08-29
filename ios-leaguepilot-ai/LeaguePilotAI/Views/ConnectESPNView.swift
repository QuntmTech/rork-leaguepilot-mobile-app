import SwiftUI

/// Pushed detail: link an ESPN league to the workspace.
/// Private-league cookie inputs are wiped right after submit and never displayed again.
struct ConnectESPNView: View {
    let session: SessionStore

    @State private var viewModel: ConnectESPNViewModel
    @Environment(\.dismiss) private var dismiss

    init(session: SessionStore) {
        self.session = session
        _viewModel = State(initialValue: ConnectESPNViewModel(session: session))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock
                identityCard
                privacyCard
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.clay)
                }
                saveButton
                cancelButton
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.canvas)
        .navigationTitle("Connect ESPN")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave {
                dismiss()
            }
        }
        .onDisappear { viewModel.clearSensitiveFields() }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Connect ESPN")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.forest)
            Text("Link your fantasy league")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.top, 8)
    }

    private var identityCard: some View {
        VStack(spacing: 0) {
            FormRow(systemImage: "tag", label: "League ID", placeholder: "Enter league ID", text: $viewModel.leagueID)
            Divider().background(Theme.border)
            FormRow(systemImage: "person", label: "Team ID", placeholder: "Enter team ID", text: $viewModel.teamID)
            Divider().background(Theme.border)
            FormRow(
                systemImage: "calendar",
                label: "Season",
                placeholder: LeaguePilotConfig.defaultSeason,
                text: $viewModel.season
            )
        }
        .padding(.horizontal, 14)
        .leagueCard()
    }

    private var privacyCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isPrivate ? "lock.fill" : "lock.open")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(width: 22)
                Text("Private league")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Toggle("", isOn: $viewModel.isPrivate)
                    .labelsHidden()
                    .tint(Theme.emerald)
            }
            .frame(minHeight: 48)

            if viewModel.isPrivate {
                Divider().background(Theme.border)
                SecureCredentialRow(systemImage: "key", label: "espn_s2", text: $viewModel.espnS2)
                Divider().background(Theme.border)
                SecureCredentialRow(systemImage: "shield", label: "SWID", text: $viewModel.swid)
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .font(.caption2)
                    Text("Cleared right after submit — never saved or shown again")
                        .font(.caption)
                }
                .foregroundStyle(Theme.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
            }
        }
        .padding(16)
        .leagueCard()
    }

    private var saveButton: some View {
        Button {
            Task { await viewModel.save() }
        } label: {
            if viewModel.isSaving {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Save Connection")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!viewModel.canSave || viewModel.isSaving)
    }

    private var cancelButton: some View {
        Button("Cancel") { dismiss() }
            .buttonStyle(OutlineButtonStyle())
            .padding(.bottom, 24)
    }
}

/// Icon + label + right-aligned text field row.
struct FormRow: View {
    let systemImage: String
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .numberPad

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 22)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: 170)
                .accessibilityLabel(label)
        }
        .frame(minHeight: 48)
    }
}

/// Secure credential row with a reveal toggle (espn_s2 / SWID).
struct SecureCredentialRow: View {
    let systemImage: String
    let label: String
    @Binding var text: String

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 22)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Group {
                if isRevealed {
                    TextField("••••••••", text: $text)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel(label)
                } else {
                    SecureField("••••••••", text: $text)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel(label)
                }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: 150)
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .accessibilityLabel(isRevealed ? "Hide \(label)" : "Show \(label)")
        }
        .frame(minHeight: 48)
    }
}
