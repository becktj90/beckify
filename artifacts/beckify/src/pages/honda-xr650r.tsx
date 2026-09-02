import { ArrowDown, BatteryCharging, Cable, Download, Gauge, Wrench } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { Layout } from "@/components/Layout";
import { SchemaHead } from "@/components/seo/SchemaHead";

/**
 * Honda XR650R electric conversion — public workshop journal.
 * Status: BUILD IN PROGRESS.
 * Do not invent specs. Figures below are from the QS datasheet, EM-200/2
 * controller sheet, Honda service/press data, and the build comparison study.
 * Unpublished / noindex exclusion is intentionally removed — Trevor wants this public.
 *
 * Receipts / PII (IMG_7834.PNG, IMG_7833.PNG) must never ship on this page.
 */

const images = {
  hero: "/projects/honda-xr650r/concept-hero.jpg",
  donor: "/projects/honda-xr650r/initial-bike.webp",
  stripped: "/projects/honda-xr650r/stripped-chassis.webp",
  swingarm: "/projects/honda-xr650r/original-swingarm.webp",
  sprocket: "/projects/honda-xr650r/rear-sprocket.webp",
  wheel: "/projects/honda-xr650r/spare-wheel.webp",
  bodywork: "/projects/honda-xr650r/bodywork.webp",
  hall: "/projects/honda-xr650r/hall-sensor.jpg",
  programming: "/projects/honda-xr650r/programming-cable.jpg",
} as const;

const designTargets = [
  { label: "Battery", value: "76 V / 24 Ah", note: "Electro & Company pack, Apr 2023" },
  { label: "Motor", value: "QS 4 kW V3", note: "15 kW listed maximum" },
  { label: "Controller", value: "Votol EM-200/2", note: "Harness mapping in progress" },
  { label: "Wheels", value: "21 / 18 in", note: "Original chassis geometry" },
] as const;

const sprocketStudy = [
  { rear: "28T", overall: "4.737:1", torque: "284–379 N·m", rpm: "802–1267", mph: "63.6–100.5", note: "Study ratio — not selected" },
  { rear: "32T", overall: "5.414:1", torque: "325–433 N·m", rpm: "702–1108", mph: "55.7–87.9", note: "Intermediate" },
  { rear: "36T", overall: "6.090:1", torque: "365–487 N·m", rpm: "624–985", mph: "49.5–78.1", note: "Stronger all-around candidate" },
  { rear: "48T", overall: "8.120:1", torque: "487–650 N·m", rpm: "468–739", mph: "37.1–58.6", note: "Trail-biased; still below stock 1st" },
] as const;

const stockWheelTorque = [
  { gear: "1", reduction: "17.454:1", torque: "1,117 N·m", rpm: "315" },
  { gear: "2", reduction: "12.030:1", torque: "770 N·m", rpm: "457" },
  { gear: "3", reduction: "9.432:1", torque: "604 N·m", rpm: "583" },
  { gear: "4", reduction: "7.546:1", torque: "483 N·m", rpm: "729" },
  { gear: "5", reduction: "6.312:1", torque: "404 N·m", rpm: "871" },
] as const;

const j1Pins = [
  { group: "Hall", pin: "J1-17", signal: "Hall", color: "Yellow" },
  { group: "Hall", pin: "J1-3", signal: "Hall +", color: "Red" },
  { group: "Hall", pin: "J1-10", signal: "Hall", color: "Green" },
  { group: "Hall", pin: "J1-11", signal: "Hall", color: "White" },
  { group: "Hall", pin: "J1-18", signal: "Hall", color: "Blue" },
  { group: "Hall", pin: "J1-2", signal: "Hall 0 V", color: "Black" },
  { group: "Speedmeter", pin: "J1-16", signal: "Speedmeter", color: "White" },
  { group: "Speedmeter", pin: "J1-23", signal: "0 V GND", color: "Black / brown" },
  { group: "Programming", pin: "J1-7", signal: "CANL", color: "Orange" },
  { group: "Programming", pin: "J1-8", signal: "CANH", color: "Blue" },
  { group: "3-speed", pin: "J1-14", signal: "Low speed", color: "Green / white" },
  { group: "3-speed", pin: "J1-23", signal: "0 V GND", color: "Black / brown" },
  { group: "3-speed", pin: "J1-20", signal: "High speed", color: "Black / white" },
  { group: "Throttle", pin: "J1-5", signal: "+5 V", color: "Pink" },
  { group: "Throttle", pin: "J1-12", signal: "Signal", color: "Green" },
  { group: "Throttle", pin: "J1-19", signal: "0 V GND", color: "Black" },
  { group: "High brake", pin: "J1-22", signal: "High brake", color: "Purple" },
  { group: "Low brake", pin: "J1-4", signal: "Low brake", color: "Grey / black" },
  { group: "Low brake", pin: "J1-23", signal: "0 V GND", color: "Black / brown" },
  { group: "Backup", pin: "J1-6", signal: "Backup", color: "Brown" },
  { group: "Parking", pin: "J1-13", signal: "Parking", color: "Brown / white" },
  { group: "Reverse", pin: "J1-21", signal: "Reverse", color: "Grey / white" },
  { group: "E-lock", pin: "J1-1", signal: "E-lock", color: "Red / yellow" },
  { group: "E-lock", pin: "J1-9", signal: "E-lock", color: "Yellow / green" },
  { group: "E-lock", pin: "J1-15", signal: "E-lock", color: "Grey / purple" },
] as const;

