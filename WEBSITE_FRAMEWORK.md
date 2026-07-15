# WEBSITE IMPLEMENTATION PLAN — [BrandName]: Remote for Roku

**Document purpose:** Standalone, phased implementation spec for the product website. Written to be executed by a coding agent (Claude Code) phase by phase. This document supersedes §3.5 (W1–W3) of `ROKU_REMOTE_PROJECT_ROADMAP.md` — the website is a **parallel workstream**, independent of all app phases. The only cross-dependency remains: **the privacy policy page must be live before App Store submission (app Phase 6).**

**Agent instructions:** Work one phase per session. Do not start a phase until the previous phase's Definition of Done is fully checked. Never interleave website work with iOS app work. Commit with conventional commits; tag `web-v0.x` at each phase boundary.

---

## 0. SCOPE, STACK & CONSTRAINTS

### 0.1 What this website is

1. **Marketing landing page** for the app: premium, dark, fast.
2. **Account system**: sign up / log in / password reset, backed by a real database.
3. **Member area**: after login, users land on a lightweight dashboard used for the **waitlist → beta tester → launched** lifecycle (waitlist position, TestFlight invite status/link, launch announcement).
4. **Legal pages**: privacy policy (App Store dependency) + terms.

**What it is NOT:** a payment system (all purchases happen in-app via Apple), a license server (the app never talks to this site), or a blog/CMS. The iOS app remains 100% independent of this website — if the site goes down, the app is unaffected. Do not build any endpoint the app would call.

### 0.2 Locked tech stack ($0/month, no servers to maintain)

| Layer | Choice | Why |
|---|---|---|
| Frontend | **Vite + vanilla TypeScript + plain CSS** (multi-page: `index`, `login`, `signup`, `account`, `privacy`, `terms`) | Static output → free GitHub Pages hosting; no framework runtime to maintain; agent-friendly |
| Hosting | **GitHub Pages** on the Namecheap student domain, HTTPS enforced | Free forever; deploys via Actions |
| Auth + DB | **Supabase free tier** (Auth + Postgres + Row Level Security) | Real accounts with zero server code; generous free tier; the `anon` public key is safe to ship in client JS **by design** — security lives in RLS policies |
| Email | Supabase built-in auth emails (confirmation, password reset) | Free; no SMTP setup for MVP |
| CI/CD | GitHub Actions: build + deploy on push to `website/**` | Already the repo pattern |

**Hard rules for the agent:**
- Zero paid services. Zero secrets in the repo (the Supabase `anon` key is public-by-design and may be committed; the `service_role` key must NEVER appear anywhere in the repo or client code).
- Every table gets Row Level Security enabled before it holds a single row. Default deny; users can only read/update their own row.
- No trackers, no analytics scripts, no cookies beyond Supabase's auth session. This is a brand promise and keeps the privacy policy short.
- Lighthouse ≥ 95 on all four categories is a standing requirement from Phase W2 onward.

### 0.3 Consistency fixes this plan forces elsewhere (do these in Phase W1)

1. **Privacy policy rewrite:** the old draft claimed "No accounts. No data collected." That is now false for the *website*. New structure: the **app** collects nothing and talks only to your Roku on your LAN; the **website** stores your email and account data (via Supabase) solely for waitlist/beta communication; no analytics, no selling data, deletion on request (and self-serve delete in W3).
2. Update `ROKU_REMOTE_PROJECT_ROADMAP.md` §3.5 with a one-line pointer to this document.

---

## 1. BRANDING SPECIFICATION (locked — do not improvise)

### 1.1 Color strategy

Roku's brand purple is **#662D91** — a warm, magenta-leaning purple, typically on white. Our palette stays in the "premium purple" family so Roku owners feel instantly at home, but shifts decisively to a **cool electric indigo on near-black**, a visibly different hue (~30° away on the color wheel) with a completely different light/dark treatment. Never use #662D91 or a near-match (stay out of the #5E2A85–#6E3099 neighborhood entirely). Never imitate the Roku logotype, its tag shape, or its white-background lockup. Include the standard disclaimer in the site footer: *"Not affiliated with or endorsed by Roku, Inc. Roku is a trademark of Roku, Inc."*

