# Memori App Improvements Audit
> **Date:** 2026-03-09 | **Status:** Backlog — work through in future sessions

---

## HIGH PRIORITY — Retention & Conversion

### 1. ~~App Store Review Prompt~~ ✅ DONE
- ReviewPromptService added — triggers after 10+ exercises, 3+ streak, 90-day cooldown

### 2. ~~Haptic Feedback Throughout App~~ ✅ DONE
- HapticService added with correct/wrong/complete/levelUp/tap/streak methods
- Wired into all 12+ exercise views

### 3. ~~Fix Number Card Persistence (Bug)~~ ✅ DONE
- Added `modelContext.insert(card)` for number cards in SpacedRepetitionView
- Memory Palace exercises also don't save to DB (not in ExerciseType enum properly)

### 4. Deep Linking
- Custom URL scheme for share links (brain score, challenge a friend)
- Notification deep links (tap notification → go directly to exercise)
- Universal links for social sharing
- Currently no deep link handling at all

### 5. ~~Paywall Exit Offer~~ ✅ DONE
- ExitOfferSheet implemented — shows on first paywall dismiss with "Start Free Trial" CTA

### 6. Sound Effects
- `SoundService.swift` exists with methods but needs actual audio assets
- Need: correct/wrong chimes, exercise complete fanfare, achievement unlock, UI taps
- Huge perceived polish boost

---

## MEDIUM PRIORITY — Engagement & Polish

### 7. ~~Streak Milestone Celebrations~~ ✅ DONE
- Full-screen StreakCelebrationView with flame animation, share prompt
- Triggers at 7, 14, 30, 60, 100 day milestones via NotificationCenter
- Streak freeze "about to expire" warning exists (scheduleStreakRisk)

### 8. ~~Comeback / Win-Back Notifications~~ ✅ DONE
- Wired `scheduleComebackNotification()` on app launch in ContentView
- Fires when user hasn't trained in 2+ days with tiered messages

### 9. Loading States & Empty States
- No skeleton loaders or shimmer effects
- Widget shows nothing on first launch
- Brain assessment has no resume if closed mid-session
- ~~Exercise cards don't show "Last played: 2 days ago"~~ ✅ DONE — added to home + train tiles

### 10. First-Time UX & Tutorial Overlays
- New users get no explanation of what each exercise does
- No "Quick Start" path — onboarding asks name, goals, assessment (too much friction)
- OnboardingAssessmentView.swift exists but unclear if integrated
- Strategy tips only shown on results; should appear during exercise intro

### 11. Friend Challenges (Social)
- ChallengeView and DuelView exist but can't actually send challenges
- Need: invite link, push notification to friend, async duel flow
- "1v1 Challenges Coming Soon" is teased in Leaderboard — needs implementation

### 12. Daily Challenge Improvements
- No challenge archive (can't see past challenges)
- No difficulty scaling by user level
- No leaderboard specific to daily challenge

---

## LOWER PRIORITY — Polish & Accessibility

### 13. Accessibility
- Many elements missing `.accessibilityHint()`
- No Dynamic Type support (fixed font sizes in game tiles, mini previews)
- Color-only information in domain bars (no colorblind fallback)
- No reduced motion alternatives for animations

### 14. Dark Mode Polish
- Many hardcoded colors in exercise views (e.g., reaction time red/green)
- `AppColors.textTertiary` may lack contrast in dark mode
- ShareCardView was rewritten for light but dark variant needed

### 15. Lock Screen Widgets (iOS 16+)
- Current widget only shows metrics, no interactive buttons
- No lock screen widget support
- Widget data sync happens on main thread (should be background)
- Cold start shows empty widget

### 16. Analytics & Tracking
- No session analytics (completion rate, avg duration, time to first exercise)
- No funnel metrics (onboarding → assessment → first exercise → paywall → purchase)
- No crash reporting (Crashlytics/Sentry)
- No cohort analysis by install date

### 17. Complete Memory Palace Implementation
- View exists but appears to be a stub
- Not fully integrated with exercise saving flow
- Route exists but not enforced

### 18. ~~Prospective Memory Predictability~~ ✅ DONE
- Trigger positions randomized (was hardcoded at 13-15, now random in 8-28 range)

---

## QUICK WINS (< 30 min each)

- [x] Add `SKStoreReviewController` at streak milestones ✅
- [x] Add haptic feedback to correct/wrong answer handlers ✅
- [x] Add "Last played" label to exercise cards on home screen ✅
- [x] Add privacy policy link in Settings ✅
- [x] Add undo confirmation to "Reset All Data" button ✅
- [x] Fix Prospective Memory trigger randomization ✅
- [x] Add `scheduleAchievementNudge()` call (method exists, never called) ✅
- [x] Move widget data sync off main thread ✅

---

## MONETIZATION IDEAS

- [ ] Pro-gate brain assessment retakes (currently unlimited for free)
- [x] Pro-gate detailed leaderboard stats (done with LeaderboardRankCard) ✅
- [ ] Pro-gate difficulty levels (higher levels = pro only)
- [ ] Weekly "Pro Preview" — unlock one pro feature for 24hrs to tease value
- [ ] Referral program — give 1 week free for each friend who signs up
- [ ] Annual plan discount popup at monthly renewal time

---

## CONTENT GAPS

- [ ] Only 3 cognitive domains tested in assessment (memory, speed, visual) — need attention & flexibility
- [ ] Spaced Repetition pro categories (words, faces, locations) have no content defined
- [ ] No exercise variety within types (e.g., multiple visual memory game modes)
- [ ] No difficulty presets (Easy/Medium/Hard) for casual vs hardcore users

---

## DATA MODEL FIXES

- [ ] Exercise model doesn't persist difficulty level
- [ ] No retry history tracking
- [ ] Dual trial systems (`PaywallTriggerService.isInReverseTrial` vs `User.subscriptionStatus.trial`) — potential inconsistency
- [ ] No local data backup/export feature
