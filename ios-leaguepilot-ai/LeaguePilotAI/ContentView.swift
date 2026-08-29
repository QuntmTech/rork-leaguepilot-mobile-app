//
//  ContentView.swift
//  LeaguePilotAI
//

import SwiftUI

/// Root gate: splash while restoring, Sign In when signed out, Home when signed in.
struct ContentView: View {
    @State private var session = SessionStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch session.phase {
            case .restoring, .loadingWorkspace, .loadingDashboard:
                VStack(spacing: 12) {
                    Text("LEAGUEPILOT AI")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.forest)
                    ProgressView()
                        .tint(Theme.forest)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                AuthenticatedShell(session: session)
            case .signedOut, .authenticating:
                SignInView(session: session)
            case let .failed(message):
                VStack(spacing: 14) {
                    Text("We couldn't load your league").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                    Text(message).font(.footnote).foregroundStyle(Theme.inkSecondary).multilineTextAlignment(.center)
                    Button("Retry") { Task { await session.retry() } }.buttonStyle(PrimaryButtonStyle())
                    Button("Sign Out") { session.signOut() }.buttonStyle(OutlineButtonStyle())
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.canvas)
        .tint(Theme.forest)
        .preferredColorScheme(.light)
        .task { await session.restoreSession() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await session.refreshSessionOnForeground() }
            }
        }
    }
}

#Preview {
    ContentView()
}
