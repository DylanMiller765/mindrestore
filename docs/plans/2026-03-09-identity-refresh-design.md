# Memori Identity Refresh — Design Document

## Brand Positioning

**Old:** "Memori is a brain training app. Every design decision should reinforce cognitive training, mental sharpness, and neural growth."

**New:** "Memori is a competitive memory game. It should feel like a place you go to prove you're sharp — and prove it to your friends. The science is real, but the experience is a game, not a prescription."

**Reference blend:**
- Monkeytype's dark, stats-forward, no-bullshit aesthetic
- NYT Games' clean simplicity where the game is the star
- Duolingo's warmth in the moments that matter (streaks, celebrations, onboarding)

---

## Color System

### Monochrome Base
| Token | Value | Usage |
|-------|-------|-------|
| `background` | `#0A0A0F` | App background, near-black void |
| `surface` | `#14141F` | Cards, sheets, elevated surfaces |
| `cardBorder` | `#1E1E2E` | Subtle card/component borders |
| `textPrimary` | `#F0F0F0` | Primary text (not pure white) |
| `textSecondary` | `#6B6B80` | Labels, captions, muted text |

### Accent
| Token | Value | Usage |
|-------|-------|-------|
| `accent` | `#00D4FF` | Primary action, scores, highlights |
| `accentMuted` | `#00D4FF` at 15% | Accent backgrounds, selected states |

### Per-Game Colors (secondary, tiles/results only)
Existing game colors (coral, violet, sky, teal, indigo, amber) stay but are demoted — they live on game tile icons and results screens only, never compete with the accent.

### Kill List
- `.ultraThinMaterial` glassmorphism — replaced with solid `surface` fills
- Colored glowing shadows — gone
- Premium purple gradient — simple accent treatment
- Warm gradient (orange/coral) — gone
- `neuralGradient` — gone

---

## Typography

### Font Strategy
- **SF Pro** (system) — navigation, labels, descriptions, buttons, body text
- **SF Mono** (monospace) — scores, ranks, timers, percentages, streaks, XP, any competitive number

### Weight Changes
- Drop `.rounded` weight entirely
- Drop `.black` weight — use `.bold` max
- Headlines use `.semibold` or `.bold` — confident, not shouty

### Hierarchy
| Element | Size | Font | Weight |
|---------|------|------|--------|
| Hero score | 48pt | SF Mono | Bold |
| Section header | 15pt | SF Pro | Semibold, ALL CAPS, tracked |
| Body | 15pt | SF Pro | Regular |
| Stats/numbers | 15pt | SF Mono | Semibold |
| Caption | 13pt | SF Mono | Regular |

### Pattern
```
YOUR RANK                    ← 11pt caps, tracked, textSecondary, SF Pro
#4                          ← 32pt mono bold, accent
Brain Score  847             ← label SF Pro, number SF Mono
Streak       12d             ← same
```

---

## Cards & Components

### Cards
- Background: `surface` solid fill (no blur, no material)
- Border: 1px `cardBorder`
- Corner radius: 12pt (down from 20pt)
- No shadows, no glows

### Buttons
- **Primary:** Solid accent fill, black text, 10pt radius, no gradient
- **Secondary:** Transparent, 1px accent border, accent text
- **Cancel/destructive:** Text only, no container

### Game Tiles (Train tab)
- Solid dark card
- Game color shows only on the icon circle
- Name in white, subtitle in textSecondary
- No colored tile backgrounds

### Leaderboard Rows
- Clean horizontal rows, rank in mono, thin dividers
- Current user row: accent at 8% opacity background
- Top 3: gold/silver/bronze medal colors (universal)

### Results Screens
- Stats in clean grid/list, all mono numbers
- Big score front and center
- Minimal celebration — the number IS the reward
- Confetti only on personal best

### Toasts
- Slide from top, solid dark surface, accent left-border stripe
- Fast dismiss

---

## Logo & App Icon

### Lettermark "M"
- Custom geometric M from clean angular lines
- Subtle synapse nod: two peaks connected by a small node/dot
- Flat accent cyan `#00D4FF` on `#0A0A0F`
- No gradients, no glow, no effects

### App Icon
- M lettermark centered on `#0A0A0F` background
- Standard iOS rounded square
- Optional: very subtle grid pattern at ~3% opacity in background

### Wordmark
- "memori" lowercase, clean sans-serif, medium weight
- The "i" dot replaced with small accent cyan circle
- Used on splash, onboarding, marketing — alongside M mark

### Killed
- Neon glowing brain icon
- All literal brain imagery in brand identity
- Neural pathway / neuroscience visual language

---

## What We're Changing (Summary)

| Before | After |
|--------|-------|
| Glassmorphism cards | Solid dark surfaces |
| 20pt corner radius | 12pt corner radius |
| Electric blue accent | Electric cyan `#00D4FF` |
| Rounded bold/black type | Clean semibold + monospace numbers |
| Colored glowing shadows | No shadows |
| Gradient buttons | Solid flat buttons |
| Neon brain logo | Geometric M lettermark |
| "Brain training app" | "Competitive memory game" |
| Wellness/clinical tone | Stats-forward, competitive tone |
