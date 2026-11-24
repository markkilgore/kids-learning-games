#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
config_dir=.build/ipad-deploy
usage() {
    echo "Usage: tools/deploy-ipads.sh [setup|both|kate|henry]" >&2
}

case "${1:-both}" in
    setup)
        xcrun devicectl list devices
        echo 'Enter the hardware UDID of each iPad (from the list or Finder).'
        printf 'Kate’s iPad UDID: '; read -r kate
        printf 'Henry’s iPad UDID: '; read -r henry
        printf 'Apple development team ID (10 characters): '; read -r team
        for udid in "$kate" "$henry"; do
            if ! printf '%s\n' "$udid" | grep -Eq '^([[:xdigit:]]{8}-[[:xdigit:]]{16}|[[:xdigit:]]{40})$'; then
                echo 'Expected an iPad hardware UDID.' >&2
                exit 1
            fi
        done
        if [ "$kate" = "$henry" ] || ! printf '%s\n' "$team" | grep -Eq '^[A-Z0-9]{10}$'; then
            echo 'Use two distinct iPad UDIDs and a 10-character team ID.' >&2
            exit 1
        fi
        mkdir -p "$config_dir"
        printf '%s\n' "$team" "$kate" "$henry" > "$config_dir/devices.tmp"
        mv "$config_dir/devices.tmp" "$config_dir/devices"
        echo 'Saved locally. Run tools/deploy-ipads.sh to update both iPads.'
        exit 0
        ;;
    both|kate|henry) ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
esac

if [ ! -f "$config_dir/devices" ]; then
    echo 'First run tools/deploy-ipads.sh setup.' >&2
    exit 1
fi
{ read -r team; read -r kate; read -r henry; } < "$config_dir/devices"
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
if [ "${1:-both}" != henry ]; then deploy kate CatMathAdventure "$kate" || status=1; fi
if [ "${1:-both}" != kate ]; then deploy henry SharkExplorer "$henry" || status=1; fi
exit "$status"
