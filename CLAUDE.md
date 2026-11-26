# Working in this repo

Two iPad learning games for two children, built from one Xcode project:

- **Shark Explorer** (`apps/shark-explorer`, scheme `SharkExplorer`) for Henry, kindergarten.
- **Cat Math Adventure** (`apps/cat-math`, scheme `CatMathAdventure`) for Kate, first grade.

Shared code lives in `packages/` (learning-engine, persistence, narration, ui-components). Read
[docs/content-guide.md](docs/content-guide.md) before adding content and [docs/roadmap.md](docs/roadmap.md)
for what is done, what is next, and known debt. [docs/architecture.md](docs/architecture.md) is the
history of how the monorepo was split.

## Commands

```sh
xcodegen generate --spec project.yml   # after adding, removing or renaming ANY file (the .xcodeproj is git-ignored)
tools/test.sh fast                     # content checks + unit tests, under two minutes; run before every commit
tools/test.sh slow                     # on-screen walkthroughs, about 30 minutes; run after pushing
node tools/validate-content.mjs        # catalog shape and missing recordings
node tools/generate-audio.mjs --prune --dry-run       # Shark narration: count first, then run without --dry-run
node tools/generate-cat-audio.mjs --prune --dry-run   # Cat narration
tools/deploy-ipads.sh                  # install on the family iPads (needs the one-time setup in the README)
```

`TEST_RUNNER_TOUR_DIR=<folder>` makes the walkthrough tests save a PNG of every screen.

## Rules

- **Workflow:** run the fast tests, then commit and push only when asked; run the slow tests afterwards and
  report the result. Do not hold a push for the slow tests.
- **Layout:** both children use 11-inch iPads in landscape. Check screens on the `iPad (A16)` simulator (the
  default in `tools/test.sh`) and look at the screenshots; a passing test does not prove a layout fits.
- **Everything spoken is a recording.** Narration is looked up by the exact text of the line. Any new or
  reworded child-facing spoken line needs a clip, and the unit tests fail until it has one. Put fixed interface
  lines in the app's `Resources/ui-lines.json`; never build spoken sentences from pieces at run time unless
  every combination is listed for the generator.
- **Swift and JavaScript must agree.** `tools/lib/lines.mjs` re-implements the Swift code that decides which
  lines can be spoken (`MissionChallenges.allSpokenLines`, `SharkReading.mark`, `MathChallengeFactory`,
  the cat story-page rules). Change both together; `testEverySpokenLineHasARecording` catches drift.
- **Reading level is enforced by tests.** Henry's "decodable" lines may only use letters and heart words in
  `shark-reading.json`. Each of Kate's story pages must practise the unit it names from `cat-reading.json`.
  Update those files from the school newsletters, not from guesses.
- **Science:** shark facts must come from a page that was actually fetched (museums, NOAA, aquariums), with the
  URL in `sourceURLs`. Nothing gory or frightening. Photos need a confirmed free licence and credit.
- **Recording costs credits.** Always dry-run and note the character count before generating audio. The
  ElevenLabs key is in the git-ignored `.env`; never print or commit it.
- **Saved progress must keep loading.** Every new field in `SharkProgress` or `CatProgress` needs a default in
  the custom decoder and a test that an older save still decodes. Never rename a shark, cat or activity id.
- **Launch arguments for tests only:** `-unlockAllSharks`, `-missionLevel N` (Shark) and
  `-heartsWithEveryCat N` (Cat). Add new ones the same way rather than special-casing test builds.

## Conventions

- Swift 6, SwiftUI, iOS 17, no third-party dependencies. Views read state from an `@Observable` store in the
  environment (`GameStore`, `CatGameStore`); logic that can be tested without a screen goes in a plain type
  (`MissionChallenges`, `MathChallengeFactory`), with randomness passed in as a generator.
- Shared controls come from `packages/ui-components` (`KidButtonStyle`, `KidTabs`, `AnswerTile`, `KidTopBar`,
  `KidArt`, `ReadAlongView`); touch targets are at least `KidTheme.touchTarget`.
- Content is data: sharks in `catalog.json`, weekly lessons in `*-weeks.json`. Cat friends are still Swift
  literals in `CatContent.swift`, which `tools/lib/lines.mjs` parses with a regular expression, so keep the
  `cat(...)` call shape exactly as it is.
- Pictures are looked up by name with an emoji or drawn fallback (`KidArt`), so art can arrive later. Quiz
  choice ids double as picture names (`choice-<id>.png`).
- Comments say why, in plain words. Child-facing text is short, warm and concrete.
- Commit messages: one summary line naming the app, then what changed for the child and why.

## Gotchas

- A new file that is not picked up, or a recording that "is missing" although it was generated, usually means
  `xcodegen generate` was not run.
- The Grok CLI (`grok --permission-mode auto -p`) generates art but cannot be given permission to copy files in
  a headless run. Ask it only to generate; the images land in
  `~/.grok/sessions/<url-encoded repo path>/<session>/images/`, and you convert them yourself (see the guide).
- `UIImage(named:)` finds a PNG without its extension but needs the extension for a JPEG (`"map-pacific.jpg"`).
- SpriteKit scenes must call `audioEngine.stop()` in `didMove`, or narration stutters.
- A `ReadAlongView` stops narration when it leaves the screen; start the next line slightly later or from the
  next view's own task.
- The full Shark walkthrough plays every mission and takes over 20 minutes. Run a single test with
  `-only-testing:SharkExplorerTourUITests/SharkTourUITests/<test name>` while iterating.
