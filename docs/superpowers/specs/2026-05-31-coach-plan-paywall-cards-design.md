# Coach Plan Paywall Cards Design

## Status

Approved direction from the 2026-05-31 paywall review. Awaiting written-spec review before implementation.

## Goal

Elevate the cute twilight paywall's weakest area: the card fan and the "personalized plan" proof. The screen should feel like Memo made the user a friendly first-week coaching plan, not like a generic subscription feature list.

The top half stays mostly intact: full-screen twilight background, ready seal, headline, Memo Pro access line, and the current research claim:

> Built from research from Stanford, Michigan, and UNC.

## Current Problem

The current center card says `MEMO PLAN` and includes:

- `Brain Training` / `10 games`
- `Focus Guard` / `Whole feed`
- `Trial Reminder` / `Before billing`

That reads as product inventory, not personalization. `Trial Reminder` is especially weak because it is billing reassurance, not something Memo learned about the user. It should move below the CTA where trust copy belongs.

## Design Direction

Use a "friendly coach plan" model.

Memo is not presenting a private psychological report. Memo is saying: "Based on your feed pull, here is how we start." That makes the personalization feel real without overclaiming.

The central card becomes the hero proof object:

- Label: `YOUR FIRST WEEK`
- Header line: `Memo made your first-week plan`
- Rows:
  - `Start point` / `{screenTimeReceiptValue} feed pull`
  - `Day 1` / `Guard your loudest app`
  - `Day 2` / `Train attention before unlocks`
  - `This week` / `Build your comeback streak`

The side cards become loose coach notes behind the hero card, not competing product cards:

- Left note: `Your pull` / `{screenTimeReceiptValue}`
- Right note: `Memo's move` / `Guard + train`

## Visual Layout

This is a composition change inside the existing `PaywallView` playful layout.

Top area:

- Keep the background image `paywall-twilight-hill-bg` full-bleed with the existing bottom dark gradient.
- Keep the top-right close button.
- Keep the white circular ready seal with a mint checkmark.
- Keep headline text: `Your personalized plan is ready`
- Keep subhead text: `Get unlimited access to Memo Pro.`
- Keep research line and university emblem row directly under the subhead.

Hero area:

- Use one central white card, 214 pt wide by about 188-198 pt tall on regular phones and about 188 pt wide by about 166-174 pt tall on compact phones.
- Place Memo mascot above the top edge of the card as a coach-presenting character, centered and overlapping the card. Keep it fully visible.
- Keep two small side cards behind the center card, tilted about -10 degrees and +10 degrees.
- Side cards should feel like sticky notes or clipped coach notes: smaller, quieter, and less "dashboardy" than the main card.
- Do not add a container around the card fan. The card fan should float directly over the illustrated hill.

Pricing area:

- Keep two side-by-side plan cards.
- Annual remains selected by default with the `BEST VALUE` badge.
- Weekly remains visually quieter.
- Lightly reduce the blocky feel by keeping annual white and weekly translucent, but tightening shadows and making the cards feel like purchase choices rather than another content grid.

CTA and footer:

- Keep the large white CTA button.
- CTA text stays `Start Free Trial` for annual and `Start Weekly Access` for weekly.
- Move billing reassurance below CTA:
  - `No payment today. Memo reminds you before billing.`
- Keep the final trust footer:
  - `No ads. No data sold.  Restore`

## Colors

Use existing `AppColors` tokens in app code.

- Background fallback and bottom scrim: `AppColors.pageBgDark`, `#0A0A0F`
- Primary action and selected annual border: `AppColors.accent`, `#4A7FE5`
- Protected/success/check states: `AppColors.mint`, RGB-derived hex `#40AD8C`
- Feed pull signal: `AppColors.coral`, RGB-derived hex `#D96659`
- Best-value badge and low-pressure reminders: `AppColors.amber`, RGB-derived hex `#D9A640`
- Main card fill: white, `#FFFFFF`
- Text on white cards: `AppColors.pageBgDark`, `#0A0A0F`, with opacity for secondary labels
- Footer/trust copy: white at 55-70% opacity

Semantic rule: coral is the problem signal, blue is the Memo action, mint is the protected/winning signal, amber is billing/value context.

Implementation rule: do not introduce new raw `Color` values in SwiftUI for this pass. Use `PW` aliases backed by `AppColors`.

## Icons

