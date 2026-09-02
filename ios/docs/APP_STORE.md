# App Store scaffolding — Beckify

Draft only. Nothing in this repository has been submitted to Apple. Uploading a build requires Trevor's Apple Developer Program account ($99/year) on a Mac with Xcode.

## Listing copy (draft)

**Name:** Beckify  
**Subtitle:** Field EE calculator  
**Category:** Productivity  
**Secondary (optional):** Utilities  
**Age rating:** 4+ (no user-generated content, no unrestricted web, no violence)  
**Price:** Free, no in-app purchases, no ads

**Promotional text (170 characters, optional):**
Native electrical calculators for field work — voltage drop, conduit fill, ampacity, transformer protection, and more. Design aid, not a PE stamp.

**Description:**

Beckify is a professional field electrical calculator for engineers and technicians. It is a native iPhone and iPad app, not a website wrapper.

Calculate and check common jobsite numbers with units, formulas, and live results:

• Ohm's Law
• DC and AC power
• Power Wizard for DC, single-phase, and three-phase (amps, kW, kVA, HP)
• Voltage drop with 3% / 5% informational checks and a 310.16 ampacity cross-check
• Conduit fill for THHN in EMT (NEC Chapter 9 Table 1)
• Transformer sizing and overcurrent protection (NEC 450.3(B), including Note 1)
• 555 timer (astable and monostable)
• Motor full-load current from NEC Tables 430.248 and 430.250
• Wire size from NEC Table 310.16, 75 °C column

Search the toolbox (try “ampacity”). Save named jobs on device. No account, no ads, no analytics, no tracking.

This app is a design aid. It is not a PE stamp, permit, inspection, or a substitute for the National Electrical Code or a qualified engineer.

**Keywords (100 characters max, comma-separated draft):**
electrical,NEC,voltage drop,ampacity,conduit fill,transformer,calculator,electrician,ohms

**What's New (1.0):**
First release. Native field EE toolbox with local saved jobs.

**Support URL:** https://beckify.com  
**Marketing URL:** https://beckify.com  
**Copyright:** 2026 Trevor Beck  
**Contact:** trevorjohnbeck@gmail.com

**Privacy Policy URL (intended, once hosted):** App Store Connect requires a public HTTPS privacy-policy URL. The draft is [`ios/docs/PRIVACY.md`](PRIVACY.md) (“Data Not Collected”). It is **not** hosted on https://beckify.com in this PR. After this file is on `main`, a typical stand-in until a dedicated page exists is the GitHub blob URL for that path (for example `https://github.com/becktj90/beckify/blob/main/ios/docs/PRIVACY.md`). Do not treat the live site as hosting this policy.

## App privacy (nutrition label)

Data collection: **none** (see [`PRIVACY.md`](PRIVACY.md)).

- No analytics
- No tracking
- No advertising identifier
- No account
- Saved jobs use on-device storage only (`UserDefaults`)

Privacy manifest: `Beckify/PrivacyInfo.xcprivacy`  
- `NSPrivacyTracking` = false  
- No collected data types  
- UserDefaults accessed with reason CA92.1 (app functionality: saved jobs)

## Export compliance

The app uses only HTTPS for optional links the user taps (beckify.com, mailto). It does not implement custom cryptography. Info.plist includes `ITSAppUsesNonExemptEncryption = NO`. In App Store Connect, answer **No** to “Does your app use encryption?” except the standard HTTPS exemption if the form still appears.

## Screenshots (required sizes)

Not captured in this repository. This repo has not run an iOS Simulator UI build, signed the app, enrolled an Apple Developer team, uploaded TestFlight, or submitted to the App Store. On a Mac with Xcode, capture Simulator screenshots at the sizes below. Do **not** ship website screenshots.

Apple's current required sets typically include:

| Device | Logical size (points) | Common simulator |
| --- | --- | --- |
| 6.7" iPhone | 1290 × 2796 px (or 1320 × 2868 on newest) | iPhone 15 Pro Max / 16 Pro Max |
| 6.5" iPhone (if still asked) | 1284 × 2778 px | iPhone 11 Pro Max / 14 Plus |
| 12.9" iPad | 2048 × 2732 px | iPad Pro (12.9-inch) |

Take 3–8 screens per size. Suggested shots:

1. Toolbox search / tool list (dark premium home)
2. Power Wizard with the 480 V 3Ø 50 kW → 66.8 A result
3. Voltage drop with 3% / 5% notes and ampacity row
4. Conduit fill pass/fail
5. Transformer 450.3(B) result
6. Saved Jobs list
7. About (Trevor Beck, EE, beckify.com, email — no phone number)

Use dark appearance. Do not show ads, Amazon, games, or a phone number.

## App icon

Placeholder bolt/toolbox icon is in `Beckify/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024). Replace with a final design before submission if desired. Do not use a photograph of a real person.

## Remaining steps that require Apple Developer login

1. Enroll or renew **Apple Developer Program** ($99 USD/year) at https://developer.apple.com as Trevor Beck.
2. In Xcode → Signing & Capabilities, set **Team** on the Beckify target. Bundle ID `com.beckify.toolbox` must be registered to that team.
3. Run on a physical device at least once (capability / provisioning check).
4. Create the app record in [App Store Connect](https://appstoreconnect.apple.com): Productivity, 4+, privacy “Data Not Collected”, English listing copy above.
5. Archive in Xcode (Product → Archive) or `xcodebuild archive` with signing enabled.
6. Upload the build (Organizer or Transporter). Wait for processing.
7. Attach screenshots, review the encryption and content-rights questions, submit for review.
8. Answer App Review if they ask about NEC table transcription or “design aid” disclaimer.

Until those steps are done, the app exists only in this repository. It is **not** on the App Store.
