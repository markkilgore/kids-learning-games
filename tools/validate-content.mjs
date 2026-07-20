import { readFile, stat } from 'node:fs/promises';

const resourceURL = new URL('../SharkExplorer/Resources/', import.meta.url);
const path = new URL('catalog.json', resourceURL);
const catalog = JSON.parse(await readFile(path, 'utf8'));
const audioManifest = JSON.parse(await readFile(new URL('audio-manifest.json', resourceURL), 'utf8'));
const errors = [];

if (catalog.schemaVersion !== 1) errors.push('schemaVersion must be 1');
if (catalog.sharks?.length !== 10) errors.push('catalog must contain exactly 10 sharks');
if (new Set(catalog.sharks.map((s) => s.id)).size !== catalog.sharks.length) errors.push('shark IDs must be unique');
const vocabulary = new Set(catalog.vocabulary.map((word) => word.id));

for (const shark of catalog.sharks) {
  if (shark.topics.length !== 5) errors.push(`${shark.id}: expected 5 topics`);
  if (shark.questions.length !== 3) errors.push(`${shark.id}: expected 3 questions`);
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

const topicCount = catalog.sharks.reduce((sum, shark) => sum + shark.topics.length, 0);
const questionCount = catalog.sharks.reduce((sum, shark) => sum + shark.questions.length, 0);
process.stdout.write(`Validated ${catalog.sharks.length} sharks, ${topicCount} topics, ${questionCount} questions, ${catalog.vocabulary.length} Ocean Words, ${requiredAudio.size} timed audio clips, and ${catalog.sharks.length} species images.\n`);
