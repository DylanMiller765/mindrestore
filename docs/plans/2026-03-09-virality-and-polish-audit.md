# Memori — Virality, Retention & Polish Audit
> **Date:** 2026-03-09 | **Status:** Actionable audit with prioritized recommendations

---

## 1. VIRALITY & GROWTH

### What Currently Exists
- **Brain Score share card** (ShareCardView) — light-mode card with score ring, brain age, percentile, domain bars. Rendered as image for iOS share sheet.
- **TikTok-style cards** (TikTokBrainScoreCard, TikTokChallengeCard, TikTokDuelResultCard) — dark 360x640 cards with big numbers, "Can you beat me?" CTA, and "Test yours free — Memori" footer.
- **Share triggers**: Brain Score reveal has Share + "Challenge a Friend" buttons. HomeView brain score card has a share button. ScoreRevealView has "Share Your Improvement" when score goes up.
- **Achievement share cards** (AchievementShareCard, LevelUpShareCard, ProfileShareCard) — exist but are NOT wired to any share flow in the app.
- **"firstShare" achievement** — tracks if user has ever shared, but no UI triggers it.

### Critical Virality Gaps

#### P0 — The Share Moment is Buried
- **Problem**: The single strongest viral moment — "Your Brain Age is 23" — happens during brain assessment reveal. The share button appears BELOW the fold after a 4-second animation sequence. Users see the number, feel the dopamine, then have to scroll past breakdown rows and leaderboard cards to find the share button.
- **Fix**: Move the share button directly below the Brain Age number in the overlay view (where `showBrainAgeShare` appears). This is correct placement — the overlay HAS a share button. But the share button uses a generic `ShareLink` that shares text, not the TikTok card. **Wire the TikTokBrainScoreCard image to the Brain Age overlay share button.** That card is the single most shareable asset in the app and it is never actually rendered anywhere except in previews.

#### P0 — No Share After Individual Exercises
- **Problem**: ReactionTimeView, VisualMemoryView, MathSpeedView, etc. have results screens with "Play Again" and "Done" buttons but NO share button. A user who gets 182ms reaction time has no way to brag about it.
- **Fix**: Add a share button to every exercise result screen. Create a `ExerciseResultShareCard` that shows: exercise icon, big score number, personal best badge if applicable, "Can you beat this?" CTA, Memori branding. Reaction Time is the single most viral exercise (everyone wants to compare ms times) — prioritize it.

#### P0 — TikTok Cards Are Dead Code
- **Problem**: `TikTokBrainScoreCard`, `TikTokChallengeCard`, and `TikTokDuelResultCard` are beautifully designed 360x640 cards optimized for stories/reels. They exist only as SwiftUI views with `#Preview` blocks. No code ever renders them as images or presents them to users.
- **Fix**: Use `TikTokBrainScoreCard` as the primary share image for brain score (replace or supplement `ShareCardView`). Use `TikTokChallengeCard` for the "Challenge a Friend" flow. These cards are 10x more shareable than the current light-mode card.

#### P1 — No Referral System
- **Problem**: No invite flow, no referral rewards. The app says "Test yours free — Memori" on share cards but there is no link, no tracking, no reward for inviting.
- **Fix**: Implement a referral system: "Give a friend 1 week of Pro free" via share link. Track referrals with a simple code system (no server needed — use App Clips or custom URL scheme). Even a basic "Share with friends" button in Settings that just opens the share sheet with a compelling message would be a start.

#### P1 — Challenge Flow is a Dead End
- **Problem**: `ChallengeView` exists and is accessible from ScoreRevealView. But it can only generate a share image — there is no way for the recipient to actually accept the challenge. No deep link handling, no async duel resolution. The "1v1 Duel" TikTok card shows "YOUR SCORE HERE" in a dashed box — but this flow does not exist.
- **Fix (MVP)**: Generate a share link that opens the app to a specific exercise. When recipient completes it, show a comparison screen. This does NOT require a server — use pasteboard or App Clips for the score passing. Even just sharing a screenshot with "My Reaction Time: 215ms — can you beat it? Download Memori" is more viral than nothing.

