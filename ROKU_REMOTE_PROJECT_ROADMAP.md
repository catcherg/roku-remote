# PROJECT ROADMAP: Premium Roku Remote for iOS (Lean MVP)

**Document purpose:** This is the master framework and execution roadmap for building a premium, one-time-purchase iOS remote control app exclusively for Roku TVs and streaming devices. It is written to be handed directly to Claude Code as the authoritative project specification. Each phase is self-contained, ends at a stable stopping point, and has explicit acceptance criteria ("Definition of Done"). Work through phases strictly in order.

---

## 0. EXECUTIVE SUMMARY

**Product:** A beautifully designed, dark-mode-optimized iOS app that discovers Roku devices on the local Wi-Fi network and controls them via Roku's official External Control Protocol (ECP).

**Business model:** One-time upfront purchase (target: $4.99–$6.99). No ads, no subscriptions, no accounts, no backend. Viable because Roku ECP is an officially documented, stable REST API requiring near-zero ongoing maintenance.

**Non-negotiable constraints:**
- Roku devices ONLY. No Samsung/LG/Sony/Fire TV. Scope creep here kills the business model.
- No server-side backend. Everything is device-to-device over the LAN.
- Bootstrap budget: GitHub Student Developer Pack for all tooling; the only unavoidable cost is the Apple Developer Program ($99/yr — see §2.4).
- Ship fast. Prefer boring, proven approaches over clever ones.

**Tech stack (locked):**
- Swift 5.10+ / SwiftUI, iOS 16.0 minimum deployment target
- `Network.framework` (NWConnection/NWListener) for UDP SSDP; `URLSession` for ECP HTTP
- Swift Package `RokuKit` for all networking logic (UI-independent, unit-testable)
- XCTest for unit tests; GitHub Actions for CI
- Static landing page: plain HTML/CSS on GitHub Pages + free-tier email capture
- Zero third-party dependencies in the app unless absolutely necessary

---

## 1. CRITICAL TECHNICAL KNOWLEDGE (READ BEFORE WRITING ANY CODE)

### 1.1 Roku External Control Protocol (ECP) — the core of the app

Every Roku device runs an HTTP server on **port 8060**. All control is plain HTTP over the LAN. Key endpoints:

| Endpoint | Method | Purpose |
|---|---|---|
| `/query/device-info` | GET | XML: model, friendly name, serial, power state, `is-tv` flag |
| `/query/apps` | GET | XML list of installed channels with app IDs |
| `/query/icon/{appID}` | GET | PNG icon for a channel (use for the channel launcher grid) |
| `/query/active-app` | GET | Currently running channel |
| `/keypress/{key}` | POST | Simulate a single button press |
| `/keydown/{key}` / `/keyup/{key}` | POST | Press-and-hold support (use for volume ramping) |
| `/launch/{appID}` | POST | Launch a channel (e.g., Netflix = 12, YouTube = 837) |
| `/search/browse?...` | POST | Deep search (v1.1 feature, not MVP) |

**Valid `{key}` values (memorize these):** `Home`, `Rev`, `Fwd`, `Play`, `Select`, `Left`, `Right`, `Up`, `Down`, `Back`, `InstantReplay`, `Info`, `Backspace`, `Search`, `Enter`, `VolumeUp`, `VolumeDown`, `VolumeMute`, `PowerOff`, `PowerOn`, `Power`, `ChannelUp`, `ChannelDown`, `InputTuner`, `InputHDMI1`–`InputHDMI4`, `InputAV1`, `FindRemote`.

- Volume/Power/Input keys only work on **Roku TVs** (`is-tv: true` in device-info), not streaming sticks. The UI must adapt: hide/disable volume & power controls for non-TV devices.
- **Keyboard input:** send `keypress/Lit_{URL-encoded UTF-8 character}` per character (e.g., `Lit_a`, `Lit_%20` for space). This powers the killer "type with your phone keyboard" feature.
- All requests are fire-and-forget; success = HTTP 200 with empty body. Timeout aggressively (1.5–2s) and treat failure as "device unreachable."

### 1.2 Device discovery — TWO strategies required (this is the project's biggest hidden risk)

**Strategy A — SSDP (primary):** Send a UDP multicast M-SEARCH to `239.255.255.250:1900` with `ST: roku:ecp`. Rokus respond with unicast UDP containing a `LOCATION: http://{ip}:8060/` header.

