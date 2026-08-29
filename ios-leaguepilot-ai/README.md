# LeaguePilot AI — mobile starter

A minimal, working mobile starter for **LEAGUEPILOT AI**: sign in, connect ESPN, queue full analysis, and read back job status + recommendations. Exactly three screens, nothing more.

> Note: this workspace builds native SwiftUI iOS apps (new Expo/React Native projects are no longer supported by the platform). The screens, backend calls, and scope match the original brief.

## Screens

1. **Sign In** — email/password sign in against PocketBase `users`, a compact create-account option, session persisted in the Keychain (stay signed in), workspace bootstrap after auth, basic Sign Out.
2. **Home** — app name, workspace name, ESPN connection status, Connect ESPN button when disconnected, Run Analysis when connected, latest job status, newest recommendations as a plain list. Pull-to-refresh re-reads everything. No realtime, no charts.
3. **Connect ESPN** — League ID, Team ID, Season, public/private toggle; private leagues also show password-style `espn_s2` and `SWID` inputs that are cleared immediately after submission and never stored or displayed again.

## Configuration

- `EXPO_PUBLIC_CLOUDPOD_URL` — PocketBase base URL (default fallback: `https://leaguepilot-ai.cloudpod.pro`). See `LeaguePilotAI/Utilities/LeaguePilotConfig.swift`.
- Expected PocketBase collections (rename in `LeaguePilotConfig.swift` if your schema differs):
  - `analysis_jobs` — fields used: `workspace`, `kind`, `status`, `created`
  - `recommendations` — fields used: `workspace`, `title` (or `summary`), `matchup`/`detail`, `confidence`, `created`

## Backend endpoints used

- `POST /api/collections/users/auth-with-password` — sign in
- `POST /api/collections/users/auth-refresh` — session restore on launch
- `POST /api/collections/users/records` — create account
- `POST /api/leaguepilot/bootstrap` — ensure/load the user's workspace
- `POST /api/leaguepilot/workspaces/{workspaceId}/analysis` — body `{"kind":"full","notify":false}`
- `PUT /api/leaguepilot/workspaces/{workspaceId}/connections/espn` — body `{"leagueId","teamId","season","isPrivate","espnS2?","swid?"}`

## Security

- Session token is stored in the iOS Keychain only. No tokens, cookies, or keys are committed or logged.
- `espn_s2` / `SWID` live only in memory inside the form fields and are wiped right after submit.
- The server URL is a public address, not a secret.

## Layout

Standard MVVM: `Models/`, `Services/`, `ViewModels/`, `Views/`, `Utilities/`. The service layer is plain request/response — realtime sync can be added later without touching the UI.
