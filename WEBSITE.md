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
- Fonts self-hosted via Fontsource. **No CDNs, no trackers, no cookies.**

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

### Motion

Exactly **one orchestrated moment**: the eyes-free swipe gesture animating in
the hero (trail + direction feedback, echoing RemoteControlView). Everything
else is static; hover/focus states only. All motion gated behind
`prefers-reduced-motion`.

## Page structure (index)

1. **Hero** — headline, trial line, **disabled App Store badge** (marked TODO
   until launch), phone mockup + swipe animation
2. **Eyes-free** — the differentiator section, dark full-width band
3. **Value props** — one price / instant connection / private by design
4. **Comparison table** — vs "typical remote apps" (signal color for their column)
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

Two real screenshots from the iOS Simulator (iPhone 16 Pro, app in dark
appearance, connected to a real Roku on the LAN): the swipe remote (hero)
and the channel grid (value props).

## Open items / blockers carried forward

- [ ] Formspree form ID (needs new domain) — swap the TODO constant
- [ ] New domain + published contact email
- [ ] Live privacy-policy URL is an App Store submission blocker;
      `Theme.swift → AppInfo.privacyPolicyURL` still points at example.com
- [ ] App must implement the trial: free download + $4.99 one-time IAP
      (StoreKit work, not website scope)
- [ ] At launch: enable the App Store badge, wire the Formspree endpoint
