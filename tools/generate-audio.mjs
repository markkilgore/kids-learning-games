import { createHash } from 'node:crypto';
import { mkdir, readFile, stat, writeFile } from 'node:fs/promises';

const apiKey = process.env.ELEVENLABS_API_KEY;
const voiceID = process.env.ELEVENLABS_VOICE_ID;
const modelID = process.env.ELEVENLABS_MODEL_ID || 'eleven_multilingual_v2';
if (!apiKey || !voiceID) {
  process.stderr.write('Set ELEVENLABS_API_KEY and ELEVENLABS_VOICE_ID before generating audio.\n');
  process.exit(1);
}

const resourceURL = new URL('../apps/shark-explorer/Resources/', import.meta.url);
const audioURL = new URL('Audio/', resourceURL);
const catalog = JSON.parse(await readFile(new URL('catalog.json', resourceURL), 'utf8'));
await mkdir(audioURL, { recursive: true });

const lines = new Set();
function visit(value, key = '') {
  if (Array.isArray(value)) {
    if (key === 'earlyReader' || key === 'story') value.forEach((line) => lines.add(line));
    else value.forEach((item) => visit(item));
  } else if (value && typeof value === 'object') {
    for (const [childKey, child] of Object.entries(value)) visit(child, childKey);
  } else if (typeof value === 'string' && ['completion', 'success', 'retry'].includes(key)) {
    lines.add(value);
  }
}
visit(catalog);
for (const word of catalog.vocabulary) lines.add(word.word);

let manifest = {};
try {
  manifest = JSON.parse(await readFile(new URL('audio-manifest.json', resourceURL), 'utf8'));
} catch {}
let completed = 0;
const orderedLines = [...lines].sort();
const concurrency = Math.max(1, Number(process.env.AUDIO_CONCURRENCY || 3));
for (let index = 0; index < orderedLines.length; index += concurrency) {
  await Promise.all(orderedLines.slice(index, index + concurrency).map(prepareClip));
  await writeFile(new URL('audio-manifest.json', resourceURL), `${JSON.stringify(manifest, null, 2)}\n`);
}

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
      voice_settings: { stability: 0.35, similarity_boost: 0.75, style: 0.65, use_speaker_boost: true }
    })
  });
  if (!response.ok) throw new Error(`ElevenLabs ${response.status}: ${(await response.text()).slice(0, 200)}`);
  const payload = await response.json();
  await writeFile(new URL(filename, audioURL), Buffer.from(payload.audio_base64, 'base64'));
  manifest[text] = { file: filename, words: collapseWords(payload.alignment) };
  completed += 1;
  process.stdout.write(`\rReady ${completed}/${lines.size}`);
}

await writeFile(new URL('audio-manifest.json', resourceURL), `${JSON.stringify(manifest, null, 2)}\n`);
process.stdout.write(`\nAudio manifest written with ${completed} clips.\n`);

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
