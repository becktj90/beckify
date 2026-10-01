# Privacy Policy — Beckify iOS

**Product:** Beckify (bundle ID `com.beckify.toolbox`)  
**Platforms:** iPhone and iPad  
**Developer:** Trevor Beck  
**Contact:** trevorjohnbeck@gmail.com  
**Public URL:** https://beckify.com/privacy  
**Last updated:** 30 September 2026

This is the privacy policy for the native Beckify iOS and iPadOS app. It is hosted at https://beckify.com/privacy (and https://beckify.com/privacy/). It describes the app, not the beckify.com website.

Sibling App Store products on the same team (`9TR6R5LV8M`) are **Look Check** (`com.beckify.lookcheck`), **Kestrel Heavy** (`com.beckify.kestrelheavy`), and **Beckify Drive** (`com.beckify.drive`). Kestrel Heavy is a standalone arcade, not a Toolbox catalog game; v1 collects no play data. See `ios/KestrelHeavy/docs/PRIVACY.md`. Beckify Drive is a separate vehicle dashboard. OBD readings stay on that device and are not uploaded. See `ios/BeckifyDrive/docs/PRIVACY.md`.

Apple’s App Privacy nutrition label for this app includes **Photos** (App Functionality) when you tap **Analyze** in Look Check, Motor Nameplate OCR, or Panel Directory, and **Other User Content** (App Functionality) when Spanish Translator sends recognized or typed text to the Beckify translate API. Those uploads are user-initiated, not linked to an account, and not used for tracking. There is no always-on upload. Sensor readings and Saved Jobs stay on the device.

## What the app does not collect

Beckify does not collect, sell, share, or transmit personal data for advertising, analytics, or tracking.

- No analytics or crash-reporting SDKs
- No advertising identifier (IDFA) and no tracking across apps or websites
- No user accounts, sign-in, or cloud sync
- No ads, store checkout, or Amazon links
- The app does not wrap or load beckify.com in a web view
- The app is a toolbox of field calculators, bench calculators, and sensors. It is not a website project gallery.

