# Brief for writing new animals

Hand this to a helper (a sub-agent or another session) together with the list of animals: for each one the id,
name, scientific name, map page, unlock rule and the hook that makes it different from animals already in the
game. Four animals per helper works well; two helpers can run side by side. Check the list against
`catalog.json` first so nothing is a near-duplicate.

The helper is writing for a kindergarten reader (age 5-6). It should read `docs/content-guide.md` ("How the
games reward learning", "Add sharks") and, in `catalog.json`, the sharks "bamboo" and "pyjama" with their
entries in "expansions" as the model for shape, length and tone. It must not edit the repo; it writes only into
its own output folder outside the repo.

Afterwards, whoever merges should: read every line, look at every photo, combine the batches into one
`batch.json` and one `photos.json`, copy the photos to `Art/shark-<id>.jpg`, and follow "Add sharks" from step 3.
For animals that are not living sharks, add the points from "Animals that are not living sharks" to the brief
(a `kind`, a painted picture instead of a photo, "Fossil Clues" in place of "Ocean Care").

## Deliverables in your output folder
1. batch.json: {"sharks": [...], "expansions": [...], "vocabulary": [...]} in the catalog's exact shape.
   - Per shark: id (given), name, scientificName, symbol, image fields (set imageAsset to "shark-<id>.jpg", others "TBD"),
     color, region, "map" and "unlockAt" (given), discover, five topics with ids home, food, size, senses, power, two traits,
     mission, three questions, 2-3 vocabularyIDs, bookFact, sourceURLs. No mapX/mapY needed. No "kind" field.
   - Expansion per shark with topics body-clues and ocean-care.
   - Every narration has "decodable", "earlyReader" and "story". Decodable lines: 2-3 sentences of 3-5 words each, using ONLY
     heart words (the a i to and is was his has of as) or 2-3 letter short-vowel words built from letters
     a b c d e f g i k m n o p s t u h r (plural s allowed), not ending in r. Examples: "A big fin is up. It can dip."
     Vary them between topics; the mission game reads them aloud. (These lists were right in November 2026; take the
     current letters and heart words from apps/shark-explorer/Resources/shark-reading.json.)
   - mission.kind must be a key of `MissionPlay.byKind` in ContentModels.swift, in November 2026: filterFeed, electrosense, suctionForage, camouflageFind, tailStrike, scentTrack, tidalWalk,
     jawStrike, energyTrail, speedChase, snailHunt, reefPatrol, mangroveNursery, riverJourney, sawSweep, glowLure, sandAmbush,
     squidHunt, shellCrunch. (The picture counted: crab, shell, fish, deep fish, tuna, snail, reef fish, shrimp, glow dots,
     flatfish, squid, urchin ...) The mission intro text should match the counting-and-reading game as in the model sharks.
   - Questions: 3 picture choices each. Strongly prefer choice ids that already have pictures; every
     `choice-<id>.png` in apps/shark-explorer/Resources/Art is one (the checker below prints which ids are new).
     At most 2 new choice ids per shark; each new one must be a simple drawable object.
   - Vocabulary: prefer existing ids (see catalog "vocabulary"). You may add at most one new word per shark, in the catalog's
     vocabulary shape; do not reuse an existing id for a new meaning.
   - Tone: short, warm, concrete. Nothing gory or frightening (no blood, bites on people, killing described). Never state a
     fact you did not confirm on a fetched page.
2. facts.md: per shark, the facts used, each with the source URL it came from. Sources must be pages you actually fetched:
   museums, aquariums, NOAA, universities (Florida Museum "Discover Fishes", Monterey Bay Aquarium, Shark Trust, Oceana,
   Australian Museum, MarineBio and similar). Put the URLs that back the content in sourceURLs. Say plainly in your report if
   a page would not load or a fact could not be confirmed.
3. One photo per shark as <id>.jpg in your output folder plus photos.json:
   {"<id>": {"imageAsset": "shark-<id>.jpg", "imageAuthor": "...", "imageLicense": "...", "imageSourceURL": "<Commons file page>"}}
   - From Wikimedia Commons only; licence must be CC0, public domain, CC BY or CC BY-SA, confirmed through the Commons API
     (extmetadata), not guessed. Landscape, the live animal clearly visible if at all possible; resize to about 1280 px wide
     and under 400 KB (sips -Z 1280 -s format jpeg -s formatOptions 70). If only a specimen/model/drawing exists, use it and say
     so in imageAuthor (e.g. "Name (preserved specimen)"). Look at the image yourself (Read tool) to confirm it shows the right
     species and is a good picture.
   - When calling outside services use a generic User-Agent; send no personal or project details.
4. Run: node tools/content/check-batch.mjs <your batch.json>  and fix until it prints OK. Report its final output.

## Report back
The checker output, new quiz choice ids (id + what the picture should show), new vocabulary ids, photo notes (anything that is
a specimen or doubtful), and any facts you were unsure of. Keep it short.
