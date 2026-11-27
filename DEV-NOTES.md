# Blobby — dev notes

Animated cartoon habit tracker (SwiftUI, iPhone). Built from Windows with the playbook in `../WINDOWS-IOS-DEV-SETUP.md`.

- Repo: `futureautomate/ios-blobby` (public) · bundle ID `com.futureautomate.blobby`
- Data: JSON file in the app's Documents folder (App Group path unused, see widget below); profile in UserDefaults
- Tests: `BlobbyTests/HabitLogicTests.swift` (streaks, rest days, pause, levels, old-data decoding)

## Demo launch arguments (CI screenshots)

`-demo sample|empty` · `-open <i>` · `-celebrate` · `-autolog` · `-add` · `-edit` · `-editHabit <i>` · `-confirm <i>` ·
`-settings` · `-history` · `-levelup` · `-recap` · `-month` · `-onboarding` · `-page <n>` · `-toast` · `-share` ·
`-menu <i>` · `-more` · `-night` · `-askName`

## Store and website

- Website: https://futureautomate.github.io/ios-blobby/ (`docs/`), privacy: `/privacy.html`, support: `/support.html`
- Store screenshots: Actions → "App Store screenshots" (manual) → `store-screenshots` branch (6.9")
- Pricing decided (2026-11-25): **paid upfront, one-time, every feature included** (like Procreate) —
  no free tier, no in-app purchases, no subscription, no ads. Price around $3.99 (≈ ₹399 tier); a launch price
  ($1.99–2.99 for the first weeks) can be set with an App Store price schedule. Future features (widgets, Watch,
  iCloud) ship to existing buyers for free; raise the price for new buyers as they arrive.
- Listing: "Blobby: Habit Buddies" · "Cute habit tracker & streaks" · Health & Fitness · 4+ · promo codes for reviewers.
- Account: individual Apple Developer account (seller = legal name). Steps in `../APP-STORE-PUBLISHING-INDIA.md`.

## Parked

- **Home-screen widget**: code in `BlobbyWidget/` + `Blobby/Shared/`. Parked because Sideloadly strips App Groups.
  Re-enable with a Mac or the paid account (see the comment in `project.yml`, git history v0.6.1).
- **Apple Health, iCloud sync**: need the paid account.
- **iPad layout**: next after the iPhone version settles.

## Decisions

- No login/accounts. Local "About you" (required nickname + buddy) instead; backup via export/import file.
- Night theme designed separately (indigo sky, plum cards, ink outlines stay dark); share images always light.

## Version log

- v0.1–v0.3 (2026-11-23): characters per habit, cartoon add sheet, cartoon delete, settings reset, app icon.
- v0.4: local reminders (work on free Apple ID), deep link to habit, edit habit, sample habits.
- v0.5–v0.6: levels + accessories, history calendar, sounds, widget attempt (parked: App Groups stripped).
- v0.7–v0.8: rest days, pause/resume, reorder, share cards, weekly recap, onboarding, undo toast, long-press menu.
- v0.8.2 (2026-11-24): cartoon header on habit screen; swipe-back kept.
- v0.9.0: Night theme (Auto/Light/Night) + accessibility (Dynamic Type, VoiceOver, Reduce Motion).
- v0.9.1: theme switch applies instantly (window style).
- v0.9.2–v0.9.3: Reports (week/month, browse back), About you, backup export/import. ✅ Verified on iPhone.
- v0.9.4: privacy manifest, no-encryption flag, privacy/support links in Settings; website + store-screenshot workflow.
- v0.10.5 (2026-11-27): simpler Reports + clearer week share card (%, habit-days, weekday letters, done/missed/not-due legend, mascot no longer covers the date, days before a habit started no longer count) — big % + bar, perfect days, vs last period, top habit; rows show done/due days with weekday letters; month calendar uses 3 shades (all/some/missed) + 'nothing due'.
- v0.10.6: share card leads with wins (% only when ≥60%), best streak line, includes today (done only), "Started <day>" label, footer spacing.
- v0.10.6 (cont.): share-card border drawn as overlay (never clipped); CI moved to macos-26 (Xcode 26, needed for App Store uploads); release.yml added (manual "Release to TestFlight", needs TEAM_ID / ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_P8 secrets). Widget stays parked until the first TestFlight build works.
- v0.10.7: Reports/share card show the user's own buddy next to the overall number (not the top habit, which read as "Read = 25%"); "of all habits done"; week = last 7 days incl. today; today only counts once done (Habit.stats). Website: new report/share copy.
- v0.10.8: report rows — day letters no longer squeezed out (fixedSize + layoutPriority), names stay on one line. Website report/share images refreshed.
- v0.10.9: week share card redesigned — your buddy + one big good number, streak/perfect-day pills, "squad" row of habit characters filled by their week, one 7-day strip for all habits (★ = perfect day). No more dot grid.
