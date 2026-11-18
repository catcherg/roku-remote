# App Store Release Checklist — Clicker – Remote for Roku

Do these in order. Each section depends on the ones above it, **except §4
(Apple business setup), which takes days to clear: start it right away, in
parallel with everything else.**

Pricing model (since commit `4a553ff`): a **weekly auto-renewable
subscription with a 3-day free trial** plus a **lifetime non-consumable
unlock**. The app gives 10 free key presses, then shows the plans sheet. The
older one-time $4.99 model is recoverable at `b93df83`.

Last updated 2026-11-15.

---

## 1. Finish the in-flight work

- [x] Commit the `feat/trial-unlock` branch.
- [x] `cd RokuKit && swift test` passes (67 tests, 4 live-device tests skipped).
- [x] Release build of the app compiles with no errors.
- [ ] App unit tests (`EntitlementPolicyTests`, `EntitlementStoreTests`, `StoreKitIntegrationTests`). Xcode 26.6 on macOS 27.2 can't start the test runner, so `xcodebuild test` hangs. **Update Xcode**, then run:
  `xcodebuild test -project App/Clicker.xcodeproj -scheme Clicker -destination 'platform=iOS Simulator,name=iPhone 17'`
- [ ] Push the branch, open a PR, merge into `main` with CI green. Merging also redeploys the website.

## 2. Fix the code blockers

- [x] Privacy policy URL points to `https://getclicker.me/privacy` ([Theme.swift](App/Clicker/DesignSystem/Theme.swift)).
- [x] Privacy manifest added at [App/Clicker/PrivacyInfo.xcprivacy](App/Clicker/PrivacyInfo.xcprivacy): no tracking, no collected data, UserDefaults with reason `CA92.1`. It lives under `Clicker/`, so XcodeGen picks it up as a resource.
- [x] `Info.plist` reads `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`. The version is **1.0.0**. Bump `CURRENT_PROJECT_VERSION` before every upload.
- [x] `DEVELOPMENT_TEAM` is in `project.yml`, so regenerating the project keeps signing.
- [ ] **Decide what a failed renewal does.** Today the remote stays unlocked through Apple's billing grace period **and** through billing retry (`SubscriptionRecord.isActive` in [Entitlement.swift](App/Clicker/Features/Purchase/Entitlement.swift)). Apple keeps retrying a failed charge for up to 60 days, so a customer whose card fails could get about eight unpaid weeks. Either keep that on purpose, or unlock only during the grace period.
- [ ] Decide on the multicast entitlement. Was the `com.apple.developer.networking.multicast` request approved?
  - **Yes:** add a `.entitlements` file with that key, regenerate the provisioning profile, and turn on the SSDP flag (`SSDPDiscoverer.swift:12`).
  - **No/pending:** ship with subnet scan only. Leave the entitlement out entirely. Signing fails if you claim an entitlement that wasn't granted.
- [ ] Do a Release-config build on a real iPhone. Check that the `#if DEBUG` purchase backend and debug launch args aren't included, that no `.storekit` file is bundled, and that there are no console warnings. A Release build for the simulator on 2026-11-17 had no `.storekit` file and no debug switches in the binary; the run on a real iPhone is still to do.

## 3. Hardening (Roadmap Phase 4)

- [ ] Go through the Phase 4 test matrix on a real Roku: Wi-Fi drops, Roku off or changing IP, sleep/resume, guest-network isolation, multiple Rokus, "Limited" mode help flow, VPN warning, button mashing, Instruments leaks/CPU.
- [x] **Free-preview edge cases:** the 10 free presses count only presses the Roku accepted, a held key always stops, and the plans sheet opens on press 11. Checked 2026-11-17 in the simulator against a stand-in Roku, not real hardware. It turned up one bug, now fixed: a hold that was interrupted (a sheet opening, the app going to the background) never sent its key-up.
- [x] **Run the app on an iPad.** It's iPhone-only (`TARGETED_DEVICE_FAMILY: 1`), but App Review often tests iPhone apps on iPads in compatibility mode. A broken layout there (paywall included) gets rejected under 2.1/4.0. Checked 2026-11-17 on the iPad (A16) simulator: remote, device list, Settings and the plans sheet. The plans sheet used to hide the Lifetime plan below the fold at this size; it now shows both.
- [x] Test the smallest screen (iPhone SE) and the largest (Pro Max), plus Dynamic Type at its largest size. The plans sheet must keep the price, renewal terms and Restore visible. Checked 2026-11-17 in the simulator: every screen on the iPhone SE (3rd generation), also at the largest text size; the remote and intro on the iPhone 17 Pro Max; the plans sheet on the iPhone 17 Pro. Fixed along the way: the remote's bottom row wrapped mid-word on every phone and ran off the screen on the SE, the volume glyphs collided at the largest text size, and the purchase button's white text was unreadable on the dark-mode teal.
- [ ] Tag `v0.4.0`.

