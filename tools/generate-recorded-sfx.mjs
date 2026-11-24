import { execFile } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';
import { loadEnv } from './lib/elevenlabs.mjs';
import { catResources, sharkResources } from './lib/lines.mjs';

// Records the interface sounds with the ElevenLabs sound-effects API (the key needs the
// `sound_generation` permission), then trims leading silence and evens out loudness so short
// sounds start the instant a child taps. `generate-sfx.mjs` makes synthesized stand-ins with no key.
// Needs macOS `afconvert`. Pass effect names to redo only those: `node generate-recorded-sfx.mjs tap pop`.
const run = promisify(execFile);

const effects = {
  tap: { text: 'One soft, short wooden click, like a small wooden toy block tapped once. Dry, clean, no echo.', seconds: 0.5, keep: 0.18, peak: 0.45 },
  correct: { text: 'Bright, happy two-note marimba chime rising in pitch, a correct-answer sound in a gentle children\'s game. Clean, no voice.', seconds: 1, keep: 0.9, peak: 0.7 },
  wrong: { text: 'Gentle, soft low two-note xylophone "try again" sound, kind and not harsh, for a young children\'s game. No buzzer, no voice.', seconds: 0.8, keep: 0.7, peak: 0.55 },
  pop: { text: 'One single cute bubble pop, short and bright. Dry, no echo.', seconds: 0.5, keep: 0.22, peak: 0.6 },
  unlock: { text: 'Magical sparkling glockenspiel run going upward, a reward unlocked in a gentle children\'s game. Clean, no voice.', seconds: 1.5, keep: 1.4, peak: 0.7 },
  celebrate: { text: 'Short joyful fanfare of marimba and bells with a sparkle at the end, celebrating a win in a gentle children\'s game. No voice, no crowd.', seconds: 2.2, keep: 2.1, peak: 0.75 },
  page: { text: 'One soft paper page turning in a picture book. Quiet, clean, no echo.', seconds: 0.6, keep: 0.45, peak: 0.5 }
};

await loadEnv();
const apiKey = process.env.ELEVENLABS_API_KEY;
if (!apiKey) {
  process.stderr.write('Set ELEVENLABS_API_KEY (shell or .env) before recording sound effects.\n');
  process.exit(1);
}

const RATE = 44_100;
const SILENT = 'The recording is silent.';
const wanted = process.argv.slice(2).filter((name) => effects[name]);
const names = wanted.length ? wanted : Object.keys(effects);
const scratch = await mkdtemp(join(tmpdir(), 'sfx-'));

/** Reads 16-bit mono PCM samples out of a WAV file as floats in -1...1. */
function samplesFrom(wav) {
  let offset = 12;
  while (offset + 8 <= wav.length) {
    const size = wav.readUInt32LE(offset + 4);
    if (wav.toString('ascii', offset, offset + 4) === 'data') {
      const count = Math.floor(Math.min(size, wav.length - offset - 8) / 2);
      return Float32Array.from({ length: count }, (_, index) => wav.readInt16LE(offset + 8 + index * 2) / 32_768);
    }
    offset += 8 + size + (size % 2);
  }
  throw new Error('No audio data in the converted file.');
}

function wavFrom(samples) {
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + samples.length * 2, 4);
  header.write('WAVEfmt ', 8);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(samples.length * 2, 40);
  const body = Buffer.alloc(samples.length * 2);
  samples.forEach((sample, index) => body.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sample)) * 32_767), index * 2));
  return Buffer.concat([header, body]);
}

/** Starts at the first audible sample, keeps `keep` seconds, fades the tail, and sets the peak level. */
function tidy(samples, { keep, peak }) {
  const loudest = samples.reduce((max, sample) => Math.max(max, Math.abs(sample)), 0);
  if (loudest < 0.01) throw new Error(SILENT);
  const start = Math.max(0, samples.findIndex((sample) => Math.abs(sample) > loudest * 0.05) - 64);
  const cut = samples.slice(start, start + Math.round(keep * RATE));
  const fade = Math.min(cut.length, Math.round(0.06 * RATE));
  return cut.map((sample, index) => {
    const tail = cut.length - index;
    return (sample / loudest) * peak * (tail < fade ? tail / fade : 1);
  });
}

/** One attempt at recording an effect; the service occasionally returns silence, so the caller retries. */
async function record(name, effect) {
  const response = await fetch('https://api.elevenlabs.io/v1/sound-generation', {
    method: 'POST',
    headers: { 'xi-api-key': apiKey, 'content-type': 'application/json' },
    body: JSON.stringify({ text: effect.text, duration_seconds: effect.seconds, prompt_influence: 0.6 })
  });
  if (!response.ok) throw new Error(`ElevenLabs ${response.status}: ${(await response.text()).slice(0, 300)}`);
  const mp3 = join(scratch, `${name}.mp3`);
  const raw = join(scratch, `${name}.wav`);
  await writeFile(mp3, Buffer.from(await response.arrayBuffer()));
  await run('afconvert', ['-f', 'WAVE', '-d', `LEI16@${RATE}`, '-c', '1', mp3, raw]);
  return tidy(samplesFrom(await readFile(raw)), effect);
}

for (const name of names) {
  const effect = effects[name];
  let samples;
  for (let attempt = 1; !samples; attempt += 1) {
    try {
      samples = await record(name, effect);
    } catch (error) {
      if (attempt >= 3 || error.message !== SILENT) throw error;
    }
  }
  for (const base of [sharkResources, catResources]) {
    const folder = new URL('Sfx/', base);
    await mkdir(folder, { recursive: true });
    await writeFile(new URL(`sfx-${name}.wav`, folder), wavFrom(samples));
  }
  process.stdout.write(`${name}: ${(samples.length / RATE).toFixed(2)}s\n`);
}
await rm(scratch, { recursive: true, force: true });
