# External Integrations

**Analysis Date:** 2026-04-27

## APIs & External Services

**Subscriptions / Monetization:**
- RevenueCat — primary purchase + entitlement layer wrapping StoreKit 2
  - SDK/Client: `purchases-ios-spm` (`RevenueCat`, ≥ 5.69.0) imported in `MindRestore/Services/StoreService.swift`
  - Auth: hardcoded API key `appl_NUUkNGthSiwlZSAtrDjAfxUGOPC` in `MindRestore/MindRestoreApp.swift` (`Purchases.configure(with: Configuration.Builder(withAPIKey:))`)
  - Companion: Apple StoreKit 2 (`import StoreKit`); local sandbox config at `MindRestore/Configuration.storekit`

**Analytics:**
- PostHog — product analytics (replaced TelemetryDeck per project memory)
  - SDK/Client: `posthog-ios` (`PostHog`, ≥ 3.50.0)
  - Auth: hardcoded `apiKey = "phc_mAu7DCNXJbqro9iG6KzYbxhTqa4s442BAmS3tCt7vPJu"` in `MindRestore/Services/AnalyticsService.swift`
  - Host: `https://us.i.posthog.com`
  - Init: `Analytics.configure()` called in `MindRestoreApp.swift`

**Game / Leaderboards:**
- Apple Game Center — leaderboard reads + score submission (no mock data per `CLAUDE.md`)
  - SDK/Client: `GameKit` (`GKLocalPlayer`, `GKLeaderboard`) in `MindRestore/Services/GameCenterService.swift`
  - Auth: `GKLocalPlayer.local.authenticateHandler` — Apple ID-backed, no key needed
  - Entitlement: `com.apple.developer.game-center` in `MindRestore/MindRestore.entitlements`

**Screen Time / Focus Mode (v2.0):**
- Apple Family Controls — user-selected app blocking
  - SDK/Client: `FamilyControls`, `ManagedSettings`, `ManagedSettingsUI`, `DeviceActivity` (Apple frameworks; entitlement-gated)
  - Auth: requires `com.apple.developer.family-controls` entitlement (declared in `MindRestore/MindRestore.entitlements`) plus runtime `AuthorizationCenter` request
  - Implementation: `MindRestore/Services/FocusModeService.swift`, `MindRestore/Extensions/DeviceActivityMonitorExtension.swift`, `MindRestore/Extensions/ShieldActionExtension.swift`, `MindRestore/Extensions/ShieldConfigurationExtension.swift`, plus extension targets `MemoriShieldAction/`, `MemoriShieldConfig/`, `FocusUnlocksReport/`

**Mascot / Animation:**
- Rive — runtime-rendered animated mascot
  - SDK/Client: `rive-ios` (`RiveRuntime`, ≥ 6.18.1) imported in `MindRestore/Views/RiveMascotView.swift`
  - Auth: none (assets bundled at `MindRestore/Resources/memori_mascot.riv`, `MindRestore/Resources/memorimascots.riv`, `MindRestore/memori (1).riv`)

**Marketing / Web:**
- `getmemoriapp.com` — marketing site, privacy policy (`/privacy`), terms (`/terms`), and the `/giving` ledger
  - Used as the `applinks` host for universal links and as the host for short-link referrals built in `MindRestore/Services/ReferralService.swift`
  - No SDK; outbound user-facing links only

## Data Storage

**Local persistence:** SwiftData store (default app sandbox container) — `@Model` types in `MindRestore/Models/` configured in `MindRestoreApp.swift`. Includes `User`, `Exercise`, `DailySession`, `BrainScoreResult`, `Achievement`, `PsychoEducationCard`, `SpacedRepetitionCard`.

**Shared storage between targets:** `UserDefaults(suiteName: "group.com.memori.shared")` — used by `MindRestore/Services/FocusModeService.swift` and `MindRestore/Widget/WidgetDataService.swift` to share state between the app, the widget, and Shield/DeviceActivity extensions.

