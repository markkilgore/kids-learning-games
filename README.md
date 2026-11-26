# Learning Adventures iPad monorepo

This repository builds two independent child-facing iPad apps from a small set of shared learning packages:

- **Shark Explorer** (`com.mkilgore.SharkExplorer`) for Henry
- **Cat Math Adventure** (`com.mkilgore.CatMathAdventure`) for Kate

The apps have separate targets, schemes, bundle identifiers, display names, icons, launch screens, content, release settings, and persistence namespaces. Neither application target compiles the other app’s source or resources.

## Quick start

Generate the Xcode project after changing `project.yml`:

```sh
xcodegen generate --spec project.yml
```

Open `SharkExplorer.xcodeproj`, then select either the **SharkExplorer** or **CatMathAdventure** scheme.

Command-line builds:

```sh
xcodebuild -project SharkExplorer.xcodeproj -scheme SharkExplorer \
  -destination 'generic/platform=iOS Simulator' build

xcodebuild -project SharkExplorer.xcodeproj -scheme CatMathAdventure \
  -destination 'generic/platform=iOS Simulator' build
```

The quick check before a commit, and the slow one afterwards:

```sh
tools/test.sh fast   # content checks and unit tests for both apps, about two minutes
tools/test.sh slow   # on-screen walkthroughs, including all 30 shark missions, about 30 minutes
```

To run a scheme by hand on an installed simulator, replace `<UDID>`:

```sh
xcodebuild -project SharkExplorer.xcodeproj -scheme SharkExplorer \
  -destination 'platform=iOS Simulator,id=<UDID>' test

xcodebuild -project SharkExplorer.xcodeproj -scheme CatMathAdventure \
  -destination 'platform=iOS Simulator,id=<UDID>' test
```

## Narration and sound

Both apps speak with bundled ElevenLabs recordings; the on-device Apple voice is only a fallback for a line with no clip. Put `ELEVENLABS_API_KEY=<key>` in a `.env` file at the repository root (it is git-ignored and never shipped), then:

```sh
npm --prefix tools run audio        # Shark Explorer
npm --prefix tools run cat-audio    # Cat Math Adventure
npm --prefix tools run validate     # fails if any spoken line lacks a clip
```

Each generator collects every line its app can speak — catalog text, Cat Math prompts, weekly lessons, and the interface lines in each app’s `Resources/ui-lines.json` — and only generates what is missing. Add `-- --dry-run` to see the clip and character count first, and `-- --prune` to delete clips that are no longer spoken. Both apps use the **Bella** voice and `eleven_v3`; set `ELEVENLABS_VOICE_ID` or `ELEVENLABS_MODEL_ID` to override, which regenerates every clip. Run `xcodegen generate --spec project.yml` afterwards so new clips join the app.

Interface sounds (tap, correct, try again, pop, unlock, celebrate, page) are recorded with the ElevenLabs sound-effects API by `npm --prefix tools run sfx:recorded` (the key needs the `sound_generation` permission; macOS only). `npm --prefix tools run sfx` writes synthesized stand-ins instead and needs no key. Parents can switch narration and sound effects off in each app’s Parent Settings.

## Checking every screen

Each scheme includes a tour test that walks the whole app and attaches a screenshot of every screen. To also save them as files:

```sh
TEST_RUNNER_TOUR_DIR=/tmp/tour xcodebuild -project SharkExplorer.xcodeproj -scheme CatMathAdventure \
  -destination 'platform=iOS Simulator,id=<UDID>' -only-testing:CatMathAdventureTourUITests test
```

See [docs/architecture.md](docs/architecture.md) for the assessment, migration stages, configuration contract, persistence strategy, and target structure. Run `tools/verify-monorepo.sh` for release-build and product-isolation checks.

## Weekly classroom lessons

Add one dated entry to `apps/cat-math/Resources/cat-weeks.json` and one to
`apps/shark-explorer/Resources/shark-weeks.json` for each reviewed recap.
Use the recap’s Monday and Sunday as ISO dates and a short date range for
display. Write a child-facing overview and two activities for each child.
Give each new activity a permanent, unique ID so installed copies retain
completion when the content is updated.

Each step provides a prompt, visual scene, choices, the exact correct
choice, and a hint. Supply `spoken` when the listening cue differs from the
on-screen prompt. For counting steps, `moves` sets the number of taps.
A track moves the guide forward; otherwise each tap removes one character
from the scene (use one emoji per object). Build both apps to deliver the
new week. The home screen uses the iPad’s local date to feature the most
recent available recap and lists earlier ones under Previous Weeks.

## Update the family iPads

Sign in to your Apple Account in Xcode and connect an unlocked iPad. Accept
Trust and enable Developer Mode when prompted. Copy the iPad's hardware UDID
from the Identifier field in Xcode's **Window → Devices and Simulators**.
Run `tools/deploy-ipads.sh setup`, enter the UDID for the child whose iPad is
connected, and press Enter at the other child's prompt. Enter your
10-character Apple development team ID. You can run setup again to add the
second iPad, leaving any saved values blank at the prompts to keep them.
The mapping lives in the ignored `.build` directory.

Install XcodeGen with `brew install xcodegen` if needed. With the iPads
reachable from Xcode, run `tools/deploy-ipads.sh` to update every configured
iPad. It generates the project, signs each app with your team, and installs it
over the previous copy on the assigned device. Use `tools/deploy-ipads.sh kate` or
`tools/deploy-ipads.sh henry` to update one device. A failed device can be
retried individually. Free Personal Team profiles expire seven days from issue.

To install both games on your own iPad for testing, pass its hardware UDID.
This uses your saved development team and leaves the family device assignments
as they are.

```sh
tools/deploy-ipads.sh --device YOUR_IPAD_UDID
```

You can also use `tools/deploy-ipads.sh both --device YOUR_IPAD_UDID`.
To install a single game on an explicit device, use
`tools/deploy-ipads.sh kate --device YOUR_IPAD_UDID` for Cat Math Adventure or
`tools/deploy-ipads.sh henry --device YOUR_IPAD_UDID` for Shark Explorer.

If you haven't run setup, supply your development team ID for this run.

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID tools/deploy-ipads.sh --device YOUR_IPAD_UDID
```
