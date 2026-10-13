# App Store scaffolding — Beckify Drive

Listing copy for **Beckify Drive** (bundle ID `com.beckify.drive`). This is not the Toolbox app. Toolbox stays `com.beckify.toolbox`, scheme **Beckify**, marketing **1.0.7**, build **313**. Do not archive Toolbox with scheme **BeckifyDrive**, and do not point Toolbox Xcode Cloud workflows at this scheme.

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

Apple’s CarPlay guide (June 2026) says a CarPlay app must be designed primarily for its category. Driving Task is `com.apple.developer.carplay-driving-task` (iOS 16+). Putting that entitlement on `com.beckify.toolbox` would ask Apple to treat the field EE toolbox as a driving app and would make Toolbox signing depend on the CarPlay capability. Apple granted Driving Task for Beckify Drive (2026-10-13); it is enabled only on `com.beckify.drive`. Beckify Drive is the driving-task app. Toolbox signing is unchanged.

## Listing copy

**Name:** Beckify Drive  
**Subtitle:** EV and OBD gauges  

**Promotional text:**
A glanceable dashboard for a Bluetooth OBD-II adapter and your phone's own sensors. Bolt EV battery, motor, and 12 V telemetry; generic Mode 01 for other cars. On-device. Not a certified diagnostic.

**Description:**

Beckify Drive is an enthusiast dashboard for a Bluetooth Low Energy OBD-II adapter (ELM327-class). The phone shows the denser dashboard: a speed hero, card sections with 60-second sparklines, and phone-sensor cards. CarPlay shows a large, low-clutter summary: charge, power (est.), regen, speed, planning range, weather-adjusted range (est.), efficiency (est.), temperature, and link status. It refreshes at most every 10 seconds and keeps working with the phone locked.

Generic vehicles get SAE J1979 Mode 01: speed, RPM, coolant, engine load, throttle, fuel level, 12 V module voltage, and ambient temperature. Fuel level is not shown as battery charge. PID 015B, when the car answers, is hybrid battery remaining life — not a state-of-health certificate.

Chevy Bolt EV and Bolt EUV switch the dashboard to electrical telemetry in three groups. Battery: displayed state of charge, pack temperature, HV current with drive and regen, an enthusiast capacity figure in amp-hours, and remaining life (HD). Motor: motor temperature and drive / regen from the sign of HV current. Power electronics: the 12 V accessory bus; inverter, DC-DC, and charger cards say "Not reported by this vehicle" because no verified request is published. The top of the screen shows power, wheel torque, and regen. Power and torque are labeled estimates from measured current and a 350 V nominal pack. This app does not read pack voltage or invent battery health.

Energy & range, all labeled estimates: real Wh/mi from charge used over GPS miles, range adjusted for temperature and headwind, a regen score, a trip energy split, a fast-charge temperature coach, and a capacity trend over months.

Phone sensors, all on device: GPS speed, altitude, heading, a G-force plot lined up with the direction you drive, barometric pressure, phone battery, and a trip (distance, time, average, and max speed). Location and Motion & Fitness are asked for only when you tap a card that needs them.

Every value shows whether it is live, a few seconds old, or not reported. A blank card was not read from the car. Estimates carry an "est." badge and state their assumption.

Planning range uses displayed state of charge only after you type a pack size and Wh/mi. The 60 kWh and 65 kWh shortcuts are GM nominal assumptions, not a reading from the car.

Vehicle readings stay on the phone. The only network call is a weather lookup with your location rounded to about 1 km. Design aid only — not a scan tool, not a warranty battery report, and not the vehicle’s own range estimate.

**Keywords:**
obd,elm327,bolt,ev,carplay,soc,gauge,regen,torque,g-force

**What’s New:**
First release. Phone dashboard and a CarPlay driving-task scene for a BLE OBD-II adapter. Generic Mode 01, plus published Bolt EV / Bolt EUV battery, motor, and 12 V telemetry. Phone-sensor cards for GPS speed, heading, G-force, barometer, and trip. Units, card order, and appearance are adjustable. On-device only.

## CarPlay entitlement — Trevor

**Status:** Apple granted the CarPlay Driving Task entitlement to the team on 2026-10-13 (email "CarPlay Driving Task App entitlement confirmation"). Steps 1–3 are done; do not file another request. The Beckify Drive record and version **1.0** already exist in App Store Connect (step 8). Next: step 4 (enable the capability on the App ID), then steps 5–7, 9 and 10.

The repo already contains the entitlement. A signed build fails with a provisioning error until **CarPlay Driving Task** is enabled on App ID `com.beckify.drive` (step 4). Unsigned simulator compile (`CODE_SIGNING_ALLOWED=NO`) does not need the profile.

