# Inkling Project Guide

Daily writing practice from Jack's mom's idea (2026-07-22): each day offers three choices, each a writing prompt
paired with a public-domain artwork; write in the app or mark the day written elsewhere; a calendar checks the
days written and counts the streak. XcodeGen project/scheme: `Inkling`, sim lease owner `writing`.

## Tech Stack
- Swift 6 / SwiftUI (strict concurrency), iOS 18+, iPhone and iPad
- XcodeGen (`project.yml`). Targets: `Inkling`, `InklingWidget` (WidgetKit, no App Group), `InklingTests`, `InklingUITests`
- RevenueCat entitlement `pro`; `Inkling.storekit` for StoreKit Testing
- No backend, no account. Writing is a JSON file in Application Support.

## IDs
- Bundle `com.jackwallner.writing` (widget `com.jackwallner.writing.widget`); App Store ID `6837382731`; ASC name "Inkling: Daily Writing Prompts"
- Products `com.jackwallner.writing.{monthly,yearly,lifetime}` ($1.99 / $14.99 with 1-week trials, $29.99 once),
  Vitals PPP tiers. RevenueCat project `proj9f276127`, app `appa9dae56733`, offering `default`.

## Architecture
- `Shared/Models/Prompt.swift`: `Prompt`, `PromptLibrary` (day N since 2026-01-01 gets prompts 3N..3N+2, wrapping)
- `Shared/Models/JournalEntry.swift`: an entry (text, or `elsewhere` for paper writing) and `Streak` math
- `Shared/Models/Days.swift`: day keys `yyyy-MM-dd` in the current time zone
- `Shared/Services/Journal.swift`: entries on disk; `SubscriptionService.swift` (Ravel's, adapted); `Reminder.swift`; `ReviewPrompt.swift`
- `Shared/Art/Art.swift`: `Art` (off-main decode and cache, also from the widget via `Bundle.app`) and `Palette`
  (nine colors sampled from an artwork; `room(dark:)` is what lights Today)
- `Shared/Services/Muse.swift`: one follow-up question from the on-device model (FoundationModels, iOS 26+,
  hidden when the model is unavailable)
- `Inkling/Views`: `TodayView` (paged gallery of three `Plate`s over `RoomBackdrop`, a mesh gradient of the
  painting's colors; `WeekBar`) -> `PromptView` (stretchy painting header, editor, floating bar: count, timer,
  Go Deeper, share) -> `ArtViewer` (pinch zoom); `JournalView` (streak numeral, `MonthWall` of painting tiles)
  -> `DayView` (that day's writing, three `Poster`s); `SettingsView`; `PaywallView` (`ArtMarquee`);
  `ShareCard` (a page as a 1080x1350 picture); `Book` (PDF of everything written)
- `InklingWidget`: today's painting and prompt (small, medium, large, Lock Screen); the three options take the
  morning, afternoon and evening; a tap opens `inkling://prompt/<id>`. It reads art and prompts from the app's
  bundle, so it needs no App Group.
- `Inkling/prompts.json` + `Inkling/Art/*.heic` (folder reference): the bundled library, built by `tools/`

## Rules that hold everywhere
- Free: today's prompts, writing, calendar, streak, reminder, timer, share card, widget, Go Deeper. Pro: earlier
  days' prompts, Export Book (PDF) and Export Text.
- Today follows the system appearance: `Palette.room` is a pale wash by day and deep at night, and
  `PaletteTests` holds both readable. Never put text on raw artwork colors.
- Writing on any day's prompt counts for the day it is written, so the calendar never backfills a streak.
- A prompt never repeats an artwork within a day; `testBundledLibraryCoversAYearWithArt` guards a year of art.
- Copy: no em dashes, no helper text or taglines.

## Prompt library (tools/)
Art is CC0 from the Art Institute of Chicago API (no attribution required; the credit shows under each image).
1. `tools/harvest_art.py` -> `catalog/candidates/candidates.json`
2. `tools/fetch_art.py` downloads 843 px images and 512 px previews (`catalog/raw/`, gitignored)
3. `tools/write_prompts.py` runs `claude -p` per batch to look at each image, drop unsuitable ones and write
   its prompt (`catalog/review/batch-*.json`, committed)
4. `tools/build_catalog.py` deals three a day across art kinds and prompt forms, writes `Inkling/prompts.json`
   and HEIC art. macOS only (sips). Pollinations (DreamCart's art path) was rejected: free tier is 1 image per
   45 s per IP and watermarks every image.

## App-specific notes
- Ratings ask: positive moment = leaving a prompt after its first counting save; asked back on Today.
- Launch args (DEBUG): `-UITesting` (in-memory journal), `-SeedDemo` (a month of writing), `-Pro`, `-MockProducts`, `-MockMuse` (a canned Go Deeper answer; the simulator has no model).

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, ratings ask, gotchas):
the global agent rules + the `ios-dev` skill.
