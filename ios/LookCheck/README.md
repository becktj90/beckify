# Look Check (standalone iOS app)

Native SwiftUI App Store product, **separate from Beckify Toolbox**. One screen: take or choose a photo, pick **Mean** or **Nice**, tap **Analyze**, get a useful verdict plus a long exaggerated roast.

This is not a website wrapper and not a second copy of the Field EE toolbox.

## Bundle ID (picked)

| Field | Value |
| --- | --- |
| Display name | Look Check |
| Bundle ID | `com.beckify.lookcheck` |
| SKU (ASC stub) | `look-check` |
| Team prefix | `9TR6R5LV8M` (same Apple Developer team as Beckify Toolbox) |
| Deployment | iOS 17+, iPhone + iPad |
| Price | Free, no IAP, no ads (v1) |

**Why `com.beckify.lookcheck` and not `com.lookcheck.app`:** Beckify Toolbox is already `com.beckify.toolbox` on the same team. A `com.beckify.*` sibling identifier keeps signing, App Store Connect, and privacy URL under one developer record. `com.lookcheck.app` would look like an unrelated publisher.

The shared contract lives in `ios/BeckifyMath` (`PhotoLookCheck`, `LookRoastMode`).

## Core loop

1. Camera or photo library — the image stays on device.
2. Toggle **Mean** (savage comedy) or **Nice** (over-the-top hype) before or after a result.
3. **Analyze** POSTs an upright JPEG to `https://api.beckify.com/api/analyze-look` with `roastMode: "mean" | "nice"`.
4. Result: verdict, photo metrics, detailed roast card, Share.

Toolbox / website clients omit `roastMode` (or send `bro`) and keep the short BroGPT one-liner.

## Hard safety

- Anyone who appears under 18 → `declined`, empty roast, no appearance rating.
- No sexual or graphic content.
- No race, disability, or body-shaming. Roast style, vibe, grooming, angle, lighting, photo quality.
- Mean mode is savage comedy, not hate speech.

## How to run (Mac + Xcode)

Linux CI can test `BeckifyMath` only. This environment cannot compile SwiftUI or archive.

1. Install Xcode 15 or later.
2. Open `ios/Beckify.xcodeproj`.
3. Select the **LookCheck** scheme (not Beckify).
4. Signing: confirm Team `9TR6R5LV8M` on the LookCheck target.
5. Run on an iPhone / iPad simulator or device.

### xcodebuild (unsigned compile check, Mac)

```bash
cd ios
xcodebuild \
  -project Beckify.xcodeproj \
  -destination 'generic/platform=iOS Simulator' \
  -scheme LookCheck \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Math tests (Linux or Mac):

```bash
cd ios/BeckifyMath
swift test
```

## API

`POST https://api.beckify.com/api/analyze-look`

```json
{
  "imageBase64": "data:image/jpeg;base64,…",
  "mimeType": "image/jpeg",
  "task": "look",
  "roastMode": "mean"
}
```

After merging the API change, **redeploy** the Vercel project whose root is `artifacts/api-server`. See `artifacts/api-server/README.md`. Until that deploy, production may still ignore `roastMode` and return the BroGPT one-liner.

## Layout

```text
ios/LookCheck/          SwiftUI app (this product)
ios/BeckifyMath/        Shared look-check JSON + roastMode
ios/LookCheck/docs/APP_STORE.md
```

## Privacy

Taking or choosing a photo does not upload it. Analyze does. Entertainment only. Camera usage string is on the LookCheck target. Nutrition label: Photos, App Functionality, not linked, not tracking. Details: [`docs/APP_STORE.md`](docs/APP_STORE.md).

## App Store

Listing stub, screenshots, export compliance, and remaining Connect steps: [`docs/APP_STORE.md`](docs/APP_STORE.md).

This repository does **not** submit anything to the App Store.
