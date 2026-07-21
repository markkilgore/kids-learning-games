import { createHash } from 'node:crypto';
import { mkdir, readFile, stat, writeFile } from 'node:fs/promises';

const apiKey = process.env.ELEVENLABS_API_KEY;
const voiceID = process.env.ELEVENLABS_VOICE_ID || 'OYTbf65OHHFELVut7v2H';
const modelID = process.env.ELEVENLABS_MODEL_ID || process.env.ELEVENLABS_MODEL || 'eleven_multilingual_v2';

const resourceURL = new URL('../apps/cat-math/Resources/', import.meta.url);
const audioURL = new URL('Audio/', resourceURL);
const source = await readFile(new URL('../apps/cat-math/Sources/CatContent.swift', import.meta.url), 'utf8');
const cats = parseCats(source);
if (cats.length !== 10) throw new Error(`Expected 10 cats in CatContent.swift, found ${cats.length}`);

const lines = new Set(['Good try. Use the picture hint and count once more.']);
const skills = ['counting', 'addition', 'subtraction', 'odd-even', 'skip-5', 'skip-10'];
for (const [catIndex, cat] of cats.entries()) {
  cat.beats.forEach((beat) => lines.add(beat.story));
  lines.add(`You did it! ${cat.name}’s friendship grew.`);
  lines.add(`Crunch! ${cat.name} loved that tasty treat.`);
  lines.add(`Yum! ${cat.name} is happily eating from the bowl.`);
  lines.add(`Ta-da! ${cat.name} performed ${cat.trickName}!`);
  for (let friendship = 0; friendship < 36; friendship += 1) {
    lines.add(challengePrompt(cat, catIndex, friendship, skills));
  }
}

if (process.argv.includes('--dry-run')) {
  process.stdout.write(`Cat audio script contains ${lines.size} clips for ${cats.length} cats.\n`);
  process.exit(0);
}
if (!apiKey) {
  process.stderr.write('Set ELEVENLABS_API_KEY before generating Cat Math audio.\n');
  process.exit(1);
}

await mkdir(audioURL, { recursive: true });
let manifest = {};
try {
  manifest = JSON.parse(await readFile(new URL('cat-audio-manifest.json', resourceURL), 'utf8'));
} catch {}

let completed = 0;
const orderedLines = [...lines].sort();
const concurrency = Math.max(1, Number(process.env.AUDIO_CONCURRENCY || 3));
process.stdout.write(`Preparing ${orderedLines.length} Cat Math clips with voice ${voiceID} and ${modelID}.\n`);
for (let index = 0; index < orderedLines.length; index += concurrency) {
  await Promise.all(orderedLines.slice(index, index + concurrency).map(prepareClip));
  await writeFile(new URL('cat-audio-manifest.json', resourceURL), `${JSON.stringify(manifest, null, 2)}\n`);
}
process.stdout.write(`\nCat audio manifest written with ${completed} clips.\n`);

async function prepareClip(text) {
  const hash = createHash('sha256').update(JSON.stringify({ text, voiceID, modelID })).digest('hex').slice(0, 24);
  const filename = `${hash}.mp3`;
  try {
    const existing = await stat(new URL(filename, audioURL));
    if (manifest[text]?.file === filename && existing.size > 1_000) {
      completed += 1;
      process.stdout.write(`\rReady ${completed}/${lines.size}`);
      return;
    }
  } catch {}

  const response = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceID}/with-timestamps`, {
    method: 'POST',
    headers: { 'xi-api-key': apiKey, 'content-type': 'application/json' },
    body: JSON.stringify({
      text,
      model_id: modelID,
      output_format: 'mp3_44100_96',
      voice_settings: { stability: 0.42, similarity_boost: 0.75, style: 0.45, use_speaker_boost: true }
    })
  });
  if (!response.ok) throw new Error(`ElevenLabs ${response.status}: ${(await response.text()).slice(0, 200)}`);
  const payload = await response.json();
  await writeFile(new URL(filename, audioURL), Buffer.from(payload.audio_base64, 'base64'));
  manifest[text] = { file: filename, words: collapseWords(payload.alignment) };
  completed += 1;
  process.stdout.write(`\rReady ${completed}/${lines.size}`);
}

function parseCats(swift) {
  const pattern = /cat\("([^"]+)", "([^"]+)", "[^"]+", "[^"]+", "[^"]+", "[^"]+", \d+, "([^"]+)", "([^"]+)", "[^"]+", "([^"]+)", "[^"]+", \[\n([\s\S]*?)\n        \]\)/g;
  return [...swift.matchAll(pattern)].map((match) => ({
    id: match[1],
    name: match[2],
    item: match[3],
    items: match[4],
    trickName: match[5],
    beats: [...match[6].matchAll(/\("[^"]+", "([^"]+)", "([^"]+)"\)/g)].map((beat) => ({ story: beat[1], lead: beat[2] }))
  }));
}

function challengePrompt(cat, catIndex, friendship, enabledSkills) {
  const skill = enabledSkills[(friendship + catIndex) % enabledSkills.length];
  const seed = Math.max(1, (friendship + [...cat.name].length) % 9 + 1);
  const story = cat.beats[Math.min(friendship, cat.beats.length - 1)];
  const noun = (count) => count === 1 ? cat.item : cat.items;
  switch (skill) {
    case 'addition': {
      const other = (seed % 4) + 1;
      return `${story.lead} ${cat.name} has ${seed} ${noun(seed)} and finds ${other} more. How many now?`;
    }
    case 'subtraction': {
      const total = seed + 4;
      const taken = Math.min(3, seed);
      return `${story.lead} ${cat.name} counts ${total} ${noun(total)}. ${taken} are put away. How many stay?`;
    }
    case 'odd-even': {
      const number = seed + 3;
      return `${story.lead} ${cat.name} finds ${number} ${noun(number)}. Is that odd or even? Choose 1 for odd or 2 for even.`;
    }
    case 'skip-5':
      return `${story.lead} help ${cat.name} count ${cat.items} by fives: 5, 10, 15. What comes next?`;
    case 'skip-10':
      return `${story.lead} help ${cat.name} count ${cat.items} by tens: 10, 20, 30. What comes next?`;
    default:
      return `${story.lead} how many ${noun(seed)} did ${cat.name} find?`;
  }
}

function collapseWords(alignment) {
  if (!alignment?.characters?.length) return [];
  const { characters, character_start_times_seconds: starts, character_end_times_seconds: ends } = alignment;
  const words = [];
  let current = null;
  for (let index = 0; index < characters.length; index += 1) {
    const char = characters[index];
    if (/\s/.test(char)) {
      if (current) words.push(current);
      current = null;
    } else if (!current) {
      current = { text: char, start: starts[index], end: ends[index] };
    } else {
      current.text += char;
      current.end = ends[index];
    }
  }
  if (current) words.push(current);
  return words;
}