#### P1 — Not Enough "Brag-Worthy" Moments
- **Current brag moments**: Brain Score reveal, streak milestones (7/14/30/60/100), achievements, personal bests (shown as banner but not shareable).
- **Missing**:
  - **Percentile rank per exercise** ("You're faster than 94% of players" after Reaction Time). The data is already faked for Brain Score — extend it to each exercise.
  - **"Genius level" thresholds** per exercise (sub-200ms reaction time, level 8+ visual memory, etc.) with special animations and share prompts.
  - **Weekly recap card** — "This week: 5 sessions, Brain Score +23, 12-day streak." Scheduled notification + in-app card with share button. WeeklyReport notification exists but has no visual card.
  - **"Top 1% / Top 5% / Top 10%"** badges per exercise that appear on result screens and are shareable.

#### P2 — Brain Score Concept Could Be More Viral
- **Current**: 0-1000 score, brain age (18-65), brain type (4 types), percentile. Good foundation.
- **Missing viral angles**:
  - **Brain Age is the viral number, not Brain Score.** Nobody shares "My brain score is 712." Everyone shares "My brain age is 23." Lead with brain age everywhere — home screen, share cards, notifications.
  - **Comparison to celebrities/archetypes**: "Your brain processes info as fast as an air traffic controller" or "Your memory rivals a chess grandmaster." These one-liners are screenshot-bait.
  - **Age group leaderboards**: "You have the sharpest brain among 25-30 year olds in your area." Even if fabricated initially, this creates competitive sharing.
  - **Brain Age trend line**: "Your brain age dropped from 34 to 28 this month." This is the story users share — improvement over time.

### Quick Viral Wins (< 2 hours each)

1. **Add ShareLink to ReactionTimeView results** — render a share card with average ms and "Can you beat this?" CTA. (1 hour)
2. **Wire TikTokBrainScoreCard to ScoreRevealView** — render it as the share image instead of ShareCardView. (30 min)
3. **Add share button to VisualMemoryView results** — "I reached Level 7 in Visual Memory." (1 hour)
4. **Create a weekly recap share card** — triggered Sunday evening, shareable in-app. (2 hours)
5. **Add "Share" to achievement unlock toast** — when achievement pops up, add a share button that renders AchievementShareCard. (1 hour)

---

## 2. USER EXPERIENCE GAPS

### First-Time User Experience

#### P0 — Onboarding Has the Right Structure but Wrong Focus
- **Current flow**: Welcome → Name → Goals (1-3) → Brain Assessment → Notifications → Privacy → Done.
- **Good**: The assessment during onboarding is smart — it gives users an immediate brain age and creates investment before they even start using the app.
- **Problem**: The assessment is 3 mini-exercises (digit span, reaction time, visual memory) with no warm-up or explanation. A first-time user who has never played these games will score poorly, get a bad brain age, and feel demoralized. This is especially bad because brain age is the first number they see.
- **Fix**: Add a 1-round practice warm-up before each assessment task. "Let's try one practice round first." This is how Lumosity and Elevate do it — they prime users to perform well so the initial score feels good (and improvement is still measurable later).

#### P1 — No Exercise Tutorial/Explanation
- **Problem**: Each exercise has a setup screen with 3 info rows (e.g., "Wait for the green screen, then tap immediately"), but some exercises are confusing without actually seeing them in action. Dual N-Back is notoriously confusing for first-timers. Color Match (Stroop effect) needs a clear "match the INK COLOR, not the word" explanation.
- **Fix**: Add a "How to play" animated demo (3-5 second looping GIF-style SwiftUI animation) on the setup screen of each exercise. Or add a "Practice Round" that doesn't count toward score.

#### P1 — Missing Exercise: Active Recall and Spaced Rep Not in Train Grid
- **Problem**: The Train tab shows 8 games in a grid (Reaction Time, Color Match, Speed Match, Visual Memory, Number Memory, Math Speed, Dual N-Back, Chunking). But Active Recall, Spaced Repetition, Memory Palace, and Prospective Memory are completely absent from the Train grid. They're only accessible via the Home screen recommendations.
- **Fix**: Add a second section to the Train tab: "Memory Techniques" with Active Recall, Spaced Repetition, and Prospective Memory. Or at minimum add them to the existing grid.

