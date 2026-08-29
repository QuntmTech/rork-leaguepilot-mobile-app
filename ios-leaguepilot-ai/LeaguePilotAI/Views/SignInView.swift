import SwiftUI

/// Entry gate: email/password sign in with a compact create-account option.
struct SignInView: View {
    let session: SessionStore

    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var fullName = ""
    @State private var signUpEmail = ""
    @State private var signUpPassword = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                signInCard
                orDivider
                if isCreatingAccount {
                    createAccountCard
                } else {
                    createAccountToggle
                }
                footer
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.canvas)
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 3) {
                Text("LEAGUEPILOT AI")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.forest)
                Circle()
                    .fill(Theme.lime)
                    .frame(width: 9, height: 9)
                    .offset(y: 2)
            }
            Text("Sign in to pilot your league")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AuthField(
                label: "Email",
                systemImage: "envelope",
                placeholder: "you@example.com",
                text: $email,
                keyboard: .emailAddress
            )
            AuthField(
                label: "Password",
                systemImage: "lock",
                placeholder: "Enter your password",
                text: $password,
                isSecure: true
            )
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.clay)
            }
            Button {
                Task { await submit() }
            } label: {
                if isBusy {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign In")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isBusy || email.isEmpty || password.isEmpty)
        }
        .padding(16)
        .leagueCard()
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.border).frame(height: 1)
            Text("OR")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    private var createAccountToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isCreatingAccount = true }
        } label: {
            HStack(spacing: 6) {
                Text("New here? Create account")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.forest)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(Theme.forest)
            }
        }
        .padding(.vertical, 8)
    }

    private var createAccountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AuthField(
                label: "Full name",
                systemImage: "person",
                placeholder: "Your full name",
                text: $fullName
            )
            AuthField(
                label: "Email",
                systemImage: "envelope",
                placeholder: "you@example.com",
                text: $signUpEmail,
                keyboard: .emailAddress
            )
            AuthField(
                label: "Password",
                systemImage: "lock",
                placeholder: "Create a password",
                text: $signUpPassword,
                isSecure: true
            )
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.clay)
            }
            Button {
                Task { await submit() }
            } label: {
                if isBusy {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Account")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isBusy || fullName.isEmpty || signUpEmail.isEmpty || signUpPassword.isEmpty)
        }
        .padding(16)
        .leagueCard()
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text("You'll stay signed in on this device.")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
            if session.isSignedIn {
                Button("Sign Out") { session.signOut() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.forest)
            }
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
    }

    private func submit() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            if isCreatingAccount {
                try await session.signUp(name: fullName, email: signUpEmail, password: signUpPassword)
            } else {
                try await session.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = FriendlyError.message(for: error)
        }
    }
}

/// Labeled single-line input with a leading icon and optional secure entry.
struct AuthField: View {
    let label: String
    let systemImage: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default

    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(width: 20)
                Group {
                    if isSecure && !isRevealed {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboard)
                            .textInputAutocapitalization(keyboard == .emailAddress ? .never : nil)
                            .autocorrectionDisabled()
                    }
                }
                .font(.body)
                .foregroundStyle(Theme.ink)
                if isSecure {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            .frame(minHeight: 46)
            .padding(.horizontal, 12)
            .background(Theme.canvas.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1))
        }
    }
}
