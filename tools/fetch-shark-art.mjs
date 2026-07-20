import { mkdir, stat, writeFile } from 'node:fs/promises';

const images = [
  ['shark-whale.jpg', 'Rhincodon typus 420227950.jpg'],
  ['shark-hammerhead.jpg', 'Sphyrna mokarran head.jpg'],
  ['shark-nurse.jpg', 'Nurse shark.jpg'],
  ['shark-great-white.jpg', 'Carcharodon carcharias.jpg'],
  ['shark-wobbegong-ambush.jpg', 'Orectolobus maculatus.jpg'],
  ['shark-thresher.png', 'Alopias vulpinus.png'],
  ['shark-tiger-underwater.jpg', 'Tiger shark.jpg'],
  ['shark-epaulette.jpg', 'Hemiscyllium ocellatum.jpg'],
  ['shark-goblin.jpg', 'Mistukurina owstoni museum victoria.jpg'],
  ['shark-greenland.jpg', 'Somniosus microcephalus okeanos.jpg']
];

const outputDirectory = new URL('../apps/shark-explorer/Resources/Art/', import.meta.url);
await mkdir(outputDirectory, { recursive: true });

for (const [filename, commonsTitle] of images) {
  const destination = new URL(filename, outputDirectory);
  try {
    const existing = await stat(destination);
    if (existing.size >= 8_000) {
      process.stdout.write(`Kept ${filename} (${Math.round(existing.size / 1024)} KB)\n`);
      continue;
    }
  } catch {}

  const source = `https://commons.wikimedia.org/wiki/Special:Redirect/file/${encodeURIComponent(commonsTitle)}?width=1200`;
  const response = await fetchWithBackoff(source);
  if (!response.ok) throw new Error(`${commonsTitle}: Wikimedia returned ${response.status}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length < 8_000) throw new Error(`${commonsTitle}: downloaded file is unexpectedly small`);
  await writeFile(destination, bytes);
  process.stdout.write(`Downloaded ${filename} (${Math.round(bytes.length / 1024)} KB)\n`);
  await pause(1_500);
}

async function fetchWithBackoff(source) {
  for (const delay of [0, 5_000, 15_000, 30_000]) {
    if (delay) await pause(delay);
    const response = await fetch(source, {
      headers: { 'user-agent': 'HenrySharkExplorer/1.0 (educational offline iPad app; contact: local-build)' }
    });
    if (response.status !== 429) return response;
  }
  throw new Error('Wikimedia rate limit did not clear after retries');
}

function pause(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
