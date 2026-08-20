# WEBSITE.md — Clicker landing page

Decision record for the website rebuild (2026-08-19). Supersedes the deleted
`WEBSITE_FRAMEWORK.md` (still in git history at `web-v0.x` tags). Every decision
below was settled with the user in a structured interview; do not silently
re-litigate them.

## What it is

A **local-only** marketing and beta-recruitment site for Clicker. No accounts,
no database, no waitlist system, no deploy, no analytics. The old domain
(getclicker.me) is dead; a new domain is not yet chosen. Run with
`npm run dev` in `website/`.

## Stack

- **Astro**, static output. Vanilla — no React/Vue islands unless a component
  genuinely needs client JS (the beta form and swipe animation are plain
  `<script>`).
- Three pages: `index`, `privacy`, `terms`.
- Fonts self-hosted (latin subset, see Type below). **No CDNs, no trackers, no cookies.**

## Design (from the frontend-design skill's two-pass process)

Light-first. **No dark mode** (deliberate; maybe later). The app's darkness
appears only inside device mockups.

### Palette — derived from the app's real asset catalog, not invented

| Token | Hex | Use |
|---|---|---|
| Ground | `#F2F2F7` | Page background (app's light launch bg) |
| Ink | `#0E1417` | Text |
| Teal | `#0FA58B` | Accent (app's light-mode AccentColor) |
| Teal deep | `#0B7D69` | Hover/pressed; small accent text needing contrast |
| Sand | `#EDE3D4` | Secondary band surfaces ONLY — never the full-page ground |
| Signal | `#B8452E` | "Typical remote apps" comparison column + form errors ONLY |
| Black | `#000000` | Device-mockup screens only (matches app's OLED dark bg) |

Guardrail: sand must stay a secondary surface. If sand becomes the dominant
ground the page lands in frontend-design's anti-pattern #1 (warm cream +
serif + terracotta).

### Type

- Display: **Archivo Expanded** (wide, 600–700)
- Body: **Public Sans**
- Labels/eyebrows/microcopy: **JetBrains Mono** (the "hardware labeling" signature)
- Inter is banned (frontend-design skill; also what the old site used).
- Fonts are **hand-declared `@font-face` in `global.css`, latin subset only**,
  from three woff2 files vendored into `public/fonts/`. Fontsource is NOT a
  dependency — we copied the files and dropped the packages so we ship exactly
  three font files. Display face is `<link rel=preload>`ed.

### Signature

The word **"deserves"** in the hero headline is set as a remote key: teal fill,
ink text, rounded — exactly how the app draws a prominent key
(`RemoteKeyStyle(prominent: true)`). This is the page's one typographic risk;
everything around it stays quiet.

### Motion

Exactly **one orchestrated moment**: a **single upward swipe** in the hero —
fingertip travels, trail draws, the app answers with a chevron tick, 5s loop
(echoing RemoteControlView's finger-tracking trail). A second rightward swipe
was built and then deliberately cut — the "remove one accessory" pass.
Everything else is static; hover/focus states only. All motion gated behind
`prefers-reduced-motion`.

## Page structure (index)

1. **Hero** — headline, trial line, **"Get a beta invite" primary button** +
   an **App Store status chip** (`App Store · soon` — deliberately NOT a
   disabled button; a control must state what it does), phone mockup + swipe
   animation
2. **Eyes-free** — the differentiator section, dark full-width band
3. **Value props** — one price / instant connection / private by design
4. **Comparison table** — vs "typical remote apps" (signal color for their
   column). Under 560px it **re-flows into stacked blocks** so the signal-red
   column is never scrolled off-screen, with `data-who` labels naming each
   side so meaning never rests on colour alone
5. **Beta** — single email field → Formspree
6. **FAQ** — 5 items: all Rokus? / after the 7 days? / same Wi-Fi? /
   account or internet needed? / how does the beta work?
7. **Footer** — Roku trademark disclaimer (required on every page)

## Business model (authoritative, per user 2026-08-19)

**Free download → 7-day free trial → $4.99 one-time IAP unlock.** The roadmap
previously said paid-upfront; that was wrong and has been corrected. Site copy
says "Free for 7 days. Then one price, forever." — **no dollar amount on the
site** (user's explicit choice, Q19).

## Beta email form

- **Formspree**, email field only. Endpoint is a single named constant,
  currently `TODO` — create the form once the new domain exists.
- Known Formspree free-tier limits (accepted): 50 submissions/mo, 30-day
  history, no export → the notification inbox is the list of record.
- This is NOT an account system. No passwords, no Supabase, nothing stored
  by us.

## Legal pages

Short, plain language. Privacy policy: the app talks only to your Roku on
your LAN and collects nothing; the website collects only the email you
submit for a beta invite, **via Formspree (named explicitly)**, never sold,
deleted on request. Contact line is a `TODO` until the new domain/email
exists (do not publish the developer's university email).

## Assets

Two real screenshots from the iOS Simulator (**iPhone 17 Pro** — no 16 Pro
runtime on this Mac; same 6.3" class, 402x874pt, app in dark appearance,
connected to a real Roku on the LAN): the swipe remote (hero) and the channel
grid (value props).

**They live in `src/assets/`, not `public/`**, and are rendered with Astro's
`<Image>` so the build emits responsive WebP (656kB of PNG → 14–48kB per
served variant). To replace a screenshot: capture via
`xcrun simctl io <udid> screenshot`, downscale to 804px wide
(`sips --resampleWidth 804`), and overwrite the file in `src/assets/` — the
build re-derives every variant. Note the swipe overlay in `Hero.astro` is
positioned against a `402x874` viewBox; re-aim it if the capture device
changes.

## Round-3 decisions (implementation grilling)

- **One action, one name**: the beta CTA is "Get a beta invite" everywhere —
  nav, hero, and the form's submit button. Never rename it mid-flow.
- **Eyebrow rule**: index-page eyebrows are REAL ECP commands only (the footer
  claims as much, so it must stay literally true). Non-product pages
  (privacy, terms, 404) use plain mono labels with no HTTP-verb fiction.
- **Favicon = the app icon's mark**: simplified D-pad ring (grey arrows, teal
  OK dot on near-black), redrawn as SVG. One brand mark, everywhere.
- **Wordmark split is deliberate**: `clicker_` (lowercase mono, teal cursor)
  is the logotype; "Clicker" (capitalized) is the name in all prose. Keep both.
- **Values kicker**: "no server to rent, no data to sell" line ties all three
  cards to the heading's question.
- **404 page** exists (`404.astro`); **honeypot** (`_gotcha`) is in the beta
  form — bots get a fake success and nothing is sent.
- **Hero recapture checklist** (after the Search-pill-wrap app fix lands):
  1. rebuild app, relaunch in simulator (iPhone 17 Pro, dark)
  2. `xcrun simctl status_bar <udid> override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3`
  3. connect to the Roku, capture remote + channels via `simctl io screenshot`
  4. `sips --resampleWidth 804`, overwrite `src/assets/*.png`
  5. `xcrun simctl status_bar <udid> clear`
  Do NOT rename the user's Roku for captures (decided Q4, round 3).

## Round-2 decisions (UI tweak pass)

Settled in a second grilling session after the first build:

- App Store slot is a **status chip**, not a disabled button (Q1)
- Hero signature is the **"deserves" key-cap** (Q2)
- Hard `<br>` removed from the headline; `text-wrap: balance` handles it (Q3)
- **Nav carries "Get a beta invite"** so the form is reachable from anywhere (Q4)
- Comparison table **restacks under 560px** (Q5)
- "Three promises" → **"Why pay once for a remote?"** (Q6)
- **Second swipe cut** from the hero loop (Q7)
- Screenshots moved to `src/assets/` + Astro `<Image>` (Q8)
- **Latin-only self-hosted fonts**, Fontsource dropped as a dependency (Q9)
- URL-independent **OG/Twitter meta added now**; `og:image` / `og:url` parked (Q10)

## Open items / blockers carried forward

- [ ] Formspree form ID (needs new domain) — swap the TODO constant
- [ ] New domain + published contact email
- [ ] Live privacy-policy URL is an App Store submission blocker;
      `Theme.swift → AppInfo.privacyPolicyURL` still points at example.com
- [ ] App must implement the trial: free download + $4.99 one-time IAP
      (StoreKit work, not website scope)
- [ ] At launch: swap the App Store status chip for Apple's official badge
      asset, wire the Formspree endpoint
- [ ] At deploy: `og:image` (1200x630 share card), `og:url`, PNG favicon
      fallback, `robots.txt`
- [ ] Recapture hero + channels screenshots once the app's quick-action
      pill-wrap fix lands (checklist in Round-3 decisions above)
