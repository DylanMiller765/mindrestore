# RESUME — Onboarding Memo Loading Beats

Read this first on resume. Everything needed is in committed files; this is the handoff.

## What this feature is
Replace the single pre-paywall personalization loader with cumulative, Memo-driven
"building your plan" beats after goals / age / screen-time, converging into a final
"presenting" beat right before the hard paywall. Goal: conversion (endowment + IKEA +
commitment-consistency + problem-agitate-solve peaking loss aversion before the offer).

## Source of truth (already committed)
- **Spec:** `docs/superpowers/specs/2026-05-28-onboarding-memo-loading-beats-design.md`
- **Plan (task-by-task, with code):** `docs/superpowers/plans/2026-05-28-onboarding-memo-loading-beats.md`
- Read the plan's top "⚠️ Divergence from spec" note: beats are an **overlay**, NOT new
  pages — zero `goToPage` renumbering. This decision is approved by the user.

## Assets (DONE, committed, in `MindRestore/Resources/`)
- `memo-building.mov` — thinking/working loop (beats 1–3)
- `memo-presenting.mov` — presenting loop (final beat)
- Both: HEVC + alpha, 960×880, ~5s, transparent bg, watermark cropped. Made from Runway
  green-screen MP4s via ffmpeg (`chromakey=0x00FF00:0.16:0.06,despill,crop=960:880:0:0,
  hevc_videotoolbox -alpha_quality 0.9 -tag:v hvc1`). No re-conversion needed.

## CORRECTION to the plan — assets are `.mov`, not `.mp4`
The plan's view code says `withExtension: "mp4"` for the Memo loops. Change BOTH beat
views to `withExtension: "mov"`:
- `OnboardingPlanBuildBeatOverlay.memoVideoName` → load `"memo-building"` `.mov`
- `OnboardingPlanFinalBeatView.memoVideoName` → load `"memo-presenting"` `.mov`

## Remaining work (in order)
1. **Bundle the assets.** Add `memo-building.mov` + `memo-presenting.mov` to the
   MindRestore target so they ship in the app bundle. Check how `onboarding_demo.mp4`
   (already in `MindRestore/Resources/`) is registered: inspect `project.yml` resource
   globs and `MindRestore.xcodeproj/project.pbxproj`. If Resources is glob-included,
   regenerate; otherwise add explicit references. User has granted project-file edit access.
2. **Execute the plan, task by task** (`...onboarding-memo-loading-beats.md`):
   - Task 0: register the 2 NEW Swift files (`PlanBuildBeatContent.swift`,
     `PlanBuildBeatContentTests.swift`) — same project-membership question as #1.
   - Task 1: pure model + XCTest (TDD) — fully verifiable alone.
   - Task 2: building-beat overlay view (note: `PlayerHostView` access level — make
     non-private so the shared `OnboardingLoopingVideo` wrapper can reuse it).
   - Task 3: final beat view; delete `OnboardingPlanPersonalizingView`.
   - Task 4: wire overlay into `OnboardingView` (state + overlay layer + `advance(after:then:)`;
     wrap the goals→age, age→screenTime, lifeSquares→memoPlan advances; repoint page 6).
   - Task 5: assets (done in #1 above).
   - Task 6: device build + `/verify-changes` + flow trace + edge cases + analytics.

## Verification rules (CLAUDE.md — non-negotiable)
- Device build + install required (`00008130-000A214E11E2001C`), not simulator-only.
- Run `/verify-changes` after each change. UI iteration is ONE change → show user →
  iterate; do NOT batch UI changes.
- Ignore SourceKit "cannot find in scope" errors; trust `xcodebuild` only.
- Use `/tmp/mindrestore-build` derivedData; `COPYFILE_DISABLE=1` on builds.

## Known verification watch-item
`AVPlayerLayer` may not composite video alpha as transparent (could render black behind
Memo). On the `#0E1014` onboarding bg this looks ~identical; if a faint rectangle shows on
device (Task 6), re-bake the loops onto solid `#0E1014` instead of alpha.

## Open confirmations for the engineer at execution time
- Exact `UserFocusGoal` case names (`Models/Enums.swift`) vs the model's mapping.
- Precise goals→age and lifeSquaresReceipt→memoPlan advance call sites (anchor on the
  `trackOnboardingStepCompleted("goals"/"age")` strings, not line numbers).
