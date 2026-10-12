# Beckify Drive

Native iPhone and iPad dashboard for a Bluetooth LE OBD-II adapter, plus a CarPlay scene. Bundle ID `com.beckify.drive`, display name **Beckify Drive**, iOS 17+.

This is a sibling of the Beckify Toolbox, not a tool inside it. Apple’s driving-task rule says the CarPlay app has to be built for that job. Toolbox stays a field EE app (`com.beckify.toolbox`, marketing **1.0.2**, build **162**). Archive scheme **BeckifyDrive** only when you mean this product. Do not point the Toolbox Xcode Cloud workflows at this scheme.

The phone screen is the dense dashboard. CarPlay uses `CPTemplate` / `CPInformationTemplate` and a dashboard shortcut scene. There is no `WKWebView`.

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

## Phone dashboard

`Dashboard/DashboardView.swift` is the root. From the top:

1. **Link pill.** Adapter state and vehicle profile. Tap it to open the adapter sheet. Under it is the line CarPlay is showing.
2. **Hero.** Combustion: speed inside an RPM arc. EV: displayed charge ring, speed, and Drive / Regen. Speed is OBD when it is read, else GPS, and says which.
3. **Card sections.** Combustion profiles get **Vehicle** (coolant, engine load, throttle, fuel, ambient, 12 V). Bolt profiles get:
   - **Battery:** HV current (signed bar centered on zero, drive vs regen color, 60 s trace), pack temp with a band gauge, capacity Ah, remaining life (HD), planning range.
   - **Motor:** motor temp (neutral gauge, no published limit), Drive / Regen from the sign of HV current only.
   - **Power electronics:** 12 V bus (Mode 01 `0142`, the accessory bus the DC-DC keeps up). Inverter temp, DC-DC output, and onboard charger are **Not reported by this vehicle** cards until a published, verified request exists.
4. **Phone sensors** (all profiles): GPS speed, altitude, heading, G-force, barometer, phone battery, trip.

Every value has one of four states, from `DriveFreshness` in `BeckifyMath`: **live**, **stale** (over 5 s old, dimmed with its age), **out of range** (decoded outside the signal's plausibility range: dash and warning glyph, never the number), and **not reported** (dash). Values expire from the reading book after 20 s.

Thresholds live in `DriveThresholds` with their sources: displayed charge under 15 % (app convention), 12 V under 12.2 V / 11.9 V (lead-acid resting levels), and pack bands at 0 / 45 / 60 °C (generic Li-ion cell guidance, not GM limits). Motor, coolant, and oil temperature have no published limit, so they get no warning color.

Traction kW, charge kW, and Wh/mi stay blank. HV current is shown in amps only.

### Signal table

`BeckifyMath/DriveSignalTable.swift` lists every signal: name, header, request, decode, unit, valid range, and source. A test checks each row decodes the same as `OBDDecode`. Adding a verified Mode 22 PID takes an `OBDReading` case plus one table row; the Bolt live cycle requests it and `OBDDecode` decodes it through the table. Today that hook adds nothing, and the cycle is unchanged.

HV current sign: + leaves the pack (drive), − enters it (regen or charge). That matches the published signed decode and the existing regen test. Confirm it on a car.

### Phone sensors

`Sensors/PhoneSensorStore.swift`. Location (When In Use) and Motion & Fitness (barometer) are asked for only when the user taps a card's button. When denied, the card offers **Enable in Settings**. Sensors stop when the app leaves the foreground.

The G-force plot turns phone axes into car axes with the attitude (true-north frame) and the GPS course. It needs Location and some speed. Until then it says so instead of guessing which way the car points. It is smoothed, the trail is about 3 s, and the peak resets with a tap.

The trip adds up the best speed each second: OBD when live, else GPS. It drops gaps over 8 s and averages over moving time only.

### Settings and layout

The slider button opens **Dashboard**. It covers units (mph / km/h, °F / °C, defaulting to the region; distance, altitude, and pressure follow the speed unit), appearance (Dark by default, or Match System), and the cards. **Edit** reorders cards within a section; toggles hide them. Everything is stored in UserDefaults on the device.

### Debug PID inspector

Debug builds add a ladybug button. It lists each table signal with its request, the last raw reply, the decoded value, and its age. It is compiled out of Release (`#if DEBUG`).

### Previews

`Dashboard/DashboardPreviews.swift` has fixture states: no adapter, partial data (generic), full Bolt EV, Bolt EV driving, Bolt EV regen, Bolt EV partial replies (stale, out of range, and missing), and light mode. Nothing scans or asks for permission.

### Files

```
BeckifyDrive/
  BeckifyDriveApp.swift          scenes; phone root is DashboardView
  DriveTheme.swift               adaptive tokens (surface, elevated, accent, regen, warning, critical)
  OBDBluetoothSession.swift      BLE session (unchanged apart from a debug-only raw reply log)
  CarPlayDriveScene.swift        CarPlay templates (unchanged)
  Dashboard/                     DashboardView, DashboardModel, DashboardCards, MetricCard,
                                 SpeedHero, EVSections, GForceView, TripCard, AdapterSheet,
                                 DashboardSettingsSheet, DashboardLayoutStore,
                                 PIDInspectorSheet (debug), DashboardPreviews (debug)
  Sensors/PhoneSensorStore.swift Core Location, Core Motion, altimeter, battery
BeckifyMath/Sources/BeckifyMath/
  DriveSignalTable.swift  DriveDashboardMath.swift  DriveMotionMath.swift  DashboardLayoutMath.swift
```

## CarPlay

Entitlement stub: `BeckifyDrive/BeckifyDrive.entitlements` → `com.apple.developer.carplay-driving-task`.

Scene manifest: `BeckifyDrive/Info.plist` (`CPTemplateApplicationScene` and the dashboard scene).

CarPlay copy refreshes at most once every 10 seconds. That is Apple’s driving-task limit (no live engine strip). The phone gauges update as PID replies arrive.

Trevor has to turn the capability on before a signed device build will succeed. Steps are in [`docs/APP_STORE.md`](docs/APP_STORE.md).

## Privacy

On-device only. No account, no analytics, no OBD upload, and no location log. Location and Motion & Fitness are optional and requested from a card. See [`docs/PRIVACY.md`](docs/PRIVACY.md).

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