### Results Screen Satisfaction

#### P1 — Results Screens Are Functional but Not Emotional
- **Problem**: Exercise results show score, stats, and "Play Again" / "Done" buttons. There's no celebration for good performance. The Reaction Time view shows a rating text ("Lightning Fast!" for sub-200ms) but no animation, no confetti, no special effect. VisualMemoryView presumably similar.
- **Fix**:
  - Add confetti/particles for scores above 80%.
  - Add a "New Personal Best!" celebration with animation (the `isNewPersonalBest` flag exists in ReactionTimeView but only shows a static label).
  - Add a quick sound effect for good/great/perfect scores.
  - Show XP earned on the results screen (currently awarded silently via `ContentView.awardXP`).

#### P2 — No "Compare With Friends" on Results
- **Problem**: After finishing an exercise, there's no social element. Users see their score in isolation.
- **Fix**: Show a leaderboard snippet on results (LeaderboardRankCard exists and IS shown for ReactionTime and BrainAssessment — verify it's on all exercise results). Add "Challenge a Friend" button to results screens.

### Navigation Issues

#### P1 — Home Screen Is Crowded for Returning Users
- **Problem**: HomeView shows greeting, free exercise counter (if free), brain score card, streak calendar, today's session card, daily challenge, XP progress, brain score chart, training limit banner. That's 8-9 cards on one scroll. For a returning user who just wants to train, it's a lot of scrolling to find what to do.
- **Fix**: Reduce home screen to the essentials: (1) Brain Score summary, (2) Streak + daily progress, (3) "Start Training" CTA. Move detailed stats to Insights. Or add a floating "Quick Train" button that opens MixedTrainingView.

#### P2 — Compete Tab (Leaderboard) — Not Verified
- **Problem**: LeaderboardView exists but uses LeaderboardService which generates fake data via inline splitmix64 RNG. This is fine for MVP but users will quickly realize the leaderboard isn't real.
- **Fix**: Add a disclaimer ("Estimated ranking based on global averages") or implement Game Center leaderboards properly (GameCenterService exists and reports scores, but unclear if GKLeaderboard display is integrated).

### Missing Features Users Expect

- **No "how it works" / science section** — Brain training apps live or die by credibility. The education content (PsychoEducationCards about cannabis, social media, sleep) is interesting but not about the training itself. Add a "The Science" section explaining why each exercise works (N-back research, spaced repetition curves, etc.).
- **No session history** — Users can't see what they did yesterday or last week. ProgressDashboardView shows aggregate stats and a heatmap but no per-session breakdown.
- **No exercise-specific progress** — No chart showing "your Reaction Time has improved from 350ms to 250ms over 2 weeks." The data exists in Exercise model but isn't surfaced.

---

## 3. RETENTION HOOKS

### Daily Return Reasons

#### Currently Implemented
- Daily streak system with freeze protection (well-implemented)
- Daily Challenge (same challenge for everyone)
- Daily session recommendations based on focus goals
- Daily exercise limit for free users (creates urgency)
- Streak risk notification at 8 PM
- Comeback notifications after 2+ days away
- Weekly report notification (Sundays)
- Achievement near-unlock nudge notifications
- XP and leveling system (20 levels)

#### P0 — No "What's New Today" Element
- **Problem**: Returning users see the same home screen every day. The Daily Challenge card says "Same challenge for everyone — Compete!" but there's no variety in the home experience itself.
- **Fix**: Add a rotating "Featured Game of the Day" that highlights a different exercise each day. Add a "Today's Tip" card with a rotating strategy tip (StrategyTipService exists but isn't shown on home). Add a "Your brain improved" insight card when scores trend upward.

#### P1 — Streak System is Good but Could Be Stickier
- **Current**: Streak count + 7-day calendar + freeze protection + milestone celebrations.
- **Missing**:
  - **Streak rewards**: No tangible reward for maintaining streaks. Streaks earn freezes every 7 days, but no XP bonus, no special badge visible on profile, no title changes. Add daily XP multiplier that increases with streak (day 1 = 1x, day 7 = 1.5x, day 30 = 2x).
  - **Social streak pressure**: No way to see friends' streaks. Add a "Streak Leaderboard" or "Your friend Alex is on a 14-day streak" push notification.
  - **Streak recovery grace period**: If a user misses a day and has no freezes, their streak goes to 1 instantly. Consider a "streak recovery" IAP or quest ("Complete 3 exercises today to restore your streak").

#### P1 — Notification Strategy Has Gaps
- **Current notifications**: Daily reminder (configurable time), streak risk (8 PM), comeback (after 2+ days), milestone, achievement nudge, weekly report, level up, retake assessment.
- **Good**: Excellent variety. Rate-limiting exists (paywall not shown more than once per 12 hours).
- **Missing**:
  - **Personal best proximity**: "You're 12ms away from your reaction time personal best!" — this is a powerful pull-back notification.
  - **Social proof**: "1,247 people trained today. Join them." (even if fabricated initially).
  - **Time-boxed challenges**: "Flash challenge: Beat 250ms in the next hour for bonus XP."

### Achievement System Assessment

#### Current: 28 achievements across 9 categories
- Streaks (3/7/14/30/60/100 days)
- Exercises (1/10/50/100/250 completed)
- Scores (1/5/10 perfect scores)
- Brain Score (500/700/900)
- Exercise Types (first Spaced Rep, Dual N-Back, Active Recall, Daily Challenge)
- Speed (sub-200ms reaction)
- Social (first share)
- Dedication (early bird, night owl, weekend warrior)
- Mastery (all exercise types, memory master)

#### P1 — Achievements Are Mostly Cumulative, Not Skill-Based
- **Problem**: Most achievements are "do X things Y times." Only `lightningReaction` (sub-200ms) and `brainScore900` are actual skill benchmarks. Users who are already good get nothing to chase.
- **Fix**: Add per-exercise skill achievements:
  - "Memory Vault" — reach Visual Memory level 8
  - "Number Cruncher" — solve 15 math problems in 30 seconds
  - "Focus Master" — complete Dual N-Back at N=4
  - "Speed Demon" — sub-150ms best reaction time
  - "Perfect Week" — 7/7 daily goals completed in a week
  - "Brain Age Under 25" — achieve brain age of 24 or lower

#### P2 — Achievements Don't Show Progress Toward Unlock
- **Problem**: AchievementType has `currentProgress(user:)` and `targetValue` but the Achievements view only shows locked/unlocked state. Users don't know they're 2 exercises away from "Dedicated Learner" (50 exercises).
- **Fix**: Show progress bars on locked achievements: "48/50 exercises completed." This creates goal proximity effect — users will do 2 more exercises just to unlock it.

---

## 4. MONETIZATION OPPORTUNITIES

### Current Monetization
- 3 free exercises per day, unlimited with Pro
- Pro gates: detailed analytics, leaderboard stats, spaced rep categories (words/faces/locations)
- Paywall triggers: daily limit, locked category, after assessment, streak milestones, daily challenge results, progress analytics, brain score history, leaderboard
- Plans: Monthly $3.99, Annual $19.99, Lifetime $14.99 (note: lifetime is CHEAPER than annual — this is likely intentional for conversion but unusual)
- Exit offer on first paywall dismiss
- Paywall rate-limited to once per 12 hours, with 72-hour cooldown after 5+ dismissals

### P0 — Lifetime Price is Lower Than Annual
- **Problem**: Lifetime at $14.99 vs Annual at $19.99 means rational users always pick lifetime. This kills recurring revenue.
- **Fix**: Either raise lifetime to $49.99-$79.99 (standard for brain training apps) or remove it entirely. If keeping lifetime, position it as a limited-time deal: "Usually $79.99, limited offer: $14.99."

### P0 — Free Users Get Too Much Value for Too Little Friction
- **Problem**: 3 exercises per day is generous. All 12 exercise types are available. Brain assessment is unlimited. Free users can train daily, maintain streaks, earn achievements, and see brain scores without ever paying.
- **Fix**:
  - Gate brain assessment retakes (first is free, retake is Pro — this was noted in previous audit).
  - Gate Dual N-Back beyond N=2 (it's the flagship exercise — advanced levels should be Pro).
  - Gate detailed results (show score but not breakdown bars, percentile, or per-round data for free users).
  - Reduce free exercises to 2 per day, or make the 3rd exercise a "bonus" that requires watching an ad (if going freemium + ads route).

### P1 — Paywall Doesn't Show What User is Missing
- **Problem**: PaywallView lists 5 generic benefits ("Unlimited daily training sessions," "All memory categories unlocked," etc.). These are features, not outcomes.
- **Fix**: Show personalized paywall messages based on trigger context:
  - After daily limit: "You've completed 3/3 exercises today. Pro members train as much as they want — and improve 2.7x faster."
  - After assessment: "Your Brain Age is 34. Pro members reduce their brain age by an average of 8 years in 30 days."
  - After streak milestone: "You're on a 7-day streak! Pro members are 3x more likely to reach 30 days."
  - These numbers can be aspirational, not necessarily data-backed (as long as they're reasonable claims).

### P1 — No Urgency or Scarcity
- **Problem**: Paywall is always the same. No time-limited offers, no personalized pricing, no "first month 50% off."
- **Fix**: Add a "New Member Offer" banner for users in their first 72 hours: "50% off your first month — $1.99/mo." Or add a countdown timer on the annual plan: "This price ends in 23:45:12." StoreKit 2 supports introductory offers natively.

### P2 — Lifetime Plan as Anchor
- **Problem**: If keeping the lifetime plan, it should be the MOST expensive option to anchor the annual plan as "best value."
- **Fix**: Show 3 tiers: Monthly $4.99, Annual $24.99 ("Best Value — Save 58%"), Lifetime $79.99. The lifetime plan makes annual look cheap by comparison. This is standard pricing psychology.

---

## 5. POLISH & DELIGHT

### Animations

#### P1 — Exercise Transitions Are Abrupt
- **Problem**: Exercises use enum-based phase switching (`phase = .finished`). The transition between phases is instant — no cross-fade, no slide, no scale animation. Going from the green "TAP NOW!" screen to the round result screen is jarring.
- **Fix**: Wrap phase transitions in `withAnimation(.spring(...))` blocks. Add `.transition(.scale.combined(with: .opacity))` to phase views. The onboarding pages already use smooth TabView animations — exercises should match.

#### P1 — Home Screen Staggered Entrance is Good
- `StaggeredEntrance` modifier exists and is applied to all home screen cards. Each card fades in and slides up with 60ms delay between items. This is polished and should be extended to other screens (Train tab, Insights tab).

#### P2 — Score Counter Animation Exists Only in BrainAssessment
- The Brain Score reveal has a beautiful counting-up animation (`startScoreCounter()` with eased cubic timing). Individual exercise results just show the final number. Add counting animations to exercise result screens for the score display.

### Sound Effects

#### P1 — SoundService Exists but Likely Has No Audio Files
- `SoundService.swift` has methods: `playTap()`, `playCorrect()`, `playWrong()`, `playComplete()`. These are called throughout the app (exercise completions, Brain Assessment reveal, etc.).
- **Verify**: Check if actual audio files (.wav/.mp3) exist in the bundle. If not, these are silent no-ops. Need: short, satisfying chimes for correct/wrong, a celebratory fanfare for exercise completion, a subtle tap sound for UI interactions.

### Dark Mode Consistency

#### P1 — Exercise Game Screens Use Hardcoded Colors
- Reaction Time uses `Color(red: 0.8, green: 0.2, blue: 0.2)` for the waiting screen and `Color.green` for the go screen. These don't adapt to dark/light mode (which is fine for gameplay since they ARE the game).
- ShareCardView uses hardcoded light colors (`Color(red: 0.969, green: 0.961, blue: 0.941)` background). This is intentional — share cards should look consistent regardless of user's theme.
- TikTokShareCard uses hardcoded dark background. Also intentional.
- **Real issue**: `AppColors.textTertiary` is a fixed color (`rgb(0.62, 0.60, 0.58)`) that may have poor contrast on dark backgrounds. Should be an adaptive color from the asset catalog.

#### P2 — No Dark-Mode Share Card Variant
- ShareCardView is always light (cream background). TikTokBrainScoreCard is always dark. Neither adapts to user preference. Consider letting users choose which card style to share, or auto-select based on their theme preference.

### Accessibility

#### P0 — No Dynamic Type Support in Game Tiles
- TrainingTile uses hardcoded font sizes: `.font(.system(size: 12, weight: .bold))` for titles, `.font(.system(size: 9, weight: .medium))` for "Last played" text. At maximum Dynamic Type these will be unreadable.
- Mini previews in tiles use fixed frame sizes (72pt height for preview, 14pt squares in grids). These won't scale.
- **Fix**: Use `@ScaledMetric` for sizes that should scale, or at minimum set `minimumScaleFactor` on text views. Game tiles are small by design, but labels should be readable.

#### P1 — Missing Accessibility Labels on Interactive Elements
- Many exercise views have good `.accessibilityLabel()` on key elements (Brain Score ring, streak count). But game interaction areas (the green tap target in Reaction Time, the grid cells in Visual Memory) lack descriptive labels.
- StreakWeekView has day circles but no individual `.accessibilityLabel("Monday, completed")`.

#### P2 — No Reduced Motion Support
- StaggeredEntrance, confetti, score counter animations, and brain age count-up have no `@Environment(\.accessibilityReduceMotion)` check. Users with motion sensitivity will see all animations.
- **Fix**: Check `accessibilityReduceMotion` and skip animations or use simple fades instead.

### Micro-interactions Missing

- **No pull-to-refresh on Home** — Users expect pull-to-refresh on scrollable screens. Not critical but feels incomplete.
- **No exercise card press state** — TrainingTile has no scale-down animation on press. Add `.scaleEffect(isPressed ? 0.96 : 1.0)` with ButtonStyle.
- **No celebration for daily goal completion** — When user completes their 3rd exercise (hitting daily goal), nothing special happens. Add a "Daily Goal Complete!" toast with confetti.
- **No "undo" on exercise exit** — If a user accidentally taps "Done" before "Play Again," there's no way back. The exercise is saved and dismissed. Consider asking "Save and exit?" or auto-saving on dismiss.

---

## 6. TOP 10 PRIORITIES (by impact)

| # | Item | Category | Impact | Effort |
|---|------|----------|--------|--------|
| 1 | Add share button + TikTok card to exercise results (especially Reaction Time) | Virality | Very High | Medium |
| 2 | Wire TikTokBrainScoreCard as share image in Brain Score reveal | Virality | Very High | Low |
| 3 | Add per-exercise percentile ranking ("Faster than 94% of players") | Virality + Retention | High | Medium |
| 4 | Fix lifetime pricing ($14.99 < annual $19.99) | Monetization | High | Low |
| 5 | Gate brain assessment retakes behind Pro | Monetization | High | Low |
| 6 | Add 1-round practice warm-up to onboarding assessment | UX | High | Medium |
| 7 | Add progress bars to locked achievements | Retention | High | Low |
| 8 | Add share button to achievement unlock toast | Virality | Medium | Low |
| 9 | Add exercise-specific skill achievements (10+) | Retention | Medium | Medium |
| 10 | Add animated transitions between exercise phases | Polish | Medium | Medium |

---

## 7. THE SINGLE MOST IMPACTFUL CHANGE

**Make Reaction Time results shareable with a TikTok-style card.**

Reaction Time is the most viral exercise in any brain training app because:
1. Everyone understands milliseconds — no explanation needed.
2. It is inherently competitive — "215ms, can you beat that?"
3. The number is immediately comparable — lower is better, period.
4. It takes 30 seconds to play — lowest friction to try.
5. The result is a single dramatic number — perfect for screenshots.

Create a `ReactionTimeShareCard` (dark background, massive ms number, "TOP 8% — LIGHTNING FAST" badge, 5-round breakdown dots, "Can you beat me? — Memori" CTA) and add it as a `ShareLink` on the results screen. This one feature could drive more organic installs than every other share trigger combined.
