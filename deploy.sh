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

while IFS=$'\t' read -r device_id device_name; do
    echo "Installing on $device_name…"
    devicectl device install app --device "$device_id" "$APP_PATH"
done <<< "$DEVICE_IDS"
