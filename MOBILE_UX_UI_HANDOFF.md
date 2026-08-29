# LEAGUEPILOT AI — Mobile UX/UI Handoff

## Source of truth

- Native product base: the Rork-generated SwiftUI application in this repository.
- Clickable design reference: `design-preview/`.
- Backend source of truth: `https://leaguepilot-ai.cloudpod.pro`.
- Public prototype: `https://leaguepilot-mobile-preview.amplycoindustries.chatgpt.site`.

The preview is a design and interaction reference. It must not replace the native SwiftUI architecture, PocketBase service layer, Keychain handling, or existing working behavior.

## Exact file map

| Purpose | File |
|---|---|
| Main interactive mobile experience and state machine | `design-preview/app/mobile-v2.tsx` |
| Complete mobile styling and responsive rules | `design-preview/app/v2.css` |
| Global tokens and Tailwind foundation | `design-preview/app/globals.css` |
| Generated HTML shell and metadata | `design-preview/app/layout.tsx` |
| Preview entry route | `design-preview/app/page.tsx` |
| Buttons, inputs, switches, tabs, dialogs and toasts | `design-preview/components/ui/` |
| Shared class helper | `design-preview/lib/utils.ts` |
| Dependencies and run commands | `design-preview/package.json` |
| Responsive 393 x 852 presentation plus Android fallback | `design-preview/app/v2.css` |

There is no separate handwritten HTML file. Next.js compiles `layout.tsx`, `page.tsx`, and `mobile-v2.tsx` into HTML. This keeps the prototype interactive and component-based.

## Implemented prototype flows

- Sign in, create account, forgot password and validation.
- First-time disconnected Home state.
- Public/private ESPN connection, secure cookie fields and success state.
- Connected command-center Home.
- Stage-based full analysis: queued, synchronization, lineup, waivers, trades, report and completion.
- My League with lineup, matchup and connection views.
- Recommendation filters, details, evidence, risk and persistent approve/dismiss decisions.
- Reports archive and readable report detail.
- Activity and job-status timeline.
- Settings, sync, disconnect and sign out.
- Offline and safe error overlays.
- Local persistence for authentication, connection and recorded decisions.

## Brand tokens

| Token | Value |
|---|---|
| Warm tan background | `#F3EFE5` |
| Off-white card | `#FFFDF8` |
| Forest-green primary | `#1D5949` |
| Bright-green highlight | `#2F7A63` |
| Dark text | `#17221F` |
| Border | `#D7D1C6` |
| Muted text | `#6E7772` |
| Lime accent | `#B8DC73` |

Do not introduce navy, dark backgrounds, or blue accents.

## Native SwiftUI application mapping

| Preview surface | SwiftUI destination |
|---|---|
| Auth screen | `SignInView` and `SessionStore` |
| Home disconnected/connected | `HomeView` and `HomeViewModel` |
| ESPN connection | `ConnectESPNView` and `ConnectESPNViewModel` |
| Recommendations | New feature module using the existing service layer |
| Reports | New feature module using the existing service layer |
| Activity/jobs | New feature module using the existing service layer |
| Settings | New feature module using session and connection services |

Port design tokens into `Theme.swift`, then split the preview's reusable patterns into native components: app header, bottom navigation, league hero, analysis card, recommendation card, risk badge, confidence indicator, report card, empty state, error state, skeleton loader, secure input, buttons and confirmation sheet.

## Expected backend actions

| User action | Backend contract |
|---|---|
| Sign in | PocketBase password authentication |
| Create account | PocketBase user creation |
| Restore session | PocketBase auth refresh |
| Prepare workspace | `POST /api/leaguepilot/bootstrap` |
| Save ESPN connection | `PUT /api/leaguepilot/workspaces/{workspaceId}/connections/espn` |
| Run full analysis | Existing analysis endpoint in `LeaguePilotService` |
| Approve/dismiss recommendation | Recommendation decision endpoint/collection action |
| Sync league | Existing ESPN sync/job endpoint |

Do not add a second backend, client-side analysis engine, PocketBase administrator credentials, stored ESPN cookies, or direct ESPN write actions.

## Data and security rules

- Preview sports values are labeled `Demo data`; never mix them with a live authenticated account.
- Missing real values must be omitted or shown as `Not available`.
- ESPN cookies disappear immediately after successful submission.
- Approval means `Decision recorded`; it never means a move was completed on ESPN.
- Treat all league, owner, team and player names as untrusted text.
- Render report Markdown safely and never render untrusted HTML.

## Accessibility and responsive behavior

- Reference canvas: 393 x 852 points.
- CSS includes smaller-device and Android-width adaptations.
- Keep native touch targets at least 44 points.
- Preserve visible text labels alongside status color and icons.
- Support Dynamic Type, VoiceOver/TalkBack, safe areas and reduced motion.

## Preview versus production

The preview is fully clickable but intentionally uses local demo state. Backend calls must remain in the native app's existing service layer. The recommended implementation sequence is: central tokens, reusable components, Priority A screens, navigation shell, recommendations, reports, activity, settings, then realtime subscriptions and exhaustive state handling.