⚠️ **CRITICAL APPLE GOTCHA:** Since iOS 14, *sending multicast/broadcast UDP requires the `com.apple.developer.networking.multicast` entitlement*, which must be **requested from Apple via a web form and manually approved** (typically days to a few weeks). This is a hard blocker if not handled on Day 1.

**Strategy B — Unicast subnet scan (fallback, build it anyway):** Enumerate the local /24 subnet (get device IP via `getifaddrs`, derive subnet), issue concurrent `GET http://{ip}:8060/query/device-info` requests with ~1s timeouts (cap concurrency at ~32). Unicast TCP requires NO special entitlement. Slower (~5–10s worst case) but always works. Also implement **manual IP entry** as a last resort (Roku shows its IP in Settings → Network → About).

**Decision rule:** Request the multicast entitlement in Phase 0. Build Strategy B first (no approval dependency), add Strategy A when/if the entitlement is granted. The app must be fully shippable on Strategy B alone.

### 1.3 iOS Local Network privacy

- Add `NSLocalNetworkUsageDescription` to Info.plist with honest, friendly copy: *"This app needs local network access to find and control Roku devices on your Wi-Fi."*
- If using Bonjour APIs anywhere, `NSBonjourServices` must list service types. (Roku uses SSDP, not Bonjour — you likely won't need this.)
- The first network operation triggers the iOS Local Network permission dialog. **Design onboarding around it:** explain WHY before triggering it, and build a clear "permission denied" recovery screen (deep-link to Settings via `UIApplication.openSettingsURLString`).
- iOS Simulator shares the Mac's network — SSDP/ECP work in the simulator if the Mac is on the same Wi-Fi as a Roku. A physical Roku device (a $25–30 used Roku Express is fine) is a **required piece of test equipment**.

### 1.4 Roku-side failure mode users WILL hit

Roku setting: **Settings → System → Advanced system settings → Control by mobile apps → Network access.** If set to **"Limited"** (some ISP-branded units default to this), ECP is blocked and the device is undiscoverable/uncontrollable. The app MUST detect this scenario (device found via SSDP but ECP requests fail, or nothing found at all) and show a help screen with these exact navigation steps. This will otherwise be the #1 source of 1-star reviews.

### 1.5 Legal / App Store landmines

- **Never name the app "Roku Remote."** Roku is a trademark; App Review Guideline 5.2 rejects names implying affiliation. Use the nominative pattern: **"[BrandName] – Remote for Roku"** (e.g., "Rokie – Remote for Roku"). No Roku logo, no Roku purple (#662D91) as brand color, and include a footer/settings disclaimer: *"Not affiliated with or endorsed by Roku, Inc. Roku is a trademark of Roku, Inc."*
- Paid apps get extra App Review scrutiny; the app must visibly work in review. Include a Reviewer Note explaining a Roku device on the same network is required, plus a demo video link.
- Enroll in the **App Store Small Business Program** (revenue < $1M) → 15% commission instead of 30%.

### 1.6 Budget reality check (correcting the source plan)

- **Apple Developer Program: $99/yr, NOT in the Student Pack.** Check eligibility for Apple's fee waiver (available to eligible students/nonprofits in some regions); otherwise this is the single unavoidable cost.
- **DigitalOcean credits: NOT NEEDED.** The app has no backend. GitHub Pages hosts the landing page free. Cutting this strengthens the zero-maintenance thesis. Keep credits in reserve only.
- Student Pack items actually used: GitHub Pro (private repos, Actions minutes), Copilot, Namecheap free `.tech`/`.me` domain, GitHub Pages.

---

## 2. ARCHITECTURE

### 2.1 Repository structure (monorepo)

```
roku-remote/
├── CLAUDE.md                  # Claude Code project memory (see §2.3)
├── README.md
├── .github/workflows/ci.yml   # build + test on every push
├── RokuKit/                   # Swift Package — ALL networking, zero UI
│   ├── Package.swift
│   ├── Sources/RokuKit/
│   │   ├── Models/            # RokuDevice, RokuApp, DeviceInfo, ECPKey
│   │   ├── ECP/               # ECPClient (URLSession-based)
│   │   ├── Discovery/         # SSDPDiscoverer, SubnetScanner, DiscoveryCoordinator
│   │   └── Persistence/       # SavedDeviceStore (UserDefaults/Codable)
│   └── Tests/RokuKitTests/    # unit tests w/ URLProtocol mocks
├── App/                       # Xcode project (SwiftUI app target)
│   └── RokuRemote/
│       ├── App/               # entry point, AppState
│       ├── Features/
│       │   ├── Onboarding/
│       │   ├── Discovery/     # device list, scanning UI, manual IP entry
│       │   ├── Remote/        # main remote screen (d-pad, transport, volume)
│       │   ├── Channels/      # channel launcher grid
│       │   ├── Keyboard/      # text input sheet
│       │   ├── Settings/      # haptics toggle, legal, help
│       │   └── Help/          # troubleshooting (incl. "Limited mode" fix)
│       └── DesignSystem/      # colors, typography, buttons, haptics
└── website/                   # static landing page → GitHub Pages
    ├── index.html
    ├── styles.css
    └── privacy.html           # required for App Store listing
```

### 2.2 Design principles

- **MVVM, lightly.** One `@Observable` (or `ObservableObject`) view model per feature. `RokuKit` is the model layer; views never touch networking directly.
- **RokuKit is a pure Swift package** — no UIKit/SwiftUI imports. Everything async/await. This makes it testable in CI *without a simulator or a real Roku* by mocking `URLProtocol` and injecting fake UDP transports.
- **Optimistic UI:** button taps fire haptic + visual feedback immediately, send the ECP request in the background, and only surface errors after N consecutive failures (show a non-blocking "Reconnecting…" banner). A remote must feel instant.
- **State machine for connection:** `disconnected → discovering → connected(device) → unreachable(device)`. Model it as an enum; drives all UI.
- **Persistence:** last-connected device (name + IP + serial) in UserDefaults. On launch: try last device directly (single `device-info` ping) before running discovery. Instant reconnect = premium feel.

### 2.3 CLAUDE.md (create this file verbatim in Phase 0)

```markdown
# Roku Remote — Claude Code Project Memory
- iOS 16+, Swift 5.10, SwiftUI, zero third-party dependencies.
- ALL networking lives in RokuKit (Swift Package). UI code never constructs URLs.
- ECP base: http://{ip}:8060 — see ROKU_REMOTE_PROJECT_ROADMAP.md §1.1 for endpoints/keys.
- Discovery: SubnetScanner is primary until multicast entitlement approved; SSDPDiscoverer behind a capability check.
- Volume/Power keys ONLY shown when device-info reports is-tv=true.
- Every RokuKit public API needs a unit test. Run: `swift test` in RokuKit/, `xcodebuild test` for app.
- Timeouts: 2s ECP commands, 1s subnet-scan probes, 4s SSDP window.
- Never block the main thread; all networking async/await.
- Brand: NOT named "Roku Remote"; no Roku logos/purple. Disclaimer in Settings.
- Commit style: conventional commits (feat:, fix:, test:, chore:).
```

---

## 3. PHASED ROADMAP

> **Cadence assumption:** one focused developer + Claude Code, moving as fast as possible. Durations are aggressive estimates. Every phase ends with: all tests green, CI passing, code committed and tagged (`v0.x`), and a working build — a true stopping point.

---

### PHASE 0 — Foundation & Unblocking (Day 1; ~half a day of work, then async waits)

**Goal:** Eliminate every external dependency that has a waiting period, and stand up the skeleton so all later work is pure execution.

**Tasks:**
1. **Apple Developer Program:** enroll immediately (approval can take 24–48h). Check student fee-waiver eligibility first.
2. **Multicast entitlement:** submit the `com.apple.developer.networking.multicast` request form on the Apple Developer portal immediately (longest external wait in the project). Justification text: "TV remote control app; SSDP M-SEARCH multicast is required to discover Roku devices on the user's local network."
3. Redeem GitHub Student Pack: GitHub Pro, Copilot, Namecheap domain. Register domain (e.g., `getrokie.tech`). Don't build the site yet.
4. Order/acquire a physical Roku test device if not owned (cheapest Roku Express, used is fine).
5. Create the monorepo with the §2.1 structure: empty Xcode SwiftUI project (bundle ID reserved), empty RokuKit package with one placeholder test, `CLAUDE.md` from §2.3.
6. GitHub Actions CI: on push → `swift build && swift test` for RokuKit + `xcodebuild build` for the app target (macOS runner). Badge in README.
7. Pick the final app name; verify App Store availability and trademark cleanliness; reserve the name in App Store Connect once enrollment clears.

**Definition of Done:**
- [ ] Developer enrollment + entitlement request submitted (screenshots/receipts saved)
- [ ] Repo pushed, CI green on the skeleton
- [ ] Domain registered; app name chosen and reserved
- [ ] Physical Roku device on hand or in transit

---

### PHASE 1 — RokuKit: The Engine (Days 2–4)

**Goal:** A fully tested, UI-free Swift package that can find and control a Roku. If Phases 2+ were cancelled, RokuKit alone would still be a working product (usable from a script).

**Tasks:**
1. **Models:** `ECPKey` enum (all keys from §1.1, raw-value = ECP string), `RokuDevice` (id/serial, name, ip, isTV, model), `RokuApp` (id, name), `DeviceInfo` XML parsing via `XMLParser` (no dependencies).
2. **ECPClient:** `URLSession`-based; methods: `deviceInfo(ip:)`, `apps(ip:)`, `icon(appID:)`, `keypress(_:)`, `keydown/keyup(_:)`, `launch(appID:)`, `typeText(_:)` (per-character `Lit_` encoding with proper URL-encoding of UTF-8). 2s timeout, no retries at this layer.
3. **SubnetScanner:** derive local IPv4 + netmask via `getifaddrs`; concurrent probe of subnet (TaskGroup, max 32 in flight, 1s timeout each); yields devices via `AsyncStream<RokuDevice>` as found.
4. **SSDPDiscoverer:** `NWConnection` UDP multicast M-SEARCH (`ST: roku:ecp`, MX 3), parse `LOCATION` headers, resolve via `device-info`, 4s listen window. Wrap in a capability check so it soft-fails to the scanner when the entitlement is absent.
5. **DiscoveryCoordinator:** public façade — runs SSDP first (if available), falls back to / merges with subnet scan, de-dupes by serial number, single `AsyncStream<RokuDevice>` API.
6. **SavedDeviceStore:** Codable persistence of known devices + last-connected, on UserDefaults.
7. **Tests (the point of this phase):** URLProtocol-mocked tests for every ECPClient method (correct paths, methods, encodings — especially `Lit_` for spaces, emoji, unicode); XML parsing fixtures (real captured `device-info`/`apps` payloads for a Roku TV and a stick); scanner IP-derivation math tests; de-dupe logic tests. Target ≥85% coverage on RokuKit.
8. **Live smoke test** (manual, not CI): tiny CLI or XCTest marked `.skip` in CI that hits the real Roku on the dev network — verify keypress, launch, typeText against physical hardware.

**Definition of Done:**
- [ ] `swift test` green in CI; coverage ≥85% on RokuKit
- [ ] Manual smoke test against a physical Roku: discovery <10s (scan) and every command works
- [ ] Tag `v0.1.0`

---

### PHASE 2 — Functional MVP App (Days 5–8)

**Goal:** An ugly-but-complete app: launch → find device → control it. All flows work end-to-end. No polish yet.

**Tasks:**
1. **AppState + connection state machine** (§2.2 enum) as the single source of truth.
2. **Onboarding (minimal):** one screen explaining local-network permission → trigger first discovery → handle permission-denied with the Settings deep-link recovery screen.
3. **Discovery screen:** live-updating device list (stream from DiscoveryCoordinator), pull-to-rescan, manual-IP-entry sheet (validate by calling `device-info`), device rename, remembered devices shown instantly on later launches.
4. **Auto-reconnect:** on launch, ping last device first; skip discovery entirely on success.
5. **Remote screen (functional layout):** d-pad (Up/Down/Left/Right/Select), Back/Home, transport (Rev/Play/Fwd, InstantReplay, Info), volume cluster + power (conditionally rendered only when `isTV`), mute. Every control wired through the view model to ECPClient.
6. **Keyboard sheet:** button opens a text field; per-keystroke send via `typeText`; Backspace and Enter mapped.
7. **Channel grid:** fetch `/query/apps`, lazy-load icons (`/query/icon/{id}`) with in-memory + disk cache, tap to `/launch/{id}`.
8. **Error handling:** consecutive-failure detection → "Reconnecting…" banner → after timeout, offer rescan + link to the Help screen; Help screen includes the §1.4 "Limited mode" walkthrough with exact Roku menu steps.
9. Unit tests for view-model logic (state transitions, failure counting).

**Definition of Done:**
- [ ] Full happy path on a physical device: cold launch → auto-reconnect → control TV in <3 seconds
- [ ] All failure paths reachable and recoverable (permission denied, no devices, device lost mid-session, Limited mode)
- [ ] CI green; tag `v0.2.0`. **This build is the go/no-go checkpoint: everything after this is polish and packaging.**

---

### PHASE 3 — Premium Polish (Days 9–13)

**Goal:** Transform the functional app into something that *justifies the price tag*. This phase IS the product differentiator — the entire business thesis is "premium quality for one fair price."

**Tasks:**
1. **Design system:** define tokens (colors, spacing, type scale — SF Pro / SF Rounded), true-black dark-mode-first palette with a single restrained accent color (not purple), light mode as a correct-but-secondary citizen.
2. **Remote screen redesign:** large circular d-pad with concave visual affordance, correct thumb-reach ergonomics (primary controls in bottom 60% of screen), subtle press animations (scale + brightness, 100–150ms), grouped control clusters.
3. **Haptics:** `UIImpactFeedbackGenerator` — light for d-pad, medium for Select/Home, rigid for power; volume press-and-hold uses `keydown`/`keyup` with repeating light ticks. Haptics toggle in Settings.
4. **Micro-interactions:** connected-device pill with live status dot; smooth state-transition animations; skeleton shimmer while channel icons load; launch screen matching the dark palette.
5. **Onboarding polish:** 2–3 elegant screens (value prop → permission explainer → scanning animation).
6. **App icon** (dark, premium, abstract remote/d-pad motif — no Roku trade dress) + tinted/dark iOS variants.
7. **Accessibility:** VoiceOver labels on every control ("Directional pad, up"), Dynamic Type where sane, ≥44pt targets, `Reduce Motion` respected.
8. **Settings screen:** haptics toggle, default device, rename/forget devices, Help, legal disclaimer (§1.5), privacy policy link, version.
9. **App-quality housekeeping:** no layout breakage from iPhone SE → Pro Max; portrait-locked (deliberate choice for MVP); zero console warnings.

**Definition of Done:**
- [ ] Side-by-side with the official Roku app, this app looks and feels more premium (honest self-assessment + 2–3 outside opinions)
- [ ] Full VoiceOver pass completed
- [ ] Tag `v0.3.0`

---

### PHASE 4 — Hardening & Real-World Chaos (Days 14–16)

**Goal:** Survive everything a real home network throws at it. A paid app with connectivity bugs gets refunded and 1-starred.

**Test matrix (execute manually, fix everything found):**
1. Wi-Fi off mid-session / airplane mode / cellular-only → correct messaging, no hangs
2. Roku powered off mid-session; Roku IP changes (DHCP renewal) → rediscovery by serial number rescues the saved device
3. Phone sleeps 10 min → resume reconnects silently; app backgrounded/foregrounded rapidly
4. Router with client isolation (guest network) → clear "your network may be blocking device-to-device traffic" help text
5. Multiple Rokus on one network → clean multi-device management and switching
6. Roku "Limited" mode → Help flow actually rescues the user
7. VPN active on phone → detect and warn (common silent killer of local discovery)
8. iPad compatibility mode looks acceptable (or ship iPhone-only — decide and commit)
9. Rapid-fire button mashing → no request queue explosion (drop/coalesce, don't buffer)
10. Memory/energy pass in Instruments: no leaks, idle CPU ~0%
11. If multicast entitlement has been approved by now: integrate SSDP path, retest discovery timing (should drop to <2s)

**Definition of Done:**
- [ ] Every matrix item passes or has an explicit, user-visible mitigation
- [ ] Zero known crashes; Instruments clean
- [ ] Tag `v0.4.0` — this is the beta candidate

---

### PHASE 5 — Beta, Landing Page & Waitlist (Days 17–20, overlaps Phase 4 tail)

**Goal:** Real users on TestFlight; public web presence capturing emails.

**Tasks — TestFlight:**
1. App Store Connect setup: bundle ID, app record, TestFlight internal build via a GitHub Actions release workflow (fastlane or `xcodebuild` archive + upload; store signing certs in Actions secrets).
2. Recruit 10–25 external testers (r/Roku, personal network — note App Review lite-reviews external TestFlight builds).
3. Feedback channel (TestFlight feedback + a simple email/form). Triage: crashes/connectivity = fix now; feature requests = v1.1 backlog. **Do not expand scope.**

**Tasks — Website (in `website/`, deployed to GitHub Pages on the Namecheap domain):**
4. Single-page static site: hero with app mockup screenshots, three value props ("One price. No ads. No subscriptions." / "Instant connection" / "Designed for Roku"), waitlist email form (Mailchimp free tier embed or Formspree free tier — pick whichever embeds cleanest into static HTML), trademark disclaimer footer.
5. `privacy.html` — required for App Store submission. Honest and short: "No data collected. No analytics. No accounts. All communication stays on your local network."
6. Basic OpenGraph tags + favicon; Lighthouse ≥95.

**Definition of Done:**
- [ ] Beta build in ≥10 real testers' hands; at least one full feedback cycle shipped
- [ ] Site live on the custom domain with working email capture and privacy policy URL
- [ ] Tag `v0.9.0`

---

### PHASE 6 — App Store Launch (Days 21–24)

**Goal:** Approved, live, purchasable.

**Tasks:**
1. **Pricing:** launch at $4.99 (Tier 5). Enroll in Small Business Program beforehand.
2. **Store assets:** 6.7" + 6.1" screenshots (device frames, dark, benefit-led captions), app preview video optional-but-valuable (screen-record the app controlling a real TV), subtitle ("The premium Roku remote. One price, forever."), keyword field (roku, remote, tv remote, ecp, streaming — no competitor trademarks beyond nominative "roku"), description emphasizing one-time price / no ads / privacy.
3. **Review preparation:** Reviewer Notes explaining the Roku-on-same-network requirement + link to an unlisted demo video showing full functionality; double-check Guideline 5.2 compliance (name, icon, screenshots contain no Roku trade dress).
4. Final release build: version 1.0.0, archived via CI, submitted.
5. **Rejection playbook (don't panic, respond same-day):** 5.2 naming → have a backup name ready; 2.1 "can't verify" → point to demo video and reply via Resolution Center; metadata issues → fix and resubmit (no new binary needed).
6. Launch day: flip website from waitlist to App Store badge link; email the waitlist; post to r/Roku (transparently, per subreddit rules) and Product Hunt if desired.

**Definition of Done:**
- [ ] App live on the App Store at $4.99
- [ ] Website converted to launch mode; waitlist emailed
- [ ] Tag `v1.0.0` 🎉

---

### PHASE 7 — Minimal-Maintenance Operations (ongoing, ~1–2 hrs/week max)

**Goal:** Honor the business thesis: near-zero maintenance without abandoning users.

**Standing playbook:**
1. **Monitor only two things:** App Store crash reports (Xcode Organizer) and reviews. Respond to every review for the first month (algorithm + trust boost).
2. **Annual obligations:** renew Apple Developer ($99), renew domain (~$10 after free year — budget it), rebuild once per major iOS release (usually zero code changes; test on the new OS in September betas).
3. **Version 1.1 backlog (only if sales justify):** SSDP fast-discovery (if entitlement arrived late), iPad layout, home-screen widgets / lock-screen controls, Apple Watch remote, private-listening research (⚠️ audio streaming uses a more complex protocol — treat as a major project, likely never), `/search` deep-linking.
4. **Hard rule:** any feature that adds a server, an account system, or a non-Roku brand is rejected by default. The moat is simplicity.

---

## 4. RISK REGISTER (ranked)

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Multicast entitlement delayed/denied | Medium | Low (by design) | Subnet-scan fallback is the primary path; SSDP is an upgrade, not a dependency |
| 2 | App Review rejection (5.2 trademark) | Medium | Medium | Nominative naming, no trade dress, backup name prepared, disclaimer everywhere |
| 3 | Local-network permission confusion → bad reviews | Medium | Medium | Onboarding explains before prompting; recovery screen; Help content |
| 4 | Roku "Limited mode" support burden | Medium | Medium | Dedicated in-app troubleshooter with exact menu steps |
| 5 | Paid-upfront conversion is weak | Medium | High | Premium screenshots/video must sell it; consider free-with-one-time-unlock IAP as a v1.1 pivot if sales flop (bigger funnel, same "one price" promise) |
| 6 | Roku deprecates/locks down ECP | Low | Fatal | Officially documented API used by Roku's own app; monitor developer.roku.com; accept as residual risk |
| 7 | Developer's Apple fee waiver denied | Medium | Low | $99 is the accepted floor cost |

---

## 5. HOW TO USE THIS DOCUMENT WITH CLAUDE CODE

1. Place this file and `CLAUDE.md` (§2.3) at the repo root before the first session.
2. Work one phase per session-cluster. Open each session with: *"We are in Phase N of ROKU_REMOTE_PROJECT_ROADMAP.md. Current state: [what's done]. Complete task N.X next."*
3. Enforce the Definition of Done checklists — do not let a phase end with red CI or skipped tests.
4. Physical-device smoke tests (Phases 1, 2, 4) are human tasks; Claude Code prepares the build and the test script, the developer executes on hardware and reports results back.
5. Commit and tag at every phase boundary so any regression has a known-good rollback point.