export default function HondaXR650RPage() {
  return (
    <Layout className="xr-journal" showAds={false}>
      <SchemaHead
        title="Honda XR650R Electric Conversion | Beckify"
        description="A public workshop journal for a Honda XR650R electric motorcycle conversion — 76 V pack, QS 4 kW V3 mid-drive, Votol EM-200/2. Build in progress."
        path="/projects/honda-xr650r"
        type="article"
      />
      <style>{`
        .xr-journal{--xr-red:#f43f38;--xr-red-dark:#8e1714;--xr-cream:#f0eadf;--xr-ink:#151718;--xr-muted:#666b69;--xr-line:color-mix(in srgb,var(--foreground) 20%,transparent);background:var(--background);color:var(--foreground);overflow-x:hidden}
        .xr-journal .starfield{display:none}.xr-journal .max-w-5xl{max-width:76rem;padding-top:1.5rem}.xr-journal *{box-sizing:border-box}.xr-journal p{font-size:1rem;line-height:1.7}.xr-journal a:focus-visible{outline:3px solid var(--xr-red);outline-offset:4px}
        .xr-breakout{width:100vw;margin-left:calc(50% - 50vw)}.xr-hero{position:relative;min-height:min(82vh,58rem);display:flex;align-items:end;isolation:isolate;background:#17191a}.xr-hero img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:center 48%;z-index:-2;filter:saturate(.88) contrast(1.04)}.xr-hero:after{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(90deg,rgba(8,9,9,.9) 0%,rgba(8,9,9,.55) 44%,rgba(8,9,9,.08) 78%),linear-gradient(0deg,rgba(8,9,9,.68),transparent 45%)}
        .xr-hero-content{width:min(76rem,100%);margin:0 auto;padding:clamp(2rem,6vw,5.5rem) clamp(1.25rem,4vw,3rem);color:#fff}.status-pill,.concept-pill{display:inline-flex;align-items:center;gap:.55rem;margin-bottom:1.4rem;margin-right:.6rem;border:1px solid rgba(255,255,255,.55);padding:.48rem .7rem;font:700 .7rem/1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.12em;text-transform:uppercase}.status-pill:before,.concept-pill:before{content:"";width:.5rem;height:.5rem;border-radius:50%;background:var(--xr-red);box-shadow:0 0 0 .22rem rgba(224,43,36,.22)}.concept-pill{border-color:rgba(255,255,255,.35);opacity:.92}.concept-pill:before{background:#c9a227;box-shadow:0 0 0 .22rem rgba(201,162,39,.22)}
        .xr-hero h1{max-width:52rem;margin:0;font-family:var(--font-display),Georgia,serif;font-size:clamp(3rem,8vw,7.2rem);line-height:.9;letter-spacing:-.065em}.xr-hero h1 span{display:block;color:#ff544d}.xr-hero-copy{max-width:40rem;margin:1.5rem 0 0;font-size:clamp(1rem,2vw,1.28rem)!important;line-height:1.55!important;color:rgba(255,255,255,.86)}.xr-scroll{display:inline-flex;align-items:center;gap:.55rem;margin-top:2.25rem;border-bottom:1px solid currentColor;padding-bottom:.45rem;color:#fff;font-size:.82rem;font-weight:800;text-decoration:none}
        .xr-specs{display:grid;grid-template-columns:repeat(4,1fr);border-bottom:1px solid var(--xr-line)}.xr-specs article{min-width:0;padding:1.5rem;border-right:1px solid var(--xr-line)}.xr-specs article:last-child{border-right:0}.xr-specs small,.xr-index{display:block;color:var(--xr-red);font:800 .66rem/1.3 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.12em;text-transform:uppercase}.xr-specs strong{display:block;margin-top:.55rem;font-size:1.04rem}.xr-specs span{display:block;margin-top:.3rem;color:var(--muted);font-size:.78rem;line-height:1.4}
        .xr-nav{position:sticky;top:0;z-index:20;display:flex;gap:1.35rem;overflow-x:auto;border-bottom:1px solid var(--xr-line);padding:1rem 0;background:color-mix(in srgb,var(--background) 90%,transparent);backdrop-filter:blur(14px);scrollbar-width:thin}.xr-nav a{flex:none;color:var(--foreground);font-size:.79rem;font-weight:800;text-decoration:none}.xr-nav a:hover{color:var(--xr-red)}
        .xr-section{padding:clamp(4.5rem,9vw,8rem) 0;border-bottom:1px solid var(--xr-line)}.xr-heading{max-width:48rem}.xr-index{margin:0 0 .9rem}.xr-heading h2,.xr-copy h2{margin:0;font-family:var(--font-display),Georgia,serif;font-size:clamp(2.45rem,5vw,5rem);line-height:.94;letter-spacing:-.05em;text-wrap:balance}.xr-heading>p:not(.xr-index),.xr-copy>p:not(.xr-index){margin:1.35rem 0 0;color:var(--muted)}
        .xr-story{display:grid;grid-template-columns:7fr 5fr;gap:clamp(2rem,6vw,6rem);align-items:center}.xr-story figure{margin:0}.xr-story img{display:block;width:100%;height:clamp(30rem,55vw,48rem);object-fit:cover}.xr-caption{margin-top:.75rem;color:var(--muted);font-size:.78rem;line-height:1.5}.xr-points{margin:1.8rem 0 0;padding:0;list-style:none;border-top:1px solid var(--xr-line)}.xr-points li{display:grid;grid-template-columns:8rem 1fr;gap:1rem;border-bottom:1px solid var(--xr-line);padding:.9rem 0;color:var(--muted);font-size:.92rem;line-height:1.55}.xr-points strong{color:var(--foreground)}
        .xr-architecture{display:grid;grid-template-columns:repeat(4,1fr);gap:1px;margin-top:3rem;background:var(--xr-line);border:1px solid var(--xr-line)}.xr-system-card{position:relative;background:var(--surface);padding:1.4rem;min-height:13rem}.xr-system-card svg{color:var(--xr-red)}.xr-system-card small{display:block;margin-top:1.8rem;color:#ffab9c;font:800 .64rem/1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.1em;text-transform:uppercase}.xr-system-card h3{margin:.55rem 0 0;font-family:var(--font-display),Georgia,serif;font-size:1.35rem}.xr-system-card p{margin:.65rem 0 0;color:#c4c7e0;font-size:.82rem!important;line-height:1.5!important}
        .xr-battery{display:grid;grid-template-columns:5fr 7fr;gap:clamp(2rem,6vw,6rem);align-items:center}.xr-pack-visual{position:relative;min-height:27rem;display:flex;align-items:center;justify-content:center;border:1px solid var(--xr-line);background:radial-gradient(circle at 50% 30%,color-mix(in srgb,var(--xr-red) 12%,transparent),transparent 55%),var(--surface);overflow:hidden}.xr-pack{position:relative;width:min(76%,25rem);aspect-ratio:1.28;border:2px solid var(--foreground);border-radius:.35rem;background:linear-gradient(145deg,#292d2e,#101213);box-shadow:1.2rem 1.2rem 0 color-mix(in srgb,var(--xr-red) 16%,transparent);color:#fff}.xr-pack:before,.xr-pack:after{content:"";position:absolute;top:-.7rem;width:2.1rem;height:.8rem;border-radius:.2rem .2rem 0 0;background:#282c2d;border:2px solid var(--foreground);border-bottom:0}.xr-pack:before{left:2rem}.xr-pack:after{right:2rem}.xr-pack-label{position:absolute;inset:1.5rem;display:flex;flex-direction:column;justify-content:space-between;border:1px solid rgba(255,255,255,.25);padding:1rem}.xr-pack-label small{color:#ff5a52;font:800 .67rem/1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.12em;text-transform:uppercase}.xr-pack-label strong{font-family:var(--font-display),Georgia,serif;font-size:clamp(2.1rem,5vw,4rem);letter-spacing:-.06em}.xr-pack-label span{font-size:.78rem;color:rgba(255,255,255,.68)}
        .xr-technical{display:grid;grid-template-columns:5fr 7fr;gap:clamp(2rem,6vw,6rem);align-items:start}.xr-photo-stack{display:grid;grid-template-columns:1fr 1fr;gap:.8rem}.xr-photo-stack figure:first-child{grid-column:1/-1}.xr-photo-stack figure{margin:0}.xr-photo-stack img{display:block;width:100%;height:17rem;object-fit:cover}.xr-photo-stack figure:first-child img{height:25rem}.xr-data{margin:2rem 0 0;border-top:2px solid var(--foreground)}.xr-data div{display:grid;grid-template-columns:1fr 1.35fr;gap:1rem;border-bottom:1px solid var(--xr-line);padding:.9rem 0}.xr-data dt{color:var(--muted);font-size:.8rem}.xr-data dd{margin:0;font-size:.9rem;font-weight:750}.xr-caution{margin-top:1.5rem;border-left:4px solid var(--xr-red);padding:1rem 1.1rem;background:color-mix(in srgb,var(--xr-red) 8%,var(--surface));color:var(--muted);font-size:.84rem;line-height:1.55}
        .xr-table-wrap{overflow:auto;margin-top:2rem;border-top:2px solid var(--foreground)}.xr-table{width:100%;min-width:40rem;border-collapse:collapse}.xr-table th,.xr-table td{border-bottom:1px solid var(--xr-line);padding:.85rem .7rem;text-align:left;vertical-align:top;font-size:.84rem}.xr-table th{color:var(--xr-red);font:800 .64rem/1.3 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.1em;text-transform:uppercase}.xr-table td strong{display:block}.xr-table .muted{color:var(--muted);font-size:.78rem}.xr-verify{display:inline-block;margin-left:.45rem;border:1px solid var(--xr-red);padding:.12rem .4rem;color:var(--xr-red);font:800 .58rem/1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.1em;vertical-align:.12em}
        .xr-mounts{display:grid;grid-template-columns:repeat(2,1fr);gap:1rem;margin-top:3rem}.xr-mount-card{display:flex;flex-direction:column;min-height:18rem;border:1px solid var(--xr-line);background:var(--surface);padding:1.5rem}.xr-mount-mark{display:flex;align-items:center;justify-content:center;width:4.5rem;height:4.5rem;border:2px solid var(--xr-red);border-radius:50%;color:var(--xr-red);font-family:var(--font-display),Georgia,serif;font-size:2rem;font-weight:800}.xr-mount-card small{display:block;margin-top:2rem;color:#ffab9c;font:800 .65rem/1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.1em;text-transform:uppercase}.xr-mount-card h3{margin:.55rem 0 0;font-family:var(--font-display),Georgia,serif;font-size:1.55rem}.xr-mount-card p{margin:.7rem 0 1.5rem;color:#c4c7e0;font-size:.85rem!important;line-height:1.55!important}.xr-download{display:inline-flex;align-items:center;gap:.5rem;width:max-content;margin-top:auto;border-bottom:1px solid currentColor;padding-bottom:.35rem;color:var(--foreground);font-size:.8rem;font-weight:800;text-decoration:none}.xr-download:hover{color:var(--xr-red)}
        .xr-gallery{display:grid;grid-template-columns:repeat(12,1fr);gap:1rem;margin-top:3rem}.xr-gallery figure{margin:0}.xr-gallery figure:nth-child(1){grid-column:span 7}.xr-gallery figure:nth-child(2){grid-column:span 5}.xr-gallery figure:nth-child(3){grid-column:span 5}.xr-gallery figure:nth-child(4){grid-column:span 7}.xr-gallery img{display:block;width:100%;height:28rem;object-fit:cover}.xr-gallery figure:nth-child(2) img,.xr-gallery figure:nth-child(3) img{height:34rem}
        .xr-roadmap{counter-reset:step;display:grid;grid-template-columns:repeat(2,1fr);gap:1px;margin-top:3rem;background:var(--xr-line);border:1px solid var(--xr-line)}.xr-step{counter-increment:step;background:var(--surface);padding:1.5rem}.xr-step:before{content:"0" counter(step);display:block;color:var(--xr-red);font:800 .7rem/1 ui-monospace,SFMono-Regular,Menlo,monospace}.xr-step h3{margin:1rem 0 .55rem;font-family:var(--font-display),Georgia,serif;font-size:1.45rem}.xr-step p{margin:0;color:#c4c7e0;font-size:.88rem!important;line-height:1.55!important}.xr-footer-note{display:flex;justify-content:space-between;gap:2rem;align-items:end;padding:4rem 0 2rem}.xr-footer-note h2{max-width:38rem;margin:0;font-family:var(--font-display),Georgia,serif;font-size:clamp(2.2rem,5vw,4.5rem);line-height:.95;letter-spacing:-.045em}.xr-footer-note p{max-width:30rem;margin:0;color:var(--muted)}
        .xr-pin-grid{display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin-top:2rem}.xr-pin-card img{display:block;width:100%;height:16rem;object-fit:cover;background:var(--surface)}
        @media(max-width:850px){.xr-specs{grid-template-columns:1fr 1fr}.xr-specs article:nth-child(2){border-right:0}.xr-specs article:nth-child(-n+2){border-bottom:1px solid var(--xr-line)}.xr-story,.xr-battery,.xr-technical{grid-template-columns:1fr}.xr-copy{order:-1}.xr-architecture{grid-template-columns:1fr 1fr}.xr-gallery figure:nth-child(n){grid-column:span 6}.xr-gallery img,.xr-gallery figure:nth-child(n) img{height:25rem}.xr-footer-note{display:block}.xr-footer-note p{margin-top:1.5rem}}
        @media(max-width:560px){.xr-journal .max-w-5xl{padding-inline:1.25rem}.xr-hero{min-height:44rem}.xr-hero-content{padding-inline:1.25rem}.xr-specs{grid-template-columns:1fr}.xr-specs article{border-right:0;border-bottom:1px solid var(--xr-line)!important}.xr-specs article:last-child{border-bottom:0!important}.xr-architecture,.xr-mounts,.xr-roadmap,.xr-pin-grid{grid-template-columns:1fr}.xr-story img{height:29rem}.xr-points li{grid-template-columns:1fr;gap:.25rem}.xr-pack-visual{min-height:22rem}.xr-photo-stack{grid-template-columns:1fr}.xr-photo-stack figure:first-child{grid-column:auto}.xr-photo-stack figure:nth-child(n) img{height:22rem}.xr-gallery{grid-template-columns:1fr}.xr-gallery figure:nth-child(n){grid-column:auto}.xr-gallery figure:nth-child(n) img{height:24rem}}
      `}</style>

      <div className="xr-breakout">
        <section className="xr-hero" aria-labelledby="xr-title">
          <img src={images.hero} alt="Concept visualization of a green Honda XR650R electric conversion with a mid-drive powertrain" />
          <div className="xr-hero-content">
            <div className="status-pill">Build in progress</div>
            <div className="concept-pill">Concept visualization</div>
            <h1 id="xr-title">Honda XR650R <span>Electric Conversion</span></h1>
            <p className="xr-hero-copy">A ground-up conversion built around the XR650R chassis, a purchased 76 V lithium-ion battery, and a high-torque mid-drive while preserving the bike's suspension, braking, and unmistakable desert-racer stance.</p>
            <a className="xr-scroll" href="#starting-point">Open the workshop journal <ArrowDown size={17} aria-hidden="true" /></a>
          </div>
        </section>
      </div>

      <div className="xr-specs" aria-label="Project targets">
        {designTargets.map((target) => <article key={target.label}><small>{target.label}</small><strong>{target.value}</strong><span>{target.note}</span></article>)}
      </div>

      <nav className="xr-nav" aria-label="XR650R project sections">
        <a href="#starting-point">Starting point</a>
        <a href="#architecture">Architecture</a>
        <a href="#battery">Battery</a>
        <a href="#gearing">Gearing</a>
        <a href="#mounts">Motor mounts</a>
        <a href="#controls">Controls</a>
        <a href="#gallery">Teardown gallery</a>
        <a href="#next">Next steps</a>
      </nav>

      <div>
        <FadeIn><section className="xr-section xr-story" id="starting-point">
          <figure>
            <img src={images.stripped} alt="Honda XR650R chassis stripped to the frame, suspension, and swingarm" />
            <figcaption className="xr-caption">The combustion system and bodywork are removed so the available battery, motor, and controller volumes can be measured from the actual chassis.</figcaption>
          </figure>
          <div className="xr-copy">
            <p className="xr-index">01 / starting point</p>
            <h2>Design from the frame outward.</h2>
            <p>The XR650R starts with a strong aluminum twin-spar chassis and long-travel suspension. The conversion plan keeps that mechanical foundation and replaces the engine, fuel, exhaust, and supporting systems with an integrated electric powertrain.</p>
            <ul className="xr-points">
              <li><strong>Preserve</strong><span>Frame, suspension geometry, hydraulic brakes, wheels, and off-road serviceability.</span></li>
              <li><strong>Package</strong><span>Battery mass low and central without interfering with steering, suspension travel, or rider movement.</span></li>
              <li><strong>Engineer</strong><span>Motor mounts, chain line, reduction, electrical isolation, cooling, and protected cable routing as one system.</span></li>
            </ul>
          </div>
        </section></FadeIn>

        <FadeIn><section className="xr-section" id="architecture">
          <div className="xr-heading">
            <p className="xr-index">02 / intended architecture</p>
            <h2>The major hardware is taking shape.</h2>
            <p>The battery, motor, controller family, charger, and first motor-mount design are now identified. Protection settings, contactor strategy, final reduction, pack placement, and vehicle-level validation remain open engineering work.</p>
          </div>
          <div className="xr-architecture">
            <article className="xr-system-card"><BatteryCharging size={26} /><small>Energy</small><h3>76 V / 24 Ah pack</h3><p>Electro &amp; Company lithium-ion battery with a matched 12 A charger and controller leads.</p></article>
            <article className="xr-system-card"><Gauge size={26} /><small>Control</small><h3>Votol EM-200/2</h3><p>Throttle, brake, three-speed, reverse, parking, hall, and e-lock functions are documented for integration.</p></article>
            <article className="xr-system-card"><Wrench size={26} /><small>Drive</small><h3>QS 4 kW V3</h3><p>Air-cooled IPM/PMSM mid-drive with integrated 19:45 reduction gearbox.</p></article>
            <article className="xr-system-card"><Cable size={26} /><small>Output</small><h3>Chain final drive</h3><p>Sprocket selection will balance launch torque, chain load, clearance, and useful road speed. 28T is a study, not a selection.</p></article>
          </div>
        </section></FadeIn>

        <FadeIn><section className="xr-section xr-battery" id="battery">
          <div className="xr-pack-visual" aria-label="Technical representation of the purchased 76 volt battery">
            <div className="xr-pack"><div className="xr-pack-label"><small>Electro &amp; Company</small><strong>76 V<br />24 Ah</strong><span>High-power lithium-ion battery</span></div></div>
          </div>
          <div className="xr-copy">
            <p className="xr-index">03 / purchased battery</p>
            <h2>The energy source is no longer hypothetical.</h2>
            <p>Purchased from Electro &amp; Company in April 2023, the pack was ordered with a 12 A charger and matched controller leads. The vendor-listed voltage and capacity represent approximately 1.82 kWh of stored energy.</p>
            <dl className="xr-data">
              <div><dt>Vendor designation</dt><dd>High Power 76 V 24 Ah Li-ion Battery</dd></div>
              <div><dt>Listed energy</dt><dd>1.824 kWh (76 V × 24 Ah)</dd></div>
              <div><dt>Charger</dt><dd>12 A, approximately 0.5C nominal rate</dd></div>
              <div><dt>Controller leads</dt><dd>Matched leads included</dd></div>
              <div><dt>Supplier / purchased</dt><dd>Electro &amp; Company / April 2023</dd></div>
              <div><dt>Still to verify<span className="xr-verify">TO VERIFY</span></dt><dd>Full-charge voltage, BMS limits, dimensions, mass, connector pinout</dd></div>
            </dl>
            <div className="xr-caution"><strong>Integration gate:</strong> confirm the pack label, measured full-charge voltage, BMS continuous and peak current, fuse coordination, charger output, polarity, and connector ratings before connecting it to the EM-200/2 system. Receipts and payment screenshots are excluded from this page.</div>
          </div>
        </section></FadeIn>

        <FadeIn><section className="xr-section xr-technical" id="gearing">
          <div className="xr-copy">
            <p className="xr-index">04 / motor &amp; gearing</p>
            <h2>Reduction before fabrication.</h2>
            <p>The motor's built-in 19:45 gearbox provides a 2.368:1 reduction before the chain drive. Using a 14T motor sprocket and the 26.66 in tire diameter carried in the build calculations, the table compares rear sprockets. None is selected until motor placement, chain line, clearance, and desired speed are reconciled.</p>
            <dl className="xr-data">
              <div><dt>Rated power</dt><dd>4 kW</dd></div>
              <div><dt>Listed maximum power</dt><dd>15 kW</dd></div>
              <div><dt>Rated voltage / current</dt><dd>72 V / 60 A</dd></div>
              <div><dt>Maximum torque</dt><dd>60–80 N·m motor; &gt;140 N·m after gearbox</dd></div>
              <div><dt>Speed range</dt><dd>3,800–6,000 rpm</dd></div>
              <div><dt>Motor mass / protection</dt><dd>14.2 kg / IP54</dd></div>
              <div><dt>Tire diameter used</dt><dd>26.66 in rear (nominal)</dd></div>
              <div><dt>Chain pull (14T, 428)</dt><dd>~5.0–6.6 kN ideal tight-side force</dd></div>
            </dl>
            <div className="xr-caution"><strong>Draft engineering note:</strong> published maximum figures are component limits, not a continuous vehicle rating. Kinematic speeds are geometry at 3,800–6,000 rpm, not predicted top speed. With 15 kW max vs the stock Honda's 45 kW, treat a power-limited ~60–70 mph band as an engineering study, not a promise, until logged road data exists.</div>
          </div>
          <div>
            <div className="xr-photo-stack">
              <figure><img src={images.swingarm} alt="Original Honda XR650R swingarm, rear wheel, chain guide, and suspension linkage" /></figure>
              <figure><img src={images.sprocket} alt="Close view of the original rear sprocket and axle adjuster" /></figure>
              <figure><img src={images.wheel} alt="Close-up of the original rear wheel, sprocket, and axle area" /></figure>
            </div>
          </div>
        </section></FadeIn>

        <FadeIn><section className="xr-section">
          <div className="xr-heading">
            <p className="xr-index">04b / sprocket study</p>
            <h2>28T is a study, not a selection.</h2>
            <p>Exact 45/19 internal reduction, 14T front, 26.66 in tire. Ideal wheel torque is static ratio multiplication and omits losses. 36T raises wheel torque 28.6% versus 28T while keeping a useful high-speed ceiling — a stronger all-around candidate. 48T is closer to trail bias and still remains below stock first-gear torque multiplication.</p>
          </div>
          <div className="xr-table-wrap">
            <table className="xr-table">
              <thead>
                <tr>
                  <th>Rear</th>
                  <th>Overall</th>
                  <th>Ideal wheel torque</th>
                  <th>Wheel rpm @ 3,800–6,000</th>
                  <th>Kinematic mph</th>
                  <th>Read</th>
                </tr>
              </thead>
              <tbody>
                {sprocketStudy.map((row) => (
                  <tr key={row.rear}>
                    <td><strong>{row.rear}</strong></td>
                    <td>{row.overall}</td>
                    <td>{row.torque}</td>
                    <td>{row.rpm}</td>
                    <td>{row.mph}</td>
                    <td className="muted">{row.note}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="xr-caption" style={{ marginTop: "1rem" }}>14T 428 pitch radius 28.5 mm. Ideal tight-side chain force ~5.0–6.6 kN before drivetrain, impact, shock, wear, and suspension-transient loads. 100.5 mph at 28T / 6,000 rpm is a geometric ceiling only.</p>

          <div className="xr-heading" style={{ marginTop: "3rem" }}>
            <p className="xr-index">04c / stock vs electric rear-wheel torque</p>
            <h2>Direct-drive torque from zero, not first-gear multiplication.</h2>
            <p>Honda 2000 XR650R press: 45 kW @ 6,750 rpm, 64 N·m @ 5,500 rpm. Service data: 1.651 primary, 5-speed 3.083 / 2.125 / 1.666 / 1.333 / 1.115, 3.429 (48/14) final for ED/DK. Ideal stock wheel-torque values omit clutch, chain/gear losses, and the fact that the engine does not produce 64 N·m at every rpm.</p>
          </div>
          <div className="xr-table-wrap">
            <table className="xr-table">
              <thead>
                <tr>
                  <th>Gear</th>
                  <th>Overall reduction</th>
                  <th>Ideal wheel torque @ 64 N·m</th>
                  <th>Wheel rpm @ 5,500 engine rpm</th>
                </tr>
              </thead>
              <tbody>
                {stockWheelTorque.map((row) => (
                  <tr key={row.gear}>
                    <td><strong>{row.gear}</strong></td>
                    <td>{row.reduction}</td>
                    <td>{row.torque}</td>
                    <td>{row.rpm}</td>
                  </tr>
                ))}
                <tr>
                  <td><strong>Electric 14/28</strong></td>
                  <td>4.737:1 fixed</td>
                  <td>284–379 N·m from zero rpm</td>
                  <td>802–1267 @ 3,800–6,000 motor rpm</td>
                </tr>
                <tr>
                  <td><strong>Electric 14/36</strong></td>
                  <td>6.090:1 fixed</td>
                  <td>365–487 N·m from zero rpm</td>
                  <td>624–985 @ 3,800–6,000 motor rpm</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div className="xr-caution">The electric conversion is smoother and immediate, but 28T does not reproduce stock 1st-gear thrust (~1,117 N·m ideal). Peak electric power is ~1/3 of stock crank power. Period tests put stock top speed just under ~100 mph; electric top speed is expected to be power-limited, not gearing-limited, with 28T.</div>
        </section></FadeIn>

        <FadeIn><section className="xr-section" id="mounts">
          <div className="xr-heading">
            <p className="xr-index">05 / motor mounting brackets</p>
            <h2>Left and right V3 bracket geometry is in CAD.</h2>
            <p>The supplied STEP models capture the current motor-mount concept as separate left- and right-side parts. They are preserved with the project so fit-up, chain alignment, fastener access, material selection, and structural checks can be completed against the real chassis.</p>
          </div>
          <div className="xr-mounts">
            <article className="xr-mount-card">
              <div className="xr-mount-mark">L</div>
              <small>AP214 STEP / V3</small>
              <h3>Left motor bracket</h3>
              <p>Current left-side solid model. Envelope from Fictiv review: 345.14 × 139.63 × 5.00 mm<span className="xr-verify">TO VERIFY</span>. Material in STEP: Steel — Satin.</p>
              <a className="xr-download" href="/projects/honda-xr650r/cad/bracket-left-v3.step" download><Download size={16} aria-hidden="true" /> Download left bracket</a>
            </article>
            <article className="xr-mount-card">
              <div className="xr-mount-mark">R</div>
              <small>AP214 STEP / V3</small>
              <h3>Right motor bracket</h3>
              <p>Current right-side solid model. Envelope from Fictiv review: 270.33 × 158.97 × 5.00 mm<span className="xr-verify">TO VERIFY</span>.</p>
              <a className="xr-download" href="/projects/honda-xr650r/cad/bracket-right-v3.step" download><Download size={16} aria-hidden="true" /> Download right bracket</a>
            </article>
          </div>
          <div className="xr-caution"><strong>Fabrication hold point:</strong> these files document design intent, not a released drawing. Confirm frame datums, motor-face spacing, shaft and sprocket alignment, full chain clearance, plate material and thickness, fastener grade, edge distances, weld details if applicable, and static/dynamic load capacity before manufacture.</div>
        </section></FadeIn>

        <FadeIn><section className="xr-section" id="controls">
          <div className="xr-heading">
            <p className="xr-index">06 / controller integration</p>
            <h2>The harness is part of the powertrain.</h2>
            <p>The Votol EM-200/2 documentation identifies phase, hall, throttle, brake, speed, reverse, parking, programming, and e-lock interfaces on connector DJ7061Y-2.3-21. Phase colors from the workbook: U=blue, V=green, W=yellow; B+ red, B− black. Before energization, the actual controller variant and connector pinout will be verified point-to-point against the delivered hardware.</p>
          </div>
          <div className="xr-pin-grid">
            <figure>
              <img src={images.hall} alt="Six-pin hall-sensor plug with yellow, green, blue, red, white, and black leads" />
              <figcaption className="xr-caption">Hall sensor plug — connect to the motor Hall plug directly.</figcaption>
            </figure>
            <figure>
              <img src={images.programming} alt="USB programming cable for the EM-200/2 controller" />
              <figcaption className="xr-caption">Programming cable — J1-7 CANL (orange) / J1-8 CANH (blue).</figcaption>
            </figure>
          </div>
          <div className="xr-table-wrap">
            <table className="xr-table">
              <thead>
                <tr>
                  <th>Function</th>
                  <th>J1 pin</th>
                  <th>Signal</th>
                  <th>Wire color</th>
                </tr>
              </thead>
              <tbody>
                {j1Pins.map((row) => (
                  <tr key={`${row.group}-${row.pin}-${row.signal}`}>
                    <td>{row.group}</td>
                    <td><strong>{row.pin}</strong></td>
                    <td>{row.signal}</td>
                    <td>{row.color}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="xr-caption" style={{ marginTop: "1rem" }}>Source: 01 Controller Interface.pdf. Pin map<span className="xr-verify">TO VERIFY</span> against the delivered controller before first power-on. The workbook does not provide a controller current-rating table — do not infer peak vehicle performance from the controller name alone.</p>
          <div className="xr-roadmap">
            <article className="xr-step"><h3>Low-voltage controls</h3><p>Map the throttle, brake interlocks, run/stop control, rider display, and any selectable drive modes.</p></article>
            <article className="xr-step"><h3>High-voltage switching</h3><p>Define service disconnect, fuse, precharge, contactor, e-lock, and a safe de-energization sequence.</p></article>
            <article className="xr-step"><h3>Motor feedback</h3><p>Verify U/V/W phase order, hall connector wiring, temperature sensing, and controller programming before loaded operation.</p></article>
            <article className="xr-step"><h3>Environmental protection</h3><p>Place components and connectors for splash protection, strain relief, cooling airflow, inspection, and trail-side service.</p></article>
          </div>
        </section></FadeIn>

        <FadeIn><section className="xr-section" id="gallery">
          <div className="xr-heading">
            <p className="xr-index">07 / teardown record</p>
            <h2>The honest starting condition.</h2>
            <p>The first build-page pass preserves the real workshop record: used hardware, old chain drive, removed plastics, and the bare chassis before design work begins. The green hero above is a concept visualization, not a photograph of the finished machine.</p>
          </div>
          <div className="xr-gallery">
            <figure>
              <img src={images.donor} alt="Partially disassembled red Honda XR650R before conversion" />
              <figcaption className="xr-caption">Initial condition and bodywork reference.</figcaption>
            </figure>
            <figure>
              <img src={images.bodywork} alt="Original red Honda XR650R bodywork and fuel tank on the donor bike" />
              <figcaption className="xr-caption">Stock bodywork on the donor bike, prior to teardown.</figcaption>
            </figure>
            <figure>
              <img src={images.wheel} alt="Close-up of the original rear wheel hub and sprocket" />
              <figcaption className="xr-caption">Wheel and hub detail.</figcaption>
            </figure>
            <figure>
              <img src={images.sprocket} alt="Weathered XR650R sprocket and swingarm detail" />
              <figcaption className="xr-caption">Baseline chain-drive condition before replacement and gearing selection.</figcaption>
            </figure>
          </div>
        </section></FadeIn>

        <FadeIn><section className="xr-section" id="next">
          <div className="xr-heading">
            <p className="xr-index">08 / next steps</p>
            <h2>What has to be settled before metal is cut.</h2>
            <p>The pack and bracket models move the build forward, but both must be validated as installed hardware. Measurements, calculations, released fabrication drawings, and test results will replace the remaining open items as the build advances.</p>
          </div>
          <div className="xr-roadmap">
            <article className="xr-step"><h3>Verify the purchased pack</h3><p>Record physical dimensions, mass, connector pinout, full-charge voltage, BMS limits, and available mounting features.</p></article>
            <article className="xr-step"><h3>Validate the V3 brackets</h3><p>Check chassis datums, motor clearance, chain line, fastener access, plate specification, and structural load cases.</p></article>
            <article className="xr-step"><h3>Complete the reduction study</h3><p>Compare candidate sprockets using loaded motor speed, wheel circumference, gradeability, chain load, and packaging. 36T is the stronger all-around candidate until measured.</p></article>
            <article className="xr-step"><h3>Finish electrical protection</h3><p>Complete the one-line, fuse and contactor sizing, precharge, service disconnect, enclosure, and interlock strategy.</p></article>
          </div>
        </section></FadeIn>
      </div>

      <div className="xr-footer-note">
        <h2>A living build record, not a finished specification.</h2>
        <p>Public workshop journal — BUILD IN PROGRESS. Claims wait on measured pack current, controller calibration, loaded rpm, finished mass, and road data. Concept renders are labeled. Receipts stay off this page.</p>
      </div>
    </Layout>
  );
}
