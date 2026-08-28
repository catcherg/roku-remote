# Clicker website

Marketing and beta-recruitment landing page for Clicker, live at
**https://getclicker.me**.

Static [Astro](https://astro.build) site — no database, no accounts, no
analytics, no trackers, no cookies. Every design and product decision is
recorded in [`../WEBSITE.md`](../WEBSITE.md); read that before changing
anything visual, so settled decisions don't get silently re-litigated.

## Requirements

Node **22** (see `.nvmrc`; anything ≥20.3 works). Nothing else — no global CLI
to install.

## Commands

Run these from the repo root, or drop `--prefix website` if you `cd website`
first.

```bash
npm install --prefix website   # once, after cloning
npm run dev --prefix website   # dev server at http://localhost:4321
npm run build --prefix website # production build into website/dist
npm run preview --prefix website
```

## Layout

```
src/
  pages/       index, privacy, terms, 404 — one file per route
  components/  Hero, EyesFree, ValueProps, Compare, Beta, Faq
  layouts/     Base.astro — head, nav, footer, OpenGraph meta
  styles/      global.css — design tokens, fonts, shared utilities
  assets/      app screenshots (built into responsive WebP)
public/        fonts, favicon, og-image, CNAME, robots.txt
```

Section-specific CSS lives scoped inside each `.astro` component; only tokens
and shared utilities belong in `global.css`.

## Deployment

Pushing to `main` with changes under `website/**` triggers
`.github/workflows/deploy-website.yml`, which builds and publishes to GitHub
Pages on the apex domain. `public/CNAME` carries the domain through each
deploy — don't delete it.

The domain lives in exactly one place in code: `site` in `astro.config.mjs`.
Canonical URLs, OpenGraph tags, and the sitemap all derive from it, so moving
domains is a one-line change plus `public/CNAME` and `public/robots.txt`.

## Still to wire

- **Beta form endpoint** — `FORMSPREE_ENDPOINT` in `src/components/Beta.astro`
  is still `TODO`. Until a real Formspree form ID is set, the form validates
  and reports that signups aren't live yet, but sends nothing.
- **Contact address** on the privacy and terms pages.
- **App Store badge** — the hero shows an `App Store · soon` status chip;
  replace it with Apple's official badge asset at launch.