Use SF Symbols and the existing Memo mascot asset. Icons should explain mechanics, not become the personality.

- Ready seal: `checkmark`
- Start point/feed pull: `chart.bar.fill`, coral
- Day 1/guard: `lock.fill` or `shield.fill`, accent blue
- Day 2/train: `brain.head.profile`, mint or violet if the existing token is used nearby
- This week/streak: `flame.fill` or `sparkles`, amber
- CTA arrow: `arrow.right`

## Personalization Rules

Use one real personalization anchor. More than one starts to feel fake unless the data is actually present.

Primary anchor:

- If Screen Time permission produced a real value, show `{screenTimeReceiptValue} feed pull`.

Estimate fallback:

- If the value is an estimate, still show the value but keep copy general:
  - `Start point` / `{screenTimeReceiptValue} feed pull`
  - Avoid claiming the exact app or "your loudest app" if the app token is unknown.

App-target fallback:

- If the app has selected shield targets or app tokens available in this paywall context, the Day 1 row can become:
  - `Day 1` / `Guard {topAppName}`
- Only use a real app name/icon if it comes from FamilyControls or stored onboarding state. Do not invent app names.

No-data fallback:

- If neither Screen Time nor app targets are credible, use:
  - `Start point` / `Find your highest-pull app`
  - `Day 1` / `Guard your loudest app`

## Copy

Final intended copy:

- Headline: `Your personalized plan is ready`
- Subhead: `Get unlimited access to Memo Pro.`
- Research: `Built from research from Stanford, Michigan, and UNC.`
- Card label: `YOUR FIRST WEEK`
- Card title: `Memo made your first-week plan`
- Row 1: `Start point` / `{screenTimeReceiptValue} feed pull`
- Row 2: `Day 1` / `Guard your loudest app`
- Row 3: `Day 2` / `Train attention before unlocks`
- Row 4: `This week` / `Build your comeback streak`
- Left note: `Your pull` / `{screenTimeReceiptValue}`
- Right note: `Memo's move` / `Guard + train`
- Annual CTA: `Start Free Trial`
- Weekly CTA: `Start Weekly Access`
- Trial trust: `No payment today. Memo reminds you before billing.`
- Footer: `No ads. No data sold.  Restore`

## Behavior

This pass changes visual composition and copy hierarchy only.

Preserve:

- Annual/weekly plan switching
- Annual trial logic
- Purchase behavior
- Restore purchases
- Exit offer routing
- Hard paywall close behavior
- Analytics calls
- Product loading fallbacks
- Existing `screenTimeReceiptValue` formatting

## Accessibility

- The card fan should be a single combined accessibility element summarizing the first-week plan.
- Decorative side cards can be accessibility-hidden if their contents repeat the main card's core data.
- Do not rely on color alone. Every row needs a text label and value.
- Text must fit on smaller iPhones without truncating important words. Prefer slightly smaller row values over clipping.
- Maintain CTA hit target height near the current large button size.

## Risks and Guardrails

- Do not fake personalization. If data is missing, use "find" or "start with" language.
- Do not turn the card into a tiny dashboard. This is a coach artifact, not analytics.
- Do not add another explanatory strip. The plan card should carry the story.
- Keep the research claim visible, but do not let logos compete with the plan card.
- Keep the mascot separate from the background and fully visible.

## Acceptance Criteria

1. The central hero card no longer includes `Trial Reminder`.
2. The central hero card reads as a first-week Memo coaching plan.
3. At least one real personalization anchor appears in the hero area.
4. Trial/billing reassurance appears below the CTA, not inside the personalization card.
5. The side cards are quieter coach notes and do not compete with the main card.
6. The paywall still supports annual and weekly selection with the same purchase behavior.
7. The preview screenshot shows no clipped headline, row text, pricing text, CTA text, or footer text.
8. Verification follows project rules after code implementation: Xcode preview screenshot, simulator build if needed, and physical device build/install for SwiftUI changes.

## Implementation Notes

Likely file:

- `MindRestore/Views/Paywall/PaywallView.swift`

Likely helper updates:

- Replace the current `mainPlanCard(compact:)` row content with a first-week plan card.
- Replace side `miniPlanCard` content with coach-note content.
- Move the trial reminder into the existing `trialPaymentNotice` area.
- Keep using `PW` token aliases backed by `AppColors`.

No `.xcodeproj` changes or new SPM packages are expected.
