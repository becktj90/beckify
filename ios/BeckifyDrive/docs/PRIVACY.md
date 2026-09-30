# Privacy Policy — Beckify Drive

**Product:** Beckify Drive (bundle ID `com.beckify.drive`)  
**Platforms:** iPhone, iPad, and CarPlay when the driving-task entitlement is enabled  
**Developer:** Trevor Beck  
**Contact:** trevorjohnbeck@gmail.com  
**Public URL:** https://beckify.com/privacy  
**Last updated:** 30 September 2026

Beckify Drive is a separate app from Beckify Toolbox (`com.beckify.toolbox`). The public policy page covers both. This file is the Drive-specific text.

## What the app does

Beckify Drive connects to a Bluetooth Low Energy OBD-II adapter you choose (ELM327-class). It shows vehicle readings on the phone and, after Apple enables CarPlay for this bundle ID, on the CarPlay screen.

## What leaves the device

Nothing the app reads from the car is uploaded. There is no account, no analytics SDK, no advertising identifier, and no cloud OBD log.

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

Deleting the app removes that store, subject to device backup. The adapter identifier is not sent to Beckify.

`bluetooth-central` background mode keeps the session alive while CarPlay is on screen and the phone is locked. Those bytes still stay on the device.

## Vehicle data

Speed, temperatures, state of charge, current, and the other PIDs are processed on device to draw the gauges. They are not a diagnostic report and they are not sold or shared.

Planning range uses a pack size and Wh/mi you enter. Those numbers are assumptions, not a reading from GM.

## Children’s privacy

The app is rated 4+ and does not collect data from anyone, including children.

## Contact

Questions: trevorjohnbeck@gmail.com
