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

See [docs/architecture.md](docs/architecture.md) for the assessment, migration stages, configuration contract, persistence strategy, and target structure. Run `tools/verify-monorepo.sh` for release-build and product-isolation checks.
