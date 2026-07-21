import { readFile, stat } from 'node:fs/promises';

const resourceURL = new URL('../apps/shark-explorer/Resources/', import.meta.url);
const path = new URL('catalog.json', resourceURL);
const catalog = JSON.parse(await readFile(path, 'utf8'));
const audioManifest = JSON.parse(await readFile(new URL('audio-manifest.json', resourceURL), 'utf8'));
const errors = [];

if (catalog.schemaVersion !== 1) errors.push('schemaVersion must be 1');
if (catalog.sharks?.length !== 10) errors.push('catalog must contain exactly 10 sharks');
if (new Set(catalog.sharks.map((s) => s.id)).size !== catalog.sharks.length) errors.push('shark IDs must be unique');
const vocabulary = new Set(catalog.vocabulary.map((word) => word.id));
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

const requiredAudio = new Set();
function visitAudio(value, key = '') {
  if (Array.isArray(value)) {
    if (key === 'earlyReader' || key === 'story') value.forEach((line) => requiredAudio.add(line));
    else value.forEach((item) => visitAudio(item));
  } else if (value && typeof value === 'object') {
    for (const [childKey, child] of Object.entries(value)) visitAudio(child, childKey);
  } else if (typeof value === 'string' && ['completion', 'success', 'retry'].includes(key)) {
    requiredAudio.add(value);
  }
}
visitAudio(catalog);
catalog.vocabulary.forEach((word) => requiredAudio.add(word.word));

for (const text of requiredAudio) {
  const clip = audioManifest[text];
  if (!clip?.file || !clip.words?.length) {
    errors.push(`missing timed narration: ${text}`);
    continue;
  }
  try {
    const audio = await stat(new URL(`Audio/${clip.file}`, resourceURL));
    if (audio.size < 1_000) errors.push(`audio clip is unexpectedly small: ${text}`);
  } catch {
    errors.push(`missing audio file: ${text}`);
  }
}

if (errors.length) {
  for (const error of errors) process.stderr.write(`ERROR ${error}\n`);
  process.exit(1);
}

const topicCount = expandedSharks.reduce((sum, shark) => sum + shark.topics.length, 0);
const questionCount = expandedSharks.reduce((sum, shark) => sum + shark.questions.length, 0);
const traitCount = expandedSharks.reduce((sum, shark) => sum + shark.traits.length, 0);
const traitImageCount = expandedSharks.reduce((sum, shark) => sum + shark.traits.filter((trait) => trait.imageAsset).length, 0);
process.stdout.write(`Validated ${catalog.sharks.length} sharks, ${topicCount} topics, ${questionCount} questions, ${traitCount} Passport traits (${traitImageCount} illustrated), ${catalog.vocabulary.length} Ocean Words, ${requiredAudio.size} timed audio clips, and ${catalog.sharks.length} species images.\n`);
