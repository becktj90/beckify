# Beckify Drive

Native iPhone and iPad dashboard for a Bluetooth LE OBD-II adapter, plus a CarPlay scene. Bundle ID `com.beckify.drive`, display name **Beckify Drive**, iOS 17+.

This is a sibling of the Beckify Toolbox, not a tool inside it. Apple’s driving-task rule says the CarPlay app has to be built for that job. Toolbox stays a field EE app (`com.beckify.toolbox`, build **160**). Archive scheme **BeckifyDrive** only when you mean this product. Do not point the Toolbox Xcode Cloud workflows at this scheme.

The phone screen is the dense gauge. CarPlay uses `CPTemplate` / `CPInformationTemplate` and a dashboard shortcut scene. There is no `WKWebView`.

## What it reads

Generic profile: SAE J1979 Mode 01 (speed, RPM, coolant, load, throttle, fuel level, 12 V module voltage, ambient, and PID 015B when the ECU answers). Fuel level is fuel level. PID 015B is hybrid battery remaining life, not state of charge.

Bolt EV and Bolt EUV share one published PID set:

- Displayed SoC `228334`, header `7E4`, A×100/255
- Pack temperature `22434F`, header `7E4`, A−40
- Capacity `2241A3`, header `7E4`, ((A×256)+B)/10 Ah (the revised 2020 scale)
- Remaining-life HD `2243AF`, header `7E4` — not a warranty state of health
- HV current `222414`, header `7E1`, signed 16-bit / 20
- Motor temperature `2228CB`, header `7E1`, A−40

Traction kilowatts stay blank. Public pack-voltage scales disagree, and the one-byte charger voltage/current formulas top out below a real pack and a DC fast-charge current, so those requests are not sent. Planning range appears only after displayed SoC is read and you type pack kWh and Wh/mi. 60 kWh and 65 kWh buttons are GM nominal assumptions, not measurements.

Decode and the 10-second CarPlay publish rule live in `BeckifyMath` (`OBDSessionMath`). Linux runs `swift test` there. This environment does not compile the iOS UI.

## CarPlay

Entitlement stub: `BeckifyDrive/BeckifyDrive.entitlements` → `com.apple.developer.carplay-driving-task`.

Scene manifest: `BeckifyDrive/Info.plist` (`CPTemplateApplicationScene` and the dashboard scene).

CarPlay copy refreshes at most once every 10 seconds. That is Apple’s driving-task limit (no live engine strip). The phone gauges update as PID replies arrive.

Trevor has to turn the capability on before a signed device build will succeed. Steps are in [`docs/APP_STORE.md`](docs/APP_STORE.md).

## Privacy

On-device only. No account, no analytics, no OBD upload. See [`docs/PRIVACY.md`](docs/PRIVACY.md).

## Mac

```bash
cd ios
xcodebuild \
  -project Beckify.xcodeproj \
  -destination 'generic/platform=iOS Simulator' \
  -scheme BeckifyDrive \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Team `9TR6R5LV8M` is already `DEVELOPMENT_TEAM`. Repo version is **1.0 (1)**.
