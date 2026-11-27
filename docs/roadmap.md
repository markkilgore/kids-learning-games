# Roadmap

Where the two games are, what is likely next, and the debt worth knowing about. Update this file when a
piece of work lands or a decision is made.

## Where things are (November 2026)

**Shark Explorer (Henry, kindergarten)**
- 53 animals on five swipeable map pages: 43 living sharks (Pacific, Atlantic, Indian, Cold Seas) and ten
  prehistoric animals on Ancient Seas (megalodon and two other extinct sharks, two ancient fish, four sea
  reptiles and an early whale), with painted pictures instead of photos.
- Missions are number and reading rounds at five levels (three stars, then two super stars).
- Sharks 21–30 unlock by total stars; sharks 31–35 unlock by super stars. On Ancient Seas three animals open
  once 35 missions are done, four more one per mission, and the last three at 18, 22 and 26 super stars.
  Sharks 36–43 open the same way: two at 35 missions, then one per mission up to 41.
- Read-along Discover and Explore pages with sound-it-out sentences limited to the letters taught so far.
- Animal Passport (pages grouped as sharks, whales, sea reptiles and other animals), Ocean Words, weekly classroom lessons, parent progress screen.

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
| Nov 26 | Henry had found all 35 sharks: Ancient Seas page with ten prehistoric animals, animal kinds beyond sharks, ammonite counting mission. |
| Nov 27 | Eight more living sharks (horn, whitetip reef, spiny dogfish, sevengill, silky, puffadder shyshark, kitefin, pocket), opening one per finished mission after the first 35. Animal Passport grouped by kind. |
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
3. **More worlds as map pages.** Ancient Seas is the first page that is not an ocean. Next in rough order:
   whales and other sea mammals, more prehistoric sea animals (Livyatan, Liopleurodon, Xiphactinus, giant sea
   scorpions), then dinosaurs and ice-age animals. The content guide says what a non-shark needs.
4. **Kate:** weekly lessons stop at Nov 9–15 in both games (Nov 16–22 was l blends and make-a-ten). Watch
   whether chapter-two math is the right level; next units are place value (tens and
   ones), time to the hour and comparing numbers. New reading units as the newsletters arrive.
5. **Work through `docs/review.md`**: recordings nobody has heard, pictures and facts nobody has checked.

## Open questions

- Should the star-locked sharks be easier to reach? Thresholds are in `catalog.json`.
- Pictures, recordings and facts still waiting for a person are listed in `docs/review.md`.

## Known debt

- **Shark wording that remains.** Non-sharks get neutral spoken lines and the book is the "Animal
  Passport", but the app name, the `shark-<id>.jpg` picture names and the saved-progress field `completedSharks` still
  say shark.
- **Cat-only naming.** `CatDefinition`, `cat-<id>.png` and `CatContent.cats` now also hold a puppy and a
  pony. Harmless, but rename before adding much more.
- **Swift logic is ported by hand to JavaScript** for the audio generator. A small Swift command that
  prints every spoken line would replace both ports.
- **Counts are hard-coded in several places** (53 animals, 15 friends): validators, tests, the tour test's
  ocean lists. The content guide lists them.
- `CatActivityView.swift` (650 lines) and `CatContent.swift` (900 lines) are the largest files and the
  hardest to change safely.
- The original map coordinates and `ocean-map.png` remain only as the fallback backdrop.
- `origin/agent/fix-shark-quiz-flow` has one commit that never reached `main` ("fix shark quiz choice
  ordering and duplicates"); check whether it is still wanted, then delete the branch. Two old agent
  worktrees remain under `.claude/worktrees/`.
