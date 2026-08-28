# Clicker – Remote for Roku

![CI](https://github.com/catcherg/roku-remote/actions/workflows/ci.yml/badge.svg)

A premium, dark-mode-first iOS remote for Roku TVs and streaming devices. One-time purchase, no ads, no accounts, no backend — all control happens over your local network via Roku's External Control Protocol (ECP).

## Structure

- `RokuKit/` — Swift Package containing all networking (discovery + ECP). Zero UI imports, fully unit-tested.
- `App/` — SwiftUI iOS app (see `App/XCODE_SETUP.md` to create the Xcode project).
- `website/` — Astro landing page, live at https://getclicker.me (auto-deploys from `main`). See `website/README.md` to run it and `WEBSITE.md` for design/product decisions.
- `ROKU_REMOTE_PROJECT_ROADMAP.md` — authoritative project spec. Work phases strictly in order.
- `CLAUDE.md` — Claude Code project memory.

## Development

```bash
cd RokuKit && swift test          # Swift package tests
npm run dev --prefix website      # website at http://localhost:4321
```
---

*Not affiliated with or endorsed by Roku, Inc. Roku is a trademark of Roku, Inc.*