1. Read the current guide: [Requesting CarPlay entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements) and the CarPlay Developer Guide. Agree to the CarPlay entitlement addendum.
2. Request **Driving Task** at [developer.apple.com/contact/carplay](https://developer.apple.com/contact/carplay/). Describe Beckify Drive as an on-device OBD dashboard (charge, power, speed, temperature) for the driver. Do not describe it as navigation, and do not request `com.apple.developer.carplay-maps`.
3. Apple adds `com.apple.developer.carplay-driving-task` to the team (done 2026-10-13). The app will not appear on the CarPlay home screen until that entitlement is in the provisioning profile. Once it is shipped, every install shows the CarPlay icon — there is no per-user switch.
4. In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list), register App ID `com.beckify.drive` (explicit, not a wildcard) if it does not exist. Enable the **CarPlay Driving Task** capability. Save.
5. Create a new Development profile and a new Distribution profile for that App ID. Download them or let Xcode automatic signing refresh.
6. On a Mac, open `ios/Beckify.xcodeproj`, scheme **BeckifyDrive**, Team **9TR6R5LV8M**. Signing & Capabilities should list CarPlay. Code Signing Entitlements is already `BeckifyDrive/BeckifyDrive.entitlements`. Do not delete that key to “make signing work” and then ship — CarPlay will not launch without it.
7. If automatic signing errors with “provisioning profile doesn’t include the CarPlay entitlement,” the capability is not on the App ID yet. Stop there and finish steps 4–5 (the entitlement is already granted; do not request it again). Do not strip the entitlement to unblock Toolbox; Toolbox does not use this file.
8. In App Store Connect, create the Beckify Drive record (bundle `com.beckify.drive`, SKU `beckify-drive`). Privacy URL `https://beckify.com/privacy`. Price free, no IAP. Create version **1.0**.
9. Archive scheme **BeckifyDrive** (not Beckify or KestrelHeavy). Upload **1.0 (1)**. Attach screenshots from a Mac simulator or device. This checkout did not capture them.
10. In App Review notes, say: design aid; Bluetooth is the user’s OBD adapter; no cloud upload of vehicle data; the only network call is Open-Meteo weather with a location rounded to about 1 km; power and torque are labeled estimates; CarPlay templates refresh at most every 10 seconds; missing manufacturer PIDs show “Not read” rather than a guessed battery health. CarPlay must be usable without telling the driver to pick up the phone — connection is established before the drive, and the CarPlay screen shows status only.

CarPlay Simulator is in Additional Tools for Xcode (Hardware folder), or use a head unit. The iOS Simulator alone does not draw the CarPlay templates.

## App privacy

Nutrition label: **Data Not Linked to You → Location → Coarse Location**, used for **App Functionality**, not for tracking. This changed from "Data Not Collected" when the weather lookup was added: it sends a location rounded to about 1 km to Open-Meteo, a third party. If Apple's reading of their questionnaire changes, revisit this. Bluetooth and vehicle readings stay on device. The privacy manifest `BeckifyDrive/PrivacyInfo.xcprivacy` declares UserDefaults reason `CA92.1` and `NSPrivacyCollectedDataTypeCoarseLocation` (not linked, no tracking, App Functionality). `NSPrivacyTracking` is false, and there are no tracking domains.

Usage strings: Bluetooth Always and Bluetooth Peripheral are build settings (Debug and Release). `NSLocationWhenInUseUsageDescription` and `NSMotionUsageDescription` are in `BeckifyDrive/Info.plist`. Location is When In Use only, for GPS speed, altitude, heading, trip, and lining up the G-force plot. Motion & Fitness covers the barometer. Both are requested lazily from a card, not at launch. Motion is processed on device. Location is processed on device, except the rounded coordinate sent for weather. No microphone or camera.

App Review note to add: location and motion are optional; every vehicle card works without them.

Background mode `bluetooth-central` is in `BeckifyDrive/Info.plist` so the adapter session can continue while CarPlay is connected and the phone is locked.

## Export compliance

The app does not implement custom cryptography and does not open network connections for OBD data. The weather lookup uses standard HTTPS through `URLSession`, which is exempt. `ITSAppUsesNonExemptEncryption` is NO. In App Store Connect, answer **No** except the standard HTTPS exemption if the form still appears.

## Screenshots

Not in this repository. Capture on a Mac:

- iPhone 6.7-inch and 6.1-inch (or the sizes Connect currently requires)
- iPad 13-inch if you ship iPad
- CarPlay, from CarPlay Simulator, once the entitlement is on the profile

Show the disconnected state and a connected state only with real or clearly non-shipping data. Do not ship a screenshot that implies a measured battery-health percentage.

The Xcode previews in `BeckifyDrive/Dashboard/DashboardPreviews.swift` (no adapter, partial data, full Bolt EV, driving, regen, partial replies, light mode) are fixtures. They are useful for review, but they are not real readings, so do not use them as App Store screenshots.

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
