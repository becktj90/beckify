# Plot and chart bar

This is a standing requirement for every beckify.com tool, including every tool
PR after the toolbox shell and the SEO follow-up. A new calculator is not done
until its pictures meet this bar.

Compare the web visual with the matching view in `ios/Beckify` and
`ios/BeckifyMath`. Upgrade the web one where it is weaker. The iOS plot chrome
(`ios/Beckify/Views/Components/PlotChrome.swift`) and the dark chart tokens in
`ios/Beckify/Theme/Theme.swift` are the reference.

## What every visual has to do

- Render crisp vectors. Use SVG, or a canvas whose backing store is scaled by
  `devicePixelRatio` (cap at 2) and whose CSS size stays in CSS pixels.
- Use the app palette: background `#080b10`, cyan `#40bad6`, blue `#609ce6`,
  copper `#e09c56`. Status colors are good `#56d6a4`, warn `#f0bc48`, and bad
  `#f47078`. Do not introduce a violet series color.
- Label both axes in words, with units. Gridlines stay visible and quieter than
  the data.
- Show a legend when more than one series is on the plot.
- Offer a hover and touch readout of the nearest point, with the same units as
  the axes.
- Animate the trace smoothly, and honor `prefers-reduced-motion`.
- Size with the container. Nothing clips, overlaps, or overflows at a 390px
  phone width or a 1280px desktop width.
- Keep text at a contrast that reads on `#080b10` (foreground `#e8eef5`, muted
  `#94a2b2` for ticks only).

Schematics (transformer banks, conduit cross-sections, NEMA faces, battery
layouts) use the same palette and stay sharp at both widths. They do not need
Cartesian gridlines when they are not a graph.

## Visual QA before merge

Screenshot each plot the PR touches at desktop width (about 1280) and phone
width (about 390). Fix anything blurry, clipped, overlapping, or unreadable
before merging. The PR report includes the before and after shots.

`src/components/control/chartPalette.ts` is the React token source. The classic
toolbox plots live under `public/toolbox/js/` and `public/toolbox/css/styles.css`.
