import { syncNarration } from './lib/elevenlabs.mjs';
import { sharkLines, sharkResources } from './lib/lines.mjs';

await syncNarration({
  label: 'Shark Explorer',
  resourceURL: sharkResources,
  manifestName: 'audio-manifest.json',
  lines: await sharkLines()
});
