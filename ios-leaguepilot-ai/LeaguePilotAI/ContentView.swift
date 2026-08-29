//
//  ContentView.swift
//  LeaguePilotAI
//

import SwiftUI

/// Root gate: splash while restoring, Sign In when signed out, Home when signed in.
struct ContentView: View {
    @State private var session = SessionStore()

    var body: some View {
        Group {
            if session.isRestoringSession {
                VStack(spacing: 12) {
                    Text("LEAGUEPILOT AI")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.forest)
                    ProgressView()
                        .tint(Theme.forest)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if session.isSignedIn {
                HomeView(session: session)
            } else {
                SignInView(session: session)
            }
        }
        .background(Theme.canvas)
        .tint(Theme.forest)
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.2), value: session.isSignedIn)
    }
}

#Preview {
    ContentView()
}
