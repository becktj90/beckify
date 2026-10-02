# Panel Directory — physical-device gaps

This PR hardens the Panel Directory / OCR trust model on Linux CI and in pure Swift tests. The following still need a physical iPhone / iPad before claiming field readiness:

1. **Camera capture roles** — Directory / Nameplate / Deadfront guidance, crop/rotate/glare, and multi-photo coverage were not exercised on-device in this environment.
2. **Vision pipeline** — ImageSanitizer flatten + ResilientOCREngine multi-pass + FuzzyPanelGrid on real plastic-sleeve glare / skewed cards.
3. **Source-crop tap** — Evidence boxes from Vision → field tap → crop overlay need a photo with bounding boxes.
4. **Cloud Analyze cancel** — Cancel mid-flight with real `/api/analyze-panel` latency; confirm prior draft is not overwritten by a late tile.
5. **Worksheet handoff** — Merge/replace preview writing Load Worksheet keys, then opening that tool on-device.
6. **Odd/even partial cards** — Mid-panel crops that must not renumber from 1; verify against a 42- or 84-circuit sticker.
7. **Conflict queue UX** — Two overlapping Analyze tiles that disagree on a description.

## Honesty

- Local OCR remains the default; cloud only after explicit Analyze.
- Confirming a schedule is not a measured load study.
- No capacity-to-add from breaker trips alone; OCR never claims code compliance or available capacity.
- Needs review / Conflict / Verified labels are not calibrated confidence percents.

Linux CI does not compile the iOS target or run Vision. `swift test` on BeckifyMath covers the pure trust/parser logic when a Swift toolchain is available.
