# CLAUDE.md — Memori (MindRestore)

## UI/Design Guidelines

Before coding anything, describe exactly what this will look like — colors (with hex values), layout, icon choices, and what each visual element represents. I'll approve before you implement.

## Bug Prevention

After implementing interactive features (buttons, gestures, detection logic), mentally trace the full user flow from trigger to completion and verify each state transition works. Pay special attention to features that depend on app lifecycle state (e.g., skip buttons during active phases, alarm re-firing).

## QA Before Every Commit

Before committing any changes, run a full QA cycle:
1. Build with `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates` — fix any compiler errors iteratively until it succeeds.
2. Install on device with `xcrun devicectl device install app --device 00008130-000A214E11E2001C` + the build output path.
3. For each modified view, verify it handles both light and dark mode by checking color assets and conditional styling.
4. Check for common iOS issues: retain cycles, force unwraps, main-thread UI violations.
5. Only after build succeeds and is installed on device, commit and push.

## Environment Constraints

This is an iOS app project (Swift/SwiftUI). Claude cannot interact with Xcode directly — do not attempt to open Xcode projects, add SPM packages via CLI, or navigate Xcode UI. Instead, provide step-by-step instructions for the user to follow in Xcode.
