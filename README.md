# LEAGUEPILOT AI Mobile App

This repository holds the Rork/native mobile application and the approved UX/UI design reference.

## Start here

- `design-preview/` — complete clickable React/TypeScript UX/UI prototype.
- `MOBILE_UX_UI_HANDOFF.md` — implementation map for applying the design to the native SwiftUI app.

The preview is intentionally isolated from native app code. When Rork exports or updates the SwiftUI project, keep that code at the repository root and use the preview as the visual and interaction specification.

## Run the clickable preview

```bash
cd design-preview
npm install
npm run dev
```

Open the local URL printed by Next.js. No production credentials are required. All sports values are visibly labeled demo data.

## Technology note

The interactive preview is a React/Next.js project, so the screen markup is in `.tsx` files rather than a single handwritten `index.html`. Next.js generates the HTML during `npm run build`. Styling is in plain CSS.

