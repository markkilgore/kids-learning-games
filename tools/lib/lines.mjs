import { readFile } from 'node:fs/promises';

export const sharkResources = new URL('../../apps/shark-explorer/Resources/', import.meta.url);
export const catResources = new URL('../../apps/cat-math/Resources/', import.meta.url);

/** Spoken by the shared weekly-lesson player. Keep in step with `WeeklySpokenLines` in WeeklyLessons.swift. */
export const weeklySharedLines = [
  'One!', 'Two!', 'Three!', 'Four!', 'Five!', 'Six!', 'Seven!', 'Eight!', 'Nine!', 'Ten!',
  'You did it!', 'Great job!', 'You got it!', 'Nice thinking!', 'Yes! That is right.'
];

const readJSON = async (name, base) => JSON.parse(await readFile(new URL(name, base), 'utf8'));

async function weeklyLines(name, base) {
  const lines = [...weeklySharedLines];
  for (const week of await readJSON(name, base)) {
    lines.push(week.overview);
    for (const activity of week.activities) {
      for (const step of activity.steps) lines.push(step.spoken ?? step.prompt, step.hint);
    }
  }
  return lines;
}

/** Static interface lines each app speaks, shared with Swift through the bundled `ui-lines.json`. */
async function uiLines(base) {
  return Object.values(await readJSON('ui-lines.json', base));
}

/**
 * JavaScript port of `MissionChallenges.allSpokenLines` and `SharkReading.mark`; the Shark tests fail if they drift.
 * Mission rounds ask for counts and numbers to ten and for each word Henry can read in the sound-it-out sentences.
 */
async function challengeLines(catalog) {
  const reading = await readJSON('shark-reading.json', sharkResources);
  const vowels = new Set('aeiou');
  const isShortVowelWord = (word) => {
    if (word.length !== 2 && word.length !== 3) return false;
    const ending = word.at(-1), vowel = word.at(-2);
    if (!vowels.has(vowel) || vowels.has(ending) || ending === 'r') return false;
    return word.length === 2 || !vowels.has(word[0]);
  };
  const readable = (word) => {
    if (reading.heartWords.includes(word)) return true;
    if (reading.irregular.includes(word) || ![...word].every((letter) => reading.letters.includes(letter))) return false;
    const bases = word.length > 3 && word.endsWith('s') ? [word, word.slice(0, -1)] : [word];
    return bases.some(isShortVowelWord);
  };
  const words = new Set();
  const visit = (value, key = '') => {
    if (Array.isArray(value) && key === 'decodable') {
      for (const sentence of value) for (const word of sentence.toLowerCase().match(/[a-z]+/g) ?? []) words.add(word);
    } else if (value && typeof value === 'object') {
      for (const [childKey, child] of Object.entries(value)) visit(child, childKey);
    }
  };
  for (const shark of catalog.sharks) visit({ discover: shark.discover, topics: shark.topics });
  visit(catalog.expansions);
  const range = (from, to) => Array.from({ length: to - from + 1 }, (_, index) => from + index);
  return [
    ...range(1, 10).map((n) => `Tap the group of ${n}.`),
    ...range(1, 10).map((n) => `Tap the number ${n}.`),
    'Which group has more?',
    'Which group has fewer?',
    ...range(1, 9).map((n) => `What is one more than ${n}?`),
    ...range(2, 10).map((n) => `What is one less than ${n}?`),
    ...[...words].filter((word) => word.length >= 2 && readable(word)).map((word) => `Tap the word: ${word}.`)
  ];
}

export async function sharkLines() {
  const catalog = await readJSON('catalog.json', sharkResources);
  const lines = [];
  const visit = (value, key = '') => {
    if (Array.isArray(value)) {
      if (key === 'decodable' || key === 'earlyReader' || key === 'story') lines.push(...value);
      else value.forEach((item) => visit(item));
    } else if (value && typeof value === 'object') {
      for (const [childKey, child] of Object.entries(value)) visit(child, childKey);
    } else if (typeof value === 'string' && ['completion', 'success', 'retry'].includes(key)) {
      lines.push(value);
    }
  };
  visit(catalog);
  for (const word of catalog.vocabulary) lines.push(word.word);
  return [...lines, ...await challengeLines(catalog), ...await weeklyLines('shark-weeks.json', sharkResources), ...await uiLines(sharkResources)];
}

export async function catLines() {
  const source = await readFile(new URL('../../apps/cat-math/Sources/CatContent.swift', import.meta.url), 'utf8');
  const cats = parseCats(source);
  if (cats.length !== 15) throw new Error(`Expected 15 friends in CatContent.swift, found ${cats.length}`);
  const lines = [];
  for (const [catIndex, cat] of cats.entries()) {
    cat.beats.forEach((beat) => lines.push(...beat.sentences));
    lines.push(
      `You did it! ${cat.name}’s friendship grew.`,
      `Crunch! ${cat.name} loved that tasty treat.`,
      `Yum! ${cat.name} is happily eating from the bowl.`,
      `Ta-da! ${cat.name} performed ${cat.trickName}!`
    );
    // Prompts repeat with period 18 once every story page is revealed, so 18 levels past the last page cover every prompt.
    const lastPage = friendshipNeeded(cat, cat.beats.length - 1);
    for (let friendship = 0; friendship < lastPage + 18; friendship += 1) lines.push(challengePrompt(cat, catIndex, friendship));
  }
  return [...lines, ...await weeklyLines('cat-weeks.json', catResources), ...await uiLines(catResources)];
}

