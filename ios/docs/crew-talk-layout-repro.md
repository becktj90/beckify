# WP-0B — Crew Talk layout repro (Quick lines / Speak / TextField / tab bar)

Tip investigated: `f68b8a5044bb6afed09fa151835dd0d38cd3fe6b` (`main`).
Scheme: Beckify only. No MARKETING_VERSION / CURRENT_PROJECT_VERSION bump.
Screenshots: **BLOCKED** in this environment (no Mac, no Xcode Simulator). Every cell below is unread on device. Cos, Trevor, or a Mac worker must capture them.

## Symptom

On Crew Talk (`SpanishTranslatorView`, Toolkit → Reference, still `ToolID.spanishTranslator`), the bottom band collides:

- **Quick lines** chips
- the composer **TextField**
- the **Speak** button
- the root **tab bar** (Toolbox / Favorites / Jobs)

Which of those four sits on top of which other one changes with phone height, Dynamic Type, and whether the keyboard is up. The failure is overlap, not a missing control. Record, Translate, Test, and the crew picker are not the overlapping row; they only steal vertical space above it.

## Where it lives

| Piece | Type | File |
| --- | --- | --- |
| Screen | `SpanishTranslatorView` | `ios/Beckify/Calculators/SpanishTranslatorView.swift` |
| Scroll column + second bottom inset | `ToolScaffold` | `ios/Beckify/Views/Components/ToolUX.swift` |
| Tab bar | `RootView` `TabView` | `ios/Beckify/BeckifyApp.swift` |
| Push | `ToolGridView` `NavigationStack` → `CalculatorHostView` | `ios/Beckify/Views/ToolGridView.swift`, `ios/Beckify/Views/ToolboxView.swift` |

No other scheme (LookCheck, KestrelHeavy, Drive) hosts this screen.

## Devices / Dynamic Type / keyboard

Published point sizes (not measured here):

- iPhone SE (3rd gen): 375 × 667, home button. Tab bar ~49 pt. Bottom safe area is the tab bar, not a home indicator.
- iPhone 16: 393 × 852, home indicator. Tab bar band ~83 pt (bar + indicator).
- iPhone 16 Pro Max: 440 × 956, same indicator band ~83 pt.

Destination height is roughly screen minus status, inline nav bar, and tab bar. That is about **550 pt on SE**, **670 pt on 16**, **770 pt on 16 Pro Max**. Keyboard heights below are typical UIKit figures, not measured here (~216–260 SE, ~336 iPhone 16, ~346 Pro Max).

| Device | Dynamic Type | Keyboard | Screenshot | Read from code (not from a screenshot) |
| --- | --- | --- | --- | --- |
| iPhone SE (3rd gen) | default | down | **BLOCKED** | Tight but can clear if the scroll actually receives the dock inset and the answer is one line. A 4-line answer + dialect helper drops the scroll viewport to a few points. Quick lines then sit under the dock. |
| iPhone SE (3rd gen) | default | up | **BLOCKED** | Expected overlap. Keyboard (~216+) plus the top crew inset (still ~200 pt with the sprite shrunk) plus the dock leaves little or no viewport. |
| iPhone SE (3rd gen) | accessibility | down | **BLOCKED** | Expected overlap. The text field and Quick lines use scaling fonts. The top bar does **not** shrink unless the field is focused. |
| iPhone SE (3rd gen) | accessibility | up | **BLOCKED** | Expected overlap. Worst cell. Field grows, keyboard covers the tab bar, dock and chips compete for what is left. |
| iPhone 16 | default | down | **BLOCKED** | Likely clear for a one-line answer if insets compose. Long answer is tight (~120 pt left under a ~316 pt crew bar). |
| iPhone 16 | default | up | **BLOCKED** | Expected overlap of Quick lines under the dock. Remaining viewport after keyboard + compact crew bar + dock is ~30 pt. |
| iPhone 16 | accessibility | down | **BLOCKED** | Expected overlap once the field wraps or an answer is showing. Top sprite stays 168 pt. |
| iPhone 16 | accessibility | up | **BLOCKED** | Expected overlap. |
| iPhone 16 Pro Max | default | down | **BLOCKED** | Likely clear. Most room (~350 pt under the crew bar before a long answer). |
| iPhone 16 Pro Max | default | up | **BLOCKED** | Borderline. One-line dock may leave ~120 pt. A wrapped field or dialect helper likely covers Quick lines. |
| iPhone 16 Pro Max | accessibility | down | **BLOCKED** | Likely overlap once the scaling field and caption chips grow. Not proven without a shot. |
| iPhone 16 Pro Max | accessibility | up | **BLOCKED** | Expected overlap. |

