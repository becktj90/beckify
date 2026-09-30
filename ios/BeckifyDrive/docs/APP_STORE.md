# App Store scaffolding — Beckify Drive

Listing copy for **Beckify Drive** (bundle ID `com.beckify.drive`). This is not the Toolbox app. Toolbox stays `com.beckify.toolbox`, scheme **Beckify**, marketing **1.0.2**, build **162**. Do not archive Toolbox with scheme **BeckifyDrive**, and do not point Toolbox Xcode Cloud workflows at this scheme.

This Linux checkout has not compiled the SwiftUI or CarPlay UI, signed a binary, or uploaded a build.

**Version:** **1.0 (1)** — `MARKETING_VERSION` **1.0**, `CURRENT_PROJECT_VERSION` **1**. First binary for a new App Store record. If TestFlight already has **≥1** for this bundle ID, bump `CURRENT_PROJECT_VERSION` before the next Archive.

**Team:** `9TR6R5LV8M`  
**Display name:** Beckify Drive  
**SKU (suggested):** `beckify-drive`  
**Category:** Utilities. Secondary, if Connect asks: Navigation. The CarPlay entitlement category is **Driving Task**, which is not the Maps entitlement.  
**Age:** 4+  
**Price:** Free, no in-app purchases, no ads  
**Privacy Policy URL:** https://beckify.com/privacy  
**Support / marketing URL:** https://beckify.com  
**Copyright:** 2026 Trevor Beck  
**Contact:** trevorjohnbeck@gmail.com

## Why this is its own target

Apple’s CarPlay guide (June 2026) says a CarPlay app must be designed primarily for its category. Driving Task is `com.apple.developer.carplay-driving-task` (iOS 16+). Putting that entitlement on `com.beckify.toolbox` would ask Apple to treat the field EE toolbox as a driving app and would make Toolbox signing depend on a capability Trevor has not been granted. Beckify Drive is the driving-task app. Toolbox signing is unchanged.

## Listing copy

**Name:** Beckify Drive  
**Subtitle:** EV and OBD gauges  

**Promotional text:**
Glanceable vehicle gauges for a Bluetooth OBD-II adapter. Bolt-leaning, with generic Mode 01 for other cars. On-device. Not a certified diagnostic.

**Description:**

Beckify Drive is an enthusiast dashboard for a Bluetooth Low Energy OBD-II adapter (ELM327-class). The phone shows the denser gauges. CarPlay shows a large, low-clutter summary: charge, power, speed, planning range, temperature, and link status.

Generic vehicles get SAE J1979 Mode 01: speed, RPM, coolant, engine load, throttle, fuel level, 12 V module voltage, and ambient temperature. Fuel level is not shown as battery charge. PID 015B, when the car answers, is hybrid battery remaining life — not a state-of-health certificate.

Chevy Bolt EV and Bolt EUV add a short list of published enhanced PIDs: displayed state of charge, pack temperature, an enthusiast capacity figure in amp-hours, HV current, and motor temperature. Kilowatts stay blank until volts and amps are both measured. This app does not invent pack voltage or battery health.

Planning range uses displayed state of charge only after you type a pack size and Wh/mi. The 60 kWh and 65 kWh shortcuts are GM nominal assumptions, not a reading from the car.

Readings stay on the phone. Nothing is uploaded. Design aid only — not a scan tool, not a warranty battery report, and not the vehicle’s own range estimate.

**Keywords:**
obd,elm327,bolt,ev,carplay,soc,gauge,bluetooth

**What’s New:**
First release. Phone gauges and a CarPlay driving-task scene for a BLE OBD-II adapter. Generic Mode 01, plus published Bolt EV / Bolt EUV PIDs. On-device only.

## CarPlay entitlement — Trevor

The repo already contains the stub. A signed run still fails until Apple puts the capability on the App ID. Unsigned simulator compile (`CODE_SIGNING_ALLOWED=NO`) does not need the profile.