### 1.2 Design tokens (implement as CSS custom properties in `tokens.css`)

```css
:root {
  /* Brand — cool electric indigo (vs Roku's warm #662D91) */
  --brand-700: #4338CA;   /* pressed / deep accents */
  --brand-600: #4F46E5;   /* PRIMARY: buttons, links, focus rings */
  --brand-500: #6366F1;   /* hover, highlights */
  --brand-400: #818CF8;   /* subtle accents, icon tints */
  --brand-glow: #A5B4FC;  /* glows, gradient tail — use sparingly */

  /* Hero gradient (the one place we get flashy) */
  --gradient-hero: linear-gradient(135deg, #4F46E5 0%, #7C6CF6 55%, #A5B4FC 100%);

  /* Surfaces — dark-first, matches the app */
  --bg-base:   #0A0A0F;   /* page background (near-black, blue-tinted) */
  --bg-raised: #12121A;   /* cards, nav */
  --bg-overlay:#1A1A26;   /* modals, inputs */
  --border:    #26263A;   /* hairlines */

  /* Text */
  --text-primary:   #F4F4F8;
  --text-secondary: #A0A0B2;
  --text-muted:     #6B6B7E;
  --text-on-brand:  #FFFFFF;

  /* Semantic */
  --success: #34D399;
  --error:   #F87171;
  --warning: #FBBF24;

  --radius-sm: 8px; --radius-md: 14px; --radius-lg: 24px; --radius-pill: 999px;
  --space-unit: 8px; /* all spacing = multiples of 8 */
}
```

### 1.3 Typography & voice

- **Font:** `Inter` (variable, self-hosted woff2 — no Google Fonts CDN, for privacy and speed). Headings 600–700 weight with `-0.02em` tracking; body 400 at 16–18px, line-height 1.6.
- **Type scale:** 56/40/28/20/18/16/14 px (clamp() down on mobile).
- **Voice:** confident, terse, anti-subscription. Sentence case everywhere (no ALL CAPS except tiny eyebrow labels). Core lines: "Try free for 7 days. Then one price, forever." / "No ads. No subscriptions. Ever."
- **Buttons:** pill radius, `--brand-600` fill, white text, subtle 150ms scale-on-press (0.98); secondary = 1px `--border` outline on transparent.

---

## 2. REPOSITORY LAYOUT

```
website/
├── index.html              # landing page
├── login.html
├── signup.html
├── account.html            # member dashboard (auth-gated client-side)
├── reset.html              # password reset landing
├── privacy.html
├── terms.html
├── src/
│   ├── styles/
│   │   ├── tokens.css      # §1.2 verbatim
│   │   ├── base.css        # reset, typography, layout primitives
│   │   └── components.css  # buttons, inputs, cards, nav, footer
│   ├── lib/
│   │   ├── supabase.ts     # client init (URL + anon key)
│   │   └── auth.ts         # signUp, signIn, signOut, resetPassword, getSession, requireAuth
│   ├── pages/              # one TS entry per page
│   └── assets/             # logo.svg, fonts/, mockups/
├── vite.config.ts          # multi-page build, base path for custom domain
├── package.json
└── .github/workflows/deploy-website.yml   # lives at repo root .github/, triggers on website/**
```

---

## 3. PHASED IMPLEMENTATION

---

### PHASE W0 — Pipeline & Placeholder (half a day)

**Goal:** An empty-but-real website deploying automatically to the live domain. All infrastructure risk retired first.

**Tasks:**
1. Register the Namecheap Student Pack domain if not already done. Configure GitHub Pages: custom domain, CNAME file, enforce HTTPS (wait for cert provisioning).
2. Scaffold the Vite multi-page project per §2 with `tokens.css` from §1.2 and a minimal `base.css`.
3. Placeholder `index.html`: logo wordmark, one line ("A premium remote for Roku. Coming soon."), footer with trademark disclaimer. Dark palette from tokens.
4. GitHub Actions workflow: on push touching `website/**` → install, `vite build`, deploy `dist/` to Pages. Verify a trivial change auto-deploys end to end.
5. Create the Supabase project (free tier). Record project URL + anon key in `src/lib/supabase.ts`. Enable email confirmations in Supabase Auth settings. Do not build auth UI yet.