**iCloud / Cloud DB:** CloudKit
- Container: `iCloud.com.dylanmiller.mindrestore` (declared in `MindRestore/MindRestore.entitlements`)
- Client: `CKContainer.default()` in `MindRestore/Services/ReferralService.swift`
- Scope: public database for referrer rewards (`saveReferrerReward`, pending-reward checks); usage commented in `MindRestore/ContentView.swift`
- Note: `MindRestore/Models/LeaderboardEntry.swift` is a placeholder for future CloudKit-backed leaderboards (currently inactive)

**File storage:** Local filesystem only — bundled assets in `MindRestore/Assets.xcassets/`, `MindRestore/Resources/`, `.riv` files. No S3/GCS/etc.

**Caching:** None beyond StoreKit/RevenueCat in-memory entitlement cache and PostHog event queue.

## Authentication & Identity

**Auth Provider:** None for app login — the app does not have user accounts.
- **Game Center identity** (`GKLocalPlayer`) is the only player identity, used for leaderboards and (future) social features.
- **RevenueCat anonymous user IDs** drive subscription state.
- **CloudKit** uses the device's iCloud identity automatically for referrer reward writes/reads.

## Monitoring & Observability

**Error Tracking:** None dedicated — no Sentry, Bugsnag, or Crashlytics integration found. Errors are surfaced via `print(...)` statements (e.g., `MindRestore/Services/GameCenterService.swift`, `MindRestore/Services/ReferralService.swift`) and captured implicitly by Apple's crash reporting through App Store Connect.

**Logs:** `print(...)` to console only. No structured logger, no `os.Logger`/`OSLog` adoption observed in services. PostHog captures product events but not logs.

## CI/CD & Deployment

**Hosting:** Apple App Store (App ID `6760178716`). The marketing site at `getmemoriapp.com` is hosted externally (not in this repo).

**CI Pipeline:** None committed — no GitHub Actions, Xcode Cloud, or fastlane configuration in the repo. Build/upload is performed manually via the `xcodebuild` recipes in `CLAUDE.md` and the App Store Connect API (key + p8 referenced in `CLAUDE.md`, stored outside the repo).

## Environment Configuration

**Required env vars:** None — iOS app uses compile-time constants. The following keys are **hardcoded in source** and ship with the binary:
- RevenueCat publishable key — `MindRestore/MindRestoreApp.swift`
- PostHog project key + host — `MindRestore/Services/AnalyticsService.swift`

**Secrets location (outside repo, do not check in):**
- App Store Connect API p8 — `/Users/dylanmiller/Downloads/AuthKey_9GRLL5VKUX.p8` (per `CLAUDE.md`); used with key id `9GRLL5VKUX`, issuer `ab66930d-a8da-451a-81e7-1cdd5f229aaf`
- Apple Developer team id `73668242TN` — embedded in build settings
- StoreKit sandbox file `MindRestore/Configuration.storekit` carries placeholder `_developerTeamID = XXXXXXXXXX`; safe to commit.
- `/tmp/ExportOptions.plist` — generated locally per `CLAUDE.md` for archive uploads, not in repo.

## Webhooks & Callbacks

**Incoming:**
- Universal links (`applinks:getmemoriapp.com`, including `?mode=developer`) — handled by `MindRestore/Services/DeepLinkRouter.swift` (`universalLinkHost = "getmemoriapp.com"`)
- Custom URL scheme `memori://` — declared in `MindRestore/Info.plist`, routed through the same `DeepLinkRouter` for friend-challenge / referral deep links (`MindRestore/Models/ChallengeLink.swift`, `MindRestore/Services/ReferralService.swift`)
- StoreKit 2 transaction listener — `Transaction.updates` consumed inside `MindRestore/Services/StoreService.swift` (RevenueCat-mediated)

**Outgoing:**
- PostHog event ingestion to `https://us.i.posthog.com`
- RevenueCat receipt validation / entitlement sync to RevenueCat servers (managed by the SDK)
- Game Center score submission via `GKLeaderboard.submitScore(...)` in `MindRestore/Services/GameCenterService.swift`
- CloudKit public database writes/queries from `MindRestore/Services/ReferralService.swift`
- No custom HTTP outbound endpoints (no `URLSession` calls to first-party APIs were found in services)

---
*Integration audit: 2026-04-27*
