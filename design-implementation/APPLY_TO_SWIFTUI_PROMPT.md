# Prompt: Apply the approved LEAGUEPILOT AI design to the native app

Work inside `QuntmTech/rork-leaguepilot-mobile-app` on the current `main` branch.

Before editing, verify that both `ios-leaguepilot-ai/` and `rork.json` exist. If either is missing, stop. Never replace the repository tree or delete the native app.

Read completely:

1. `design-implementation/README.md`
2. `design-implementation/swiftui/LeaguePilotDesignTokens.swift`
3. `design-implementation/swiftui/LeaguePilotUIComponents.swift`
4. `design-implementation/specs/SCREEN_IMPLEMENTATION.md`
5. `design-implementation/specs/SF_SYMBOLS_AND_ASSETS.md`
6. `MOBILE_UX_UI_HANDOFF.md`
7. `design-preview/app/mobile-v2.tsx`
8. `design-preview/app/v2.css`

Apply the approved tan-and-green design natively to the existing SwiftUI application. Preserve the existing MVVM structure, Keychain session persistence, PocketBase service layer, endpoints, authentication, ESPN connection behavior and all working backend calls.

Do not copy the browser preview shell. Exclude the fake phone, Dynamic Island, desktop background, preview control rail, demo labels, quick-jump navigation, localStorage and simulated network controls. Use native safe areas, the real iOS status bar, real navigation and real application state.

First merge the provided tokens into `Utilities/Theme.swift`. Then add or merge the provided reusable components into `Utilities/Components.swift`. Update `SignInView.swift`, `HomeView.swift` and `ConnectESPNView.swift` first. After Priority A builds and tests pass, implement the four-tab shell and the remaining feature screens as small native SwiftUI modules.

Use SF Symbols from the supplied mapping. No external image assets are required. Do not invent sports data, recommendation confidence, projections, records, opponents, sync times or completed ESPN actions. Approval records a decision and never implies ESPN execution.

Verify on an iPhone 16 Pro reference size, a smaller iPhone and a common Android-equivalent width where the platform preview supports it. Verify Dynamic Type, VoiceOver labels, 44-point touch targets, keyboard avoidance, safe areas and Reduce Motion.

Run the native build and existing tests. Report the exact files changed, flows proven, simulated behavior, backend-dependent behavior not run and any remaining design-only screens. Do not claim the design is complete merely because the app builds.

