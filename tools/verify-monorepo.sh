#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
derived_root=${MONOREPO_DERIVED_DATA:-/private/tmp/learning-adventures-verification}
shark_derived="$derived_root/shark"
cat_derived="$derived_root/cat"

cd "$project_dir"
xcodegen generate --spec project.yml

xcodebuild -quiet -project SharkExplorer.xcodeproj -scheme SharkExplorer \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$shark_derived" CODE_SIGNING_ALLOWED=NO build

xcodebuild -quiet -project SharkExplorer.xcodeproj -scheme CatMathAdventure \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$cat_derived" CODE_SIGNING_ALLOWED=NO build

shark_app="$shark_derived/Build/Products/Release-iphoneos/SharkExplorer.app"
cat_app="$cat_derived/Build/Products/Release-iphoneos/CatMathAdventure.app"

test "$(plutil -extract CFBundleIdentifier raw "$shark_app/Info.plist")" = "com.mkilgore.SharkExplorer"
test "$(plutil -extract CFBundleDisplayName raw "$shark_app/Info.plist")" = "Shark Explorer"
test "$(plutil -extract CFBundleIdentifier raw "$cat_app/Info.plist")" = "com.mkilgore.CatMathAdventure"
test "$(plutil -extract CFBundleDisplayName raw "$cat_app/Info.plist")" = "Cat Math Adventure"

test -f "$shark_app/catalog.json"
test -f "$cat_app/cat-catalog.json"
test ! -e "$shark_app/cat-catalog.json"
test ! -e "$cat_app/catalog.json"

if find "$cat_app" -type f -name 'shark-*' | grep -q .; then
  echo "Cat Math product contains Shark artwork" >&2
  exit 1
fi

echo "PASS: both release apps built with independent identities and resources"