**Screenshot note:** this worker cannot run iOS Simulator. Do not treat the “expected” column as a captured repro. Cos/Trevor or a Mac worker must shoot SE / 16 / 16 Pro Max × default vs accessibility Dynamic Type (AX3 or larger) × keyboard down vs up, scrolled so Quick lines are on screen, with and without a multi-line answer.

## Root cause (from code)

Confirmed container stack, top to bottom, inside the tab:

1. **`crewHelperBar`** — `SpanishTranslatorView.safeAreaInset(edge: .top)`. Pinned. Sprite `height: composerFocused ? 96 : 168`, first name, `crew.blurb` (`Theme.TypeRole.help`, a scaling `.caption`) hidden only while `composerFocused`, then a horizontal chip row (`minHeight: Theme.touchTarget` = 44, font fixed 16 pt). Padding `Theme.Space.xs` / `.sm`. Ideal height is about **300 pt** keyboard-down and about **200 pt** keyboard-up. It does not react to Dynamic Type or to short phones.

2. **`ToolScaffold` `ScrollView`** — holds `quickPhrasesCard` (`ResultCard` title `"Quick lines"`). Chips use `.font(.caption.weight(.semibold))` (scales) and `minHeight: Theme.touchTarget`. The card is after `phaseLine`, `directionCard`, `attentionCard`, and `recordCard`, so it is the first interactive block near the bottom of the form. The scroll uses `.scrollDismissesKeyboard(.interactively)` and horizontal padding `Theme.Space.lg` (20).

3. **`ToolScaffold.safeAreaInset(edge: .bottom)`** — always installed (`immersivePlay` is false). Content is `stickyChrome`. Crew Talk passes `stickyAnswer: nil` and does not register a Calculate field, so `showsStickyCalculate` is false and the `VStack` is empty. **Confirmed:** a second bottom `safeAreaInset` still wraps this screen. **Hypothesis:** a zero-height inner inset on the same edge blocks the outer dock inset from becoming the scroll view’s content inset, so Quick lines draw underneath `composerDock` even when the arithmetic says a sliver of room remains.

4. **`composerDock`** — `SpanishTranslatorView.safeAreaInset(edge: .bottom)` **outside** `ToolScaffold`. One `VStack`: `TextField` (`axis: .vertical`, `lineLimit(1...3)`, default font so it scales, `.focused($composerFocused)`), then an `HStack` of the answer (`lineLimit(4)`, **fixed** 18 pt) plus optional dialect helper (`lineLimit(3)`, **fixed** 13 pt) plus **Speak** (`frame(width:height: Theme.touchTarget)`). Padding is `.top 10` / `.bottom 8` only. Comment in source says this dock stays above the keyboard. It does **not** call `ignoresSafeArea`, and it does **not** add its own keyboard or tab-bar padding. It relies entirely on `safeAreaInset` placement. There is no max height. Ideal height runs from ~100 pt (one line, no dialect) to well over 300 pt once the field hits 3 lines at an accessibility size and the answer uses its 4-line limit.

5. **`RootView` `TabView`** — `.toolbarBackground(.ultraThinMaterial, for: .tabBar)` and `.toolbarBackground(.visible, for: .tabBar)`. The bar is a real bottom safe area, not an overlay the dock can ignore. **Confirmed** it stays visible; nothing on this screen sets `toolbar(.hidden, for: .tabBar)`. **Hypothesis:** with the keyboard up, UIKit covers that bar, but SwiftUI still adds the tab-bar safe area on top of the keyboard safe area. The dock then sits a tab-bar-height too high and covers Quick lines, or it fails to move and the keyboard covers the TextField and Speak.

