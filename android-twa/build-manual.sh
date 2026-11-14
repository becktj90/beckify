#!/bin/bash
# Manual release build for the Beckify TWA (com.beckify.toolbox).
#
# Why this exists: the Gradle wrapper cannot build in this VM. The sandbox
# intercepts outbound TCP connects from JVM processes (even loopback), so the
# Gradle daemon's client<->daemon socket handshake fails with
# "Could not receive a message from the daemon" / "Unexpected type tag 109".
# (Java receives the sandbox's "Other TCP connections is turned off" text.)
# This script builds the exact same app without Gradle:
#   aapt2 (resources) -> javac -> d8 (dex) -> bundletool (AAB) -> jarsigner
# It reproduces what `bubblewrap build` / `./gradlew assembleRelease` would
# produce: package com.beckify.toolbox, versionName 1.0.6, versionCode 1,
# minSdk 21, targetSdk 36, androidbrowserhelper 2.7.4.
# Differences from the Gradle build: no R8 minification (release minifyEnabled
# is true in app/build.gradle, but the unminified AAB is still a valid,
# Play-acceptable release build).
#
# Usage: ./build-manual.sh   (run from android-twa/)
# Output: android-twa/beckify-1.0.6-release.aab  (signed with the upload key)
# Requires: JDK 17 + Android SDK at ~/workspace/android-tools (see below),
#   the upload keystore + keystore-credentials.txt in this directory.
#   Dependency AARs/JARs are cached at ~/workspace/android-tools/twa-deps
#   and downloaded from Google Maven / Maven Central on first run.

set -e
cd "$(dirname "$0")"
PROJECT_DIR=$PWD
JDK=~/workspace/android-tools/jdk17
export PATH="$JDK/bin:$PATH"
SDK=~/workspace/android-tools/android-sdk
AAPT2=$SDK/build-tools/36.1.0/aapt2
D8=$SDK/build-tools/36.1.0/d8
ANDROID_JAR=$SDK/platforms/android-36/android.jar
DEPS=~/workspace/android-tools/twa-deps
BUNDLETOOL=~/workspace/android-tools/bundletool.jar
SRC=$PWD/app/src/main
W=/tmp/twa-build/work

# --- 0. Dependencies (download if the cache is missing) ---------------------
if [ ! -f "$DEPS/androidbrowserhelper-2.7.4.aar" ]; then
  echo "Downloading TWA dependencies (Google Maven / Maven Central)..."
  mkdir -p "$DEPS"
  cd "$DEPS"
  dl() { curl -sSL -o "$2" "$1"; }
  dl https://maven.google.com/com/google/androidbrowserhelper/androidbrowserhelper/2.7.4/androidbrowserhelper-2.7.4.aar androidbrowserhelper-2.7.4.aar
  dl https://maven.google.com/androidx/browser/browser/1.10.0/browser-1.10.0.aar browser-1.10.0.aar
  dl https://maven.google.com/androidx/core/core/1.17.0/core-1.17.0.aar core-1.17.0.aar
  dl https://maven.google.com/androidx/annotation/annotation/1.9.1/annotation-1.9.1.jar annotation-1.9.1.jar
  dl https://maven.google.com/androidx/appcompat/appcompat/1.7.0/appcompat-1.7.0.aar appcompat-1.7.0.aar
  dl https://repo1.maven.org/maven2/com/google/guava/guava/33.4.8-android/guava-33.4.8-android.jar guava-33.4.8-android.jar
  dl https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib/2.1.20/kotlin-stdlib-2.1.20.jar kotlin-stdlib-2.1.20.jar
  dl https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib-jdk7/2.1.20/kotlin-stdlib-jdk7-2.1.20.jar kotlin-stdlib-jdk7-2.1.20.jar
  dl https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib-jdk8/2.1.20/kotlin-stdlib-jdk8-2.1.20.jar kotlin-stdlib-jdk8-2.1.20.jar
  dl https://repo1.maven.org/maven2/org/jetbrains/kotlinx/kotlinx-coroutines-core/1.8.1/kotlinx-coroutines-core-1.8.1.jar kotlinx-coroutines-core-1.8.1.jar
  dl https://repo1.maven.org/maven2/org/jetbrains/annotations/13.0/annotations-13.0.jar annotations-13.0.jar
  dl https://repo1.maven.org/maven2/org/jspecify/jspecify/1.0.0/jspecify-1.0.0.jar jspecify-1.0.0.jar
  dl https://repo1.maven.org/maven2/com/google/guava/failureaccess/1.0.3/failureaccess-1.0.3.jar failureaccess-1.0.3.jar
  while read -r src path; do
    base="https://maven.google.com/"; [ "$src" = "M" ] && base="https://repo1.maven.org/maven2/"
    curl -sSL -o "$(basename "$path")" "${base}${path}"
  done <<'LIST'
