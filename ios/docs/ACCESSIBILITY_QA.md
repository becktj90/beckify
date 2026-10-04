# Beckify iOS accessibility and field-use QA

This checklist is a release gate, not a claim that device testing has already
passed. Run it on a signed or Simulator build of the **Beckify** scheme; Linux
math tests do not exercise SwiftUI, VoiceOver, or system file pickers.

## Assistive access

- [ ] Use VoiceOver to navigate Field home, search results, Favorites, Jobs,
  Settings, and at least one calculator from each area.
- [ ] Confirm each numeric field announces its label, optional state, unit,
  and any validation message.
- [ ] Confirm result rows announce the result label and value together, including
  units; stale results are identified as stale.
- [ ] Confirm Calculate, Reset, Example, Copy, Save, disclosure, and navigation
  actions have meaningful names and state.
- [ ] With Voice Control, activate each primary action by its spoken label.
- [ ] With Switch Control, reach and operate segmented controls, pickers,
  disclosure buttons, and the bottom Calculate bar.

## Text, display, and motion

- [ ] Test the largest Dynamic Type sizes on a compact iPhone and iPad. No input,
  result, warning, or action may be clipped or made unreachable.
- [ ] Test light and dark appearance, Increase Contrast, and Button Shapes.
  Status must not rely on color alone.
- [ ] Enable Reduce Motion. Navigation and disclosure changes must remain
  understandable without animation.
- [ ] Check landscape and split-screen iPad widths, including long formulas,
  code notices, imported note metadata, and multi-line results.

## Field workflow

- [ ] Enter a multi-field calculation using only the keyboard. Verify Next,
  Done, and Calculate remain reachable and focus follows visual order.
- [ ] Verify controls are usable one-handed and meet the shared 44-point target.
- [ ] Test one stale result: edit an input after Calculate, confirm the stale
  state is announced and the old result cannot be saved.
- [ ] Test permission denial and recovery for each instrument without blocking
  access to Toolbox or other tools.
- [ ] Test the Saved Jobs file importer and exporter with a valid archive,
  malformed JSON, an unsupported schema version, and an archive containing
  duplicate note IDs. Confirm canceling either system picker is silent.

## Back navigation

CI runs `BeckifyUITests/NavigationTests` on iPhone 16 with iOS 18.5 and 26.2.
Run the same tests on a Mac with the **Beckify** scheme:

```bash
xcodebuild -project ios/Beckify.xcodeproj -scheme Beckify \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test
```

- [ ] From Field → Jobsite → Voltage Drop, swipe from the left edge once.
  Jobsite must remain visible; a second swipe returns to Field home.
- [ ] From Voltage Drop, open Wire Size & Ampacity through the related-tools
  row. One edge swipe must return to Voltage Drop; the next returns to Jobsite.
- [ ] Repeat after pinning/unpinning a tool and after switching tabs. Confirm
  the back button follows the same sequence as the edge swipe.
- [ ] Start an edge swipe and cancel it. The current tool and its inputs must
  stay visible, and the next completed swipe must still return one page.

## Charts and diagrams

- [ ] Navigate plots and diagrams with VoiceOver. Confirm a concise summary,
  units, and a meaningful nonvisual equivalent of the key result is available.
- [ ] Verify full-screen, zoom, and share controls are labeled and can be
  dismissed without relying on a gesture alone.
- [ ] Compare shared PNG output with on-screen labels and disclaimers.

Record device model, iOS version, appearance, text size, and any defect before
marking a release checklist item complete.
