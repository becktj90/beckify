# Kestrel Heavy (standalone iOS app)

Native SwiftUI App Store product, **separate from Beckify Toolbox** and **Look Check**. One screen: a WKWebView that plays the existing Phaser 4 Pier 7 launch arcade from a **local bundled** `Game/` pack. This is not a website wrapper of beckify.com, and it is **not** a Toolbox catalog game.

The playable website stays at https://beckify.com/games/kestrel-heavy.

## Bundle ID (picked)

| Field | Value |
| --- | --- |
| Display name | Kestrel Heavy |
| Target / scheme | `KestrelHeavy` |
| Bundle ID | `com.beckify.kestrelheavy` |
| SKU (ASC stub) | `kestrel-heavy` |
| Team prefix | `9TR6R5LV8M` (same Apple Developer team as Beckify Toolbox and Look Check) |
| Deployment | iOS 17+, iPhone + iPad, portrait + landscape |
| Price | Free, no IAP, no ads (v1) |

**Why `com.beckify.kestrelheavy` and not `com.kestrelheavy.app`:** Beckify Toolbox is already `com.beckify.toolbox` on the same team; Look Check is `com.beckify.lookcheck`. A `com.beckify.*` sibling identifier keeps signing, App Store Connect, and the privacy URL under one developer record.

## Archive / Xcode Cloud (do not mix with Toolbox)

Toolbox Archive-iOS / Xcode Cloud Archive **must** stay on scheme **Beckify** (`com.beckify.toolbox`).

| ASC app | Bundle ID | Archive scheme |
| --- | --- | --- |
| Beckify Toolbox | `com.beckify.toolbox` | **Beckify** only |
| Look Check | `com.beckify.lookcheck` | **LookCheck** |
| Kestrel Heavy | `com.beckify.kestrelheavy` | **KestrelHeavy** |

Do **not** point Toolbox Archive-iOS at **KestrelHeavy** or **LookCheck**. Keep Archive workflows separate.

## What ships

- SwiftUI shell (`KestrelHeavyApp`, full-bleed `WKWebView`).
- Packed Phaser 4 cabinet from `artifacts/beckify/public/arcade/kestrel-heavy` → `ios/KestrelHeavy/Game/`.
- Offline: vendor Phaser, ES modules, NASA/Suno audio served from `kestrel-heavy://game/` (not `file://`). Scores stay in WKWebView `localStorage`.
- Portrait + landscape — Phaser 1280×720 `ENVELOP` fills the WKWebView; camera zoom keeps the corridor and booster in the cropped strip.
- Fictional **Kestrel Heavy / Pier 7 / Haven** branding. No Blue Origin or New Glenn marks.

## How to run (Mac + Xcode)

Linux CI can test `BeckifyMath` only. This environment cannot compile SwiftUI or archive.

1. Install Xcode 15 or later.
2. Open `ios/Beckify.xcodeproj`.
3. Select the **KestrelHeavy** scheme (not Beckify, not LookCheck).
4. Signing: confirm Team `9TR6R5LV8M` on the KestrelHeavy target.
5. Run on an iPhone / iPad simulator or device (portrait or landscape).

Refresh the local game pack after arcade changes (the KestrelHeavy target also runs this before compile):

```bash
python3 ios/scripts/pack_kestrelheavy_game.py
```

### xcodebuild (unsigned compile check, Mac)

```bash
cd ios
xcodebuild \
  -project Beckify.xcodeproj \
  -destination 'generic/platform=iOS Simulator' \
  -scheme KestrelHeavy \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Layout

```text
ios/KestrelHeavy/          SwiftUI app (this product)
ios/KestrelHeavy/Game/     Packed Phaser cabinet (generated)
ios/KestrelHeavy/docs/APP_STORE.md
ios/scripts/pack_kestrelheavy_game.py
ios/scripts/generate_kestrelheavy_icon.py
```

## Privacy

Play is on-device. No account, no analytics, no tracking, no network required. No camera / mic / location usage strings — v1 is a pure game. Nutrition label: no collected data types. Details: [`docs/APP_STORE.md`](docs/APP_STORE.md).

## App Store

Listing stub, screenshots, export compliance, and remaining Connect steps: [`docs/APP_STORE.md`](docs/APP_STORE.md).

This repository does **not** submit anything to the App Store.