1. Read the current guide: [Requesting CarPlay entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements) and the CarPlay Developer Guide. Agree to the CarPlay entitlement addendum.
2. Request **Driving Task** at [developer.apple.com/contact/carplay](https://developer.apple.com/contact/carplay/). Describe Beckify Drive as an on-device OBD dashboard (charge, power, speed, temperature) for the driver. Do not describe it as navigation, and do not request `com.apple.developer.carplay-maps`.
3. Wait for Apple to add `com.apple.developer.carplay-driving-task` to the team. The app will not appear on the CarPlay home screen until that entitlement is in the provisioning profile. Once it is shipped, every install shows the CarPlay icon — there is no per-user switch.
4. In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list), register App ID `com.beckify.drive` (explicit, not a wildcard) if it does not exist. Enable the **CarPlay Driving Task** capability. Save.
5. Create a new Development profile and a new Distribution profile for that App ID. Download them or let Xcode automatic signing refresh.
6. On a Mac, open `ios/Beckify.xcodeproj`, scheme **BeckifyDrive**, Team **9TR6R5LV8M**. Signing & Capabilities should list CarPlay. Code Signing Entitlements is already `BeckifyDrive/BeckifyDrive.entitlements`. Do not delete that key to “make signing work” and then ship — CarPlay will not launch without it.
7. If automatic signing errors with “provisioning profile doesn’t include the CarPlay entitlement,” the capability is not on the App ID yet. Stop there and finish steps 2–5. Do not strip the entitlement to unblock Toolbox; Toolbox does not use this file.
8. In App Store Connect, create the Beckify Drive record (bundle `com.beckify.drive`, SKU `beckify-drive`). Privacy URL `https://beckify.com/privacy`. Price free, no IAP. Create version **1.0**.
9. Archive scheme **BeckifyDrive** (not Beckify, LookCheck, or KestrelHeavy). Upload **1.0 (1)**. Attach screenshots from a Mac simulator or device. This checkout did not capture them.
10. In App Review notes, say: design aid; Bluetooth is the user’s OBD adapter; no cloud upload; CarPlay templates refresh at most every 10 seconds; missing manufacturer PIDs show “Not read” rather than a guessed battery health. CarPlay must be usable without telling the driver to pick up the phone — connection is established before the drive, and the CarPlay screen shows status only.

CarPlay Simulator is in Additional Tools for Xcode (Hardware folder), or use a head unit. The iOS Simulator alone does not draw the CarPlay templates.

## App privacy

Nutrition label: **Data Not Collected**. Bluetooth and vehicle readings stay on device. Privacy manifest `BeckifyDrive/PrivacyInfo.xcprivacy` declares UserDefaults reason `CA92.1` and no collected data types. `NSPrivacyTracking` is false.

Usage strings (Debug and Release): Bluetooth Always and Bluetooth Peripheral. No location, microphone, camera, or motion.

Background mode `bluetooth-central` is in `BeckifyDrive/Info.plist` so the adapter session can continue while CarPlay is connected and the phone is locked.

## Export compliance

The app does not implement custom cryptography and does not open network connections for OBD data. `ITSAppUsesNonExemptEncryption` is NO. In App Store Connect, answer **No** except the standard HTTPS exemption if the form still appears.

## Screenshots

Not in this repository. Capture on a Mac:

- iPhone 6.7-inch and 6.1-inch (or the sizes Connect currently requires)
- iPad 13-inch if you ship iPad
- CarPlay, from CarPlay Simulator, once the entitlement is on the profile

Show the disconnected state and a connected state only with real or clearly non-shipping data. Do not ship a screenshot that implies a measured battery-health percentage.

## Build

```bash
cd ios
xcodebuild \
  -project Beckify.xcodeproj \
  -scheme BeckifyDrive \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/BeckifyDrive.xcarchive \
  DEVELOPMENT_TEAM=9TR6R5LV8M \
  archive
```

That archive command needs the CarPlay profile. Until then, use `CODE_SIGNING_ALLOWED=NO` and a Simulator destination to compile.