Optional links the user may tap (https://beckify.com and `mailto:trevorjohnbeck@gmail.com`) open in the system browser or mail app. Those destinations are not part of in-app data collection.

## Sensors and permissions (on-device only)

Permissions are requested only when the related tool is used, not at launch (except iOS may show the system sheet the first time that tool starts).

| Permission | Tools | What happens |
| --- | --- | --- |
| Microphone | Noise Meter, Acoustic Imager, Room & Rig Check, Breath Flute, Stillness Anomaly Watch, Spanish Translator | Relative dBFS, an on-device audible spectrum, optional speaker test signals (pink noise, a sweep, or tone bursts) for a room and rig A/B, a blow-gated local tone, impulse marks, and speech recognition for Spanish Translator. Audio is not saved as a recording file and is not uploaded as audio. Spanish Translator may send **recognized text** (not the waveform) to the Beckify translate API only when you stop recording or tap Translate. Not a calibrated SLM, not absolute dB SPL, and not a leak position. Room & Rig Check is a relative listening check on this phone, not a lab measurement. Breath Flute is a play tool: silent until you blow into the bottom edge. Stillness does not save audio. |
| Speech Recognition | Spanish Translator | On-device speech-to-text for the words you speak into Spanish Translator. Prefer on-device recognition when the system supports it. Audio is not kept as a recording. The resulting text may leave the device only when you stop recording or tap Translate (see cloud translate below). |
| Bluetooth | BLE Scanner, Stillness Anomaly Watch | Nearby BLE advertisements. The scanner shows name, identifier, RSSI, and advertised fields. Stillness uses advertiser IDs, count, and RSSI jumps only — not names as people, and not occupancy. Not uploaded. Device count is not a people count. |
| Location (When In Use) | Position; Wi-Fi Path; Solar Design Wizard (optional latitude) | Coordinates, current SSID, Apple `signalStrength` 0…1, on-device heatmap samples, optional latitude for PV tilt advice. Not used at launch. Not uploaded. |
| Local Network | Wi-Fi Path (optional); Cellular Path (optional) | TCP connect timing to a LAN or default-gateway host the user chooses. Used only when measuring **link quality (RTT)** to a private/LAN host. Not uploaded. Public hosts such as 1.1.1.1, and **Online / Captive** to `captive.apple.com`, do not need this permission. |
| Camera | Motor Nameplate OCR; Panel Directory; Look Check | A still photo. On-device Vision runs first for nameplate and panel. Taking or choosing a photo does not upload it. A photo leaves this device only after you tap **Analyze** / **Analyze Look**. Photos are not kept as images in Saved Jobs. |
| Motion & Fitness | Barometer; Bubble Level / plumb; Magnetometer (including Mag Sweep); g-Force Snapshot; Stillness Anomaly Watch; Coupled Vibration; Solar Design Wizard (optional panel aim) | On-device `CMAltimeter` pressure / relative altitude and `CMMotionManager` gravity, heading, and acceleration. Requested when you open those tools, not at launch. Not uploaded. Design aid only — not a calibrated instrument, not ISO 10816, and not surveyed elevation. If the barometer is missing or Motion & Fitness is off, Barometer shows an unavailable state instead of crashing. |

Photo Library full access is **not** requested. Look Check, Panel Directory, and Motor Nameplate OCR can use the system photo picker (`PhotosPicker`) so you choose one or more images. Motor Nameplate OCR, Panel Directory, and Look Check can also use the camera for a still photo. Taking or choosing a photo does not upload it. A photo leaves this device only after you tap **Analyze** (nameplate / panel) or **Analyze Look**.

Structured nameplate fields and panel-schedule rows use the same honesty pattern (each value has a confidence and a reviewed flag). Human confirm sets reviewed. On-device Vision and the heuristic parser work offline and do not require the API. Optional cloud **Analyze** is user-initiated only — never automatic, and never at launch.

**Look Check** (the catalog photo tool, not the Wi-Fi / Cellular Online / Captive card) is cloud-only, matching the website product. Taking or choosing a photo does not upload it. **Analyze Look** POSTs an upright JPEG to `https://api.beckify.com/api/analyze-look` (or a HTTPS endpoint you enter). The Beckify API may forward that photo to OpenAI and/or Anthropic. The result is an entertainment verdict (looks good / looks off / mixed / no person / not rated) plus lighting, framing, expression, sharpness, and overall scores, and a roast when the subject appears 18+ and is rated. It is not medical, dating, or beauty authority. Anyone who appears under 18 is not rated and gets no roast. The photo is not saved in Saved Jobs.

**Spanish Translator** (Toolkit → Reference) uses the microphone and Speech Recognition on this device. Audio is not saved as a recording file. When you stop recording or tap **Translate**, the recognized (or typed) English text POSTs to `https://api.beckify.com/api/translate` (or a HTTPS endpoint you enter). The Beckify API may forward that text to OpenAI to produce Cuban / Florida LatAm Spanish for loud on-device playback. Nothing is uploaded at launch or while you are only listening. It is not a certified interpreter and not a recording product.

**Motor Nameplate OCR** and **Panel Directory** keep Apple Vision on this device as the default. Before that read, the photo can be perspective-flattened (when a page rectangle is found) and contrast-adjusted on this device so faded ink and glare are easier to read. That preprocessing does not leave the phone. Optional **Analyze** POSTs an upright JPEG to `https://api.beckify.com/api/analyze-nameplate` or `https://api.beckify.com/api/analyze-panel` (or a HTTPS endpoint you enter) only when you tap the button. The Beckify API may forward that photo to OpenAI and/or Anthropic. The JSON draft fills editable fields; you still confirm before Saved Jobs or demand numbers are treated as reviewed. A scan-quality score can ask you to retake. It is not uploaded. There are no ads and no in-app purchases.

Share on an engineer plot renders a PNG on this device and opens the system share sheet (Save Image, Files, AirDrop, and so on). The image is written to a temporary file, or held as an in-memory `UIImage` if that write fails. Nothing is uploaded. Choosing Save Image in the system sheet does not require the app to request Photo Library full access.

CoreMotion tools use the Motion & Fitness (`NSMotionUsageDescription`) string on the generated Info.plist. Battery and thermal state are local diagnostics and do not use that key. Device Health also reads on-device free space and the time since boot (`systemUptime` and `kern.boottime`) so it can show a field snapshot. Those readings stay on the device and are not uploaded.

iOS does **not** give third-party apps Wi-Fi RSSI in dBm. The Wi-Fi Path tool leads with **Online / Captive**: an HTTP GET to Apple’s public `http://captive.apple.com/hotspot-detect.html`. A `Success` body means no captive splash; a redirect or login page is called a captive portal; a satisfied path that cannot reach that host is “local only.” The request carries no user content and is not uploaded to Beckify. Optional **local IPv4** is the Network.framework `localEndpoint` of that probe when it is an IPv4 address — not a public-IP lookup and not RSSI. The tool also shows Apple’s public 0…1 `signalStrength` (percent and bars) when `NEHotspotNetwork` returns it, an on-device coverage sketch, and TCP **link quality (RTT)** to a gateway or chosen host. It does not invent dBm. App Store apps cannot send ICMP ping; a failed or permission-blocked probe stays blank.

iOS does **not** give third-party apps cellular RSRP, RSRQ, SINR, RSSI, or dBm. The Cellular Path tool reuses the same Online / Captive probe on the default path, then reads on-device CoreTelephony radio identity (carrier name, MCC/MNC, ISO country, RAT, data-service id) and Network path flags. Optional TCP RTT runs only when you tap Start and only while the default path uses cellular. It does not invent field-strength numbers. Empty CTCarrier fields stay blank.

## What stays on the device

Named **Saved Jobs** are lightweight on-device notes (bench or field snapshots of calculator inputs/results or sensor numbers the user chooses to save). They use Apple’s `UserDefaults`. They are not a project gallery and are not uploaded. Deleting the app removes them, subject to the user’s device backup settings.

Last-used calculator and sensor form values (the numbers and picker choices in each tool) also stay in on-device `UserDefaults` so a tool reopens where you left it. They are not uploaded and are not a projects product. Cable Ladder stores the same kind of on-device form values (tray size, cable rows, and the optional phase-color legend). It does not add a permission.

Settings choices — electrical code (NEC or AS/NZS), preferred length units, and appearance (system, light, or dark) — stay in on-device `UserDefaults` as well. They are not uploaded.

## Children’s privacy

The app is rated 4+ and does not collect data from anyone, including children.

## Changes

If this policy changes, the updated text will be published at https://beckify.com/privacy.

## Contact

Questions: trevorjohnbeck@gmail.com
