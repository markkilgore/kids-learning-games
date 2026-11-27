#!/bin/sh
# Usage: tools/test.sh [fast|slow|all]
#   fast  content checks and both apps' unit tests (about two minutes). Run this before every commit.
#   slow  the on-screen walkthroughs: every screen of both apps and every animal's mission (about 35 minutes).
#         Run it after a push, or before sending a build to the iPads.
# TEST_SIMULATOR names the simulator to use; the default is the kids' iPad size.
set -eu
cd "$(dirname "$0")/.."
mode=${1:-fast}
simulator=${TEST_SIMULATOR:-iPad (A16)}
derived=${TEST_DERIVED_DATA:-.build/dd}

run() {
    scheme=$1
    shift
    xcodebuild -quiet -project SharkExplorer.xcodeproj -scheme "$scheme" \
        -destination "platform=iOS Simulator,name=$simulator" -derivedDataPath "$derived" "$@" test
}

fast() {
    node tools/validate-content.mjs
    run SharkExplorer -only-testing:SharkExplorerTests
    run CatMathAdventure -only-testing:CatMathAdventureTests
}

slow() {
    run CatMathAdventure -skip-testing:CatMathAdventureTests
    run SharkExplorer -skip-testing:SharkExplorerTests
}

xcodegen generate --spec project.yml >/dev/null
case "$mode" in
    fast) fast ;;
    slow) slow ;;
    all) fast; slow ;;
    *) echo "Usage: tools/test.sh [fast|slow|all]" >&2; exit 2 ;;
esac
echo "PASS: $mode tests"
