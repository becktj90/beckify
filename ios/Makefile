# Mac-only app build. Math tests run on Linux or Mac via `swift test`.

.PHONY: test-math build-sim

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
