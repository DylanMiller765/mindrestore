# Memori Design System & Direction

## Brand Identity
**Memori** is a brain training app. Not a fitness app, not a meditation app. Every design decision should reinforce *cognitive training, mental sharpness, and neural growth*.

## Color Palette (2026 — v2)

### Primary
- **Accent (Electric Blue):** `rgb(56, 133, 245)` — cognitive, neural, trustworthy
- **Accent Gradient:** Electric Blue → Indigo — feels like neural pathways firing

### Secondary Palette
| Name    | Hex       | Use Case                         |
|---------|-----------|----------------------------------|
| Teal    | `#00BAB0` | Memory domain, success states    |
| Indigo  | `#5957D6` | Premium, techniques, depth       |
| Coral   | `#FA6B59` | Speed domain, urgency, alerts    |
| Violet  | `#9457EB` | Premium gradient, achievements   |
| Sky     | `#3F9CFA` | Attention domain, info           |
| Amber   | `#FFC247` | Streaks, rewards, warmth         |
| Rose    | `#EB4D8C` | Social, challenges               |
| Mint    | `#00D19E` | Success, completion              |

### Cognitive Domain Colors (used on exercise cards, radar charts)
- **Memory:** Violet `#9457EB`
- **Speed:** Coral/Orange `#FA6B59`
- **Attention:** Sky Blue `#3F9CFA`
- **Flexibility:** Teal `#00BAB0`
- **Problem Solving:** Amber `#FFC247`

## Design Inspiration (2026)

### Primary Reference: **Elevate** (dark/premium direction)
- Dark backgrounds with glassmorphism cards (`.ultraThinMaterial`)
- Large corner radii (20-24pt)
- Cream/warm white text on dark surfaces
- Staggered entrance animations
- Editorial typography hierarchy

### Secondary Reference: **Lumosity** (warm/inviting elements)
- Curated daily sessions ("Today's Workout")
- Playful but purposeful illustrations
- Orange `#FA6432` + Teal `#0E91A1` accent pairing
- Pill-shaped gradient CTAs

### Secondary Reference: **Peak** (gamification + credibility)
- Named workout modes (Quick Session, Full Workout, Weakest Link)
- Coach persona with motivational messaging
- Science-backed credibility signals
- Electric blue primary

## Layout Patterns

### Home Screen
1. **Personalized greeting** with time-of-day awareness
2. **Brain Score ring** — large circular visualization, not a flat number
3. **Today's Session** — curated 3-5 exercises, one-tap start
4. **Streak calendar** — horizontal week view with filled/empty dots
5. **Quick stats** — XP, level, days trained

### Training View
- **2-column grid** of exercise tiles (game-menu feel)
- Featured exercise as full-width hero card
- Each tile shows: icon, name, current level/progress
- Color-coded by cognitive domain

### Exercise Cards
- Vertical tiles with centered icon in colored circle
- Gradient accent on active/selected states
- Level badge overlay showing user's current level
- NOT a flat list of rows

## Typography
- **Display:** `.system(.rounded)` weight `.bold` / `.black` for scores and headlines
- **Body:** System default
- **Monospaced:** `.monospacedDigit()` for scores, timers, stats
- Size hierarchy: 52pt (hero scores) → 28pt (section titles) → 17pt (body) → 13pt (captions)

## Components

### Cards
- `appCard()` — `.ultraThinMaterial` background, 20pt corner radius, subtle shadow
- `glowingCard(color:)` — adds colored shadow + 1pt stroke in domain color
- No flat colored backgrounds; always use material + color accent

### Buttons
- Primary: Gradient fill (accent gradient), 16pt corner radius, white text
- Secondary: Material background with colored text
- Pill shape for CTAs in marketing/paywall contexts

### Icons
- SF Symbols throughout
- Cognitive domain icons: `brain.head.profile` (memory), `bolt.fill` (speed), `eye.fill` (attention), `arrow.triangle.branch` (flexibility), `puzzlepiece.fill` (problem solving)

## Animation
- Page transitions: `.easeOut(duration: 0.3)` with stagger delays
- Score counters: cubic ease-out over 2s
- Progress rings: `.spring(response: 0.6, dampingFraction: 0.8)`
- Card appearances: `.move(edge: .bottom).combined(with: .opacity)`

## What NOT To Do
- No literal brain renders/illustrations on main UI
- No fitness-app green
- No flat list-of-rows for exercises
- No fake reviews or social proof
- No generic "system grouped background" without personality
- No purple-gradient-on-white (AI slop aesthetic)

---

## Known Exercise Issues (Audit — March 2026)

### Critical
1. **Dual N-Back levels 2-5 locked in trial** — Fixed: now checks `paywallTrigger.isInReverseTrial`
2. **Categories have zero pro gating** — Free users can access all pro categories in SpacedRepetitionView
3. **Mixed Training saves as `.spacedRepetition`** — Should be its own type or `.activeRecall`

### High Priority
4. **ActiveRecallView timer not cleaned up on dismiss** — memory leak
5. **Number cards in SpacedRepetition not persisted** — defeats the purpose of spaced repetition

### Medium Priority
6. **Memory Palace routes not enforced** — users can skip learning phase
7. **Prospective Memory triggers at predictable positions** — should be randomized
8. **Chunking Training doesn't measure benefit** — no with/without hint comparison
9. **Memory Palace not in ExerciseType enum** — exercises never saved to DB
