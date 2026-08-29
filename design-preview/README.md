# Clickable mobile UX/UI preview

This folder contains the complete interactive LEAGUEPILOT AI mobile design reference.

```bash
npm install
npm run dev
```

Main files:

- `app/mobile-v2.tsx` — screens, demo data and interactions.
- `app/v2.css` — complete visual system and responsive behavior.
- `app/globals.css` — global brand tokens and CSS foundation.
- `app/page.tsx` — entry page.
- `app/layout.tsx` — generated HTML shell and metadata.
- `components/ui/` — reusable UI primitives.

The project generates HTML from React/TypeScript. It does not use a monolithic static `index.html` file.

Prototype state is stored only in browser `localStorage`. The preview does not contain PocketBase administrator credentials, ESPN cookies, worker keys, or production secrets.
