# Mac-only app build. Math tests run on Linux or Mac via `swift test`.

.PHONY: test-math build-sim drive-device drive-testflight

test-math:
	cd BeckifyMath && swift test

# Requires Xcode on macOS. Toolbox Archive / Xcode Cloud stays on scheme Beckify.
build-sim:
	xcodebuild \
	  -project Beckify.xcodeproj \
	  -scheme Beckify \
	  -destination 'generic/platform=iOS Simulator' \
	  -configuration Debug \
	  CODE_SIGNING_ALLOWED=NO \
	  build

# Beckify Drive on your Mac, signed with the Apple ID in Xcode → Settings → Accounts.
drive-device:
	./scripts/drive_ship.sh --device

drive-testflight:
	./scripts/drive_ship.sh