6. **`ToolScaffold` background** — `.background(Theme.background.ignoresSafeArea())`. **Confirmed** this paints under the home indicator / tab bar. It does not move the dock’s frame. It can make scroll content that is missing a bottom inset show through the frosted tab bar.

`safeAreaInset` does not compress its child. If the top inset’s ideal height plus the dock’s ideal height exceed the destination, the insets paint over the scroll. Quick lines, the TextField, and Speak are in **different** containers (scroll card vs bottom inset vs tab bar), so they can occupy the same y. That is the fight: **top `safeAreaInset` (`crewHelperBar`) + bottom `safeAreaInset` (`composerDock`) + `ToolScaffold`’s second bottom `safeAreaInset` (`stickyChrome`) + keyboard safe area + `TabView` tab-bar safe area**, with the Quick lines chip row left in the scroll between them.

Build 247 (`4fa354e`) and build 251 (`87406a2`) already moved the field, answer, and Speak into `composerDock` so they would clear the keyboard. That fixed “field hidden by keyboard” by adding another pinned bottom inset. It left Quick lines in the scroll and left the dock’s height unbounded, which is why the overlap moves to the tab bar and the chip row instead of going away.

### Confirmed vs hypothesis

**Confirmed from code**

- Quick lines are not in the dock. TextField and Speak are not in the scroll.
- Two bottom `safeAreaInset`s are nested (scaffold sticky chrome, then `composerDock`).
- Dock height is unbounded (`lineLimit` 1...3 / 4 / 3, no `maxHeight`).
- Crew bar shrinks only when `composerFocused` is true, not for short height or Dynamic Type.
- Scaling text: TextField (body) and Quick lines (`.caption`). Not scaling: answer 18 pt, dialect 13 pt, Speak 44 pt, crew-name chips 16 pt.
- Tab bar safe area is always on (`toolbarBackground` visible). Dock padding bottom is 8 pt.
- `ignoresSafeArea` on this screen is only the scaffold background.

**Hypothesis (needs the Mac matrix)**

- Empty `stickyChrome` inset drops the outer dock out of the scroll content inset (overlap even when the budget looks positive).
- Keyboard safe area and tab-bar safe area are both applied, so the dock floats a bar-height too high or stays under the keyboard.
- Exact cell boundaries in the table (especially iPhone 16 default keyboard-down, and Pro Max default keyboard-up).

## Recommended fix (small, local)

Do this in `SpanishTranslatorView.swift` only. Do not redesign the tool. Do not change `ToolScaffold` for every calculator, and do not touch the tab bar.

1. Put **Quick lines chips, TextField, answer, and Speak in the one bottom `safeAreaInset`**, stacked in one `VStack`, so they cannot cover each other. Keep `spanishTranslator.quickPhrase.*`, `spanishTranslator.composer`, and `spanishTranslator.speakAgain`.
2. **Cap that inset** (leave room for the crew bar and a sliver of the form). If the stack is taller than the cap, **scroll inside the dock**. The inset’s height is what the scroll content inset and the tab-bar safe area see, so the dock cannot grow through the tab bar.
3. **Compact `crewHelperBar`** when the destination is short (`< ~640 pt`), when Dynamic Type `isAccessibilitySize`, or when the field is focused — not only on focus. Same sprite, shorter; hide the blurb in that mode (already the focus behavior).
4. Leave the single keyboard **Done** `ToolbarItemGroup(placement: .keyboard)` as it is (`showsKeyboardToolbar: false` on the scaffold).

Follow-up only if a device shot still shows a tab-bar gap with the keyboard up: add a default-true flag on `ToolScaffold` so Crew Talk can skip the empty `stickyChrome` `safeAreaInset`. That file is shared; do not change its behavior for other tools unless a shot proves the nested inset is still in the way.

No version bump. No `APP_STORE` / `PRIVACY` / catalog edit for this layout bug.

## Screenshot handoff

Screenshots require Mac Xcode Simulator. Cos/Trevor or a Mac worker must capture:

- iPhone SE (3rd gen), iPhone 16, iPhone 16 Pro Max
- Dynamic Type default and an accessibility size
- keyboard down and keyboard up
- Quick lines scrolled into view, plus one shot with a multi-line answer and dialect helper showing

Until those exist, the matrix above is a code reading, not a visual repro.
