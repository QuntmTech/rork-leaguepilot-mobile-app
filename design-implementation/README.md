# LEAGUEPILOT AI — Native Design Implementation Package

This folder is the clean handoff for applying the approved mobile UX/UI to the native SwiftUI app.

It intentionally contains **no fake phone frame, Dynamic Island, desktop preview background, prototype control rail, browser-only navigation, or simulated device chrome**.

## What to use

1. `swiftui/LeaguePilotDesignTokens.swift` — native colors, typography, spacing, radii and shadows.
2. `swiftui/LeaguePilotUIComponents.swift` — reusable native SwiftUI building blocks.
3. `specs/SCREEN_IMPLEMENTATION.md` — screen-by-screen application plan.
4. `specs/SF_SYMBOLS_AND_ASSETS.md` — complete icon and asset mapping.
5. `APPLY_TO_SWIFTUI_PROMPT.md` — ready-to-paste instructions for the implementation AI.
6. `implementation-manifest.json` — machine-readable package inventory and exclusions.

## Visual source of truth

The exact approved visual composition remains available in:

- `design-preview/app/mobile-v2.tsx`
- `design-preview/app/v2.css`

Use only the in-app screen content from those files. Never port these preview-only elements:

- `.v2-shell`
- `.v2-control`
- `.v2-stage`
- `.v2-phone`
- `.v2-status`
- `.v2-home-bar`
- `.v2-mobile-menu`
- `.v2-stage-meta`
- `.v2-stage-note`
- `DemoLabel`
- prototype quick-jump and simulated-network controls

## Asset readiness

The design requires no external player photography or decorative raster artwork. All functional icons map to Apple SF Symbols. The existing native app icon remains in `ios-leaguepilot-ai/LeaguePilotAI/Assets.xcassets/`.

This package contains every new design token, native component definition, icon mapping and implementation instruction required to apply the design without copying browser preview chrome.

