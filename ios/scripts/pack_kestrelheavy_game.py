#!/usr/bin/env python3
"""Copy the Phaser 4 Kestrel Heavy cabinet into the iOS app bundle pack.

Source of truth: artifacts/beckify/public/arcade/kestrel-heavy
Destination:     ios/KestrelHeavy/Game

Patches the copied index.html so WKWebView can play offline:
  * relative local-store stub (website uses /toolbox/js/local-store.js)
  * viewport-fit=cover + iOS safe-area / no-bounce / no-callout CSS
  * no Google Fonts network fetch
  * body marked is-embedded / is-ios-app (hides FULL, fills the shell)

Usage:
    python3 ios/scripts/pack_kestrelheavy_game.py
"""

from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "artifacts" / "beckify" / "public" / "arcade" / "kestrel-heavy"
DEST = ROOT / "ios" / "KestrelHeavy" / "Game"

IOS_CSS = """
    /* iOS WKWebView pack — injected by pack_kestrelheavy_game.py */
    html, body {
      overscroll-behavior: none;
      -webkit-overflow-scrolling: auto;
      -webkit-user-select: none;
      user-select: none;
      -webkit-touch-callout: none;
      -webkit-tap-highlight-color: transparent;
    }
    body.is-ios-app #arcade-fullscreen-btn { display: none !important; }
    body.is-ios-app .mc-hud {
      inset: max(12px, calc(env(safe-area-inset-top, 0px) + 8px))
             max(8px, env(safe-area-inset-right, 0px)) auto
             max(8px, env(safe-area-inset-left, 0px));
    }
    body.is-ios-app .hud-btns {
      top: max(8px, env(safe-area-inset-top, 0px));
      right: max(8px, env(safe-area-inset-right, 0px));
    }
    body.is-ios-app #ng-tape {
      left: max(8px, env(safe-area-inset-left, 0px));
      right: max(8px, env(safe-area-inset-right, 0px));
      bottom: max(6px, env(safe-area-inset-bottom, 0px));
    }
    html, body, body.is-ios-app .cabinet, body.is-ios-app #arcade-fs-wrapper {
      width: var(--game-vv-width, 100%) !important;
      height: var(--game-vv-height, 100%) !important;
      min-height: var(--game-vv-height, 100%) !important;
      max-width: none !important;
      max-height: none !important;
      aspect-ratio: unset;
    }
"""

LOCAL_STORE_STUB = """/* Offline stub — website uses /toolbox/js/local-store.js.
   Kestrel Heavy already persists scores in localStorage via js/storage.js.
   recordGameScore is a no-op so a missing toolbox IDB never breaks a flight. */
window.recordGameScore = window.recordGameScore || function () { return Promise.resolve(null); };
"""

SKIP_NAMES = {
    "ENGINE.md",
    "STORAGE.md",
}


def patch_index(html: str) -> str:
    ios_viewport = (
        'content="width=device-width, initial-scale=1.0, viewport-fit=cover, '
        'maximum-scale=1.0, user-scalable=no"'
    )
    if ios_viewport not in html:
        html = html.replace(
            'content="width=device-width, initial-scale=1.0, viewport-fit=cover"',
            ios_viewport,
        )
    if ios_viewport not in html:
        html = html.replace(
            'content="width=device-width, initial-scale=1.0"',
            ios_viewport,
        )
    html = html.replace(
        'content="default-src \'self\'; script-src \'self\' \'unsafe-inline\'; style-src \'self\' \'unsafe-inline\' https://fonts.googleapis.com; font-src \'self\' https://fonts.gstatic.com data:; img-src \'self\' data: blob:; connect-src \'self\'; worker-src \'self\' blob:; object-src \'none\'; base-uri \'self\'; form-action \'self\';"',
        'content="default-src \'self\' kestrel-heavy:; script-src \'self\' \'unsafe-inline\' kestrel-heavy:; style-src \'self\' \'unsafe-inline\'; font-src \'self\' data:; img-src \'self\' data: blob:; connect-src \'self\' kestrel-heavy:; worker-src \'self\' blob:; media-src \'self\' blob: kestrel-heavy:; object-src \'none\'; base-uri \'self\'; form-action \'self\';"',
    )
    html = html.replace(
        '  <link rel="preconnect" href="https://fonts.googleapis.com">\n'
        '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
        '  <link href="https://fonts.googleapis.com/css2?family=Exo+2:wght@600;700;800&family=IBM+Plex+Mono:wght@500;600&family=Sora:wght@400;600&display=swap" rel="stylesheet">\n',
        "  <meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n",
    )
    html = html.replace(
        '<script src="/toolbox/js/local-store.js"></script>',
        '<script src="./local-store.js"></script>',
    )
    html = html.replace(
        '<body data-arcade-standalone="true" data-phase="MENU">',
        '<body class="is-cabinet is-embedded is-ios-app" data-arcade-standalone="true" data-ios-app="true" data-phase="MENU">',
    )
    if "is-ios-app .mc-hud" not in html:
        html = html.replace("  </style>", IOS_CSS + "  </style>")
    return html


def copy_tree() -> None:
    if not SRC.is_dir():
        raise SystemExit(f"Missing arcade source: {SRC}")
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True)

    for item in SRC.iterdir():
        if item.name in SKIP_NAMES:
            continue
        target = DEST / item.name
        if item.is_dir():
            shutil.copytree(item, target, ignore=shutil.ignore_patterns("README.md"))
        else:
            shutil.copy2(item, target)

    index_path = DEST / "index.html"
    index_path.write_text(patch_index(index_path.read_text()), encoding="utf-8")
    (DEST / "local-store.js").write_text(LOCAL_STORE_STUB, encoding="utf-8")
    (DEST / "PACK.md").write_text(
        "Packed from `artifacts/beckify/public/arcade/kestrel-heavy` by "
        "`ios/scripts/pack_kestrelheavy_game.py`.\n\n"
        "Do not edit files here by hand. Re-run the pack script after arcade changes.\n"
        "The KestrelHeavy Xcode target also runs this script as a pre-compile phase.\n",
        encoding="utf-8",
    )

    packed = index_path.read_text()
    if "/toolbox/js/" in packed:
        raise SystemExit("Pack left an absolute /toolbox/js path in index.html")
    if packed.count("viewport-fit=cover") != 1:
        raise SystemExit("Pack viewport-fit=cover missing or duplicated")
    if not (DEST / "vendor" / "phaser.min.js").is_file():
        raise SystemExit("Pack missing vendor/phaser.min.js")
    if not (DEST / "js" / "main.js").is_file():
        raise SystemExit("Pack missing js/main.js")
    if not (DEST / "js" / "voice.js").is_file():
        raise SystemExit("Pack missing js/voice.js")
    if not (DEST / "js" / "telemetry.js").is_file():
        raise SystemExit("Pack missing js/telemetry.js")
    if not (DEST / "js" / "fullscreen.js").is_file():
        raise SystemExit("Pack missing js/fullscreen.js")
    if not (DEST / "js" / "camera.js").is_file():
        raise SystemExit("Pack missing js/camera.js")


def main() -> None:
    copy_tree()
    print(f"Packed {SRC} -> {DEST}")


if __name__ == "__main__":
    main()
