# Privacy Policy — Beckify Drive

**Product:** Beckify Drive (bundle ID `com.beckify.drive`)  
**Platforms:** iPhone, iPad, and CarPlay when the driving-task entitlement is enabled  
**Developer:** Trevor Beck  
**Contact:** trevorjohnbeck@gmail.com  
**Public URL:** https://beckify.com/privacy  
**Last updated:** 12 October 2026 (weather lookup added)

Beckify Drive is a separate app from Beckify Toolbox (`com.beckify.toolbox`). The public policy page covers both. This file is the Drive-specific text.

## What the app does

Beckify Drive connects to a Bluetooth Low Energy OBD-II adapter you choose (ELM327-class). It shows vehicle readings on the phone and, after Apple enables CarPlay for this bundle ID, on the CarPlay screen.

## What leaves the device

Nothing the app reads from the car is uploaded. There is no account, no analytics SDK, no advertising identifier, and no cloud OBD log.

The one network request is a weather lookup (below). It carries a location rounded to about 1 km and nothing else: no vehicle data and no identifier.

- No analytics or crash-reporting SDKs
- No tracking
- No ads and no in-app purchases
- The app does not load beckify.com in a web view

Optional links you tap (https://beckify.com and `mailto:trevorjohnbeck@gmail.com`) open in the system browser or mail app.

## Bluetooth

Permission is requested when you open Beckify Drive, because the app’s job is the adapter session. The system sheet is Apple’s. The app scans for nearby BLE devices, connects to the one you pick, and reads ELM327 text replies.

Stored on this device only (`UserDefaults`):

- Vehicle profile (generic, Bolt EV, or Bolt EUV)
- Planning pack kWh and Wh/mi, if you type them
- The identifier of the last adapter, so the phone can reconnect
- Dashboard preferences: units, appearance, and which cards show in what order
- One battery-capacity reading per day (amp-hours and date) for the capacity trend chart
- The latest GPS fix and timestamp for the weather fallback
- The last weather reading described above

Deleting the app removes that store, subject to device backup. The adapter identifier is not sent to Beckify.

`bluetooth-central` background mode keeps the session alive while CarPlay is on screen and the phone is locked. Those bytes still stay on the device.

## Location

Beckify Drive asks for Location **While Using the App** only when you tap a card that needs it (GPS speed, altitude, heading, G-force, or trip). It is not requested at launch, and every vehicle card works without it.

Location is used on the phone to show speed, altitude, heading, and grade, to add up the trip, and to tell forward from sideways on the G-force plot. Only the latest GPS fix and its timestamp are saved on this device for weather while a new fix is unavailable; the fallback expires after two hours and still requires Location permission. There is no map and no route history. Location stops when the app leaves the screen.

## Weather (network)

On Bolt profiles with Location allowed, the app asks Open-Meteo (open-meteo.com) for the current temperature and wind, to adjust the range estimate. The request sends a latitude and longitude rounded to two decimal places (about 1 km) over HTTPS, at most every 15 minutes or 10 km. It sends no vehicle readings, no account, and no device identifier. Like any web request, it reaches Open-Meteo's servers with your IP address. Their privacy terms are at https://open-meteo.com/en/terms.

The last weather reading (temperature, wind, time, and that rounded location) is kept in UserDefaults so the card works offline. Deny Location and no weather request is made.

## Motion & Fitness

The barometer card asks for Motion & Fitness the first time you tap it. The app reads air pressure and altitude change on the phone. The G-force plot uses the motion sensors, which do not need that permission. Motion data is not stored or uploaded.

## Phone battery

The phone battery card reads the battery level the system already shows. It is not stored or uploaded.

## Vehicle data

Speed, temperatures, state of charge, current, and the other PIDs are processed on device to draw the gauges. They are not a diagnostic report and they are not sold or shared.

Planning range uses a pack size and Wh/mi you enter. Those numbers are assumptions, not a reading from GM. Power, torque, efficiency, regen score, trip energy, and weather-adjusted range are on-device estimates, labeled "est." in the app.

## Children’s privacy

The app is rated 4+ and does not collect data from anyone, including children.

## Contact

Questions: trevorjohnbeck@gmail.com
