# LEAGUEPILOT AI iOS

Mobile Phase 3 is a native SwiftUI iOS 18+ client for the hosted LEAGUEPILOT AI PocketBase control plane. It supports sign in, connect/select an ESPN league, queue and observe analysis, and inspect the backend’s stored league intelligence.

## Build and test

Open `LeaguePilotAI.xcodeproj` in Xcode 26 or later, select the shared `LeaguePilotAI` scheme, then use an iOS 18+ simulator. Command line:

```bash
xcodebuild -project LeaguePilotAI.xcodeproj -scheme LeaguePilotAI \
  -destination 'platform=iOS Simulator,name=QUNTM Test 2' clean test
```

The project intentionally has no Apple team configured and retains its temporary Rork bundle identifier until QuntmTech supplies final signing details. The deployment target remains iOS 18.

## Configuration and live contract

`LEAGUEPILOT_CLOUDPOD_URL` is an optional public Xcode build setting exposed through the generated Info.plist. It must be a plain HTTPS origin; invalid values fall back to `https://leaguepilot-ai.cloudpod.pro`.

The app uses PocketBase `users` authentication plus `POST /api/leaguepilot/bootstrap`, `espn_connections`, `job_runs`, `league_snapshots`, `recommendations`, and `reports`. ESPN saves use the backend's exact snake-case fields, and analysis always includes the selected connection record ID. Mobile and web share users and owner-scoped records through this same backend; their sessions remain intentionally independent. The app refreshes its Keychain-backed token when returning to the foreground.

League Intelligence decodes the selected connection’s latest usable stored snapshot and renders its teams, rosters, standings, current matchup, and opponent detail. Malformed payloads are quarantined, and unsupported schema versions, expiry metadata, and stale backend snapshots are shown with explicit warnings rather than inferred values. Power rankings are rendered only from a stored weekly report’s backend metrics. Home’s “Path to #1” likewise uses that stored ranking plus recommendations linked to the same snapshot; it does not calculate or claim unsupported forecasts.

## Security and limits

The PocketBase token is stored only in this-device Keychain storage. `espn_s2` and `SWID` are form-memory values only and are cleared after every save attempt and when the form closes. The app never contains worker keys, superuser credentials, encryption keys, or ESPN write capability. A recommendation review calls the owner-scoped review endpoint and never submits an ESPN transaction.

While signed in, the app keeps a native PocketBase realtime subscription for connection, job, snapshot, recommendation, and report changes. Transient stream failures reconnect; expired/unauthorized sessions stop realtime work and return to authentication without a retry loop. Those events invalidate the relevant SwiftUI tasks, so a review completed on the web is reflected in mobile without an app restart. APNs device registration and durable alert read/unread state are intentionally not implemented because the backend support for them is not yet available.

An active CloudPod worker and an authorized real ESPN league are required for queued syncs and analysis to finish. Without them, local and CI tests validate the client contract only; they do not prove a live end-to-end ESPN analysis.
