# LEAGUEPILOT AI iOS

Mobile Foundation v0.2 is a native SwiftUI iOS 18+ client for the hosted LEAGUEPILOT AI PocketBase control plane. It preserves the three-screen flow: sign in, connect/select an ESPN league, then queue and observe analysis.

## Build and test

Open `LeaguePilotAI.xcodeproj` in Xcode 26 or later, select the shared `LeaguePilotAI` scheme, then use an iOS 18+ simulator. Command line:

```bash
xcodebuild -project LeaguePilotAI.xcodeproj -scheme LeaguePilotAI \
  -destination 'platform=iOS Simulator,name=QUNTM Test 2' clean test
```

The project intentionally has no Apple team configured and retains its temporary Rork bundle identifier until QuntmTech supplies final signing details. The deployment target remains iOS 18.

## Configuration and live contract

`LEAGUEPILOT_CLOUDPOD_URL` is an optional public Xcode build setting exposed through the generated Info.plist. It must be a plain HTTPS origin; invalid values fall back to `https://leaguepilot-ai.cloudpod.pro`.

The app uses PocketBase `users` authentication plus `POST /api/leaguepilot/bootstrap`, `espn_connections`, `job_runs`, `league_snapshots`, and `recommendations`. ESPN saves use the backend's exact snake-case fields, and analysis always includes the selected connection record ID. Mobile and web share users and owner-scoped records through this same backend; their sessions remain intentionally independent. The app refreshes its Keychain-backed token when returning to the foreground.

## Security and limits

The PocketBase token is stored only in this-device Keychain storage. `espn_s2` and `SWID` are form-memory values only and are cleared after every save attempt and when the form closes. The app never contains worker keys, superuser credentials, encryption keys, or ESPN write capability. Approval/review features and PocketBase realtime are not part of this milestone.

An active CloudPod worker is required for queued syncs and analysis to finish. Without an authorized account, league, and worker heartbeat, local tests validate the client contract only; they do not prove a live ESPN analysis.