**Definition of Done:**
- [ ] `https://{domain}` serves the placeholder over HTTPS
- [ ] Push-to-deploy verified working
- [ ] Supabase project exists; email confirmation enabled
- [ ] Tag `web-v0.1`

---

### PHASE W1 — Framework Site + Working Accounts (2–3 days) ← the "early phase" deliverable

**Goal:** A structurally complete website, live online, with real sign-up/login against a real database. Plain-but-clean styling only (tokens + base components); no fancy UI yet.

**Tasks:**

*Database (run as SQL migrations in Supabase; RLS first):*
1. `profiles` table: `id uuid PK references auth.users`, `email text`, `display_name text`, `created_at timestamptz default now()`, `waitlist_position serial`, `beta_status text default 'waitlist'` (enum-check: `waitlist | invited | tester`), `testflight_url text null`. Trigger: auto-insert profile row on new auth user.
2. RLS: enable on `profiles`; policies — users can `select` and `update` (display_name only) their own row; no deletes; no reads of other rows. Verify by attempting cross-user reads with two test accounts.

*Auth flows (in `lib/auth.ts` + pages):*
3. **Sign up** (`signup.html`): email + password (min 10 chars) + optional display name → Supabase signUp → "check your email" confirmation state → confirmed users land on `/account`.
4. **Log in** (`login.html`): email + password; friendly error mapping (wrong password vs unconfirmed email vs no account); link to reset.
5. **Password reset:** request form on `login.html` → Supabase reset email → `reset.html` sets new password.
6. **Session handling:** `requireAuth()` guard on `account.html` (redirect to login if no session); nav shows Login/Sign up when logged out, Account/Log out when logged in; log out works from anywhere.
7. **Account dashboard** (`account.html`), minimal: greeting, waitlist position ("You're #42 on the list"), beta status badge, TestFlight button (rendered only when `beta_status='invited'` and URL present), log out.

*Pages & structure:*
8. `index.html` skeleton with real copy in semantic sections (hero, three value props, how-it-works, FAQ stub, CTA → sign up) — structure and copy final, styling basic.
9. `privacy.html` (rewritten per §0.3 — app collects nothing / website stores email for waitlist-beta communication only) and `terms.html` (short, plain-language). Footer links + disclaimer on every page.
10. Form hygiene: client-side validation, disabled-while-pending buttons, error/success states for every async action, no unstyled flashes.

**Testing checklist (execute all):**
- [ ] Sign up → confirmation email arrives → confirm → auto-profile row exists with waitlist position
- [ ] Login wrong password / unconfirmed / nonexistent → distinct friendly errors
- [ ] Password reset full loop works
- [ ] `/account` unreachable logged-out (redirects); reachable logged-in; logout clears session
- [ ] Two-account RLS probe: user A cannot read/modify user B's profile (test via browser console queries)
- [ ] All flows work on the live domain (not just localhost) — Supabase redirect URLs configured for production domain

**Definition of Done:**
- [ ] All tests above pass on production; site fully navigable with final copy
- [ ] Tag `web-v0.2`. **This is the framework milestone the rest builds on.**

---

### PHASE W2 — Landing Page Design (2–3 days)

**Goal:** The public pages go from "clean skeleton" to "premium product site" that sells the app's value proposition.

**Tasks:**
1. **Hero:** headline ("The remote Roku deserves."), subline with trial/one-price promise, primary CTA (Join the waitlist → signup), and an iPhone device mockup showing the app's remote screen (export from the app project; placeholder mock until app Phase 3 assets exist — leave a marked TODO). Restrained use of `--gradient-hero` on the headline accent or mockup glow only.
2. **Value props row:** three cards (One price forever / Instant connection / Private by design — no accounts *in the app*, nothing leaves your Wi-Fi).
3. **"How it works"**: three steps with simple custom SVG line icons (open → auto-finds your Roku → control everything), drawn in `--brand-400` strokes. No stock icon dumps.
4. **Comparison strip:** subtle table vs "typical remote apps" (weekly subscription, ads, trackers → all ✕ for us). Factual, no competitor names.
5. **FAQ:** accordion (native `<details>` styled) — works with all Rokus? / what happens after 7 days? / is it really one-time? / does it need an account? (app: no; site account is only for the waitlist/beta).
6. **Footer:** nav, legal links, disclaimer, "Built independently" line.
7. Fully responsive 320px→1440px; test iPhone SE width specifically.
8. Performance pass: self-hosted font subsetting, `loading="lazy"` images, preload critical CSS. Lighthouse ≥95 ×4.

