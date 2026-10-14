#!/usr/bin/env bash
# Build Beckify Drive on this Mac and either upload it to TestFlight (default)
# or install it on a plugged-in iPhone (--device).
#
# Signing uses the Apple ID signed in to Xcode (Xcode → Settings → Accounts),
# team 9TR6R5LV8M, automatic signing. No API keys or certificates to manage.
#
#   ios/scripts/drive_ship.sh             # archive + upload to TestFlight
#   ios/scripts/drive_ship.sh --device    # build + install + launch on your iPhone
#
# Each TestFlight upload gets a fresh build number from the clock
# (yyMMddHHmm), so you can run it as often as you like. Marketing version
# stays at the project's MARKETING_VERSION (1.0).
set -euo pipefail

TEAM_ID="9TR6R5LV8M"
SCHEME="BeckifyDrive"
BUNDLE_ID="com.beckify.drive"
PORTAL_URL="https://developer.apple.com/account/resources/identifiers/list"
TESTFLIGHT_URL="https://appstoreconnect.apple.com/apps"

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
}

MODE="testflight"
case "${1:-}" in
  "" | --testflight) MODE="testflight" ;;
  --device) MODE="device" ;;
  -h | --help) usage; exit 0 ;;
  *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="$REPO_ROOT/ios/Beckify.xcodeproj"
OUT="$REPO_ROOT/ios/build/drive"
LOG="$OUT/xcodebuild.log"
mkdir -p "$OUT"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
fail() { printf '\n\033[1;31mxx %s\033[0m\n' "$1" >&2; exit 1; }

# Explain the common signing failures in plain words, then stop.
explain_failure() {
  echo
  echo "Last lines of the build log ($LOG):"
  tail -n 25 "$LOG" || true
  if grep -qiE "carplay|entitlement|capabilit" "$LOG"; then
    echo
    echo "Signing is missing the CarPlay capability. Fix:"
    echo "  1. In the page that just opened, open $BUNDLE_ID"
    echo "  2. Tick 'CarPlay Driving Task' and press Save"
    echo "  3. Run this script again"
    open "$PORTAL_URL" 2>/dev/null || true
  elif grep -qiE "no account|not signed in|No Accounts|authentication" "$LOG"; then
    echo
    echo "Xcode isn't signed in. Open Xcode → Settings → Accounts, add your Apple ID, then run this again."
  fi
  exit 1
}

run_logged() {
  if command -v xcbeautify >/dev/null 2>&1; then
    "$@" 2>&1 | tee "$LOG" | xcbeautify || explain_failure
  else
    "$@" >"$LOG" 2>&1 || explain_failure
  fi
}

step "Checking tools"
# xcode-select often points at the standalone Command Line Tools, which have no
# xcodebuild. Use the installed Xcode for this run instead (no sudo needed).
if ! xcodebuild -version >/dev/null 2>&1; then
  XCODE_APP="$(ls -d /Applications/Xcode.app /Applications/Xcode*.app 2>/dev/null | head -1 || true)"
  [ -n "$XCODE_APP" ] || fail "Xcode isn't installed in /Applications. Install it from the App Store, open it once, then run this again."
  export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
  echo "Using $XCODE_APP (xcode-select points at $(xcode-select -p 2>/dev/null || echo 'nothing'))."
  echo "To make it permanent: sudo xcode-select -s \"$DEVELOPER_DIR\""
  xcodebuild -version >/dev/null 2>&1 \
    || fail "Xcode at $XCODE_APP isn't ready. Open it once to finish setup (accept the license), then run this again."
fi
xcodebuild -version | head -1

step "Updating the repo"
cd "$REPO_ROOT"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "You have local changes; building them as they are (no pull)."
elif [ "$BRANCH" = "main" ]; then
  git pull --ff-only --quiet origin main && echo "main is up to date ($(git rev-parse --short HEAD))."
else
  echo "On branch $BRANCH; building it as it is (no pull)."
fi

if [ "$MODE" = "device" ]; then
  step "Finding your iPhone"
  DEVICES_JSON="$OUT/devices.json"
  xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1 \
    || fail "Couldn't list devices. Plug in your iPhone, unlock it and tap Trust."
  read -r UDID DEVICE_NAME < <(/usr/bin/python3 - "$DEVICES_JSON" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1])).get("result", {}).get("devices", [])
for d in devices:
    hw = d.get("hardwareProperties", {})
    conn = d.get("connectionProperties", {})
    if hw.get("platform") == "iOS" and conn.get("pairingState") == "paired" \
            and conn.get("tunnelState") != "unavailable":
        print(hw.get("udid", ""), d.get("deviceProperties", {}).get("name", "iPhone"))
        break
PY
  ) || true
  [ -n "${UDID:-}" ] || fail "No paired iPhone found. Plug it in, unlock it, tap Trust, and turn on Developer Mode (Settings → Privacy & Security)."
  echo "Using $DEVICE_NAME ($UDID)"

  step "Building $SCHEME for $DEVICE_NAME (a few minutes the first time)"
  DERIVED="$OUT/DerivedData"
  run_logged xcodebuild \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
    -destination "id=$UDID" -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic \
    build
  APP="$(find "$DERIVED/Build/Products/Debug-iphoneos" -maxdepth 1 -name '*.app' | head -1)"
  [ -n "$APP" ] || fail "Build finished but no .app was found in $DERIVED."

  step "Installing and launching"
  xcrun devicectl device install app --device "$UDID" "$APP" >/dev/null
  xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" >/dev/null || true
  echo
  echo "Beckify Drive is on $DEVICE_NAME."
  echo "If iOS says 'Untrusted Developer': Settings → General → VPN & Device Management → trust your Apple ID."
  exit 0
fi

BUILD_NUMBER="${BUILD_NUMBER:-$(date +%y%m%d%H%M)}"
ARCHIVE="$OUT/BeckifyDrive-$BUILD_NUMBER.xcarchive"
EXPORT_OPTIONS="$OUT/ExportOptions.plist"

step "Archiving $SCHEME, build $BUILD_NUMBER (5–10 minutes)"
run_logged xcodebuild \
  -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  archive

cat >"$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

step "Uploading build $BUILD_NUMBER to App Store Connect"
run_logged xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$OUT/export-$BUILD_NUMBER" -allowProvisioningUpdates

echo
echo "Uploaded Beckify Drive 1.0 ($BUILD_NUMBER)."
echo "Apple processes it in about 10–20 minutes, then it appears in the TestFlight app on your iPhone"
echo "(add yourself once under App Store Connect → Beckify Drive → TestFlight → Internal Testing)."
open "$TESTFLIGHT_URL" 2>/dev/null || true
