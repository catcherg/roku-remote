# App Store Release Checklist — Clicker – Remote for Roku

Do these in order. Each section depends on the ones above it.
Items tagged **[code]** are problems found in this repo as of 2026-11-14.

---

## 1. Finish the in-flight work

- [ ] Commit the `feat/trial-unlock` branch. Purchase/, ClickerTests/ and Clicker.storekit are still untracked, and 9 files are modified.
- [ ] `cd RokuKit && swift test` passes.
- [ ] `xcodebuild test -project App/Clicker.xcodeproj -scheme Clicker -destination 'platform=iOS Simulator,name=iPhone 17'` passes (TrialPolicy, EntitlementStore and StoreKit integration tests).
- [ ] Merge into `main`, with CI green.

## 2. Fix the code blockers

- [ ] **[code]** The privacy policy URL is a placeholder: `AppInfo.privacyPolicyURL = https://example.com/privacy.html` ([Theme.swift:52](App/Clicker/DesignSystem/Theme.swift:52)). Change it to `https://getclicker.me/privacy`. App Review taps this link.
- [ ] **[code]** There's no privacy manifest (`PrivacyInfo.xcprivacy`). The app and RokuKit use `UserDefaults`, which is a "required-reason" API, so uploads get flagged without one. Add a manifest to the app target with:
  - `NSPrivacyTracking` = false, `NSPrivacyTrackingDomains` = [], `NSPrivacyCollectedDataTypes` = []
  - `NSPrivacyAccessedAPITypes`: `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1`
  - Add it to `project.yml` sources so XcodeGen doesn't drop it.
- [ ] **[code]** The version in `Info.plist` is hardcoded (`CFBundleShortVersionString` = `1.0`, `CFBundleVersion` = `1`), so `MARKETING_VERSION: 0.3.0` in `project.yml` has no effect. Change them to `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`. Then set the version to **1.0.0** and bump the build number on every upload.
- [ ] **[code]** `DEVELOPMENT_TEAM = YZSL25MTN9` only exists in `project.pbxproj`. Add it to `project.yml` (`settings.base`) so that running `xcodegen` again doesn't remove signing.
- [ ] Decide on the multicast entitlement. Was the `com.apple.developer.networking.multicast` request approved?
  - **Yes:** add a `.entitlements` file with that key, regenerate the provisioning profile, and turn on the SSDP flag (`SSDPDiscoverer.swift:12`).
  - **No/pending:** ship with subnet scan only. Leave the entitlement out entirely. Signing fails if you claim an entitlement that wasn't granted.
- [ ] Do a Release-config build on a real iPhone. Check that the `#if DEBUG` purchase backend and debug launch args aren't included, that no `.storekit` file is bundled, and that there are no console warnings.

## 3. Hardening (Roadmap Phase 4, not yet checked off)

- [ ] Go through the Phase 4 test matrix on a real Roku: Wi-Fi drops, Roku off or changing IP, sleep/resume, guest-network isolation, multiple Rokus, "Limited" mode help flow, VPN warning, button mashing, Instruments leaks/CPU.
- [ ] **Run the app on an iPad.** It's iPhone-only (`TARGETED_DEVICE_FAMILY: 1`), but App Review often tests iPhone apps on iPads in compatibility mode. A broken layout there gets rejected under 2.1/4.0.
- [ ] Test the smallest screen (iPhone SE) and the largest (Pro Max), plus Dynamic Type at its largest size.
- [ ] Tag `v0.4.0`.

## 4. Apple business setup (only you can do this, in App Store Connect)

- [ ] Developer Program membership is active and paid.
- [ ] **Paid Applications Agreement** accepted (Business → Agreements). In-app purchases won't load at all, not even in sandbox or TestFlight, until it's active.
- [ ] Banking info and tax forms (W-9) submitted, and the agreement status shows **Active**.
- [ ] Enroll in the **App Store Small Business Program** (15% commission instead of 30%). Do it before launch.
- [ ] **EU Digital Services Act trader status.** Declare it, or the app can't be sold in the EU. If you declare yourself a trader, your address/phone/email appear on the product page. If you'd rather not do that, leave EU storefronts out.

## 5. App Store Connect app record

- [ ] Register the bundle ID `com.catchergriffin.clicker` (Certificates, Identifiers & Profiles), with the In-App Purchase capability turned on.
- [ ] Create the app: name **"Clicker – Remote for Roku"** (25/30 chars), primary language English (U.S.), bundle ID, any SKU (e.g. `clicker-ios`).
- [ ] Have a backup name ready in case the name is taken or rejected under 5.2.
- [ ] Category: **Utilities** (secondary: Entertainment).

## 6. In-app purchases (must match the code exactly)