**Definition of Done:**
- [ ] Side-by-side with roku.com, the site reads as related-in-spirit but unmistakably a different brand
- [ ] Lighthouse ≥95 all categories, mobile + desktop
- [ ] Tag `web-v0.3`

---

### PHASE W3 — UX Depth & Account Polish (2 days)

**Goal:** The logged-in experience and micro-interactions reach app-level quality.

**Tasks:**
1. **Dashboard redesign:** card layout; waitlist position with subtle count-up animation; beta status as a stepped progress indicator (Waitlist → Invited → Tester); copy that sets expectations ("Invites go out in waves during beta").
2. **Self-serve account deletion** (privacy promise): confirm-modal → delete auth user + profile (Supabase RPC with security-definer function). Update privacy.html to mention it.
3. **Micro-interactions site-wide:** button press scale, input focus rings in `--brand-500`, card hover lift (transform only — no layout shift), smooth page-load fade, scroll-triggered fade-up on landing sections via `IntersectionObserver`. **Every animation gated behind `prefers-reduced-motion`.**
4. **Accessibility pass:** full keyboard navigation, visible focus states, ARIA on accordion/modals, color-contrast audit (all text ≥4.5:1 against surfaces — verify `--text-secondary` on `--bg-base`), form labels + error association.
5. **Empty/edge states:** expired reset links, already-confirmed emails, network-failure toasts with retry.
6. OpenGraph/Twitter cards + social share image (dark card, logo, tagline), favicon set, `sitemap.xml`, `robots.txt`.

**Definition of Done:**
- [ ] Keyboard-only walkthrough of every flow succeeds; reduced-motion respected
- [ ] Account deletion verified end-to-end
- [ ] Tag `web-v0.4`

---

### PHASE W4 — Launch Mode (half a day; executed on app launch day)

**Goal:** Flip from waitlist site to launched-product site.

**Tasks:**
1. Hero CTA becomes the official App Store badge (Apple's asset, linked to the store page); waitlist signup demoted to a "get updates" footer form (accounts remain for existing users).
2. Swap mockups for real 1.0 screenshots; add App Store rating badge once reviews exist.
3. Dashboard update: beta stages collapse into "The app is live — download now" state with the store link.
4. Email announcement to all accounts (Supabase → export emails → send via free-tier Mailchimp/Buttondown one-shot campaign; BCC-style privacy, unsubscribe honored by deleting from list).
5. Post-launch: site enters maintenance mode — dependency updates quarterly, otherwise touch nothing.

**Definition of Done:**
- [ ] Launch site live within an hour of App Store approval
- [ ] Announcement sent; tag `web-v1.0` 🎉

---

## 4. RISKS & GUARDRAILS

| Risk | Mitigation |
|---|---|
| Supabase free-tier project pauses after ~1 week of inactivity | Weekly scheduled GitHub Action pinging a trivial select keeps the project warm; traffic at this scale will never exceed free quotas |
| RLS misconfiguration exposes user emails | RLS-first rule (§0.2); mandatory two-account probe test in W1; never use `service_role` client-side |
| Trade-dress drift toward Roku | Palette locked in §1; forbidden hex neighborhood specified; disclaimer in footer; review against roku.com at each phase DoD |
| Privacy policy contradiction with app marketing | §0.3 split-scope policy: "the app collects nothing; the website stores your email for the waitlist" — keep this distinction in ALL copy |
| Scope creep (blog, payments, license keys) | Explicitly out of scope (§0.1). Reject by default |

## 5. SESSION PROTOCOL FOR THE AGENT

Open each session with: *"We are in Phase W{N} of WEBSITE_IMPLEMENTATION_PLAN.md. Current state: [done items]. Complete task W{N}.{X} next."* Close each phase by running its full testing checklist on the **production domain**, not localhost, before tagging.