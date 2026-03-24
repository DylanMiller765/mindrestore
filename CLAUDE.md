# Memori — Brain Training App

## Project Context

This is an iOS app project using Swift/SwiftUI. Claude cannot modify `.xcodeproj` files or add SPM packages directly. Flag these manual steps clearly for the user with step-by-step Xcode UI instructions. Don't attempt CLI workarounds for Xcode-specific tasks.

## Verify Changes (REQUIRED)

After **every** code change, run the `/verify-changes` skill: build via Xcode MCP, render a preview screenshot if available, show it to the user, and explain what changed. Never skip this step.

## Commands

```bash
# Build for device
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build

# Build for simulator
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build

# Run tests
xcodebuild test -project MindRestore.xcodeproj -scheme MindRestoreTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build

# Install on device
xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app

# Archive for App Store
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Release -destination 'generic/platform=iOS' -archivePath build/MindRestore.xcarchive archive -allowProvisioningUpdates

# Upload to App Store Connect
xcodebuild -exportArchive -archivePath build/MindRestore.xcarchive -exportPath build/export -exportOptionsPlist /tmp/ExportOptions.plist -allowProvisioningUpdates
```

## Gotchas

- **SourceKit false positives**: "Cannot find X in scope" errors are WRONG. Only trust `xcodebuild` output. IGNORE all SourceKit diagnostics.
- **ExportOptions.plist**: Must create at `/tmp/ExportOptions.plist` with teamID `73668242TN`, method `app-store`, destination `upload` before uploading.
- **Device family**: MUST be `TARGETED_DEVICE_FAMILY = 1` (iPhone only). Never set to "1,2".
- **`build/` directory**: Gitignored. Safe to delete for clean builds.
- **`#if DEBUG` wrapping**: `ScreenshotDataGenerator` must be wrapped in `#if DEBUG` or archive builds fail.

## Architecture

- **SwiftUI + SwiftData**, iOS 17+, iPhone only
- `ContentView.swift` — Root TabView (Home, Train, Compete, Insights, Profile) + TrainingView + TrainingTile (large file, ~900 lines)
- `DesignSystem.swift` — AppColors, button/card modifiers, CognitiveDomain enum
- Environment objects: StoreService, AchievementService, PaywallTriggerService, TrainingSessionManager, GameCenterService, DeepLinkRouter
- Models: User, Exercise, DailySession, BrainScoreResult, Achievement (all SwiftData @Model)
- Games are in `Views/Exercises/`, each file has both ViewModel and View

## Key Files

- `MindRestoreApp.swift` — App entry, SwiftData container, analytics init
- `ContentView.swift` — Tabs, TrainingView, awardXP(), exercise navigation
- `Services/GameCenterService.swift` — Leaderboard IDs, score reporting, NO mock data
- `Services/NotificationService.swift` — All 8 notification types
- `Services/DeepLinkRouter.swift` — URL scheme handling, challenge deep links
- `Models/ChallengeLink.swift` — URL-encoded friend challenge data
- `Views/Onboarding/OnboardingAssessmentView.swift` — Brain Age assessment in onboarding

## Branching

- `main` = App Store (current live version)
- `test` = next version in development (v1.2 with new games + async challenges)
- Always commit and push after changes

## App Store Connect API

- Key ID: `9GRLL5VKUX`, Issuer: `ab66930d-a8da-451a-81e7-1cdd5f229aaf`
- P8 key: `/Users/dylanmiller/Downloads/AuthKey_9GRLL5VKUX.p8`
- App ID: `6760178716`
- Use PyJWT + ES256 for JWT generation (see memory/reference_asc_api.md)

## Design & UI

- When designing color schemes or visual systems, always ask clarifying questions about the semantic meaning of colors BEFORE implementing. E.g., do colors represent categories, progress levels, or states?
- Front-load design intent: confirm understanding of visual/UX intent before writing code

## Debugging

- For bug fixes, verify the root cause before implementing a fix. Read the relevant code thoroughly and check for type/overflow issues (e.g., UInt64 vs Int). Don't assume the first hypothesis is correct.
- Explain the root cause to the user BEFORE writing any fix
- Search for similar patterns elsewhere in the codebase after fixing

## Code Style

- Use `AppColors` constants, never raw `Color` values
- Games: setup → playing → results flow pattern
- Every game has share cards via `ExerciseShareCard`
- PersonalBestTracker for high scores, AdaptiveDifficultyEngine for difficulty
- Composite leaderboard scores for capped games: `primaryScore * 1000 + max(0, 999 - durationSeconds)`

## Current State (v1.1.2 live, v1.2 on test)

- 8 games live: Reaction Time, Color Match, Speed Match, Visual Memory, Number Memory, Math Speed, Dual N-Back, Chunking
- v1.2 adds: Word Scramble, Memory Chain, async friend challenges, daily challenge leaderboard
- Spaced repetition, memory palace, active recall, prospective memory, mixed training: REMOVED (user finds boring)
