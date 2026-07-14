# Clicker – Remote for Roku

![CI](https://github.com/catcherg/roku-remote/actions/workflows/ci.yml/badge.svg)

A premium, dark-mode-first iOS remote for Roku TVs and streaming devices. One-time purchase, no ads, no accounts, no backend — all control happens over your local network via Roku's External Control Protocol (ECP).

## Structure

- `RokuKit/` — Swift Package containing all networking (discovery + ECP). Zero UI imports, fully unit-tested.
- `App/` — SwiftUI iOS app (see `App/XCODE_SETUP.md` to create the Xcode project).
- `website/` — static landing page, deployed to GitHub Pages (Phase 5).
- `ROKU_REMOTE_PROJECT_ROADMAP.md` — authoritative project spec. Work phases strictly in order.
- `CLAUDE.md` — Claude Code project memory.

## Development

```bash
cd RokuKit && swift test
```
---

*Not affiliated with or endorsed by Roku, Inc. Roku is a trademark of Roku, Inc.*
