# Dark Reskin + Viral Brain Age Reveal

**Date:** 2026-03-07
**Type:** Strategic reskin — same layout/structure, new visual energy
**Target audience:** 18-25 year olds, TikTok-first virality
**Goal:** Make the Brain Age reveal the viral moment. Make the app look flex-worthy on screen recordings.

---

## 1. Dark Canvas Foundation

### Surfaces
| Surface | Color | Usage |
|---------|-------|-------|
| Page background | `rgb(10, 10, 14)` | All screens |
| Card | `rgb(22, 22, 28)` | `appCard()`, standard cards |
| Elevated card | `rgb(28, 28, 36)` | `heroCard()`, featured content |
| Card border | `white.opacity(0.06)` | 1px border on all cards |

No `Color(.systemBackground)` — all surfaces are explicitly dark. Near-black with slight blue tint, not pure black (too harsh) or system dark gray (too safe).

### Text
| Role | Color |
|------|-------|
| Primary | `white.opacity(0.92)` |
| Secondary | `white.opacity(0.55)` |
| Tertiary/muted | `white.opacity(0.35)` |

Never pure white — it's harsh on dark backgrounds.

### Cards
- Same corner radii (16pt standard, 20pt hero)
- No shadows — border separation does the work on dark
- Border: `white.opacity(0.06)`, 1px

---

## 2. Brain Age Reveal — The Viral Moment

### Flow (full-screen takeover after assessment)
1. Screen goes full black
2. "Your Brain Age" fades in — small, `white.opacity(0.5)`
3. **Number counts up from 18** — 96pt `.rounded .black`
   - Color shifts: green `#00D19E` → amber `#FFC247` → coral `#FA6B59` as number climbs
   - Takes ~3 seconds (fast enough to not bore, slow enough to build dread)
4. Number lands — holds for a beat, subtle pulse glow behind it
5. Snarky subtitle slides in: "You have the brain of a 63-year-old"
6. Percentile bar fades in: "Sharper than 23% of people your age"
7. **"Share Your Brain Age"** — gradient pill CTA, prominent
8. "Start Training" below — secondary action

### Sound (respects sound toggle)
- Tick/click on each number increment
- Low thud when number lands

### Share Card (static image, 1080x1920)
- Background: `rgb(14, 14, 18)`
- Brain Age number: 120pt, centered, colored by score (green→red)
- User's name + avatar emoji above
- "Sharper than X% of 20-year-olds" — personalized to age group
- Faint neural network dot/line pattern at `white.opacity(0.03)`
- Bottom: "Memori" wordmark + "Train your brain" tagline, small
- Designed for TikTok screenshots + IG stories

---

## 3. Typography

| Element | Size | Weight | Notes |
|---------|------|--------|-------|
| Hero scores (brain age, brain score) | 72-96pt | `.rounded .black` | The centerpiece |
| Stat numbers (streak, XP, session scores) | 32-40pt | `.rounded .bold` | Bold and clear |
| Section headers | 20pt | `.semibold` | `white.opacity(0.55)` — understated |
| Body/labels | 15pt | `.medium` | `white.opacity(0.55)` |

**Rule:** Numbers are the art. Labels are quiet.

---

## 4. Color on Dark

### Domain colors (unchanged values, new treatment)
- Exercise cards: subtle colored gradient at top edge OR soft radial glow behind icon
- Active/selected states: domain color at `opacity(0.12)` as card fill
- Streak/XP/level badges: amber/coral accents

### Brain Score Ring
- Thicker stroke on dark (12pt)
- Soft outer glow in the score color — should feel like it's emitting light

### Brain Age Color Spectrum
| Range | Color | Meaning |
|-------|-------|---------|
| 18-25 | Green `#00D19E` | Sharp |
| 26-40 | Sky `#3F9CFA` | Average |
| 41-55 | Amber `#FFC247` | Declining |
| 56+ | Coral `#FA6B59` | Needs work |

---

## 5. What Changes vs. What Stays

### Changes (reskin)
- All surface colors → dark palette
- All text colors → white opacity variants
- Card modifiers (appCard, glowingCard, heroCard) → dark fills + white borders
- Typography scale → bigger numbers, quieter labels
- Brain Score ring → thicker, glowing
- Brain Age reveal → new full-screen dramatic flow
- Share card → new dark design with viral optimization
- Exercise card accent treatment → colored glow/accent line on dark

### Stays the same
- Screen layout and navigation structure
- Tab bar and navigation patterns
- Exercise gameplay views
- Data models and services
- All existing functionality
