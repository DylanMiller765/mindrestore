# Memo - Doomscroll Blocker (v2.0)

**Project Code:** MEMO-V2
**Type:** iOS brain training app + screen-time blocker
**Status:** Brownfield — v1.4.2 live on App Store, v2.0 in flight
**Active Branch:** `v2.0-focus-mode`
**Initialization Date:** 2026-04-27

## What This Is

Memori is an iOS brain training app rebranding to **"Memo - Doomscroll Blocker"** with the v2.0 release. Beyond the existing 10 brain training games, v2.0 introduces **Focus Mode** — the user picks apps to block (TikTok, Instagram, etc.), and Memo locks them via FamilyControls until the user trains. Training a brain game earns unlock minutes.

The brand positioning is anti-big-social-media: Memo is the user's "bouncer," not the algorithm. The voice is informed-fear + Gen Z defiance. 10% of profit is donated quarterly (split between Center for Humane Technology + community-picked cause).

**Tagline:** "Block Apps. Train Your Brain."
**Mascot:** "Memo" — purple brain with glasses (Rive animations + static poses)

## Core Value

The single most important thing that must work:

> **Train → unlock loop:** User picks blocked apps in Focus Mode → tries to open one → gets locked → plays a brain game → earns N minutes of access → app unlocks.

If this loop is friction-free and feels rewarding, v2.0 succeeds. Everything else (onboarding polish, leaderboards, subscriptions) is amplification.

## Context

**Live state:** v1.4.2 in App Store Review, v1.4.0 ready for sale. Single Pro tier ($6.99/mo, $39.99/yr 3-day trial, $2.99/wk). Apple Small Business Program (85% revenue retention).

**v2.0 work in flight:**
- Onboarding rewrite (16-page OB-design-system flow with bouncer welcome, pain cards, industry scare, empathy, goals, age, screen time, personal scare, quick assessment, brain age reveal, plan reveal, comparison, differentiation, paywall, focus mode setup, notif priming, commitment)
- Focus Mode — FamilyControls + ManagedSettings + DeviceActivity, train-to-unlock loop
- Brand rename — "Memori" → "Memo - Doomscroll Blocker" (App Store), home-screen name "Memo"
- Bricolage Grotesque brand font bundled
- Hi-res social media app icons (256×256 from coloured-icons MIT-licensed library)

**Critical external dependency:** **FamilyControls Distribution entitlement** is pending Apple review (submitted April 19/20/25 — all "Submitted," none approved). Decision deadline ~May 15: if not granted, ship v2.0 without Focus Mode.

**Current user state:** Solo indie developer (Dylan), revenue baseline $11 MRR, v2.0 ship targets $1K MRR end of May. Aspirational $10K MRR end of summer to drop out of college and move to Vietnam.

## Requirements

### Validated (existing v1.x capabilities, inferred from codebase)

- ✓ **10 brain training games** — Reaction Time, Color Match, Speed Match, Visual Memory, Number Memory, Math Speed, Dual N-Back, Chunking, Chimp Test, Verbal Memory — existing in `MindRestore/Views/Exercises/`
- ✓ **Daily streak system** — User model + AchievementService
- ✓ **Brain Score composite metric** — `BrainScoreCard.swift`, segmented ring, daily snapshot
- ✓ **StoreKit 2 single Pro tier** — `StoreService.swift`, $6.99/mo / $39.99/yr / $2.99/wk
- ✓ **GameCenter recurring leaderboards** — `GameCenterService.swift`, weekly/monthly/all-time
- ✓ **PostHog analytics** — `AnalyticsService.swift`, replaced TelemetryDeck in v1.4
- ✓ **Notifications (8 types)** — `NotificationService.swift`, streak warnings + re-engagement
- ✓ **Daily limit gating** — Free users 3 games/day, paywall on 4th
- ✓ **Brain Age reveal** — Spotify Wrapped-style assessment in onboarding
- ✓ **Share cards (TikTok-style)** — Per-game share cards via `ExerciseShareCard`
- ✓ **Widget extension** — `MemoriWidgetBundle.swift` shows daily metrics

### Active (v2.0 ship requirements)

- [ ] App rename to "Memo - Doomscroll Blocker" (App Store) / "Memo" (home screen)
- [ ] Focus Mode complete — FamilyControls picker + shield + train-to-unlock loop
- [ ] FamilyControls Distribution entitlement granted (or ship without Focus Mode by May 15)
- [ ] Onboarding 16-page redesign final polish (Pain Cards receipt fixes, Goals redesign pending Codex)
- [ ] ASC metadata push for new name + new keywords
- [ ] App Store screenshot set (5 screenshots, ASO-optimized for v2.0)
- [ ] TestFlight QA pass (5+ testers)
- [ ] App Review submission

### Out of Scope (deferred or explicitly excluded)

- **Friend challenges** — deferred to v2.1+; async link-sharing doesn't feel social enough
- **Real-time 1v1 multiplayer** — requires 1K+ active users for matchmaking; deferred
- **Custom profiles via CloudKit** — later milestone
- **v2.1 gamification (rank system, leaderboard redesign)** — next milestone after v2.0 ships
- **Login / signup / accounts** — explicitly never; Memo has no auth
- **Lifetime subscription tier** — explicitly excluded; only monthly/annual/weekly Pro
- **Mixed training, spaced repetition, memory palace, active recall, prospective memory** — already removed from UI (user finds boring)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Single Pro tier (no Ultra split) | Earlier "Ultra" attempt added decision friction; one tier converts better | Implemented in v1.4 |
| Anti-big-social-media voice | Differentiates from Lumosity/Elevate clones; Gen Z brand resonance | Locked — see `docs/BRAND.md` |
| Memo mascot stays "Memo" through rename | Mascot has equity even when app brand changes | Locked |
| 10% profit to charity (5% CHT + 5% community) | Brand differentiator, real-time ledger at getmemoriapp.com/giving | Locked |
| Drop typewriter animation on Welcome | Overused (still on Commitment); first impression needs visual punch | Implemented |
| Shared OB design system tokens | Onboarding pages were visually inconsistent; OB.* tokens unify | Implemented |
| FamilyControls Distribution required | Without it, screen-time blocking is dev-builds only | **PENDING Apple review** |
| Ship v2.0 without Focus Mode if entitlement not granted by May 15 | Don't block launch on Apple's queue | Decided 2026-04-25 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---

*Last updated: 2026-04-27 after initialization*
