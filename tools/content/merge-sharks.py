#!/usr/bin/env python3
"""Add a batch of sharks to the Shark Explorer catalog and lay every map page out again.

Usage: tools/content/merge-sharks.py [batch.json [photos.json]]

batch.json   {"sharks": [...], "expansions": [...], "vocabulary": [...]} in the catalog's own shape.
             Each shark also needs "map" (a page id from the catalog's "maps") and its unlock rule:
             "unlockAt" (missions finished), and optionally "unlockStars" or "unlockSuperStars".
photos.json  {"<shark id>": {"imageAsset", "imageAuthor", "imageLicense", "imageSourceURL"}}; fills the
             credit fields, so the batch may leave them as "TBD".

With no arguments it only re-does the layout, which is safe to run at any time.
Sharks already in the catalog with the same id are replaced. Afterwards run tools/test.sh fast.
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CATALOG = os.path.join(ROOT, 'apps/shark-explorer/Resources/catalog.json')
ART = os.path.join(ROOT, 'apps/shark-explorer/Resources/Art')
# Keys every shark has, in catalog order; the optional ones sit right after the key named here.
OPTIONAL_AFTER = {'unlockStars': 'unlockAt', 'unlockSuperStars': 'unlockAt', 'map': 'mapY'}
# Each page is a staggered grid with room for 14 markers: rows of 5, 4 and 5.
ROWS = [[(0.1 + i * 0.2, 0.2) for i in range(5)], [(0.2 + i * 0.2, 0.5) for i in range(4)], [(0.1 + i * 0.2, 0.8) for i in range(5)]]

def ordered(shark, keys):
    out = {}
    for key in keys:
        out[key] = shark[key]
        for optional, after in OPTIONAL_AFTER.items():
            if after == key and optional in shark: out[optional] = shark[optional]
    return out

def layout(sharks, pages):
    for page in pages:
        here = [s for s in sharks if s['map'] == page]
        if len(here) > 14: sys.exit(f'{page}: {len(here)} sharks, but a page holds 14. Add a page to "maps".')
        # Spread a short list over the three rows instead of filling the top row first.
        per = [0, 0, 0]
        for n in range(len(here)): per[n % 3] += 1
        picked = [row[(len(row) - count) // 2:][:count] for row, count in zip(ROWS, per)]
        for n, shark in enumerate(here):
            shark['mapX'], shark['mapY'] = round(picked[n % 3][n // 3][0], 2), picked[n % 3][n // 3][1]

def main():
    catalog = json.load(open(CATALOG))
    pages = [page['id'] for page in catalog['maps']]
    keys = [k for k in catalog['sharks'][0] if k not in OPTIONAL_AFTER]
    if len(sys.argv) > 1:
        batch = json.load(open(sys.argv[1]))
        photos = json.load(open(sys.argv[2])) if len(sys.argv) > 2 else {}
        ids = {s['id'] for s in batch['sharks']}
        catalog['sharks'] = [s for s in catalog['sharks'] if s['id'] not in ids]
        catalog['expansions'] = [e for e in catalog['expansions'] if e['sharkID'] not in ids]
        for shark in batch['sharks']:
            shark.update({k: v for k, v in photos.get(shark['id'], {}).items() if k.startswith('image')})
            missing = set(keys) - set(shark)
            if missing or shark.get('map') not in pages: sys.exit(f"{shark['id']}: missing {sorted(missing)} or unknown map {shark.get('map')}")
            catalog['sharks'].append(shark)
        catalog['expansions'] += batch['expansions']
        known = {word['id'] for word in catalog['vocabulary']}
        catalog['vocabulary'] += [word for word in batch.get('vocabulary', []) if word['id'] not in known]
    layout(catalog['sharks'], pages)
    catalog['sharks'] = [ordered(s, keys) for s in catalog['sharks']]
    with open(CATALOG, 'w') as out:
        json.dump(catalog, out, indent=2, ensure_ascii=False)
        out.write('\n')
    words = {word['id'] for word in catalog['vocabulary']}
    used = {i for s in catalog['sharks'] for i in s['vocabularyIDs']}
    shared = {'trees', 'forest', 'climbs', 'sky', 'night', 'lunch', 'fly', 'flies'}  # QuestionRoundView.sharedArt
    choices = {c['id'] for s in catalog['sharks'] for q in s['questions'] for c in q['choices']} - shared
    print(f"{len(catalog['sharks'])} sharks on {len(pages)} map pages")
    print('Ocean Words no shark uses:', sorted(words - used) or 'none')
    print('Ocean Words not defined:', sorted(used - words) or 'none')
    print('Quiz choices with no picture:', sorted(c for c in choices if not os.path.exists(f'{ART}/choice-{c}.png')) or 'none')
    print('Next: update the shark count in ContentStore.swift, validate-content.mjs and the tests, add the sharks to')
    print('SharkAppConfiguration.swift and the tour test, record audio, then run tools/test.sh fast.')

main()
