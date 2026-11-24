import { mkdir, writeFile } from 'node:fs/promises';
import { catResources, sharkResources } from './lib/lines.mjs';

// Synthesizes the short interface sounds shared by both apps; no network or API key needed.
// File names match `FeedbackEffect` in the Narration package.
const RATE = 44_100;

/** A struck, marimba-like note: a sine with two quieter overtones and a fast exponential decay. */
function note(frequency, start, length, gain = 0.5) {
  return (time) => {
    const t = time - start;
    if (t < 0 || t > length) return 0;
    const envelope = Math.min(1, t / 0.004) * Math.exp(-t * (5 / length));
    const tone = Math.sin(2 * Math.PI * frequency * t) + 0.3 * Math.sin(2 * Math.PI * frequency * 2 * t) + 0.12 * Math.sin(2 * Math.PI * frequency * 4 * t);
    return gain * envelope * tone;
  };
}

/** A pitch glide, used for the bubble pop. */
function sweep(from, to, length, gain = 0.6) {
  return (time) => {
    if (time > length) return 0;
    const progress = time / length;
    const phase = 2 * Math.PI * (from * time + ((to - from) * time * time) / (2 * length));
    return gain * Math.sin(phase) * Math.sin(Math.PI * progress) ** 0.5 * (1 - progress * 0.4);
  };
}

/** Smoothed noise that swells and fades, for a page turn. */
function swish(length, gain = 0.35) {
  let previous = 0;
  let seed = 12_345;
  return (time) => {
    if (time > length) return 0;
    seed = (seed * 1_103_515_245 + 12_345) % 2_147_483_648;
    previous += 0.18 * ((seed / 1_073_741_824 - 1) - previous);
    return gain * previous * Math.sin((Math.PI * time) / length) ** 2 * 3;
  };
}

const C5 = 523.25, E5 = 659.25, G5 = 783.99, A5 = 880, C6 = 1046.5, E6 = 1318.5, G6 = 1568;
const effects = {
  tap: { length: 0.09, voices: [note(A5, 0, 0.08, 0.35)] },
  correct: { length: 0.7, voices: [note(E5, 0, 0.35), note(C6, 0.12, 0.55)] },
  wrong: { length: 0.5, voices: [note(329.63, 0, 0.3, 0.4), note(261.63, 0.14, 0.34, 0.4)] },
  pop: { length: 0.12, voices: [sweep(380, 980, 0.11)] },
  unlock: { length: 1.2, voices: [C5, E5, G5, C6, E6].map((pitch, index) => note(pitch, index * 0.09, 0.8, 0.4)) },
  celebrate: {
    length: 1.9,
    voices: [
      ...[C5, E5, G5, C6, G5, C6, E6].map((pitch, index) => note(pitch, index * 0.1, 0.5, 0.36)),
      ...[C6, E6, G6].map((pitch) => note(pitch, 0.78, 1.1, 0.3))
    ]
  },
  page: { length: 0.3, voices: [swish(0.3)] }
};

function wav({ length, voices }) {
  const count = Math.ceil(length * RATE);
  const buffer = Buffer.alloc(44 + count * 2);
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + count * 2, 4);
  buffer.write('WAVEfmt ', 8);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(RATE, 24);
  buffer.writeUInt32LE(RATE * 2, 28);
  buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write('data', 36);
  buffer.writeUInt32LE(count * 2, 40);
  for (let index = 0; index < count; index += 1) {
    const time = index / RATE;
    const fadeOut = Math.min(1, (length - time) / 0.01);
    const sample = voices.reduce((sum, voice) => sum + voice(time), 0) * fadeOut;
    buffer.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sample)) * 32_000), 44 + index * 2);
  }
  return buffer;
}

for (const [name, effect] of Object.entries(effects)) {
  const audio = wav(effect);
  for (const base of [sharkResources, catResources]) {
    const url = new URL(`Sfx/sfx-${name}.wav`, base);
    await mkdir(new URL('.', url), { recursive: true });
    await writeFile(url, audio);
  }
  process.stdout.write(`Wrote sfx-${name}.wav (${audio.length} bytes)\n`);
}
