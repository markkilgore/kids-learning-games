# Roadmap

Where the two games are, what is likely next, and the debt worth knowing about. Update this file when a
piece of work lands or a decision is made.

## Where things are (November 2026)

**Shark Explorer (Henry, kindergarten)**
- 35 sharks on four swipeable map pages: Pacific, Atlantic, Indian, Cold Seas.
- Missions are number and reading rounds at five levels (three stars, then two super stars).
- Sharks 21–30 unlock by total stars; sharks 31–35 unlock by super stars.
- Read-along Discover and Explore pages with sound-it-out sentences limited to the letters taught so far.
- Shark Passport, Ocean Words, weekly classroom lessons, parent progress screen.

**Cat Math Adventure (Kate, first grade)**
- 15 friends in three places: House and Garden (ten cats) and Meadow (puppy, bunny, duckling, hedgehog, pony).
- Eight-page stories written around her school reading units; chapter two brings sums and differences
  to 20, doubles and counting by twos.
- Friend Journal, celebration rewards, weekly classroom lessons, parent progress screen.

## History

| When | What |
|---|---|
| Earlier | One Shark app split into a two-app monorepo with shared packages (see architecture.md). |
| Nov 2026 | Polish pass on both apps: shared design system, recorded narration, sound effects, drawn art. |
| Nov 2026 | Reading units for Kate, sound-it-out sentences for Henry, weekly lessons from the newsletters. |
| Nov 24 | Sharks 11–20. |
| Nov 25 | Missions became number and reading rounds with stars. Sharks 21–30, star unlocks. Meadow animals and chapter two for Kate. `tools/test.sh`. |
| Nov 25 | Map pages by ocean, sharks 31–35, super-star levels with sums and sentence reading. |
| Nov 25 | Clean-up: Cat Math friends moved to `cat-friends.json`, Shark code made animal-neutral, mission intros for sharks 1–20 rewritten for the counting-and-reading game, repo guides added. |
| Nov 26 | Kate: story pages open silently for her to read, a hear-and-find sentence question after each page, and make-a-ten subtraction on ten-frames. |

## Next steps

Henry finishes new sharks within a day or two, so content alone does not last. Prefer changes that
make each visit richer over simply adding more animals.

1. **More to do per shark.** Ideas: a second mission type per shark (sorting, patterns, measuring
   "longer or shorter than"), a reading challenge that builds a sentence from word tiles, a "teach it
   back" quiz that mixes facts from several sharks on one map page.
2. **Keep the reading level current.** `shark-reading.json` holds the letters taught to mid-November;
   digraphs and more heart words are coming at school. The heart-word list is an estimate until checked
   against Henry's passages.
3. **New worlds as map pages.** The map already supports pages that are not oceans. Planned, in rough
   order: whales and other sea mammals, prehistoric ocean animals (megalodon, ichthyosaurs, mosasaurs),
   then dinosaurs and ice-age megafauna. Each needs the animal schema loosened first (see debt).
4. **Kate:** weekly lessons stop at Nov 9–15 in both games (Nov 16–22 was l blends and make-a-ten). Watch
   whether chapter-two math is the right level; next units are place value (tens and
   ones), time to the hour and comparing numbers. New reading units as the newsletters arrive.
5. **Listen through the recordings** on a device. Nothing recorded since mid-November has been checked
   by ear.

## Open questions

- Should the star-locked sharks be easier to reach? Thresholds are in `catalog.json`.
- Four shark photos are models or specimens (megamouth, frilled, spinner, dwarf lanternshark), the salmon
  shark photo is black and white, and the porbeagle is a specimen. Replace when better free photos exist.

## Known debt

- **Shark wording that is recorded.** The code is animal-neutral (`AnimalDefinition`, `AnimalKind`) and
  on-screen text follows the animal's kind, but five spoken interface lines, the app name, "Shark Passport"
  and the saved-progress field `completedSharks` still say shark. The content guide lists what to do when
  the first non-shark is added.
- **Cat-only naming.** `CatDefinition`, `cat-<id>.png` and `CatContent.cats` now also hold a puppy and a
  pony. Harmless, but rename before adding much more.
- **Swift logic is ported by hand to JavaScript** for the audio generator. A small Swift command that
  prints every spoken line would replace both ports.
- **Counts are hard-coded in several places** (35 sharks, 15 friends): validators, tests, the tour test's
  ocean lists. The content guide lists them.
- `CatActivityView.swift` (650 lines) and `CatContent.swift` (900 lines) are the largest files and the
  hardest to change safely.
- The original map coordinates and `ocean-map.png` remain only as the fallback backdrop.
- `origin/agent/fix-shark-quiz-flow` has one commit that never reached `main` ("fix shark quiz choice
  ordering and duplicates"); check whether it is still wanted, then delete the branch. Two old agent
  worktrees remain under `.claude/worktrees/`.
