#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
config_dir=.build/ipad-deploy
config_file=$config_dir/devices
usage() {
    echo "Usage: tools/deploy-ipads.sh [setup|both|kate|henry|--device UDID]" >&2
    echo "       tools/deploy-ipads.sh both --device UDID" >&2
}

is_hardware_udid() {
    printf '%s\n' "$1" | grep -Eq '^([[:xdigit:]]{8}-[[:xdigit:]]{16}|[[:xdigit:]]{40})$'
}

select_xcode() {
    if xcrun --find devicectl >/dev/null 2>&1; then return; fi
    if [ -z "${DEVELOPER_DIR:-}" ] && [ -x /Applications/Xcode.app/Contents/Developer/usr/bin/devicectl ]; then
        export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
        if xcrun --find devicectl >/dev/null 2>&1; then return; fi
    fi
    echo 'Deployment requires full Xcode with Swift 6 support (Xcode 16 or later).' >&2
    echo 'Install or update Xcode and open it once to finish setup.' >&2
    echo 'For a custom Xcode location, export DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer and retry.' >&2
    exit 1
}

team=
kate=
henry=
if [ -f "$config_file" ]; then
    { read -r team; read -r kate; read -r henry; } < "$config_file"
fi

if [ "${1:-}" = both ] && [ "${2:-}" = --device ]; then
    shift
fi
target=${1:-both}
if [ "$target" = --device ]; then
    if [ "$#" -ne 2 ]; then usage; exit 2; fi
    testing_udid=$2
    if ! is_hardware_udid "$testing_udid"; then
        echo 'Expected an iPad hardware UDID for --device.' >&2
        exit 2
    fi
elif [ "$#" -gt 1 ]; then
    usage
    exit 2
fi
case "$target" in
    setup)
        echo 'Copy the hardware UDID from Finder or Xcode’s Devices and Simulators window.'
        echo 'Press Enter to keep a saved value or skip an iPad you don’t have.'
        printf 'Kate’s iPad UDID: '; read -r entered_kate
        printf 'Henry’s iPad UDID: '; read -r entered_henry
        printf 'Apple development team ID (10 characters): '; read -r entered_team
        kate=${entered_kate:-$kate}
        henry=${entered_henry:-$henry}
        team=${entered_team:-$team}
        if [ -z "$kate$henry" ]; then
            echo 'Enter at least one iPad hardware UDID.' >&2
            exit 1
        fi
        for udid in "$kate" "$henry"; do
            [ -n "$udid" ] || continue
            if ! is_hardware_udid "$udid"; then
                echo 'Expected an iPad hardware UDID.' >&2
                exit 1
            fi
        done
        if [ -n "$kate" ] && printf '%s\n' "$kate" | grep -Fxiq "$henry"; then
            echo 'Use distinct UDIDs when setting up two iPads.' >&2
            exit 1
        fi
        if ! printf '%s\n' "$team" | grep -Eq '^[A-Z0-9]{10}$'; then
            echo 'Enter a 10-character Apple development team ID.' >&2
            exit 1
        fi
        mkdir -p "$config_dir"
        config_tmp=$(mktemp "$config_dir/devices.XXXXXX")
        trap 'rm -f "$config_tmp"' EXIT
        printf '%s\n' "$team" "$kate" "$henry" > "$config_tmp"
        mv "$config_tmp" "$config_file"
        echo 'Saved locally. Run tools/deploy-ipads.sh to update the configured iPads.'
        exit 0
        ;;
    --device)
        team=${DEVELOPMENT_TEAM:-$team}
        if ! printf '%s\n' "$team" | grep -Eq '^[A-Z0-9]{10}$'; then
            echo 'Set DEVELOPMENT_TEAM to your 10-character Apple development team ID or run tools/deploy-ipads.sh setup.' >&2
            exit 1
        fi
        selected_udids=$testing_udid
        ;;
    both|kate|henry)
        if [ ! -f "$config_file" ]; then
            echo 'First run tools/deploy-ipads.sh setup.' >&2
            exit 1
        fi
        case "$target" in
            kate) selected_udids=$kate ;;
            henry) selected_udids=$henry ;;
            both) selected_udids=$kate$henry ;;
        esac
        ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
esac

if [ -z "$selected_udids" ]; then
    echo "No iPad configured for $target. Run tools/deploy-ipads.sh setup." >&2
    exit 1
fi
select_xcode
if ! command -v xcodegen >/dev/null 2>&1; then
    echo 'XcodeGen is required. Install it with brew install xcodegen.' >&2
    exit 1
fi
xcodegen generate --spec project.yml

deploy() {
    child=$1
    scheme=$2
    udid=$3
    derived="$PWD/$config_dir/$child"
    echo "Building $scheme for $child …"
    xcodebuild -quiet -project SharkExplorer.xcodeproj -scheme "$scheme" \
        -configuration Release -destination "platform=iOS,id=$udid" -destination-timeout 20 \
        -derivedDataPath "$derived" -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
        "DEVELOPMENT_TEAM=$team" CODE_SIGN_STYLE=Automatic build || return 1
    xcrun devicectl device install app --device "$udid" \
        "$derived/Build/Products/Release-iphoneos/$scheme.app" || return 1
    echo "Installed $scheme for $child."
}

status=0
if [ "$target" = --device ]; then
    deploy testing CatMathAdventure "$testing_udid" || status=1
    deploy testing SharkExplorer "$testing_udid" || status=1
else
    if [ "$target" != henry ] && [ -n "$kate" ]; then deploy kate CatMathAdventure "$kate" || status=1; fi
    if [ "$target" != kate ] && [ -n "$henry" ]; then deploy henry SharkExplorer "$henry" || status=1; fi
fi
exit "$status"
