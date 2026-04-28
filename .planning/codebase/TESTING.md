# Testing Patterns

**Analysis Date:** 2026-04-27

## Test Framework

**Runner:** XCTest (no migration to Swift Testing yet). Test files use `import XCTest` and inherit from `XCTestCase` with `final class` declarations.

**Config:** No standalone config file. Test target is configured inside `MindRestore.xcodeproj` (scheme: `MindRestoreTests`). Tests live alongside the app at `/Users/dylanmiller/Desktop/mindrestore/MindRestoreTests/`.

**Run Commands:**
```bash
# Simulator (canonical for tests)
xcodebuild test -project MindRestore.xcodeproj -scheme MindRestoreTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath build
```

There is no project-level pre-commit hook running tests. The `CLAUDE.md` QA cycle requires only a successful `xcodebuild` *build* (not test) before commits.

## Test File Organization

**Location:** Separate target at `/Users/dylanmiller/Desktop/mindrestore/MindRestoreTests/` (NOT co-located with source). The test target imports the app via `@testable import MindRestore`.

**Naming:** `{TypeUnderTest}Tests.swift`. Current files:
- `ChallengeLinkTests.swift` — `ChallengeLink` model + URL encoding
- `DeepLinkRouterTests.swift` — `DeepLinkRouter` URL parsing
- `ReferralServiceTests.swift` — `ReferralService` CloudKit logic
- `SeededGeneratorTests.swift` — `SeededGenerator` deterministic RNG
- `V1_5FeatureTests.swift` — cross-cutting v1.5 feature tests (e.g. `ChallengeLinkV15Tests`)

**Structure:** Flat directory — no subfolders, no Unit/Integration split. Multiple `XCTestCase` subclasses per file are allowed when the file represents a feature epoch (see `V1_5FeatureTests.swift`).

## Test Structure

**Suite Organization:** Standard XCTest pattern.

```swift
import XCTest
@testable import MindRestore

final class SeededGeneratorTests: XCTestCase {

    // MARK: - Determinism

    func testSameSeedProducesSameSequence() {
        var rng1 = SeededGenerator(seed: 42)
        var rng2 = SeededGenerator(seed: 42)

        for _ in 0..<100 {
            XCTAssertEqual(rng1.next(), rng2.next())
        }
    }
}
```

**Patterns:**
- `// MARK: - Section` headers group related tests inside a single `XCTestCase`.
- Test method names are full sentences describing the behavior — `testSameSeedProducesSameSequence`, `testVercelURLWithSpacesInName`, `testShareMessageIncludesGameName`.
- No `setUp()` / `tearDown()` overrides observed in current tests — each test constructs its own fixtures inline.
- Assertions: `XCTAssertEqual`, `XCTAssertTrue`, `XCTAssertFalse`, `XCTAssertGreaterThan`, occasional `XCTAssertNil`.
- Failure messages are passed as the trailing string argument: `XCTAssertFalse(allSame, "Different seeds should produce different sequences")`.

## Mocking

**Framework:** None. No Cuckoo, no Mockingbird, no protocol-based DI scaffolding for mocks. Limited mocking — manual stubs only.

**Patterns:** Tests exercise pure value types and pure-function-style logic where possible:
- `ChallengeLink` — initialized directly with test data and asserted on its computed properties (`vercelURL`, `shareMessage()`).
- `SeededGenerator` — used as a real instance; determinism is the test invariant.
- `DeepLinkRouter` — tests construct `URL` instances and call routing methods directly.

For things that *can't* be unit-tested without infrastructure (StoreKit, GameKit, CloudKit, FamilyControls), the codebase relies on **manual QA on the physical device** (per `CLAUDE.md` QA cycle, step 2: install on device `00008130-000A214E11E2001C`).

**What to Mock:** Pure logic dependencies you control — value types, deterministic helpers, model methods. If you need to introduce a mock, do it via a protocol + struct-based stub rather than a mocking framework.

**What NOT to Mock:**
- SwiftUI views — never asserted in tests; verified visually via `/verify-changes` skill.
- StoreKit / RevenueCat — use the local `Configuration.storekit` testing config in Xcode instead.
- GameKit / CloudKit / FamilyControls — manual device QA.
- SwiftData models — no in-memory `ModelContainer` test fixtures observed; SwiftData logic is currently untested at the unit level.

## Fixtures and Factories

**Test Data:** Inline literals in each test. No shared `Fixtures.swift`, no factory functions. Pattern from `V1_5FeatureTests.swift`:

```swift
let link = ChallengeLink(
    game: .reactionTime,
    seed: 12345,
    score: 288,
    challengerName: "Dylan"
)
```

**Location:** N/A — fixtures are per-test inline. If shared fixtures become necessary, create a `MindRestoreTests/Fixtures/` directory.

## Coverage

**Requirements:** None enforced. No coverage gate, no CI configuration committed, no `xccov` thresholds.

**View Coverage:**
```bash
xcodebuild test -project MindRestore.xcodeproj -scheme MindRestoreTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath build -enableCodeCoverage YES
xcrun xccov view --report build/Logs/Test/*.xcresult
```

## Test Types

**Unit Tests:** All five test files are unit tests against pure-ish types — RNG determinism, URL encoding, link parsing, message formatting. No integration of Apple frameworks.

**Integration Tests:** None. Cross-service flows (purchase → entitlement update → UI gating, leaderboard submission, push notification scheduling) are validated by hand on device.

**UI Tests:** Not used. There is no `MindRestoreUITests` target. Visual verification is performed via the `/verify-changes` skill (Xcode MCP build + screenshot) on every code change.

## Common Patterns

**Async Testing:** No `async`/`await` test methods observed yet. When adding async tests, the modern XCTest pattern is `func testXxx() async throws { … }` — prefer this over `XCTestExpectation` for new code.

**Error Testing:** Optional unwrapping with force-unwrap inside tests (`link.vercelURL!`) is acceptable in test code — a crash *is* a failure. For thrown errors, use `XCTAssertThrowsError(try …)` (no current examples but it's the standard).

## Test Coverage Reality

**Coverage is light.** The Memori test target contains 5 files covering: deterministic RNG (`SeededGenerator`), URL encoding/decoding for friend-challenge deep links (`ChallengeLink`, `DeepLinkRouter`), CloudKit referral helpers (`ReferralService`), and a v1.5 feature suite. There are **no tests** for:

- Any SwiftUI view (by design — visual verification covers this)
- Any game ViewModel (`ReactionTimeViewModel`, `ColorMatchViewModel`, etc.)
- `StoreService` / RevenueCat purchase flow
- `AchievementService`, `PaywallTriggerService`, `TrainingSessionManager`, `GameCenterService`
- SwiftData model methods including the non-trivial `User.updateStreak(on:)` and streak-freeze logic
- `AdaptiveDifficultyEngine`, `WorkoutEngine`, `DualNBackEngine`
- Focus Mode (`FocusModeService`) and the FamilyControls / DeviceActivity / ManagedSettings extensions

The project's QA strategy per `CLAUDE.md` is **build + install on device + manual visual QA** rather than automated coverage. New work should add unit tests for any new pure-logic helpers (engines, encoders, score formulas) but is not blocked on testing UI or framework-bound services.

---
*Testing analysis: 2026-04-27*
