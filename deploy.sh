#!/bin/zsh
# Build NebulaSwift and install it on the device (no launch).
set -e

PROJECT="NebulaSwift.xcodeproj"
SCHEME="NebulaSwift"
CONFIGURATION="Debug"

cd "$(dirname "$0")"

# Codesign needs the login keychain; unlock it first if this session sees it locked.
if ! security show-keychain-info login.keychain >/dev/null 2>&1; then
    echo "Login keychain is locked — enter your macOS password to unlock it."
    security unlock-keychain login.keychain
fi

BUILD_ARGS=(-project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination 'generic/platform=iOS')

xcodebuild "${BUILD_ARGS[@]}" \
    -quiet \
    -allowProvisioningUpdates \
    build

# Uses the default DerivedData location (no -derivedDataPath), so ask xcodebuild where it put the app.
APP_PATH=$(xcodebuild "${BUILD_ARGS[@]}" -showBuildSettings 2>/dev/null | awk -F' = ' '/ CODESIGNING_FOLDER_PATH /{print $2; exit}')

# Discover paired physical devices instead of hardcoding names/UDIDs.
DEVICE_IDS=$(devicectl list devices --json-output - 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
for dev in data["result"]["devices"]:
    hw = dev.get("hardwareProperties", {})
    conn = dev.get("connectionProperties", {})
    if hw.get("reality") == "physical" and conn.get("pairingState") == "paired":
        identifier = dev["identifier"]
        name = dev.get("deviceProperties", {}).get("name", identifier)
        print(f"{identifier}\t{name}")
')

if [[ -z "$DEVICE_IDS" ]]; then
    echo "No paired physical devices found." >&2
    exit 1
fi

# Paired devices stay listed while they're away, and devicectl reports every tunnel as disconnected
# until something opens one, so probe each device and skip the ones that don't answer.
INSTALLED=0
while IFS=$'\t' read -r device_id device_name; do
    if ! devicectl device info details --device "$device_id" --timeout 15 </dev/null >/dev/null 2>&1; then
        echo "Skipping $device_name (not reachable)."
        continue
    fi
    echo "Installing on $device_name…"
    # A device can answer the probe and still refuse the install (e.g. while locked); move on to the next one.
    if devicectl device install app --device "$device_id" "$APP_PATH" </dev/null; then
        INSTALLED=$((INSTALLED + 1))
    else
        echo "Install on $device_name failed, skipping it." >&2
    fi
done <<< "$DEVICE_IDS"

if (( INSTALLED == 0 )); then
    echo "Couldn't install on any of the paired devices." >&2
    exit 1
fi
