# Blobby — dev notes

Animated cartoon habit tracker (SwiftUI, iPhone). Built from Windows with the playbook in `../WINDOWS-IOS-DEV-SETUP.md`.

- Repo: `futureautomate/ios-blobby` (public) · bundle ID `com.futureautomate.blobby`
- Data: JSON file in the app's Documents folder (App Group path unused, see widget below); profile in UserDefaults
- Tests: `BlobbyTests/HabitLogicTests.swift` (streaks, rest days, pause, levels, old-data decoding)

## Demo launch arguments (CI screenshots)

`-demo sample|empty` · `-open <i>` · `-celebrate` · `-autolog` · `-add` · `-edit` · `-editHabit <i>` · `-confirm <i>` ·
`-settings` · `-history` · `-levelup` · `-recap` · `-month` · `-onboarding` · `-page <n>` · `-toast` · `-share` ·
`-menu <i>` · `-more` · `-night` · `-askName`

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
