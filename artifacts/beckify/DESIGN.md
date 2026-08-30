---
version: alpha
name: "Beckify Arcade"
description: "A responsive collection of short, family-friendly browser games inside Beckify's deep-space visual world."
colors:
  background: "#05060F"
  surface: "rgba(255, 255, 255, 0.035)"
  text: "#EEF0FA"
  muted: "#9497B8"
  border: "rgba(255, 255, 255, 0.09)"
  violet: "#8B7BFF"
  blue: "#4F8BFF"
  play: "#55E6CB"
  reward: "#FFB84A"
typography:
  body:
    fontFamily: "Inter, system-ui, -apple-system, Segoe UI, sans-serif"
  display:
    fontFamily: "Space Grotesk, Inter, system-ui, sans-serif"
  utility:
    fontFamily: "JetBrains Mono, Courier New, monospace"
rounded:
  DEFAULT: "0.5rem"
  stage: "1.5rem"
  control: "0.625rem"
spacing:
  screen-gutter: "1rem"
  control-gap: "0.5rem"
  section-gap: "1.5rem"
components:
  game-stage:
    border: "one luminous perimeter border"
    focus: "visible violet ring"
  game-control:
    minHeight: "2.75rem"
    touchTarget: "2.75rem"
---

# Beckify Arcade Design System

## Overview

### Creative North Star

Beckify Arcade should feel like a well-loved tabletop arcade cabinet tuned for a dark family game room: glowing controls, clear score readouts, and toy-like reward colors against the established nebula background.

### Product context and register

- **Audience and primary job:** Families and young children playing fast, repeatable browser games; start a round and understand the next action immediately.
- **Target market(s) and evidence:** General English-language Beckify site; no region-specific market assumptions.
- **Locale(s) and language policy:** English UI with short, plain action labels.
- **Usage scene:** Phone or laptop, short breaks, touch-first controls and a readable desktop keyboard path.
- **Register:** Hybrid — Beckify brand shell with product-like game controls.
- **Memorable signature:** A luminous cabinet edge and a single bright play/reward color per game. Cosmic Cadet extends this into a portrait arcade cabinet with a three-part combat HUD, a physical-looking touch d-pad, and a dedicated shoot button.
- **Restraint:** HUDs stay at the outer edge and never cover the player or the lower-middle playfield during a round.
- **Anti-references:** Admin dashboards, tiny unlabeled icon controls, and permanent tutorial panels over gameplay.
- **Token ownership/runtime mapping:** This document mirrors the canonical CSS variables in `src/index.css`; it does not generate runtime tokens.

## Colors

Use the existing deep-space background and translucent surfaces for the site shell. Violet and blue identify Beckify navigation and focus. Each game reserves one action color: cyan for play/positive feedback and amber for scores/rewards. Errors and hazards use game-local warm color, never red text alone.

## Typography

Space Grotesk is used for game titles and state headings; Inter carries directions and button labels; JetBrains Mono is reserved for compact score, speed, and status readouts. Use sentence case for actions. Keep instructions to one sentence at a time on mobile.

## Layout

The canvas is the primary surface. Cosmic Cadet frames it with a sparse desktop mission brief and quick tips; on phones those secondary panels collapse, leaving the portrait cabinet and thumb controls. Controls sit immediately below it with 44px minimum touch targets. The header contains only title, best score, sound, and fullscreen. Mobile fullscreen maintains the playfield’s aspect ratio and always exposes an exit affordance.

## Elevation & Depth

Stages use a single restrained outer glow, a subtle inner grid/atmosphere, and a contrast backing for overlays. Controls lift only on hover/press; persistent shadows do not compete with canvas effects.

## Shapes

Game stages use rounded cabinet corners on pages and square edges in fullscreen. Action controls use a 10px radius, with circular icon-only controls only when their accessible label clearly explains them.

## Components

### Foundational visual states

All game controls have default, hover, active, visible focus, and muted/disabled states. The play screen announces score and state changes through text, color, iconography, and sound where enabled.

### Buttons and actions

The start/restart action is high-emphasis cyan. Pause, reset, movement, sound, and fullscreen are neutral outline controls. Icon-only controls retain accessible names and a 44px hit area.

### Motion

Motion is short and stateful: a cabinet glow for readiness, a bounce for successful movement, and a brief alert for damage. Honor `prefers-reduced-motion` by removing decorative transitions while keeping state changes visible.

## Do's and Don'ts

- **Do:** let the playfield be the hero and keep core controls within thumb reach.
- **Do:** reward clear player actions with a small visual and audio response.
- **Don't:** place long instructions or card grids over a live game.
- **Don't:** use a dashboard-like HUD that competes with the world being played.

## Toolbox Visual System

The Electrical Engineering Toolbox is a separate product register from the
Arcade: it should feel like a well-labelled bench instrument and a field
notebook, not a game or a generic analytics dashboard. The reader is an
electrician, technician, or engineer checking a calculation quickly, often on
a phone beside equipment.

- **Primary job:** Make the relationship behind a calculation immediately
  legible, while keeping every exact value copyable and visible as text.
- **Visual hierarchy:** Inputs and result rows remain the source of truth;
  the diagram explains their relationship and never replaces them.
- **Color roles:** violet is the primary calculated relationship, blue is an
  electrical reference/input, green indicates a satisfactory margin or output,
  amber means a limit or caution, and red is reserved for an invalid condition
  or hazard. No result depends on color alone.
- **Chart policy:** A graphic must use the active inputs or calculated result.
  Do not display a generic trend line or sample bar chart where the values are
  not a real ordered series. Prefer direct labels, thresholds, and annotated
  schematic paths over detached legends.
- **Mobile rule:** SVG diagrams scale to one column, retain a text alternative,
  and never require hover to expose a value or warning. Motion is optional and
  must honor reduced-motion preferences.
- **Safety rule:** Limit lines and status colors communicate a calculation
  result, not code compliance or an installation approval. Keep assumptions,
  applicable-code notes, and uncertainty visible next to the result.
