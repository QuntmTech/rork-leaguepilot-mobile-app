# SF Symbols and asset manifest

## Required external assets

None. The approved interface does not depend on player photos, league logos, decorative background images or web-hosted artwork.

Keep the existing application icon and accent-color catalog in `ios-leaguepilot-ai/LeaguePilotAI/Assets.xcassets/`.

## Icon mapping

| Purpose | SF Symbol |
|---|---|
| LEAGUEPILOT mark / analysis | `bolt.fill` |
| Home | `house` / `house.fill` |
| Recommendations | `sparkles.rectangle.stack` |
| Reports | `doc.text` / `doc.text.fill` |
| Settings | `gearshape` / `gearshape.fill` |
| ESPN connection | `link` |
| Security/read-only | `shield.checkered` |
| Private credential | `lock.fill` |
| Show password | `eye` |
| Hide password | `eye.slash` |
| Sync | `arrow.clockwise` |
| Activity | `clock.arrow.circlepath` |
| Success | `checkmark.circle.fill` |
| Warning/risk | `exclamationmark.triangle.fill` |
| Error | `xmark.circle.fill` |
| Offline | `wifi.slash` |
| Lineup | `person.crop.rectangle.stack` |
| Waiver | `person.badge.plus` |
| Trade | `arrow.left.arrow.right` |
| Matchup | `figure.american.football` |
| League | `person.3` |
| Confidence | `gauge.with.dots.needle.67percent` |
| Evidence | `checklist` |
| Copy | `doc.on.doc` |
| Share | `square.and.arrow.up` |
| Notifications | `bell` |
| Sign out | `rectangle.portrait.and.arrow.right` |

Use a consistent rounded stroke weight. Icons supplement text; they do not replace status labels.

## Branding rule

The wordmark is rendered as native text plus the bolt mark. No separate logo file is required for screen headers. If a final custom vector logo is added later, place its universal PDF in a named image set under `Assets.xcassets` and retain the text accessibility label `LEAGUEPILOT AI`.