G androidx/activity/activity/1.9.0/activity-1.9.0.aar
G androidx/appcompat/appcompat-resources/1.7.0/appcompat-resources-1.7.0.aar
G androidx/collection/collection/1.4.2/collection-1.4.2.jar
G androidx/cursoradapter/cursoradapter/1.0.0/cursoradapter-1.0.0.aar
G androidx/drawerlayout/drawerlayout/1.0.0/drawerlayout-1.0.0.aar
G androidx/customview/customview/1.0.0/customview-1.0.0.aar
G androidx/emoji2/emoji2/1.3.0/emoji2-1.3.0.aar
G androidx/emoji2/emoji2-views-helper/1.2.0/emoji2-views-helper-1.2.0.aar
G androidx/fragment/fragment/1.5.4/fragment-1.5.4.aar
G androidx/lifecycle/lifecycle-runtime/2.6.2/lifecycle-runtime-2.6.2.aar
G androidx/lifecycle/lifecycle-common/2.6.2/lifecycle-common-2.6.2.jar
G androidx/lifecycle/lifecycle-viewmodel/2.6.1/lifecycle-viewmodel-2.6.1.aar
G androidx/lifecycle/lifecycle-livedata-core/2.5.1/lifecycle-livedata-core-2.5.1.aar
G androidx/lifecycle/lifecycle-livedata/2.5.1/lifecycle-livedata-2.5.1.aar
G androidx/lifecycle/lifecycle-viewmodel-savedstate/2.5.1/lifecycle-viewmodel-savedstate-2.5.1.aar
G androidx/lifecycle/lifecycle-common-java8/2.5.1/lifecycle-common-java8-2.5.1.jar
G androidx/arch/core/core-common/2.2.0/core-common-2.2.0.jar
G androidx/arch/core/core-runtime/2.2.0/core-runtime-2.2.0.aar
G androidx/savedstate/savedstate/1.2.1/savedstate-1.2.1.aar
G androidx/profileinstaller/profileinstaller/1.3.1/profileinstaller-1.3.1.aar
G androidx/interpolator/interpolator/1.0.0/interpolator-1.0.0.aar
G androidx/concurrent/concurrent-futures/1.0.0/concurrent-futures-1.0.0.jar
G androidx/tracing/tracing/1.2.0/tracing-1.2.0.aar
G androidx/versionedparcelable/versionedparcelable/1.1.1/versionedparcelable-1.1.1.aar
G androidx/annotation/annotation-experimental/1.4.1/annotation-experimental-1.4.1.aar
G androidx/core/core-viewtree/1.0.0/core-viewtree-1.0.0.aar
G androidx/viewpager/viewpager/1.0.0/viewpager-1.0.0.aar
G androidx/loader/loader/1.0.0/loader-1.0.0.aar
LIST
  # NOTE: listenablefuture-1.0 is intentionally NOT downloaded: its classes
  # duplicate Guava's and break d8. Guava already contains ListenableFuture.
  cd - >/dev/null
fi
if [ ! -f "$BUNDLETOOL" ]; then
  curl -sSL -o "$BUNDLETOOL" https://github.com/google/bundletool/releases/download/1.18.1/bundletool-all-1.18.1.jar
fi

# --- 1. Extract AARs ---------------------------------------------------------
mkdir -p "$DEPS/extracted"
for a in "$DEPS"/*.aar; do
  d="$DEPS/extracted/$(basename "$a" .aar)"
  [ -f "$d/classes.jar" ] || { mkdir -p "$d"; unzip -q -o "$a" -d "$d"; }
done

# --- 2. Overlay sources + generated resValues -------------------------------
# (Gradle generates these from app/build.gradle's resValue calls; we emit the
# same values as a values XML so aapt2 can link them.)
rm -rf $W; mkdir -p $W/gen $W/compiled $W/classes $W/dex $W/modules
cp -r $SRC $W/src
cat > $W/src/res/values/generated.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="appName">Beckify</string>
    <string name="launcherName">Beckify</string>
    <string name="launchUrl">https://beckify.com/</string>
    <string name="webManifestUrl">https://beckify.com/manifest.json</string>
    <string name="fullScopeUrl">https://beckify.com/</string>
    <string name="hostName">beckify.com</string>
    <color name="colorPrimary">#40BAD6</color>
    <color name="colorPrimaryDark">#000000</color>
    <color name="navigationColor">#000000</color>
    <color name="navigationColorDark">#000000</color>
    <color name="navigationDividerColor">#000000</color>
    <color name="navigationDividerColorDark">#000000</color>
    <color name="backgroundColor">#060B12</color>
    <string name="providerAuthority">com.beckify.toolbox.fileprovider</string>
    <bool name="enableNotification">true</bool>
    <integer name="splashScreenFadeOutDuration">300</integer>
    <string name="generatorApp">bubblewrap-cli</string>
    <string name="fallbackType">customtabs</string>
    <bool name="enableSiteSettingsShortcut">true</bool>
    <string name="orientation">any</string>
</resources>
EOF

# --- 3. Compile + link resources (protobuf format for bundletool) -----------
$AAPT2 compile --dir $W/src/res -o $W/compiled/app.zip
for d in $DEPS/extracted/*/; do
  n=$(basename $d)
  [ -d "$d/res" ] && $AAPT2 compile --dir "$d/res" -o "$W/compiled/$n.zip" 2>/dev/null || true
