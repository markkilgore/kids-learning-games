import { syncNarration } from './lib/elevenlabs.mjs';
import { catLines, catResources } from './lib/lines.mjs';

await syncNarration({
  label: 'Cat Math',
  resourceURL: catResources,
  manifestName: 'cat-audio-manifest.json',
  lines: await catLines()
});
