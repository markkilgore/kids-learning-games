import { readFile, stat } from 'node:fs/promises';
import { narrationProblems } from './lib/elevenlabs.mjs';
import { catLines, catResources, sharkLines } from './lib/lines.mjs';

const resourceURL = new URL('../apps/shark-explorer/Resources/', import.meta.url);
const path = new URL('catalog.json', resourceURL);
const catalog = JSON.parse(await readFile(path, 'utf8'));
const errors = [];

if (catalog.schemaVersion !== 1) errors.push('schemaVersion must be 1');
if (catalog.sharks?.length !== 45) errors.push('catalog must contain exactly 45 animals');
if (!catalog.sharks.map((s) => s.unlockAt).sort((a, b) => a - b).every((unlockAt, index) => unlockAt <= index)) errors.push('a shark can never be unlocked');
if (!catalog.sharks.map((s) => s.unlockStars ?? 0).sort((a, b) => a - b).every((stars, index) => stars <= 3 * index)) errors.push('a shark needs more stars than can be earned');
if (!catalog.sharks.map((s) => s.unlockSuperStars ?? 0).sort((a, b) => a - b).every((stars, index) => stars <= 2 * index)) errors.push('a shark needs more super stars than can be earned');
const mapIDs = new Set((catalog.maps ?? []).map((page) => page.id));
if (!mapIDs.size) errors.push('catalog needs map pages');
for (const page of mapIDs) {
  const spots = catalog.sharks.filter((s) => s.map === page).map((s) => `${s.mapX},${s.mapY}`);
  if (!spots.length) errors.push(`map page ${page} has no sharks`);
  if (new Set(spots).size !== spots.length) errors.push(`map page ${page} has two sharks in one spot`);
}
for (const shark of catalog.sharks) if (!mapIDs.has(shark.map)) errors.push(`${shark.id}: unknown map page ${shark.map}`);
if (new Set(catalog.sharks.map((s) => s.id)).size !== catalog.sharks.length) errors.push('shark IDs must be unique');
const vocabulary = new Set(catalog.vocabulary.map((word) => word.id));
if (vocabulary.size !== catalog.vocabulary.length) errors.push('Ocean Word IDs must be unique');
const expansions = new Map((catalog.expansions ?? []).map((expansion) => [expansion.sharkID, expansion]));
if (expansions.size !== catalog.sharks.length) errors.push('every shark must have an expansion');
const expandedSharks = catalog.sharks.map((shark) => {
  const expansion = expansions.get(shark.id);
  return {
    ...shark,
    topics: [...shark.topics, ...(expansion?.topics ?? [])],
    questions: [...shark.questions, ...(expansion?.questions ?? [])]
  };
});

for (const shark of expandedSharks) {
  if (shark.topics.length !== 7) errors.push(`${shark.id}: expected 7 topics`);
  if (shark.questions.length !== 3) errors.push(`${shark.id}: expected 3 questions`);
  if (shark.traits?.length !== 2) errors.push(`${shark.id}: expected 2 Passport traits`);
  if (new Set(shark.topics.map((topic) => topic.id)).size !== shark.topics.length) errors.push(`${shark.id}: topic IDs must be unique`);
  if (shark.vocabularyIDs.length < 2 || shark.vocabularyIDs.length > 3) errors.push(`${shark.id}: expected 2-3 vocabulary IDs`);
  if (!shark.vocabularyIDs.every((id) => vocabulary.has(id))) errors.push(`${shark.id}: unknown vocabulary ID`);
  if (!shark.sourceURLs?.length) errors.push(`${shark.id}: missing science source`);
  if (!shark.imageAsset || !shark.imageSourceURL || !shark.imageAuthor || !shark.imageLicense) errors.push(`${shark.id}: incomplete image credit`);
  try {
    const image = await stat(new URL(`Art/${shark.imageAsset}`, resourceURL));
    if (image.size < 8_000) errors.push(`${shark.id}: species image is unexpectedly small`);
  } catch {
    errors.push(`${shark.id}: missing species image file`);
  }
  for (const topic of shark.topics) {
    if (!topic.narration.earlyReader.length || !topic.narration.story.length) errors.push(`${shark.id}/${topic.id}: missing narration mode`);
  }
  for (const trait of shark.traits ?? []) {
    if (!trait.id || !trait.title || !trait.description || !trait.unlockTopicID) errors.push(`${shark.id}: incomplete Passport trait`);
    if (!shark.topics.some((topic) => topic.id === trait.unlockTopicID)) errors.push(`${shark.id}/${trait.id}: unknown Passport unlock topic`);
    if (trait.imageAsset) {
      try {
        const image = await stat(new URL(`Art/Traits/${trait.imageAsset}`, resourceURL));
        if (image.size < 8_000) errors.push(`${shark.id}/${trait.id}: trait image is unexpectedly small`);
      } catch {
        errors.push(`${shark.id}/${trait.id}: missing trait image file`);
      }
    }
  }
  for (const question of shark.questions) {
    if (question.choices.length !== 3) errors.push(`${question.id}: expected 3 choices`);
    if (question.choices.filter((choice) => choice.id === question.correctID).length !== 1) errors.push(`${question.id}: expected exactly one correct choice`);
  }
}

const sharkAudio = await sharkLines();
errors.push(...await narrationProblems({ resourceURL, manifestName: 'audio-manifest.json', lines: sharkAudio }));
const catAudio = await catLines();
errors.push(...(await narrationProblems({ resourceURL: catResources, manifestName: 'cat-audio-manifest.json', lines: catAudio })).map((problem) => `cat-math: ${problem}`));
const requiredAudio = new Set([...sharkAudio, ...catAudio]);

if (errors.length) {
  for (const error of errors) process.stderr.write(`ERROR ${error}\n`);
  process.exit(1);
}

const topicCount = expandedSharks.reduce((sum, shark) => sum + shark.topics.length, 0);
const questionCount = expandedSharks.reduce((sum, shark) => sum + shark.questions.length, 0);
const traitCount = expandedSharks.reduce((sum, shark) => sum + shark.traits.length, 0);
const traitImageCount = expandedSharks.reduce((sum, shark) => sum + shark.traits.filter((trait) => trait.imageAsset).length, 0);
process.stdout.write(`Validated ${catalog.sharks.length} sharks, ${topicCount} topics, ${questionCount} questions, ${traitCount} Passport traits (${traitImageCount} illustrated), ${catalog.vocabulary.length} Ocean Words, ${requiredAudio.size} timed audio clips across both apps, and ${catalog.sharks.length} species images.\n`);
