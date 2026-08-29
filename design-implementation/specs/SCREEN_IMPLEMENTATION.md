# Screen implementation specification

## Global native shell

- Root background: `LPColor.background` (`#F3EFE5`), extending through safe areas.
- Use the real iOS status bar and home indicator. Never recreate either in SwiftUI.
- Primary tabs: Home, Recommendations, Reports and Settings.
- Hide the tab bar only for authentication, ESPN setup, analysis progress and focused detail workflows.
- Standard horizontal inset: 16 points; compact screens may use 14 points.
- Minimum interactive target: 44 x 44 points.
- Avoid fixed screen heights. Use `ScrollView`, `safeAreaInset` and Dynamic Type.

## Authentication

Apply to `Views/SignInView.swift` without changing `SessionStore` or PocketBase behavior.

- Warm tan full-screen background with compact brand mark.
- Product promise above fields; no onboarding carousel.
- Off-white fields, 48-point height, 11-point radius and visible focus/error treatment.
- Create Account includes full name, email and password.
- Loading copy: `Preparing your command center…`.
- Include incorrect credentials, validation, rate-limit and offline states.

## Home — disconnected

Apply to `Views/HomeView.swift` while preserving `HomeViewModel` calls.

- Compact header with brand, workspace/week context and avatar.
- Centered off-white ESPN connection card with shield/orbit symbol.
- Copy: `Connect your ESPN league` and `Import your team, matchup and league context securely.`
- Trust row: `Encrypted • Read-only • Never posts moves`.
- Primary CTA: `Connect ESPN`.

## Home — connected

- Forest-green league hero containing league, team, record, opponent, current week and connection status only when supplied.
- Never convert missing values to zero.
- Prominent analysis card: `Run Full Analysis` with truthful stage description.
- Decision queue shows no more than three prioritized recommendations.
- Latest report and My League shortcuts appear below the decision queue.
- Partial-data warning is compact and amber, not alarming.

## Connect ESPN

Apply to `Views/ConnectESPNView.swift` without changing secure submission behavior.

- Fields: League ID, Team ID, Season, private toggle, `espn_s2`, `SWID`.
- Private values use secure inputs with visibility controls.
- Clear cookie state immediately after every successful submission.
- Sticky bottom action respects keyboard and safe area.
- Use plain-language failures; never display raw server payloads.

## Analysis progress

- Stages: Queued, Synchronizing ESPN, Analyzing lineup, Checking waivers, Evaluating trades, Preparing report.
- Display completed/current/waiting state; no fake percentage.
- Allow dismissal while work continues when supported.
- Completed state routes to recommendations.

## Recommendations

- Filter chips: All, Lineup, Waivers, Trades, Approved and Dismissed.
- Every card includes type icon, title, evidence sentence, confidence if supplied, impact if supplied, risk, timestamp and status.
- Differentiate types with icon + label + accent, never color alone.
- Detail view contains evidence, player comparison, source, freshness and risks.
- Approval disclosure must read: `Approval records your decision. LEAGUEPILOT AI does not execute this move on ESPN.`
- Confirmation reads `Decision recorded`, never `Move completed`.

## My League

- League summary, roster, matchup and connection health are separate sections/tabs.
- Omit unavailable scores, records, projections and opponents.
- Provide Sync Now and Edit Connection actions.

## Reports

- Archive row: week, title, publication time, preview and restrained narration label.
- Detail: headline, league/week context, sections, power ranking, matchup summary, manager efficiency and share/copy.
- Sanitize Markdown; do not render untrusted HTML.

## Activity

- Timeline includes connection, sync, analysis, recommendation and report events.
- Job detail may show type, safe status, attempt count and timestamps.
- Never display worker keys, lease tokens, ciphertext, cookies or raw provider payloads.

## Settings

- Groups: Account, Workspace, ESPN, Preferences, Safety and Privacy.
- Label unimplemented preferences `Coming later`; do not create functioning-looking dead controls.
- Keep Sign Out visually separated.

## Required states

Every implemented screen must include loading, empty, offline, recoverable error and unavailable-data handling appropriate to that surface. Realtime changes must update existing state rather than inserting fabricated production data.

