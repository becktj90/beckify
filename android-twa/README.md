# Beckify Android (Trusted Web Activity)

Wraps the Beckify PWA at https://beckify.com as a Trusted Web Activity for
Google Play. Generated with Bubblewrap (`@bubblewrap/cli` 1.27.0) from the
live PWA manifest; package `com.beckify.toolbox` (matches the iOS bundle ID),
version 1.0.6 (versionCode 1).

## Files

- `twa-manifest.json` — Bubblewrap manifest (source of truth for the TWA).
- `app/` — generated Android project (Bubblewrap template, AGP 8.9.1).
- `build-manual.sh` — reproducible release build (see below).
- `feature-graphic-1024x500.png` — Play Store feature graphic (1024×500).
- `beckify-1.0.6-release.aab` — signed release bundle (gitignored; rebuilt by
  the script below). SHA-256 of the build shipped 2026-11-14:
  `6c78400ad65d4e4d2f381e254dc1fc324a441dd9b403e143238cebf641740bf0`
  (3,993,917 bytes). Verified: `jarsigner -verify`, `bundletool validate`,
  universal APK dumps `com.beckify.toolbox`, versionCode 1, versionName 1.0.6,
  minSdk 21, targetSdk 36, LauncherActivity + autoVerify deep link +
  `TRUSTED_WEB_ACTIVITY_SERVICE`.
- `beckify-upload.keystore` + `keystore-credentials.txt` — **NEVER committed**
  (gitignored). The upload key; losing it means a new Play listing. The
  private key is protected by the **store** password (see the note in
  `keystore-credentials.txt`). SHA-256 fingerprint:
  `45:22:4F:2F:A8:22:8F:5F:B3:31:B9:DB:F1:4E:40:67:58:DD:E0:4E:EA:AA:89:DE:11:F8:F9:B6:F3:E5:39:51`

## Building

Normal route: `./gradlew assembleRelease` (Gradle 8.11.1, via
`bubblewrap build`). **That does not work in this VM's sandbox**: the sandbox
intercepts outbound TCP connects from JVM processes — even loopback — so the
Gradle daemon's client↔daemon handshake fails ("Could not receive a message
from the daemon"). On a normal machine, use Gradle.

In this VM, use the manual build instead:

```
./build-manual.sh
```

It does the same build without Gradle — `aapt2` → `javac` → `d8` →
`bundletool build-bundle` → `jarsigner` — using the JDK 17 / Android SDK /
dependency cache under `~/workspace/android-tools/`. It is the build that
produced the AAB above. One difference: no R8 minification (Gradle's release
build sets `minifyEnabled true`); the unminified AAB is still a valid
Play-acceptable release build.

## Digital Asset Links

`artifacts/beckify/public/.well-known/assetlinks.json` (in this same PR)
declares the SHA-256 above for `com.beckify.toolbox` with
`delegate_permission/common.handle_all_urls`. It deploys with the site
(Vercel serves `public/`). **After merge, verify it is live at
https://beckify.com/.well-known/assetlinks.json** — until then the TWA shows
the browser address bar instead of running fullscreen.

## Still needed before / at Play submission (Trevor's steps)

- Google Play developer account ($25 one-time) + create the app, upload
  `beckify-1.0.6-release.aab` as the first release.
- Phone screenshots (at least 2) from a real Android device/emulator running
  the TWA — none exist yet; no emulator was available in this VM.
- Store listing text, content rating questionnaire, privacy policy URL
  (https://beckify.com/privacy).
- Keep `beckify-upload.keystore` backed up privately; future releases must be
  signed with the same key.
