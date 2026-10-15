# Beckify Drive

Native iPhone and iPad dashboard for a Bluetooth LE OBD-II adapter, plus a CarPlay scene. Bundle ID `com.beckify.drive`, display name **Beckify Drive**, iOS 17+.

This is a sibling of the Beckify Toolbox, not a tool inside it. Apple’s driving-task rule says the CarPlay app has to be built for that job. Toolbox stays a field EE app (`com.beckify.toolbox`, marketing **1.0.2**, build **162**). Archive scheme **BeckifyDrive** only when you mean this product. Do not point the Toolbox Xcode Cloud workflows at this scheme.

The phone screen is the dense dashboard. CarPlay uses a `CPTabBarTemplate` with a `CPGridTemplate` Gauges tab and a `CPListTemplate` Readings tab, gauge detail cards, and a dashboard shortcut scene. There is no `WKWebView`.

## What it reads

Generic profile: SAE J1979 Mode 01 (speed, RPM, coolant, load, throttle, fuel level, 12 V module voltage, ambient, and PID 015B when the ECU answers). Fuel level is fuel level. PID 015B is hybrid battery remaining life, not state of charge.

Bolt EV and Bolt EUV share one published PID set:

- Displayed SoC `228334`, header `7E4`, A×100/255
- Pack temperature `22434F`, header `7E4`, A−40
- Capacity `2241A3`, header `7E4`, ((A×256)+B)/10 Ah (the revised 2020 scale)
- Remaining-life HD `2243AF`, header `7E4` — not a warranty state of health
- HV current `222414`, header `7E1`, signed 16-bit / 20
- Motor temperature `2228CB`, header `7E1`, A−40

Pack voltage is never decoded. Public pack-voltage scales disagree, and the one-byte charger voltage/current formulas top out below a real pack and a DC fast-charge current, so those requests are not sent. Power appears only as a labeled estimate (see the data policy below). Planning range appears only after displayed SoC is read and you type pack kWh and Wh/mi. 60 kWh and 65 kWh buttons are GM nominal assumptions, not measurements.

Decode and the 10-second CarPlay publish rule live in `BeckifyMath` (`OBDSessionMath`). Linux runs `swift test` there. This environment does not compile the iOS UI.

## Vehicles

| Profile | Dashboard | PIDs | Estimates |
|---|---|---|---|
| Generic OBD | Vehicle (coolant, load, throttle, fuel, ambient, 12 V, remaining life) + phone | Mode 01 | none |
| Generic EV | Speed hero + Vehicle (ambient, 12 V, battery remaining life 015B) + phone | Mode 01 | none (no HV current) |
| Bolt EV / Bolt EUV | Power / torque / regen hero, Battery, Motor, Power electronics, Energy & range, phone | Mode 01 + published Bolt Mode 22 | yes, from `VehicleSpec.bolt` |

Generic EV works on any EV that answers standard Mode 01. It never sends maker-specific requests, so charge, pack temperature, current, and every estimate stay off. To add a specific EV, add:

1. Its verified Mode 22 rows to `DriveSignalTable` (header, request, decode, range, source).
2. A `VehicleSpec` with sourced pack volts, wheel radius, mass, and drag (`DriveEstimateMath.swift`).
3. A `VehicleProfile` case that maps to both.

Nothing is added from guesswork. The Bolt EUV uses the Bolt EV spec because its own mass and drag are not entered.

## Data policy: measured vs estimated

This replaces the old "traction kW stays blank" rule.

- **Measured** values come straight from a PID or a phone sensor: displayed charge, temperatures, HV current, speed, 12 V, GPS, barometer. They are shown as read. Unknown is an em dash and a muted card, never a zero or a guess.
- **Estimated** values are allowed only when all three of these hold:
  1. They carry the **est.** badge.
  2. The card states the assumption.
  3. The constants live in `BeckifyMath` with a source comment and a test.

  Estimates use the violet `DriveTheme.estimated` token; measured values use `DriveTheme.measured`, so the two never look alike. Color is never the only cue: the badge is always there.