## 4. Apple business setup (only you can do this, in App Store Connect). START NOW

- [ ] Developer Program membership is active and paid.
- [ ] **Paid Applications Agreement** accepted (Business → Agreements). In-app purchases and subscriptions won't load at all, not even in sandbox or TestFlight, until it's active.
- [ ] Banking info and tax forms (W-9) submitted, and the agreement status shows **Active**.
- [ ] Enroll in the **App Store Small Business Program** (15% commission instead of 30%). Do it before launch.
- [ ] **EU Digital Services Act trader status.** Declare it, or the app can't be sold in the EU. If you declare yourself a trader, your address/phone/email appear on the product page. If you'd rather not do that, leave EU storefronts out.

## 5. App Store Connect app record

- [ ] Register the bundle ID `com.catchergriffin.clicker` (Certificates, Identifiers & Profiles), with the In-App Purchase capability turned on.
- [ ] Create the app: name **"Clicker – Remote for Roku"** (25/30 chars), primary language English (U.S.), bundle ID, any SKU (e.g. `clicker-ios`).
- [ ] Have a backup name ready in case the name is taken or rejected under 5.2.
- [ ] Category: **Utilities** (secondary: Entertainment).

## 6. In-app purchases (must match the code exactly)

The product IDs are in [Entitlement.swift](App/Clicker/Features/Purchase/Entitlement.swift). Prices are read from the App Store at runtime, so the prices below are only what `Clicker.storekit` uses. Set whatever you like in App Store Connect.

- [ ] **Subscription group** "Clicker", containing one auto-renewable subscription:
  - Product ID `com.catchergriffin.clicker.weekly`, reference name "Weekly", duration **1 week**, price **$6.99** (or your choice).
  - **Introductory offer: Free trial, 3 days**, for new subscribers, all territories. An offer can't be edited once it's created; delete it and make a new one.
  - Display name "Clicker Weekly", description "Full use of Clicker, billed weekly."
  - Subscription group display name and at least one group localization.
  - Family Sharing **off** (matches `Clicker.storekit`).
- [ ] **Non-consumable** `com.catchergriffin.clicker.unlock`, reference name "Lifetime Unlock", display name "Clicker Lifetime", price **$24.99** (or your choice), Family Sharing **on**.
- [ ] Do **not** create the old `com.catchergriffin.clicker.trial` product. The free trial is now the weekly plan's introductory offer. If you already created it, delete it or leave it out of the submission.
- [ ] Check the price in each country. Apple fills them in from the US price. Set Mexico by hand, as the go-to-market doc says.
- [ ] For each one: localized display name and description, plus a **review screenshot** (the plans sheet). The screenshot is required.
- [ ] Both show **"Ready to Submit."** The first IAPs and the first subscription must be attached to the 1.0 version page when you submit (see §10). They can't be submitted on their own.
- [ ] **Guideline 3.1.2 (subscriptions) check:** the plans sheet shows the price per week, the trial length, that it auto-renews until cancelled, and links to Terms and Privacy. Restore is reachable from the sheet and from Settings. All of this is in `PaywallView` already, so re-check it on the final build. A simulator pass on 2026-11-17, with the debug store's prices, found all of it present on the iPhone SE, iPhone 17 Pro and iPad.
- [ ] **Terms of Use link in the metadata. This is required, not optional.** Apple says both the app and the App Store metadata must link to the Terms of Use and Privacy Policy. The plans sheet already does. For the metadata, put `https://getclicker.me/terms` in the description (§9), in every language you add. A missing link is a common 3.1.2 rejection.

## 7. TestFlight

