# Adding content

Recipes for the changes that come up most. Each ends with `tools/test.sh fast`.

## How the games reward learning

**Shark Explorer.** Each shark has Discover and Explore pages to read along with, a mission, and three
picture questions. A mission is five or six rounds that alternate numbers and reading, built by
`MissionChallenges` from the shark's own "decodable" sentences:

| Star | Numbers | Reading |
|---|---|---|
| 1 | Count groups of 1–5, find a number 1–10 | Pick the word you hear from three that look different |
| 2 | Count groups of 5–10, more or fewer | One look-alike word, plus heart words |
| 3 | One more, one less, groups that differ by one | Near-neighbour words (big / bit / bug) |
| 4 (super) | Sums to 9, numbers 11–20, one more or less to 20 | The three- or four-word sentence you hear |
| 5 (super) | Sums and take-aways to 10 | The four- to six-word sentence you hear |

The first star needs a finished mission; each later star needs all but one round right on the first tap.
Sharks unlock in three ways, all set in `catalog.json`: `unlockAt` (missions finished), `unlockStars`
(stars across all sharks) and `unlockSuperStars` (fourth and fifth stars across all sharks). The later
rules exist so that new sharks are reached by replaying earlier ones at harder levels.

**Cat Math Adventure.** Each friend has an eight-page story. A page opens silently so Kate reads it herself
(a parent setting narrates it instead); then she hears one of its sentences and finds it among three
(`ReadingQuestion`, no extra recordings). A round is three puzzles; finishing a round opens the next page. Chapter one is pages 1–4 (hearts 0, 3, 6, 9). Chapter two is pages 5–8 and starts at
27 hearts for the ten cats and 12 for the meadow animals (`CatDefinition.chapterTwoStart`). Chapter-two
puzzles use sums to 20, take-aways across ten drawn on two ten-frames ("make a ten"), doubles, odd or even to 16, and counting by twos and fives.
Friends unlock by total hearts (`unlockAt`).

## Add sharks

1. **Write the batch.** A JSON file shaped `{"sharks": [], "expansions": [], "vocabulary": []}` using an
   existing shark (and its expansion) as the model. Per shark: five topics (`home`, `food`, `size`,
   `senses`, `power`) plus `body-clues` and `ocean-care` in the expansion, two traits, a mission
   (`kind` picks the picture that is counted; reuse a kind from `MissionPlay.byKind` when one fits),
   three questions, 2–3 vocabulary ids, `map` (a page id from `maps`) and an unlock rule.
   - Decodable lines: 2–3 sentences of 3–5 words each, only words `SharkReading.mark` accepts. The
     hard mission levels read these sentences aloud, so each shark needs several short ones.
   - Reuse quiz choice ids that already have a picture; list any new ids for the art step.
   - Fetch every source page and keep only confirmed facts.
2. **Photos.** One per shark from Wikimedia Commons into `apps/shark-explorer/Resources/Art/shark-<id>.jpg`:
   landscape, about 1280 px wide, under 400 KB, CC0 / public domain / CC BY / CC BY-SA confirmed through
   the Commons API. Say so in the credit when the photo is a specimen, model or another species.
3. **Merge:** `tools/content/merge-sharks.py batch.json photos.json`. It replaces sharks with the same id,
   lays every map page out again (14 spaces a page) and prints what is still missing.
4. **Wire up the count.** Update the shark count in `ContentStore.validate`, `tools/validate-content.mjs`
   and `ContentStoreTests`; add the sharks to `SharkAppConfiguration.characters` and to the ocean lists
   in `tests/TourUI/SharkTourUITests.swift`. A new mission kind needs a `MissionPlay.byKind` entry and a
   `mission-<name>.png` cut-out.
5. **Art** for new quiz choices (below), **audio** (below), then `xcodegen generate` and the fast tests.

A map page that is full needs a new entry in the catalog's `maps` (id, short name, SF Symbol) and,
ideally, a backdrop `Art/map-<id>.jpg`; without one the page shows the world map. Pages do not have to be
oceans: the same mechanism is meant for future worlds such as prehistoric seas.