- Estimates today, with their assumptions (all in `DriveEstimateMath.swift` / `DriveInsightMath.swift`):

| Estimate | Built from | Assumption |
|---|---|---|
| Power kW, regen kW | HV current `222414` | 350 V nominal Bolt pack (96s × 3.65 V) |
| Wheel torque | power, OBD speed | 0.32 m wheel radius (215/50R17); no drivetrain loss; dash under 3 m/s |
| Efficiency Wh/mi | displayed-charge drop, GPS distance | the pack kWh you type; needs 1 % drop and 1 mi |
| Regen score | HV current sign, speed deltas | 1,696 kg (curb + driver), 350 V |
| Trip energy split | current, speed, altitude | 350 V, 1,696 kg; climate and conditioning share the "stopped" bucket |
| Weather-adjusted range | planning range, Open-Meteo, GPS course | AAA 2019 temperature curve; Cd 0.308, assumed 2.4 m² frontal area, Crr 0.009 |
| Grade | barometer or GPS altitude, GPS distance | fit over the last 200 m |
| Fast-charge ETA | pack temp trend | BU-410 window 5–45 °C (cell guidance, not GM's map) |
| Capacity trend | daily `2241A3` readings | straight-line fit; needs a month |

PID 015B is hybrid battery remaining life, not state of charge. Fuel level is fuel level. The PID set, headers, and decode formulas in `OBDSessionMath.swift` do not change for estimates.

## Phone dashboard

`Dashboard/DashboardView.swift` is the root. From the top:

1. **Link pill.** Adapter state and vehicle profile. Tap it to open the adapter sheet. Under it is the line CarPlay is showing.
2. **The big three** (Bolt profiles, `Dashboard/PowerHero.swift`):
   - **Regen state** banner: REGEN / DRIVE / IDLE from the sign of measured HV current, or a dash. During regen it shows the regen kW (est.).
   - **Power**: a semicircle centered on zero, with drive sweeping right in teal and regen left in green, plus retro seven-segment digits (`RetroDigits.swift`).
   - **Wheel torque**: retro digits and a bar centered on zero. Gauge scales round up from the session peak and are display scales, not limits.
3. **Charge and speed.** Combustion: speed inside an RPM arc. EV: displayed charge ring, speed, and Drive / Regen. Speed is OBD when it is read, else GPS, and says which.
4. **Card sections.** Combustion profiles get **Vehicle** (coolant, engine load, throttle, fuel, ambient, 12 V). Bolt profiles get:
   - **Battery:** HV current (signed bar centered on zero, drive vs regen color, 60 s trace), pack temp with a band gauge, capacity Ah, remaining life (HD), planning range.
   - **Motor:** motor temp (neutral gauge, no published limit), Drive / Regen from the sign of HV current only.
   - **Power electronics:** 12 V bus (Mode 01 `0142`, the accessory bus the DC-DC keeps up). Inverter temp, DC-DC output, and onboard charger are **Not reported by this vehicle** cards until a published, verified request exists.
   - **Energy & range** (estimates): efficiency, weather-adjusted range, regen score, trip energy, fast-charge temp, capacity trend.
5. **Phone sensors** (all profiles): GPS speed, altitude, heading, G-force, barometer, phone battery, grade, trip.

Every value has one of four states, from `DriveFreshness` in `BeckifyMath`: **live**, **stale** (over 5 s old, dimmed with its age), **out of range** (decoded outside the signal's plausibility range: dash and warning glyph, never the number), and **not reported** (dash). Values expire from the reading book after 20 s.

Thresholds live in `DriveThresholds` with their sources: displayed charge under 15 % (app convention), 12 V under 12.2 V / 11.9 V (lead-acid resting levels), and pack bands at 0 / 45 / 60 °C (generic Li-ion cell guidance, not GM limits). Motor, coolant, and oil temperature have no published limit, so they get no warning color.

HV current is measured in amps. Power, torque, and Wh/mi are estimates under the policy above.

### Weather

`Net/WeatherService.swift` asks Open-Meteo (`api.open-meteo.com`, no key) for current temperature and wind. It runs only on Bolt profiles with Location allowed, and sends the location rounded to 0.01° (about 1 km). When there is no live fix, it can use the last GPS fix saved on the device if it is under two hours old; the same age limit applies to a fix retained in memory after backgrounding; Location permission is still required. Only the latest fix is retained, not a location history. It refreshes after 15 min or 10 km and retries no sooner than 2 min after a failure. The last reading is cached in UserDefaults. Older than 3 h, the card says so and stops adjusting range. The dashboard never waits on the network.

The charger finder from the feature list is not built.

### Signal table

`BeckifyMath/DriveSignalTable.swift` lists every signal: name, header, request, decode, unit, valid range, and source. A test checks each row decodes the same as `OBDDecode`. Adding a verified Mode 22 PID takes an `OBDReading` case plus one table row; the Bolt live cycle requests it and `OBDDecode` decodes it through the table. Today that hook adds nothing, and the cycle is unchanged.

HV current sign: + leaves the pack (drive), − enters it (regen or charge). That matches the published signed decode and the existing regen test. Confirm it on a car.

### Phone sensors

`Sensors/PhoneSensorStore.swift`. Location (When In Use) and Motion & Fitness (barometer) are asked for only when the user taps a card's button. When denied, the card offers **Enable in Settings**. Sensors stop when the app leaves the foreground.

The G-force plot turns phone axes into car axes with the attitude (true-north frame) and the GPS course. It needs Location and some speed. Until then it says so instead of guessing which way the car points. It is smoothed, the trail is about 3 s, and the peak resets with a tap.

The trip adds up the best speed each second: OBD when live, else GPS. It drops gaps over 8 s and averages over moving time only.

### Settings and layout

The slider button opens **Dashboard**. It covers units (mph / km/h, °F / °C, kW / hp, Nm / lb-ft, defaulting to the region: US gets mph, °F, hp, and lb-ft; distance, altitude, and pressure follow the speed unit), appearance (Dark by default, or Match System), and the cards. **Edit** reorders cards within a section; toggles hide them. Everything is stored in UserDefaults on the device.

### Debug PID inspector

Debug builds add a ladybug button. It lists each table signal with its request, the last raw reply, the decoded value, and its age. It is compiled out of Release (`#if DEBUG`).

### Previews

`Dashboard/DashboardPreviews.swift` has fixture states: no adapter, partial data (generic), full Bolt EV, Bolt EV driving, Bolt EV regen, Bolt EV partial replies (stale, out of range, and missing), ICE generic, and light mode. The driving fixtures run 34 minutes of synthetic stops through the real estimators. Nothing scans or asks for permission.

### Files

```
BeckifyDrive/
  BeckifyDriveApp.swift          scenes; phone root is DashboardView
  DriveTheme.swift               adaptive tokens (surface, elevated, accent, regen, warning, critical)
  OBDBluetoothSession.swift      BLE session (unchanged apart from a debug-only raw reply log)
  CarPlayDriveScene.swift        CarPlay templates (unchanged)
  Dashboard/                     DashboardView, DashboardModel, PowerHero, RetroDigits,
                                 InsightCards, DashboardCards, MetricCard, SpeedHero,
                                 EVSections, GForceView, TripCard, AdapterSheet,
                                 DashboardSettingsSheet, DashboardLayoutStore,
                                 PIDInspectorSheet (debug), DashboardPreviews (debug)
  Sensors/PhoneSensorStore.swift Core Location, Core Motion, altimeter, battery
  Net/WeatherService.swift       Open-Meteo, cached, offline-tolerant
BeckifyMath/Sources/BeckifyMath/
  DriveSignalTable.swift  DriveDashboardMath.swift  DriveMotionMath.swift  DashboardLayoutMath.swift
  DriveEstimateMath.swift DriveInsightMath.swift
```

## CarPlay

Entitlement stub: `BeckifyDrive/BeckifyDrive.entitlements` → `com.apple.developer.carplay-driving-task`.

Scene manifest: `BeckifyDrive/Info.plist` (`CPTemplateApplicationScene` and the dashboard scene).

CarPlay copy refreshes at most once every 10 seconds. CarPlay is a primary screen, not an extra. Its root has two tabs: **Gauges** and **Readings**. Gauges uses `CPGridTemplate` to fill the template area with eight retro gauge buttons on Bolt profiles: charge, power (est.), regen score, speed, range, weather-adjusted range (est.), efficiency (est.), and pack temperature. Generic profiles keep their six gauges (speed, RPM, coolant, fuel, 12 V, and outside temperature). CarPlay controls button placement, normally two rows of four for the eight-gauge cluster; exact spacing and size depend on the car. Driving-task apps can't draw a custom full-screen HUD. Artwork uses `CPGridTemplate.maximumGridButtonImageSize` at runtime on iOS 26; iOS 17/18 use the legacy 40-point size. Each button carries its full spoken reading for VoiceOver. The **Readings** tab gives the grouped list its own screen and list budget instead of squeezing it below the home gauges. A 2 s tick republishes (still at most every 10 s) so GPS speed, weather, and efficiency changes show without an OBD reply. On iOS 26, tapping a tile opens a large card for it (the rest of the cluster follows, swipe sideways), refreshed on the same cadence. Cards and tiles use a 90s vacuum-fluorescent look: segmented gauges, glowing seven-segment digits over unlit 8s, scanlines, and a bezel. Each card adds gauge end labels (E/F, REGEN/DRIVE) and three readouts, e.g. power shows peak, torque (est.) and HV amps; speed shows trip average, top speed and distance. Missing readouts show a dash; earlier iOS has no large image rows and opens the text view instead. In the Readings tab (and under the Gauges cards) every other reading appears as list rows, grouped Battery, Range and energy, Drive, Outside and link, as many as the car allows; "All readings" appears when some had to be left off. Range uses the pack size and Wh/mi you type, else this trip's measured Wh/mi, else published Bolt figures (65 kWh usable; EPA 259 mi Bolt EV, 247 mi Bolt EUV), marked "EPA default". The debug launch argument `-BeckifyDriveCarPlayPreview YES` shows an illustrative four-column grid and the detail artwork on the phone; it is not a screenshot of the actual CarPlay template; CI screenshots it as `carplay-tiles.png`. The dashboard shortcuts are charge and power (est.). CarPlay text uses the iPhone's region units (Settings → General → Language & Region): US is mph, °F, mi, and hp; metric regions get km/h, °C, km, and kW; the UK gets mph and °C. The phone dashboard's own unit toggles do not change CarPlay. Both CarPlay scenes attach to the shared `DashboardModel`, so the trip, efficiency, regen, grade, and weather estimators keep running with the phone locked in a mount (Location is "in use" while the CarPlay scene is up). There are no charger features. That is Apple’s driving-task limit (no live engine strip). The phone gauges update as PID replies arrive.

Trevor has to turn the capability on before a signed device build will succeed. Steps are in [`docs/APP_STORE.md`](docs/APP_STORE.md).

## Privacy

No account, no analytics, no OBD upload, and no location history. The latest GPS fix is saved on the device for the weather fallback above. The one network call is the Open-Meteo weather lookup, which sends a location rounded to about 1 km. Location and Motion & Fitness are optional and requested from a card. See [`docs/PRIVACY.md`](docs/PRIVACY.md).

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
