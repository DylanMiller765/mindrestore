# Codebase Concerns

**Analysis Date:** 2026-04-27

## Tech Debt

**Onboarding mega-files:**
- Issue: Onboarding is split across two ~2,000-line single-struct files. All 16+ onboarding pages (goals, plan reveal, paywall lead-in, focus intro, etc.) are inline in one body. Hard to navigate, slow to compile, painful to refactor.
- Files: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` (2,375 lines), `MindRestore/Views/Onboarding/OnboardingView.swift` (2,236 lines), `MindRestore/Views/Onboarding/FocusOnboardingPages.swift` (921 lines), `MindRestore/Views/Onboarding/QuickAssessmentView.swift` (774 lines)
- Impact: Editing one page risks breaking another; AI tools and humans alike struggle with the file. Compile times degraded. SourceKit reports false-positive UIKit errors here (per CLAUDE.md), masking real problems.
- Fix approach: Extract each page into its own `OnboardingPages/` subfolder file, keep the parent struct as a coordinator. ~2-4hr refactor.

**Zombie / removed game code still in tree:**
- Issue: Per CLAUDE.md and MEMORY.md, Spaced Repetition, Active Recall, Memory Palace, Prospective Memory, and Mixed Training were "removed from UI (user finds them boring)" — but their full Views, ViewModels, Engines, Content, and Models remain in the codebase, still compiled into the binary.
- Files: `MindRestore/Views/Exercises/SpacedRepetitionView.swift`, `ActiveRecallView.swift`, `MemoryPalaceView.swift` (1,171 lines), `ProspectiveMemoryView.swift` (1,012 lines), `MixedTrainingView.swift` (1,211 lines), `MindRestore/Services/SpacedRepetitionEngine.swift`, `ActiveRecallEngine.swift`, `MindRestore/ViewModels/SpacedRepetitionViewModel.swift`, `ActiveRecallViewModel.swift`, `MindRestore/Content/SpacedRepetitionContent.swift`, `ActiveRecallContent.swift`, `MindRestore/Models/SpacedRepetitionCard.swift`
- Impact: Adds ~5,500+ lines of dead code, inflates binary size, increases compile time, and `SpacedRepetitionCard` is still registered in the SwiftData ModelContainer at `MindRestoreApp.swift:60` — meaning it occupies disk schema for every user.
- Fix approach: Delete files, then drop `SpacedRepetitionCard.self` from the ModelContainer. Requires SwiftData migration plan since existing users may have records. ~1-2hr.

**ContentView.swift overload:**
- Issue: 1,534-line file holds the root TabView, TrainingView, TrainingTile, awardXP logic, exercise navigation, and per-tab routing. Per CLAUDE.md it is "(large file, ~900 lines)" — already grew 70% past that note.
- Files: `MindRestore/ContentView.swift`
- Impact: Single source of merge conflicts; any tab change touches the same file as every other tab change. Cognitive load is high.
- Fix approach: Split TrainingView and TrainingTile into `Views/Train/`. Move awardXP into `XPService`.

**Force-try in ModelContainer initialization:**
- Issue: `try! ModelContainer(...)` will crash the app on launch if SwiftData schema migration ever fails (e.g., legacy `SpacedRepetitionCard` removed without migration).
- Files: `MindRestore/MindRestoreApp.swift:59`
- Impact: One-shot crash on launch with no recovery path; user loses access until reinstall, which destroys their data.
- Fix approach: Wrap in `do/catch`, fall back to in-memory container with a recovery banner; log to PostHog. Implement a deletion-and-recreate path as last resort.

**Heavy view files (>800 lines) with mixed concerns:**
- Issue: Multiple large view files each combining a ViewModel, helpers, share-card, and render logic.
- Files: `MindRestore/Views/Social/DuelView.swift` (1,230), `MindRestore/Views/Settings/SettingsView.swift` (1,041), `MindRestore/Views/Components/TikTokShareCard.swift` (921), `MindRestore/Views/Home/HomeView.swift` (893), `MindRestore/Views/FocusMode/FocusModeCard.swift` (886), `MindRestore/Views/Exercises/WordScrambleView.swift` (872), `MindRestore/Views/Assessment/ScoreRevealView.swift` (836), `MindRestore/Views/Progress/ProgressDashboardView.swift` (831)
- Impact: Slow incremental builds, hard to unit-test sub-components, easy to introduce bugs during edits.
- Fix approach: Extract ViewModels to sibling files, isolate share-card variants, pull style modifiers into DesignSystem.

**Print-statement logging instead of unified logger:**
- Issue: 11 raw `print(...)` calls scattered across the codebase rather than `os.Logger` / unified logging.
- Files: across `MindRestore/**/*.swift`
- Impact: No log levels, no subsystems, no privacy redaction, no way to disable in Release. Some prints may include user data.
- Fix approach: Replace with `Logger(subsystem: "com.dylanmiller.mindrestore.Memori", category: ...)`.

## Known Bugs

**FamilyControls Distribution entitlement not yet approved by Apple:**
- Symptoms: Per MEMORY.md (submitted Apr 19/20/25, all "Submitted" status, no approvals), Focus Mode features will fail in App Store distribution builds because the production entitlement isn't granted. Development builds work because development entitlement is granted automatically.
- Files: `MindRestore/Services/FocusModeService.swift`, `MindRestore/Extensions/DeviceActivityMonitorExtension.swift`, `MindRestore/Extensions/ShieldActionExtension.swift`, `MindRestore/Extensions/ShieldConfigurationExtension.swift`
- Trigger: Submitting v2.0 to the App Store before Apple approves the FamilyControls Distribution entitlement.
- Workaround: None — this is the critical path blocker for v2.0 ship. Decision deadline May 15 (per memory).

**Pre-existing Swift 6 concurrency warnings:**
- Symptoms: Per CLAUDE.md, build emits Swift 6 isolation warnings in GameCenterService.swift, main-actor isolated property access in PaywallView.swift, Sendable closure capture in DuelView.swift.
- Files: `MindRestore/Services/GameCenterService.swift`, `MindRestore/Views/Paywall/PaywallView.swift`, `MindRestore/Views/Social/DuelView.swift`
- Trigger: Compile in any configuration; warnings persist.
- Workaround: Currently warnings, not errors — but will become errors when SWIFT_VERSION is bumped from 5.9 to 6.0.

## Security Considerations

**StoreKit2 receipt validation:**
- Risk: Subscription state is determined client-side. Receipts are not server-validated, so a jailbroken device or local proxy could spoof Pro entitlement.
- Files: `MindRestore/Services/StoreService.swift`
- Current mitigation: StoreKit 2's signed `Transaction` verification (built-in JWS check).
- Recommendations: For revenue-protection at scale, add server-side receipt validation via App Store Server API or RevenueCat (per memory, RevenueCat is in observer mode — finish the integration). Low priority while user count is small.

**FamilyControls is privacy-sensitive:**
- Risk: FamilyControls grants the app the ability to shield/unshield arbitrary apps and websites; mishandling could lock users out of their device or surface child-protection abuse vectors.
- Files: `MindRestore/Services/FocusModeService.swift`, `MindRestore/Extensions/DeviceActivityMonitorExtension.swift`, `MindRestore/Extensions/ShieldActionExtension.swift`
- Current mitigation: Apple gates with the Distribution entitlement (still pending approval — see Known Bugs).
- Recommendations: Before launch, document the privacy stance in-app (no app-usage data leaves device, no analytics on shielded apps), add a kill-switch in Settings to instantly clear all shields.

**Deep link routing trust:**
- Risk: `DeepLinkRouter` parses URL-encoded `ChallengeLink` payloads from external sources (notifications, share sheets). Malformed input or maliciously crafted links could trigger unexpected navigation or state.
- Files: `MindRestore/Services/DeepLinkRouter.swift`, `MindRestore/Models/ChallengeLink.swift`
- Current mitigation: Tests exist (`DeepLinkRouterTests.swift`, `ChallengeLinkTests.swift`).
- Recommendations: Confirm bounds-checking on numeric fields (score, seed) against UInt64 overflow; reject links with unrecognized schemas.

## Performance Bottlenecks

**SwiftUI body re-evaluation in mega-files:**
- Problem: 2,000+ line body computed properties (Onboarding) re-evaluate every state change.
- Files: `MindRestore/Views/Onboarding/OnboardingView.swift`, `OnboardingNewScreens.swift`
- Cause: All pages are siblings inside a single TabView/ZStack; one `@State` change re-runs the entire body.
- Improvement path: Extract pages into separate views so SwiftUI can diff at view boundaries. Use `@StateObject`/`@Observable` to pin state.

**Compile-time bottleneck:**
- Problem: Large mixed files (`OnboardingNewScreens.swift`, `OnboardingView.swift`, `ContentView.swift`, `DuelView.swift`) take disproportionately long to type-check.
- Files: same as above
- Cause: Type-inference cost in large `body` properties; nested ViewBuilder generics.
- Improvement path: Annotate intermediate types explicitly; split files; consider `@ViewBuilder` helper functions returning `some View`.

**Rive runtime size:**
- Problem: RiveRuntime is a heavyweight framework relative to its single use case (Memo mascot states).
- Files: `MindRestore/Views/Components/RiveMascotView.swift`
- Cause: Rive ships a full graphics runtime even when used for a small SVG/JSON mascot.
- Improvement path: For mascot-only use, evaluate replacing with a Lottie file or static SF Symbols/SwiftUI shapes. Defer if mascot animation is core to brand.

## Fragile Areas

**Onboarding flow (high blast radius):**
- Files: `MindRestore/Views/Onboarding/OnboardingView.swift`, `OnboardingNewScreens.swift`, `FocusOnboardingPages.swift`, `QuickAssessmentView.swift`, `MindRestore/Views/Assessment/OnboardingAssessmentView.swift`
- Why fragile: Conversion-critical path. SourceKit reports false UIKit errors here (per CLAUDE.md "IGNORE all SourceKit diagnostics"), so the IDE actively misleads anyone editing it. State is shared across 16+ pages via a coordinator that lives in the same 2,000-line struct.
- Safe modification: Always run `xcodebuild` and `/verify-changes` after every onboarding edit. Manual end-to-end test on device. No unit tests cover this code path.
- Test coverage: Zero. Critical conversion funnel with no automated regression protection.

**FocusModeService + DeviceActivity extensions:**
- Files: `MindRestore/Services/FocusModeService.swift` (480 lines), `MindRestore/Extensions/DeviceActivityMonitorExtension.swift`, `MindRestore/Extensions/ShieldActionExtension.swift`, `MindRestore/Extensions/ShieldConfigurationExtension.swift`
- Why fragile: Cross-process boundary (extensions run independently of the app), plus the comment in `DeviceActivityMonitorExtension.swift:12` notes "DeviceActivitySchedule is interval-based and has no native day-of-week filter, so [...]" — meaning the extension implements scheduling logic by hand. Extensions cannot be debugged with breakpoints in App Store builds, and entitlement is still pending.
- Safe modification: Test on physical device only (extensions don't run reliably in simulator). Verify shields lift on uninstall.
- Test coverage: None. No tests for the shield/unshield lifecycle or schedule edge cases (DST, day-of-week boundaries).

**`MindRestoreApp.swift` ModelContainer schema:**
- Files: `MindRestore/MindRestoreApp.swift:58-64`
- Why fragile: Hard-coded list of `@Model` types includes the legacy `SpacedRepetitionCard.self`. Adding/removing a Model type without a migration plan crashes existing users.
- Safe modification: Bump SwiftData schema version, write `VersionedSchema`, test with seeded data from previous version.
- Test coverage: No SwiftData migration tests.

**StoreService subscription state:**
- Files: `MindRestore/Services/StoreService.swift`
- Why fragile: Drives entire monetization. Single source of truth for `isPro`. Any state desync between StoreKit2 transactions and the cached `isPro` flag silently breaks paywall gating.
- Safe modification: Test with all four legacy/current SKUs ($3.99/$19.99 grandfathered + $6.99/$39.99 current). Test cancellation and restore on physical device.
- Test coverage: None for StoreKit logic.

## Scaling Limits

**Game Center leaderboards as social graph:**
- Current capacity: Game Center handles leaderboard reads/writes globally; no app-level cap.
- Limit: Real-time 1v1 (per memory `project_1v1_priority.md`) requires either Game Center matchmaking (rate-limited, slow) or a custom backend. Gated until 1K+ active users (per memory).
- Scaling path: Move to CloudKit custom profiles (`project_cloudkit_profiles.md`) or build a small backend (e.g., Supabase) for matchmaking and presence.

**SwiftData on-device only:**
- Current capacity: All user data is local — sessions, achievements, brain scores. No CloudKit sync (`cloudKitDatabase: .none` at `MindRestoreApp.swift:62`).
- Limit: Switching devices loses all history. Cannot recover after uninstall.
- Scaling path: Enable CloudKit private DB once schema is stable. Adds privacy/security review burden.

## Dependencies at Risk

**ConfettiSwiftUI 1.1.0:**
- Risk: Single-author small package, last-version pin is several years old.
- Impact: If iOS 27/28 breaks the API, no upstream fix.
- Migration plan: Visual effect only — easily replaced with a custom emitter (`CAEmitterLayer` wrapped in `UIViewRepresentable`) or `TimelineView`-based animation.

**RiveRuntime:**
- Risk: Heavy framework for a single mascot use case; Rive's pricing/licensing has shifted historically.
- Impact: If Rive deprecates the runtime or paywalls features, mascot breaks.
- Migration plan: Convert mascot to Lottie or SwiftUI-native Canvas animations.

**PostHog:**
- Risk: Currently active analytics provider (replaced TelemetryDeck in v1.4.0 per memory). Self-hosted option exists but adds ops burden.
- Impact: Vendor lock-in for funnel data; price scales with events.
- Migration plan: `AnalyticsService` is already a thin wrapper at `MindRestore/Services/AnalyticsService.swift` — swap implementations behind it if needed.

**RevenueCat (observer mode, per memory):**
- Risk: Integration is partial. If StoreKit2 transactions don't sync to RevenueCat, dashboards lie.
- Impact: Inability to trust revenue/retention metrics; harder to add cross-platform later.
- Migration plan: Either complete the RevenueCat integration (preferred) or remove it to reduce surface area.

## Missing Critical Features

**Server-side subscription validation:**
- Problem: All entitlement checks are client-side via StoreKit2.
- Blocks: Cannot detect refunds, family-sharing edge cases, or jailbroken bypass at scale. Limits trust in revenue analytics.

**SwiftData migration strategy:**
- Problem: No `VersionedSchema` declared; `try!` on ModelContainer init.
- Blocks: Removing the legacy `SpacedRepetitionCard` (and other zombie models) without crashing existing users.

**Automated end-to-end test for paywall + onboarding conversion:**
- Problem: The two highest-revenue-impact flows (onboarding completion and paywall purchase) have zero automated coverage.
- Blocks: Confidence in shipping refactors; A/B test rollback safety.

**Crash analytics:**
- Problem: No mention of crash reporting (Crashlytics, Sentry, App Store Crash Reports only). PostHog is event analytics, not crash.
- Blocks: Detecting `try!` crashes or extension failures in production.

## Test Coverage Gaps

**StoreKit / subscription logic — UNTESTED:**
- What's not tested: `StoreService.swift` — purchases, restore, entitlement evaluation, legacy SKU handling.
- Files: `MindRestore/Services/StoreService.swift`
- Risk: Silent revenue loss or free-Pro-for-all bug ships unnoticed.
- Priority: High

**Onboarding flow — UNTESTED:**
- What's not tested: 16+ onboarding pages, branching logic, paywall lead-in, focus intro, completion persistence.
- Files: `MindRestore/Views/Onboarding/OnboardingView.swift`, `OnboardingNewScreens.swift`, `FocusOnboardingPages.swift`
- Risk: Conversion regressions ship unnoticed; this is the single biggest revenue driver.
- Priority: High

**FocusMode / FamilyControls — UNTESTED:**
- What's not tested: Shield enable/disable, schedule day-of-week logic (custom code per `DeviceActivityMonitorExtension.swift:12`), DST/timezone edge cases, app-uninstall cleanup.
- Files: `MindRestore/Services/FocusModeService.swift`, `MindRestore/Extensions/DeviceActivityMonitorExtension.swift`
- Risk: Users locked out of apps; shields persist after uninstall; v2.0 differentiator silently broken.
- Priority: High

**Game-specific scoring and adaptive difficulty — UNTESTED:**
- What's not tested: 10 active game ViewModels, `AdaptiveDifficultyEngine` (501 lines), `WorkoutEngine` (487 lines), composite leaderboard score formula.
- Files: `MindRestore/Views/Exercises/*.swift`, `MindRestore/Services/AdaptiveDifficultyEngine.swift`, `WorkoutEngine.swift`
- Risk: Score regressions, leaderboard drift, unfair difficulty scaling.
- Priority: Medium

**SwiftData migrations — UNTESTED:**
- What's not tested: Container initialization across schema versions; legacy model removal.
- Files: `MindRestore/MindRestoreApp.swift`, all `MindRestore/Models/*.swift`
- Risk: Launch crash on schema change.
- Priority: High (becomes critical when removing zombie code)

**Existing test suite:**
- Total: ~979 lines across 5 test files (`ChallengeLinkTests`, `DeepLinkRouterTests`, `ReferralServiceTests`, `SeededGeneratorTests`, `V1_5FeatureTests`). Out of ~44,766 lines of app code, that is ~2.2% test-to-code ratio.
- Coverage focuses on deep linking, referrals, seeded RNG, and v1.5 feature flags — NOT on core revenue, onboarding, games, FocusMode, StoreKit, or SwiftData.

---
*Concerns audit: 2026-04-27*
