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

Run tests on an installed simulator by replacing `<UDID>`:

```sh
xcodebuild -project SharkExplorer.xcodeproj -scheme SharkExplorer \
  -destination 'platform=iOS Simulator,id=<UDID>' test

xcodebuild -project SharkExplorer.xcodeproj -scheme CatMathAdventure \
  -destination 'platform=iOS Simulator,id=<UDID>' test
```

## Cat Math narration

Cat Math uses bundled ElevenLabs clips when a line exists in `cat-audio-manifest.json`, with the on-device Apple voice as an offline fallback for any line not yet generated. Generate or refresh the complete Cat script from the repository root:

```sh
ELEVENLABS_API_KEY=<key> npm --prefix tools run cat-audio
```

The generator defaults to the bright, warm **Bella** educational voice and `eleven_multilingual_v2`; set `ELEVENLABS_VOICE_ID` or `ELEVENLABS_MODEL_ID` to override either one. API credentials are generation-time secrets and are never included in the iPad app.

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