- [ ] Archive the Release build (Xcode → Product → Archive) and upload through Organizer.
- [ ] Answer export compliance. `ITSAppUsesNonExemptEncryption = false` is already set, so this should be skipped automatically.
- [ ] Internal testing: create a **Sandbox Apple Account** (Users and Access → Sandbox) and test on a real device. In sandbox a weekly plan renews every 3 minutes and stops after 12 renewals, so a full subscription lifecycle takes under an hour. In a TestFlight build it renews once a day, 6 times.
  - [ ] Use the 10 free presses, then the plans sheet appears
  - [ ] Start the weekly plan: the 3-day free trial shows, Settings shows "trial" and the renewal date
  - [ ] Let it renew a few times, then cancel in Manage Subscription and confirm the app locks after expiry
  - [ ] Billing retry / grace period does what you decided in §2; today both keep the app unlocked (turn on Billing Grace Period for the app in App Store Connect first; covered by unit tests if sandbox won't trigger it)
  - [ ] Buy Lifetime while subscribed: the app shows the "cancel your subscription" reminder
  - [ ] Delete and reinstall, then **Restore Purchases** (both products)
  - [ ] Ask to Buy / pending flow, and a family-shared Lifetime
  - [ ] Refund or revoke: clear purchase history in sandbox settings and confirm the app locks again
  - [ ] A second sandbox account that already used the trial isn't shown "3 days free"
- [ ] External testers (optional; skip to launch faster). The first external build goes through Beta App Review, which usually takes about a day.
- [ ] Fix whatever comes back, then tag `v0.9.0`.

## 8. Website / URLs (getclicker.me)

- [x] Privacy and Terms pages list a contact email: `support@getclicker.me`.
- [x] The privacy page says purchases are handled by Apple and Clicker never sees payment info.
- [x] Support page at `https://getclicker.me/support` (troubleshooting, restore, cancel, refunds, contact).
- [ ] **Set up email forwarding for `support@getclicker.me`** (e.g. in Namecheap's email forwarding, or ImprovMX). Send it a test message. App Review and users will write to it.
- [ ] The beta form isn't connected (`FORMSPREE_ENDPOINT` is still a TODO in [Beta.astro](website/src/components/Beta.astro)). Either create the Formspree form, or skip the external beta and replace the form with the App Store badge at launch (§11).

## 9. Product page metadata

Drafts of every text field below, in English and Spanish (Mexico), are in [APP_STORE_LISTING.md](APP_STORE_LISTING.md), each checked against Apple's character limit. Paste from there.

- [ ] **Subtitle** (max 30 chars). Ideas: "Swipe to control your TV" (24), "No ads. No account." (19). Don't promise "one price" now that there's a subscription.
- [ ] **Keywords** (100 chars, comma-separated, no spaces). Don't repeat words already in the name ("clicker", "remote", "roku"). No competitor trademarks.
- [ ] Description and promotional text: describe both plans (weekly with a 3-day free trial, or a one-time Lifetime), no ads, no account, no tracking. Say that the subscription auto-renews until cancelled, and link the Terms of Use and Privacy Policy. Put the "Not affiliated with Roku, Inc." disclaimer in the description.
- [ ] **Screenshots:** 6.9" iPhone (1320 × 2868) is required. 3 minimum, up to 10, dark. **No Roku logo, purple, or Roku UI in the shots** (5.2). Be careful with TV-screen backgrounds. Two of four are made, in English and Spanish, in `AppStore/screenshots/`. The keyboard and channel-grid shots are still missing; [APP_STORE_LISTING.md](APP_STORE_LISTING.md) says how to add them.
- [ ] App preview video (optional, recommended).
- [ ] Support URL `https://getclicker.me/support`, Marketing URL `https://getclicker.me`, Privacy Policy URL `https://getclicker.me/privacy`.
- [ ] Copyright line (e.g. "2026 Catcher Griffin").
- [ ] **App Privacy questionnaire:** "Data Not Collected."
- [ ] **Age rating questionnaire** (the 2025 revised version): answer "none" throughout, which should give 4+.
- [ ] **Content rights:** the app shows channel icons pulled from the user's own Roku. Answer honestly and mention it in the review notes.
- [ ] **Pricing & Availability:** Free, with territories chosen (see the EU/DSA note in §4).
- [ ] **Spanish (Mexico) listing**, as the go-to-market doc decided: name, subtitle, keywords, description with the Terms link, and the display names of both products and the subscription group.

## 10. Submit for review

- [ ] Version **1.0.0** page: select the build, and under **In-App Purchases and Subscriptions** attach the weekly subscription and the Lifetime unlock.
- [ ] **App Review Information:** contact name, phone and email. Sign-in required: **No**.
- [ ] **Review notes:** a Roku device on the same Wi-Fi network is required, with a link to an **unlisted demo video** (iPhone controlling a real TV: discovery, remote, keyboard, channels, the 10 free presses, plans sheet, subscribe, lifetime, restore). Explain that the reviewer can reach the plans sheet without a Roku via Settings → See Plans. Point out the nominative "for Roku" name and the in-app disclaimer (Settings and Help). The notes are drafted in [APP_STORE_LISTING.md](APP_STORE_LISTING.md); only the video link is missing.
- [ ] Release option: **Manually release**, so you control launch day.
- [ ] Submit. Review typically takes 24–48h.
- [ ] If rejected, follow the playbook in Roadmap Phase 6 step 5: reply in App Review the same day. Metadata-only fixes don't need a new build. If the rejection is about the weekly price under 3.1.2, the one-time model at `b93df83` is the fallback.

## 11. Launch

- [ ] Release the version in App Store Connect.
- [ ] Website: swap the beta form for the App Store badge and link, and update the "beta" FAQ entries.
- [ ] Email the beta list (if any), then post to r/Roku (following its rules) and optionally Product Hunt.
- [ ] Tag `v1.0.0` on `main`.
- [ ] For the first month: check Xcode Organizer crash reports and App Store Connect subscription numbers weekly, and reply to every review.
