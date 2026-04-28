# Technology Stack

**Analysis Date:** 2026-04-27

## Languages
**Primary:** Swift 5.9 — all app source under `MindRestore/` (Services, Views, Models, Extensions, Widget) and target extensions (`MemoriWidget/`, `MemoriShieldAction/`, `MemoriShieldConfig/`, `FocusUnlocksReport/`).
**Secondary:** None. No Objective-C, no shell/scripting checked into the app target. Build settings include a stale `SWIFT_VERSION = 5.0` for one auxiliary target alongside the primary `5.9`.

## Runtime
**Environment:** iOS 17.0+ (`IPHONEOS_DEPLOYMENT_TARGET = 17.0` for the main app). One auxiliary target is pinned at `IPHONEOS_DEPLOYMENT_TARGET = 26.2` (likely the FamilyControls report extension that requires newer system frameworks). iPhone-only — `TARGETED_DEVICE_FAMILY = 1` on the main app (an unrelated target still has the legacy `"1,2"` value and should be audited).
**Package Manager:** Swift Package Manager only (resolved via Xcode). No CocoaPods, no Carthage. SPM resolution is committed via `MindRestore.xcodeproj/project.pbxproj` (`XCRemoteSwiftPackageReference` blocks). `Package.resolved` lockfile lives inside the `.xcodeproj` workspace bundle.

## Frameworks
**Core:**
- SwiftUI (declarative UI — every view under `MindRestore/Views/`)
- SwiftData — `@Model` classes in `MindRestore/Models/` (`User.swift`, `Exercise.swift`, `DailySession.swift`, `Achievement.swift`, `BrainScore.swift`, etc.); container wired up in `MindRestore/MindRestoreApp.swift`
- UIKit — interop for tab bar appearance (`MindRestoreApp.swift` `configureTabBarAppearance()`) and a few host components
- Foundation, AudioToolbox (haptic/sound feedback in `MindRestore/Services/SoundService.swift` and `HapticService.swift`)
- Charts — Apple Swift Charts framework (Insights views)
- WidgetKit — Home Screen widget in `MemoriWidget/`
- GameKit — leaderboards, see `MindRestore/Services/GameCenterService.swift`
- StoreKit 2 — sandbox testing via `MindRestore/Configuration.storekit`; production purchases routed through RevenueCat
- UserNotifications — local notification scheduling in `MindRestore/Services/NotificationService.swift`
- CloudKit — referral reward sync via `CKContainer.default()` in `MindRestore/Services/ReferralService.swift`

**Screen Time / Focus stack (v2.0):**
- FamilyControls — entitlement-gated app picker
- ManagedSettings, ManagedSettingsUI — app blocking primitives, used by `MemoriShieldConfig/ShieldConfigurationExtension.swift` and `MemoriShieldAction/ShieldActionExtension.swift`
- DeviceActivity — schedule/event monitoring in `MindRestore/Extensions/DeviceActivityMonitorExtension.swift` and `FocusUnlocksReport/`

**Testing:** XCTest — wired via the `MindRestoreTests` scheme. No test files were found in the working tree at audit time; CI/scheme references exist but the test target is sparse.

**Build/Dev:** Xcode (toolchain controlled by the user's Xcode install; `xcodebuild` is the canonical CLI per `CLAUDE.md`). No fastlane, no CI configuration files committed.

## Key Dependencies
**Critical (SPM):**
- `posthog-ios` — `https://github.com/PostHog/posthog-ios.git`, `upToNextMajorVersion` from `3.50.0` — analytics SDK, configured in `MindRestore/Services/AnalyticsService.swift` against `https://us.i.posthog.com`
- `purchases-ios-spm` (RevenueCat) — `https://github.com/RevenueCat/purchases-ios-spm.git`, `upToNextMajorVersion` from `5.69.0` — subscription paywall + entitlement plumbing in `MindRestore/Services/StoreService.swift`, configured in `MindRestoreApp.swift`
- `rive-ios` — `https://github.com/rive-app/rive-ios`, `upToNextMajorVersion` from `6.18.1` — animated mascot rendering via `MindRestore/Views/RiveMascotView.swift`, with `.riv` assets at `MindRestore/memori (1).riv` and `MindRestore/Resources/memori_mascot.riv` / `memorimascots.riv`

**Infrastructure:**
- `ConfettiSwiftUI` — `https://github.com/simibac/ConfettiSwiftUI.git`, `upToNextMajorVersion` from `1.1.0` — celebration effects on results screens

## Configuration
**Environment:**
- RevenueCat API key is **hardcoded** in `MindRestore/MindRestoreApp.swift` (`appl_NUUkNGthSiwlZSAtrDjAfxUGOPC`). Treat as production publishable key.
- PostHog API key is **hardcoded** in `MindRestore/Services/AnalyticsService.swift` (`phc_…`) plus host `https://us.i.posthog.com`. No `.env` system; iOS app uses compile-time constants.
- StoreKit local testing via `MindRestore/Configuration.storekit` (sandbox-only; the file in repo has placeholder `_developerTeamID = XXXXXXXXXX`).
- App Group: `group.com.memori.shared` — wired in `MindRestore/Services/FocusModeService.swift` and `MindRestore/Widget/WidgetDataService.swift`; must be added to the main app, widget, shield, and DeviceActivity targets.
- iCloud container: `iCloud.com.dylanmiller.mindrestore` (declared in `MindRestore/MindRestore.entitlements`).
- URL scheme: `memori://` plus universal links `applinks:getmemoriapp.com` (entitlements + `Info.plist`).
- Custom fonts registered via `UIAppFonts` in `MindRestore/Info.plist`: `BricolageGrotesque-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf`, sourced from `MindRestore/Resources/Fonts/`.

**Build:**
- `MindRestore.xcodeproj/project.pbxproj` — single Xcode project, multiple targets: `MindRestore` (app), `MindRestoreTests`, `MemoriWidget`, `MemoriShieldAction`, `MemoriShieldConfig`, `FocusUnlocksReport`.
- Bundle IDs: `com.dylanmiller.mindrestore` (app), `.widget`, `.MemoriShieldAction`, `.MemoriShieldConfig`, `.FocusUnlocksReport`, `.tests`. (One `.Memori` bundle ID also exists — verify it's not orphaned.)
- Development Team: `73668242TN`.
- Marketing version `1.4.2`, build `28` (per `CURRENT_PROJECT_VERSION`).

## Platform Requirements
**Development:**
- macOS with Xcode (matching iOS 17+ SDK; portions need iOS 26 SDK for the FamilyControls report target).
- Apple Developer account on team `73668242TN` with provisioning for Family Controls, Game Center, CloudKit, App Groups, and Associated Domains.
- Physical device required for Family Controls and Screen Time testing — primary device id `00008130-000A214E11E2001C` per `CLAUDE.md`.

**Production:**
- Distribution via Apple App Store (App ID `6760178716`).
- Single Pro tier subscriptions configured in App Store Connect, surfaced through RevenueCat.

---
*Stack analysis: 2026-04-27*
