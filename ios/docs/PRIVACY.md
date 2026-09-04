# Privacy Policy — Beckify iOS

**Product:** Beckify (bundle ID `com.beckify.toolbox`)  
**Platforms:** iPhone and iPad  
**Developer:** Trevor Beck  
**Contact:** trevorjohnbeck@gmail.com  
**Public URL:** https://beckify.com/privacy  
**Last updated:** 4 September 2026

This is the privacy policy for the native Beckify iOS and iPadOS app. It is hosted at https://beckify.com/privacy (and https://beckify.com/privacy/). It describes the app, not the beckify.com website.

Apple’s App Privacy nutrition label for this app is **Data Not Collected**. Sensor readings and Saved Jobs stay on the device.

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
| Location (When In Use) | Position; Wi-Fi Path; Solar Design Wizard (optional latitude) | Coordinates, current SSID, Apple `signalStrength` 0…1, on-device heatmap samples, optional latitude for PV tilt advice. Not used at launch. Not uploaded. |
| Local Network | Wi-Fi Path (optional) | TCP connect timing to a LAN or default-gateway host the user chooses. Used only when measuring **link quality (RTT)**. Not uploaded. Public hosts such as 1.1.1.1 do not need this permission. |
| Camera | Motor Nameplate OCR | A still photo of a motor nameplate. Vision text recognition and the structured field parser run on this device. The photo is not uploaded and is not kept in Saved Jobs. |

Photo Library full access is **not** requested. Panel Directory and Motor Nameplate OCR can use the system photo picker (`PhotosPicker`) so you choose one image; Vision text recognition runs on that image on-device and the recognized text stays in the tool. Motor Nameplate OCR can also use the camera for a still photo. Nothing is uploaded.

Structured nameplate fields use a shared schema (each field is a value, a confidence, and a reviewed flag). Human confirm sets reviewed. Vision and the heuristic parser stay on this device. A future cloud VLM/agent path may be wired to the same keys. It is **off by default** in this app and is not enabled in this release. If it is ever offered, a photo or recognized text would leave the device only after an explicit user action — never automatically, and never at launch.

Share on an engineer plot renders a PNG on this device and opens the system share sheet (Save Image, Files, AirDrop, and so on). The image is written to a temporary file, or held as an in-memory `UIImage` if that write fails. Nothing is uploaded. Choosing Save Image in the system sheet does not require the app to request Photo Library full access.

CoreMotion (level, magnetometer, barometer, g-force) does not use those permission strings. Battery and thermal state are local diagnostics.

iOS does **not** give third-party apps Wi-Fi RSSI in dBm. The Wi-Fi Path tool shows Apple’s public 0…1 `signalStrength` (percent and bars), an on-device coverage sketch, and TCP **link quality (RTT)** to a gateway or chosen host. It does not invent dBm. App Store apps cannot send ICMP ping; a failed or permission-blocked probe stays blank.

## What stays on the device

Named **Saved Jobs** are lightweight on-device notes (homework or field snapshots of calculator inputs/results or sensor numbers the user chooses to save). They use Apple’s `UserDefaults`. They are not a project gallery and are not uploaded. Deleting the app removes them, subject to the user’s device backup settings.

Last-used calculator and sensor form values (the numbers and picker choices in each tool) also stay in on-device `UserDefaults` so a tool reopens where you left it. They are not uploaded and are not a projects product.

## Children’s privacy

The app is rated 4+ and does not collect data from anyone, including children.

## Changes

If this policy changes, the updated text will be published at https://beckify.com/privacy.

## Contact

Questions: trevorjohnbeck@gmail.com
