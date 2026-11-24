# Art brief

Illustrations that replace emoji and drawn placeholders. The apps already look for these files and
fall back to the current emoji or drawn shapes when one is missing, so art can arrive a piece at a time.

Everything to generate is listed in `tools/art-prompts.json`:

- `cats`: ten cat portraits for Cat Math, using `catStyle`. The app shows each one as a round medallion,
  so keep the cat centred with a plain background.
- `scenes`: the House and Garden backdrops for Cat Math and the ocean map for Shark Explorer. Each names
  the style key to use.

For every entry, combine the named style with the entry's `prompt`, generate one PNG at the given `size`,
and save it at `file` (paths are relative to the repository root). Do not change any other file.

Rules for every image: suitable for ages 5 to 7; no text, letters, numbers, logos or watermarks; no real
people; no existing characters from books, films or games.

After adding files, run `xcodegen generate --spec project.yml` and the tour tests in the README to see
them in place.
