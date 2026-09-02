# Privacy Policy — Beckify iOS

**Product:** Beckify (bundle ID `com.beckify.toolbox`)  
**Developer:** Trevor Beck  
**Contact:** trevorjohnbeck@gmail.com  
**Status:** Draft for App Store Connect. The intended App Store Connect privacy URL is https://beckify.com/privacy once that URL returns HTTP 200. As of this PR, https://beckify.com/privacy returns 404; do not treat the live site as already hosting this policy. Until it returns 200, the only live public HTTPS copy is https://github.com/becktj90/beckify/blob/main/ios/docs/PRIVACY.md.

Apple’s App Privacy nutrition label for this app is **Data Not Collected**. Sensor readings and Saved Jobs stay on the device. This repository has not signed a build, uploaded TestFlight, or submitted to the App Store. Developer Program enrollment is reported by Trevor, not verified here.

## What the app does not collect

Beckify does not collect, sell, share, or transmit personal data for advertising, analytics, or tracking.

- No analytics or crash-reporting SDKs
- No advertising identifier (IDFA) and no tracking across apps or websites
- No user accounts, sign-in, or cloud sync
- No ads, store checkout, or Amazon links
- The app does not wrap or load beckify.com in a web view
- The app is a toolbox of field calculators, homework calculators, and sensors. It is not a website project gallery.

Optional links the user may tap (https://beckify.com and `mailto:trevorjohnbeck@gmail.com`) open in the system browser or mail app. Those destinations are not part of in-app data collection.

## Sensors and permissions (on-device only)

Permissions are requested only when the related tool is used, not at launch (except iOS may show the system sheet the first time that tool starts).

| Permission | Tools | What happens |
| --- | --- | --- |
| Microphone | Noise Meter | Relative dBFS from live audio. Not recorded, not uploaded, not a calibrated SLM. |
| Bluetooth | BLE Scanner | Nearby BLE advertisements (name, identifier, RSSI, advertised service UUIDs). Not uploaded. |
| Location (When In Use) | Position; Wi-Fi Path (SSID / 0…1 amplitude / optional GPS coverage sketch) | Coordinates, current SSID, Apple `signalStrength` 0…1, on-device heatmap samples. Not used at launch. Not uploaded. |

CoreMotion (level, magnetometer, barometer, g-force) does not use those permission strings. Battery and thermal state are local diagnostics.

iOS does **not** give third-party apps Wi-Fi RSSI in dBm. The Wi-Fi Path tool shows Apple’s public 0…1 `signalStrength` (percent and bars) and an on-device coverage sketch. It does not invent dBm.

## What stays on the device

Named **Saved Jobs** are lightweight on-device notes (homework or field snapshots of calculator inputs/results or sensor numbers the user chooses to save). They use Apple’s `UserDefaults`. They are not a project gallery and are not uploaded. Deleting the app removes them, subject to the user’s device backup settings.

## Children’s privacy

The app is rated 4+ and does not collect data from anyone, including children.

## Changes

If this policy changes, the updated text will replace this draft. This document is not an App Store submission and does not mean the app is listed, signed, or in TestFlight. When https://beckify.com/privacy returns HTTP 200, App Store Connect should use that URL; until then use the GitHub blob above.

## Contact

Questions: trevorjohnbeck@gmail.com
