#!/usr/bin/env bash
# Install Beckify Drive (Debug) on a booted simulator and screenshot fixture states.
# Usage: capture_drive_screenshots.sh <udid> <app path> <out dir> <full|core> [content size]
set -euo pipefail
udid="$1" app="$2" out="$3" set_name="$4" content_size="${5:-}"

xcrun simctl install "$udid" "$app"
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
if [ -n "$content_size" ]; then
  xcrun simctl ui "$udid" content_size "$content_size"
fi
mkdir -p "$out"

shoot() {
  local name="$1" appearance="$2" scroll="${3:-}"
  xcrun simctl ui "$udid" appearance "$appearance"
  xcrun simctl terminate "$udid" com.beckify.drive 2>/dev/null || true
  if [ -n "$scroll" ]; then
    xcrun simctl launch "$udid" com.beckify.drive -BeckifyDriveFixture "$name" -BeckifyDriveScroll "$scroll"
  else
    xcrun simctl launch "$udid" com.beckify.drive -BeckifyDriveFixture "$name"
  fi
  sleep 5
  xcrun simctl io "$udid" screenshot "$out/${name}${scroll:+-$scroll}.png"
}

# Every device: the hero in both directions, the dense card sections, and each profile type.
shoot boltDriving dark
shoot boltDriving dark battery
shoot boltDriving dark energy
shoot boltRegen dark
shoot boltPartial dark battery
shoot genericEV dark
shoot iceGeneric dark

if [ "$set_name" = "full" ]; then
  shoot boltDriving dark phone
  shoot fullBolt dark
  shoot boltPartial dark
  shoot noAdapter dark
  shoot partialGeneric dark
  shoot iceGeneric dark phone
  shoot genericEV dark phone
  shoot boltLight light
fi
ls -la "$out"
