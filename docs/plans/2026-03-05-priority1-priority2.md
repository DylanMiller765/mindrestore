# Priority 1 & 2: Retention + Leaderboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add XP/leveling, achievements, brain score history, smart notifications, and leaderboard system to drive retention and virality.

**Architecture:** Extend existing SwiftData models with new Achievement and LeaderboardEntry models. Add XP/level tracking to User model. New LeaderboardView tab. Achievement toast overlay system. All leaderboard data simulated locally (CloudKit-ready architecture).

**Tech Stack:** SwiftUI, SwiftData, Swift Charts, UserNotifications

---

### Task 1: XP & Level System — Model Layer
**Files:**
- Modify: `MindRestore/Models/User.swift` (add XP, level, username fields)
- Modify: `MindRestore/Models/Enums.swift` (add UserLevel enum)

### Task 2: Achievement System — Model & Data
**Files:**
- Create: `MindRestore/Models/Achievement.swift` (Achievement @Model + AchievementType enum)

### Task 3: Leaderboard — Model & Service
**Files:**
- Create: `MindRestore/Models/LeaderboardEntry.swift` (@Model for entries)
- Create: `MindRestore/Services/LeaderboardService.swift` (simulated data + local ranking)

### Task 4: Achievement Tracking Service
**Files:**
- Create: `MindRestore/Services/AchievementService.swift` (check & unlock logic)

### Task 5: XP Earning Integration
**Files:**
- Modify: `MindRestore/Views/DailyChallenge/DailyChallengeView.swift` (award XP on complete)
- Modify: `MindRestore/Views/Exercises/SpacedRepetitionView.swift` (award XP)
- Modify: `MindRestore/ContentView.swift` (TrainingView exercises award XP)
- Modify: `MindRestore/Views/Assessment/BrainAssessmentView.swift` (award XP)

### Task 6: Achievement Toast Overlay
**Files:**
- Create: `MindRestore/Views/Components/AchievementToast.swift`
- Modify: `MindRestore/ContentView.swift` (overlay on main tab view)

### Task 7: Brain Score History Chart
**Files:**
- Modify: `MindRestore/Views/Progress/ProgressDashboardView.swift` (add history chart)

### Task 8: Achievements View
**Files:**
- Create: `MindRestore/Views/Achievements/AchievementsView.swift`

### Task 9: Leaderboard View
**Files:**
- Create: `MindRestore/Views/Leaderboard/LeaderboardView.swift`

### Task 10: Home View Integration
**Files:**
- Modify: `MindRestore/Views/Home/HomeView.swift` (XP bar, level badge, achievement previews)

### Task 11: Navigation & Tab Updates
**Files:**
- Modify: `MindRestore/ContentView.swift` (add Leaderboard tab)
- Modify: `MindRestore/MindRestoreApp.swift` (register new models)

### Task 12: Smart Notifications
**Files:**
- Modify: `MindRestore/Services/NotificationService.swift` (varied copy, comeback, achievement nudges)

### Task 13: Shareable Cards
**Files:**
- Create: `MindRestore/Views/Components/ShareableCard.swift` (level-up, achievement, profile cards)