- [ ] Non-consumable `com.catchergriffin.clicker.trial`, price **Free (Tier 0)**. Apple requires the display name to follow the "XX-day Trial" pattern, e.g. "7-Day Trial".
- [ ] Non-consumable `com.catchergriffin.clicker.unlock`, price **$4.99**, Family Sharing **on** (this matches `Clicker.storekit`).
- [ ] For each one: localized display name and description, plus a **review screenshot** (the paywall or trial screen). The screenshot is required.
- [ ] Both show **"Ready to Submit."** The first IAPs must be attached to the 1.0 version page when you submit (see §10). They can't be submitted on their own.

## 7. TestFlight

- [ ] Archive the Release build (Xcode → Product → Archive) and upload through Organizer. This needs Xcode 26 with the iOS 26 SDK; you have 26.6.
- [ ] Answer export compliance. `ITSAppUsesNonExemptEncryption = false` is already set, so this should be skipped automatically.
- [ ] Internal testing: create a **Sandbox Apple Account** (Users and Access → Sandbox) and test on a real device:
  - [ ] Start the trial, and check that the trial screen states the length and what happens after it ends
  - [ ] Buy the unlock, delete and reinstall, then **Restore Purchases**
  - [ ] Ask to Buy / pending flow, and a family-shared unlock
  - [ ] Expired trial reaches the paywall (sandbox can't fast-forward a non-consumable; trust the unit tests plus the debug `-ClickerDebugDaysAhead 8` run)
  - [ ] Refund or revoke: clear purchase history in sandbox settings and confirm the app locks again
- [ ] External testers (optional, recommended by the roadmap): the first external build goes through Beta App Review, which usually takes about a day.
- [ ] Fix whatever comes back, then tag `v0.9.0`.

## 8. Website / URLs (getclicker.me)

- [ ] **[code]** The privacy page still has a contact TODO ([privacy.astro](website/src/pages/privacy.astro)). Publish a real contact email.
- [ ] Add a line to the privacy page saying purchases are handled by Apple and Clicker never sees payment info.
- [ ] Add a **Support URL** page (or a support section) with that contact email. App Store Connect requires one.
- [ ] Update the "beta invite" wording once you launch.

## 9. Product page metadata

- [ ] **Subtitle** (max 30 chars). The roadmap's "The premium Roku remote. One price, forever." is **44 characters**, so it's too long. One option: "One price. No ads. No account." (30).
- [ ] **Keywords** (100 chars, comma-separated, no spaces). Don't repeat words already in the name ("clicker", "remote", "roku"). No competitor trademarks.
- [ ] Description and promotional text: say the trial is free, then **$4.99 once**, with no ads, no account and no tracking. Put the "Not affiliated with Roku, Inc." disclaimer in the description.
- [ ] **Screenshots:** 6.9" iPhone (1320 × 2868) is required. 3 minimum, up to 10, dark. **No Roku logo, purple, or Roku UI in the shots** (5.2). Be careful with TV-screen backgrounds.
- [ ] App preview video (optional, recommended).
- [ ] Support URL, Marketing URL (`https://getclicker.me`), Privacy Policy URL (`https://getclicker.me/privacy`).
- [ ] Copyright line (e.g. "2026 Catcher Griffin").
- [ ] **App Privacy questionnaire:** "Data Not Collected."
- [ ] **Age rating questionnaire** (the 2025 revised version): answer "none" throughout, which should give 4+.
- [ ] **Content rights:** the app shows channel icons pulled from the user's own Roku. Answer honestly and mention it in the review notes.
- [ ] **Pricing & Availability:** Free, with territories chosen (see the EU/DSA note in §4).

## 10. Submit for review

- [ ] Version **1.0.0** page: select the build, and under **In-App Purchases** attach both IAPs.
- [ ] **App Review Information:** contact name, phone and email. Sign-in required: **No**.
- [ ] **Review notes:** a Roku device on the same Wi-Fi network is required, with a link to an **unlisted demo video** (iPhone controlling a real TV: discovery, remote, keyboard, channels, trial, paywall, unlock, restore). Explain how the 7-day trial works, and point out the nominative "for Roku" name and the in-app disclaimer (Settings and Help).
- [ ] Release option: **Manually release**, so you control launch day.
- [ ] Submit. Review typically takes 24–48h.
- [ ] If rejected, follow the playbook in Roadmap Phase 6 step 5: reply in App Review the same day. Metadata-only fixes don't need a new build.

## 11. Launch

- [ ] Release the version in App Store Connect.
- [ ] Website: swap the beta form for the App Store badge and link.
- [ ] Email the beta list, then post to r/Roku (following its rules) and optionally Product Hunt.
- [ ] Tag `v1.0.0` on `main`.
- [ ] For the first month: check Xcode Organizer crash reports weekly and reply to every review.