done
EXTRA=""
for pkg in androidx.activity com.google.androidbrowserhelper androidx.annotation.experimental androidx.appcompat androidx.appcompat.resources androidx.browser androidx.core androidx.arch.core androidx.core.viewtree androidx.emoji2 androidx.emoji2.viewsintegration androidx.fragment androidx.lifecycle.livedata androidx.lifecycle.livedata.core androidx.lifecycle.runtime androidx.lifecycle.viewmodel androidx.lifecycle.viewmodel.savedstate androidx.profileinstaller androidx.savedstate androidx.tracing; do
  EXTRA="$EXTRA --extra-packages $pkg"
done
$AAPT2 link -o $W/linked.apk \
  --manifest $W/src/AndroidManifest.xml \
  -I $ANDROID_JAR \
  --java $W/gen \
  --auto-add-overlay \
  --proto-format \
  --min-sdk-version 21 --target-sdk-version 36 \
  --version-code 1 --version-name 1.0.6 \
  $EXTRA \
  $W/compiled/*.zip

# --- 4. Compile Java ---------------------------------------------------------
CP=""
for j in $DEPS/extracted/*/classes.jar; do CP="$CP:$j"; done
for j in $DEPS/*.jar; do case "$j" in *listenablefuture*|*kotlin-stdlib-1.8.22*) continue;; esac; CP="$CP:$j"; done
CP="$CP:$ANDROID_JAR"
mkdir -p $W/srcfiles
find $W/src/java -name '*.java' > $W/srcfiles/list.txt
find $W/gen -name 'R.java' >> $W/srcfiles/list.txt
$JDK/bin/javac -encoding UTF-8 -source 8 -target 8 -nowarn -cp "$CP" -d $W/classes @$W/srcfiles/list.txt

# --- 5. Dex ------------------------------------------------------------------
$JDK/bin/jar cf $W/classes.jar -C $W/classes .
$D8 --min-api 21 --output $W/dex --lib $ANDROID_JAR \
  $W/classes.jar \
  $DEPS/extracted/*/classes.jar \
  $(ls $DEPS/*.jar | grep -v -e listenablefuture -e kotlin-stdlib-1.8.22)

# --- 6. Assemble base module + AAB ------------------------------------------
mkdir -p $W/modules/base/manifest $W/modules/base/dex $W/modules/base/res
cd $W && unzip -q -o linked.apk -d linked-extract
cp linked-extract/AndroidManifest.xml $W/modules/base/manifest/
cp $W/dex/*.dex $W/modules/base/dex/
cp linked-extract/resources.pb $W/modules/base/ 2>/dev/null || true
[ -d linked-extract/res ] && cp -r linked-extract/res/* $W/modules/base/res/ 2>/dev/null || true
cd $W/modules/base && zip -qr ../base.zip manifest dex res resources.pb
cd $W
$JDK/bin/java -jar $BUNDLETOOL build-bundle \
  --modules=$W/modules/base.zip --output=$W/beckify-release.aab

# --- 7. Sign with the upload keystore ---------------------------------------
# The private key is protected by the STORE password (keytool stored it under
# the store password; see keystore-credentials.txt). Use it for both.
STOREPASS=$(grep '^Store password:' "$PROJECT_DIR/keystore-credentials.txt" | sed 's/^Store password: //')
$JDK/bin/jarsigner -keystore "$PROJECT_DIR/beckify-upload.keystore" \
  -storepass "$STOREPASS" -keypass "$STOREPASS" \
  -digestalg SHA-256 -sigalg SHA256withRSA \
  -signedjar "$PROJECT_DIR/beckify-1.0.6-release.aab" $W/beckify-release.aab beckify-upload

echo "=== Built + signed: $PROJECT_DIR/beckify-1.0.6-release.aab ==="
ls -la "$PROJECT_DIR/beckify-1.0.6-release.aab"