function parseCats(swift) {
  const pattern = /cat\("([^"]+)", "([^"]+)", "[^"]+", "[^"]+", "([^"]+)", "[^"]+", \d+, "([^"]+)", "([^"]+)", "[^"]+", "([^"]+)", "[^"]+", \[\n([\s\S]*?)\n        \]\)/g;
  return [...swift.matchAll(pattern)].map((match) => ({
    name: match[2],
    location: match[3],
    item: match[4],
    items: match[5],
    trickName: match[6],
    beats: [...match[7].matchAll(/\("[^"]+", "[^"]+", \[([^\]]+)\], "([^"]+)"\)/g)].map((beat) => ({
      sentences: [...beat[1].matchAll(/"([^"]+)"/g)].map((sentence) => sentence[1]),
      lead: beat[2]
    }))
  }));
}

const skills = ['counting', 'addition', 'subtraction', 'odd-even', 'skip-5', 'skip-10'];
const chapterTwoSkills = ['addition', 'subtraction', 'doubles', 'odd-even', 'skip-2', 'skip-5'];

/** Ports of `CatDefinition.chapterTwoStart`, `friendshipNeeded(forPage:)` and `storyPage(for:)`. */
const chapterTwoStart = (cat) => (cat.location === 'meadow' ? 12 : 27);
const friendshipNeeded = (cat, page) => (page < 4 ? page * 3 : chapterTwoStart(cat) + (page - 4) * 3);
function storyPage(cat, friendship) {
  let page = 0;
  for (let index = 0; index < cat.beats.length; index += 1) if (friendshipNeeded(cat, index) <= friendship) page = index;
  return page;
}

/**
 * JavaScript port of `MathChallengeFactory.challenge(for:friendship:)`; the Cat tests fail if the two drift.
 * Adaptive difficulty in Swift only swaps in the prompt for friendship + 6 or + 12 once the last story
 * page shows, which this period-18 loop already covers, so it adds no new lines here.
 */
function challengePrompt(cat, catIndex, friendship) {
  const chapterTwo = cat.beats.length > 4 && friendship >= chapterTwoStart(cat);
  const skill = (chapterTwo ? chapterTwoSkills : skills)[(friendship + catIndex) % skills.length];
  const seed = Math.max(1, (friendship + [...cat.name].length) % 9 + 1);
  const lead = cat.beats[storyPage(cat, friendship)].lead;
  const noun = (count) => (count === 1 ? cat.item : cat.items);
  if (chapterTwo) {
    switch (skill) {
      case 'addition': {
        const first = seed + 5;
        return `${lead} ${cat.name} has ${first} ${noun(first)} and finds ${(seed % 5) + 2} more. How many now?`;
      }
      case 'subtraction': {
        const total = seed + 9;
        return `${lead} ${cat.name} counts ${total} ${noun(total)}. ${(seed % 5) + 2} are put away. How many stay?`;
      }
      case 'doubles': {
        const half = seed + 1;
        return `${lead} ${cat.name} has ${half} ${noun(half)} and finds ${half} more. What is double ${half}?`;
      }
      case 'odd-even': {
        const number = seed + 7;
        return `${lead} ${cat.name} finds ${number} ${noun(number)}. Is that odd or even?`;
      }
      default: {
        const step = skill === 'skip-2' ? 2 : 5;
        const start = step === 2 ? 2 * ((seed % 4) + 1) : 5 * ((seed % 3) + 4);
        return `${lead} help ${cat.name} count ${cat.items} by ${step === 2 ? 'twos' : 'fives'}: ${start}, ${start + step}, ${start + 2 * step}. What comes next?`;
      }
    }
  }
  switch (skill) {
    case 'addition': {
      const other = (seed % 4) + 1;
      return `${lead} ${cat.name} has ${seed} ${noun(seed)} and finds ${other} more. How many now?`;
    }
    case 'subtraction': {
      const total = seed + 4;
      const taken = Math.min(3, seed);
      return `${lead} ${cat.name} counts ${total} ${noun(total)}. ${taken} ${taken === 1 ? 'is' : 'are'} put away. How many stay?`;
    }
    case 'odd-even': {
      const number = seed + 3;
      return `${lead} ${cat.name} finds ${number} ${noun(number)}. Is that odd or even?`;
    }
    case 'skip-5': {
      const start = 5 * (seed % 3 + 1);
      return `${lead} help ${cat.name} count ${cat.items} by fives: ${start}, ${start + 5}, ${start + 10}. What comes next?`;
    }
    case 'skip-10': {
      const start = 10 * (seed % 3 + 1);
      return `${lead} help ${cat.name} count ${cat.items} by tens: ${start}, ${start + 10}, ${start + 20}. What comes next?`;
    }
    default:
      return `${lead} how many ${noun(seed)} did ${cat.name} find?`;
  }
}
