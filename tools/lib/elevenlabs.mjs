import { createHash } from 'node:crypto';
import { mkdir, readdir, readFile, stat, unlink, writeFile } from 'node:fs/promises';

export const DEFAULT_VOICE_ID = 'hpp4J3VqNfWAUOO0d1Us';
export const DEFAULT_MODEL_ID = 'eleven_v3';
export const VOICE_SETTINGS = { stability: 0.42, similarity_boost: 0.75, style: 0.45, use_speaker_boost: true };
const MIN_CLIP_BYTES = 1_000;

/** Reads KEY=value pairs from the repository `.env` without overriding the shell. */
export async function loadEnv() {
  let text;
  try {
    text = await readFile(new URL('../../.env', import.meta.url), 'utf8');
  } catch {
    return;
  }
  for (const line of text.split('\n')) {
    const match = line.match(/^\s*(?:export\s+)?([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (!match || process.env[match[1]]) continue;
    process.env[match[1]] = match[2].replace(/^(['"])(.*)\1$/, '$2');
  }
}

export function settings() {
  return {
    apiKey: process.env.ELEVENLABS_API_KEY,
    voiceID: process.env.ELEVENLABS_VOICE_ID || DEFAULT_VOICE_ID,
    modelID: process.env.ELEVENLABS_MODEL_ID || process.env.ELEVENLABS_MODEL || DEFAULT_MODEL_ID
  };
}

export function clipFilename(text, voiceID, modelID) {
  return `${createHash('sha256').update(JSON.stringify({ text, voiceID, modelID })).digest('hex').slice(0, 24)}.mp3`;
}

export async function synthesize(text, { apiKey, voiceID, modelID }) {
  for (let attempt = 1; ; attempt += 1) {
    const response = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceID}/with-timestamps?output_format=mp3_44100_96`, {
      method: 'POST',
      headers: { 'xi-api-key': apiKey, 'content-type': 'application/json' },
      body: JSON.stringify({ text, model_id: modelID, voice_settings: VOICE_SETTINGS })
    });
    if (response.ok) {
      const payload = await response.json();
      return { audio: Buffer.from(payload.audio_base64, 'base64'), words: collapseWords(payload.alignment) };
    }
    const detail = (await response.text()).slice(0, 300);
    if (attempt >= 4 || ![429, 500, 502, 503, 504].includes(response.status)) {
      throw new Error(`ElevenLabs ${response.status}: ${detail}`);
    }
    await new Promise((resolve) => setTimeout(resolve, attempt * 4_000));
  }
}

/**
 * Brings one app's bundled narration in line with `lines`.
 * Flags: --dry-run (report only), --prune (drop clips no longer spoken).
 */
export async function syncNarration({ label, resourceURL, manifestName, lines }) {
  await loadEnv();
  const config = settings();
  const dryRun = process.argv.includes('--dry-run');
  const prune = process.argv.includes('--prune');
  const audioURL = new URL('Audio/', resourceURL);
  const manifestURL = new URL(manifestName, resourceURL);
  let manifest = {};
  try {
    manifest = JSON.parse(await readFile(manifestURL, 'utf8'));
  } catch {}

  const wanted = [...new Set(lines)].sort();
  const pending = [];
  for (const text of wanted) {
    const filename = clipFilename(text, config.voiceID, config.modelID);
    if (manifest[text]?.file === filename && await isUsable(new URL(filename, audioURL))) continue;
    pending.push({ text, filename });
  }
  const stale = Object.keys(manifest).filter((text) => !wanted.includes(text));
  const characters = pending.reduce((sum, clip) => sum + clip.text.length, 0);
  process.stdout.write(`${label}: ${wanted.length} lines, ${pending.length} to generate (${characters} characters), ${stale.length} stale, voice ${config.voiceID}, model ${config.modelID}.\n`);
  if (dryRun) return;

  if (pending.length && !config.apiKey) {
    process.stderr.write('Set ELEVENLABS_API_KEY (shell or .env) before generating audio.\n');
    process.exit(1);
  }
  await mkdir(audioURL, { recursive: true });
  const save = () => writeFile(manifestURL, `${JSON.stringify(sorted(manifest), null, 2)}\n`);
  const concurrency = Math.max(1, Number(process.env.AUDIO_CONCURRENCY || 3));
  let done = 0;
  for (let index = 0; index < pending.length; index += concurrency) {
    await Promise.all(pending.slice(index, index + concurrency).map(async ({ text, filename }) => {
      const clip = await synthesize(text, config);
      await writeFile(new URL(filename, audioURL), clip.audio);
      manifest[text] = { file: filename, words: clip.words };
      done += 1;
      process.stdout.write(`\r${label}: generated ${done}/${pending.length}`);
    }));
    await save();
  }
  if (pending.length) process.stdout.write('\n');

  if (prune) {
    for (const text of stale) delete manifest[text];
    const keep = new Set(Object.values(manifest).map((entry) => entry.file));
    let removed = 0;
    for (const file of await readdir(audioURL)) {
      if (file.endsWith('.mp3') && !keep.has(file)) {
        await unlink(new URL(file, audioURL));
        removed += 1;
      }
    }
    process.stdout.write(`${label}: pruned ${stale.length} stale entries and ${removed} unused clips.\n`);
  }
  await save();
}

/** Returns a list of problems; empty when every line has a usable timed clip. */
export async function narrationProblems({ resourceURL, manifestName, lines }) {
  const manifest = JSON.parse(await readFile(new URL(manifestName, resourceURL), 'utf8'));
  const problems = [];
  for (const text of new Set(lines)) {
    const clip = manifest[text];
    if (!clip?.file || !clip.words?.length) {
      problems.push(`missing timed narration: ${text}`);
    } else if (!await isUsable(new URL(`Audio/${clip.file}`, resourceURL))) {
      problems.push(`missing or tiny audio file: ${text}`);
    }
  }
  return problems;
}

async function isUsable(url) {
  try {
    return (await stat(url)).size > MIN_CLIP_BYTES;
  } catch {
    return false;
  }
}

function sorted(object) {
  return Object.fromEntries(Object.entries(object).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)));
}

/** One timed entry per whitespace-separated chunk; the app maps chunks onto its own word tokens. */
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