## Animals that are not living sharks

The Ancient Seas page holds extinct sharks, armored fish, sea reptiles and an early whale. They use the same
shape as a shark, with these differences:

1. **Kind.** Set `"kind"` to an id from `AnimalKind.all` in `ContentModels.swift` (`fish`, `sea-reptile`,
   `whale`; sharks leave the field out). On-screen text takes its noun from the kind ("Hidden sea reptile").
   A new kind is one more entry there.
2. **Spoken lines.** Five interface lines say "shark"; each has a neutral twin in `ui-lines.json`
   (`lockedAnimal`, `newAnimal`, `allStarsAnimal` and so on) that `SharkLine.about(_:)` picks for a
   non-shark. The animal's own text must never call it a shark.
3. **Pictures.** There are no photos of extinct animals, so the picture is a generated painting, credited as
   an illustration with `imageSourceURL` pointing at the museum page it was checked against. Check each
   painting against that page (tail shape, flippers, neck) before using it.
4. **Topics.** The ids stay `home`, `food`, `size`, `senses`, `power`, `body-clues`, `ocean-care`, but titles
   may change: `ocean-care` becomes "Fossil Clues" (how we know about the animal), and `senses` may become
   "Teeth" or "Armor" when no senses fact can be sourced.
5. **Facts** follow the same rule as sharks (a fetched museum page), and say "scientists think" where the
   source is unsure. The Passport and book titles still say "Shark".

## Add a friend to Cat Math

1. Add an entry to `apps/cat-math/Resources/cat-friends.json`, copying an existing friend: id, name, emoji,
   colour, `locationID`, favourite thing, `unlockAt`, the counting item (singular, plural, emoji), the trick,
   and eight `pages`, each with a title, reading unit id, four sentences and a puzzle lead.
   - The page must contain at least three pattern words and two sight words of its unit
     (`testEveryStoryPagePractisesItsSchoolReadingUnit`). The puzzle lead ends in a comma and must read
     naturally before "Name has 3 items…", "help Name count…" and "how many items did Name find?".
2. Art: `cat-<id>.png` and `cat-<id>-happy.png` (512 px portraits), `count-<item>.png` (256 px cut-out,
   spaces in the item become hyphens), and `backdrop-<location>.png` for a new location.
3. A new location is one more `LearningLocation` in `CatContent.locations`.
4. Update the counts in `cat-catalog.json`, `tools/lib/lines.mjs` (`Expected 15 friends`) and the tests.
   A friend that is not a cat still uses the `cat-<id>` picture names.
5. Audio, `xcodegen generate`, fast tests.

## Weekly classroom lessons

See "Weekly classroom lessons" in the README. When the newsletter names new letters or sight words, also
update `shark-reading.json` (letters, newest letters, heart words) or add a unit to `cat-reading.json`.

## Art

Prompts for every generated picture are recorded in `tools/art-prompts.json`; add yours there.

- **Tiles** (quiz choices, topic icons): square, subject centred on plain cream, saved at 256 px:
  `sips -s format png -Z 256 in.jpg --out Art/choice-<id>.png`.
- **Cut-outs** (mission targets, counting items): painted on flat pure green, then
  `python3 tools/art/chroma-key.py in.jpg Art/mission-<name>.png` keys the green out, crops and pads.
- **Portraits and backdrops:** see the existing entries for wording. Happy poses are edits of the portrait.

With the Grok CLI, write the prompt to a file and run
`grok --permission-mode auto -p "$(cat prompt.txt)"` from the repo root. Tell it to generate and name the
images only; then collect them from `~/.grok/sessions/<url-encoded repo path>/<newest session>/images/`.
Look at every image before using it.

## Audio

```sh
node tools/generate-audio.mjs --prune --dry-run   # how many clips and characters
node tools/generate-audio.mjs --prune             # record them
xcodegen generate --spec project.yml              # so the new clips are bundled
```

Use `generate-cat-audio.mjs` for Cat Math. Recordings cannot be checked automatically for
pronunciation; listen to a sample on the iPad, especially short or unusual words.
