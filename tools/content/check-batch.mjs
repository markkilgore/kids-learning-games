// Usage: node tools/content/check-batch.mjs batch.json
// Checks a batch of new animals before it is merged: the catalog shape, that every "decodable" word is one
// Henry can read (the same rule as SharkReading.mark), and which quiz choices still need a picture.
import { readFile } from 'node:fs/promises';
const repo = new URL('../../apps/shark-explorer/Resources/', import.meta.url).pathname;
const reading = JSON.parse(await readFile(repo + 'shark-reading.json', 'utf8'));
const catalog = JSON.parse(await readFile(repo + 'catalog.json', 'utf8'));
const batch = JSON.parse(await readFile(process.argv[2], 'utf8'));
const vowels = new Set('aeiou');
const short = (w) => { if (w.length !== 2 && w.length !== 3) return false; const e = w.at(-1), v = w.at(-2); if (!vowels.has(v) || vowels.has(e) || e === 'r') return false; return w.length === 2 || !vowels.has(w[0]); };
const readable = (w) => { if (reading.heartWords.includes(w)) return true; if (reading.irregular.includes(w) || ![...w].every((l) => reading.letters.includes(l))) return false; const bases = w.length > 3 && w.endsWith('s') ? [w, w.slice(0, -1)] : [w]; return bases.some(short); };
const problems = [];
const model = catalog.sharks.find((s) => s.id === 'bamboo');
const vocab = new Set([...catalog.vocabulary, ...(batch.vocabulary ?? [])].map((v) => v.id));
for (const s of batch.sharks) {
  for (const k of Object.keys(model)) if (!(k in s) && !['unlockSuperStars', 'mapX', 'mapY'].includes(k)) problems.push(`${s.id}: missing key ${k}`);
  const narr = [['discover', s.discover], ...s.topics.map((t) => [t.id, t.narration])];
  for (const [where, n] of narr) {
    if (!n.decodable?.length) problems.push(`${s.id}/${where}: no decodable line`);
    for (const line of n.decodable ?? []) {
      for (const w of line.toLowerCase().match(/[a-z]+/g) ?? []) if (!readable(w)) problems.push(`${s.id}/${where}: "${w}" is not readable (in "${line}")`);
      for (const sentence of line.split(/(?<=[.!?])\s+/)) { const n = sentence.trim().split(/\s+/).length; if (n < 3 || n > 5) problems.push(`${s.id}/${where}: sentence "${sentence}" has ${n} words (want 3-5)`); }
    }
    if (!n.earlyReader?.length || !n.story?.length) problems.push(`${s.id}/${where}: missing earlyReader or story`);
  }
  if (s.topics.map((t) => t.id).join() !== 'home,food,size,senses,power') problems.push(`${s.id}: topic ids must be home,food,size,senses,power`);
  const exp = batch.expansions.find((e) => e.sharkID === s.id);
  if (!exp || exp.topics.map((t) => t.id).join() !== 'body-clues,ocean-care') problems.push(`${s.id}: expansion needs topics body-clues, ocean-care`);
  if (s.traits?.length !== 2) problems.push(`${s.id}: needs 2 traits`);
  for (const t of s.traits ?? []) if (![...s.topics, ...(exp?.topics ?? [])].some((x) => x.id === t.unlockTopicID)) problems.push(`${s.id}: trait ${t.id} unlockTopicID unknown`);
  if (s.questions?.length !== 3) problems.push(`${s.id}: needs 3 questions`);
  for (const q of s.questions ?? []) { if (q.choices.length !== 3 || q.choices.filter((c) => c.id === q.correctID).length !== 1) problems.push(`${q.id}: 3 choices, one correct`); }
  if (s.vocabularyIDs.length < 2 || s.vocabularyIDs.length > 3 || !s.vocabularyIDs.every((v) => vocab.has(v))) problems.push(`${s.id}: 2-3 known vocabulary ids`);
  if (!s.sourceURLs?.length) problems.push(`${s.id}: no sourceURLs`);
}
const have = new Set(catalog.sharks.flatMap((s) => s.questions.flatMap((q) => q.choices.map((c) => c.id))));
const fresh = [...new Set(batch.sharks.flatMap((s) => s.questions.flatMap((q) => q.choices.map((c) => `${c.id} (${c.label})`))))].filter((c) => !have.has(c.split(' ')[0]));
console.log(problems.length ? problems.join('\n') : 'OK');
console.log('New quiz choice ids needing a picture:', fresh.join(', ') || 'none');
