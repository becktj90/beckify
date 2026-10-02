# Switchgear Logic Lab

The website tool is the source of truth at `artifacts/beckify/public/toolbox/switchgear-logic-lab.html` and its `js/switchgear` engine, UI script, and CSS. The iOS catalog opens the same files in a bundled WKWebView; the Xcode Beckify target already includes its two Swift files and resource folder. No network service is needed.

After changing the tool, run:

```sh
python3 ios/scripts/pack_switchgear_logic_lab.py
python3 ios/scripts/pack_switchgear_logic_lab.py --check
node --test artifacts/beckify/tests/switchgear-final.test.cjs
```

The website test command includes the original 25 engine acceptance checks and the finishing regression suite. The Switchgear Logic Lab workflow also detects drift between the website and iOS bundle. The generated website permalink opens and embeds the actual tool.

## Workflow

Start blank or load the main-tie-main generator demo. Load a one-line template before mapping signals. Add or edit signals and assign command/feedback roles to breakers. Connect logic nodes, set breaker operate delays, and script input, breaker position, source availability, or supported fault events. Run a scenario to see the transfer sequence, final-scan signal explanation, timing chart, and candidate findings. Static lint, bounded settled-state enumeration, latch comparison, and saved-scenario timer interpretation comparison are available under Analyze. Review HTML includes logic, topology, I/O, findings with evidence and disposition, coverage, and the latest transfer sequence. JSON projects move between app and website.

Any project change clears the prior run, coverage, and findings. Findings are deduplicated by category and title. Automatic storage uses localStorage on the website and UserDefaults through the native bridge in iOS. Exported JSON, CSV, and HTML use browser downloads on the website and the system share sheet in iOS. Exports are review packages, never vendor-loadable settings files.

## Model limits

This is an offline model for engineering review. The demo deliberately exposes weaknesses; it is not a commissioned transfer scheme. Entellisys assumptions remain unverified. Events occur on the next scan at or after their timestamp. Breaker movement is applied before feedback is read for that scan. Momentary commands act on a rising edge; maintained commands retry while asserted. Supported faults are fail-to-open, fail-to-close, slow-breaker (default 5× delay), and inverted feedback. Source losses are source-availability events. A primary-disconnected or locked-out breaker does not respond to modeled commands.

Scenarios are limited to 10,000 scans and 1,000 events. Enumeration is exhaustive up to 10 independent inputs and samples at most 1,024 vectors beyond that. Each vector starts with cleared runtime state and has at most 500 settling scans; unsettled vectors remain explicitly marked. This does not prove every latch history or timing sequence. Review vendor manuals and actual equipment behavior independently.

## Mac/device checks still required

Build scheme Beckify in Xcode. On iPhone and iPad, load the demo, edit and map a signal, run a scenario, inspect timing/transfer/explanation screens, and change a timer field to confirm prior results clear. Close and reopen the app to verify persistence. Import a JSON project through Files. Export JSON, HTML, and CSV through the share sheet; cancel an export and retry. Confirm dialogs, iPad popover placement, VoiceOver tab navigation, and offline operation in airplane mode. This Linux environment cannot verify WebKit native dialogs, Files import, signing, or an iOS archive.
