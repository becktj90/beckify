import { ArrowDown, Download } from "lucide-react";
import { Link } from "wouter";
import { Layout } from "@/components/Layout";
import { FadeIn } from "@/components/FadeIn";
import { SchemaHead, SITE_URL } from "@/components/seo/SchemaHead";
import {
  HubMotorVisual,
  PowerElectronicsMap,
} from "@/components/VespaBuildVisuals";
import { VespaEngineeringNotebook } from "@/components/VespaEngineeringNotebook";
import { VespaTheoreticalComparison } from "@/components/VespaTheoreticalComparison";
import { VespaBatteryDiagram } from "@/components/VespaBatteryDiagram";
import { VespaPartsCatalog } from "@/components/VespaPartsCatalog";

const img = {
  hero: "/projects/vespa/studio/vespa-side-profile.jpg",
  rearDetail: "/projects/vespa/studio/rear-hub-detail.jpg",
  front: "/projects/vespa/studio/front-portrait.jpg",
  controllerBay: "/projects/vespa/studio/controller-install.jpg",
  finished: "/projects/vespa/journal/finished-vespa.jpg",
  install: "/projects/vespa/journal/installation-work.jpg",
  pack: "/projects/vespa/journal/pack-test.jpg",
  busbars: "/projects/vespa/journal/nickel-busbars.jpg",
  cells: "/projects/vespa/journal/cell-stack.jpg",
  motor: "/projects/vespa/journal/hub-motor.jpg",
  harness: "/projects/vespa/journal/em100-harness.jpg",
  cad: "/projects/vespa/journal/swingarm-cad-render.jpg",
  weld: "/projects/vespa/journal/swingarm-weld.jpg",
} as const;

function DownloadLink({ href, children }: { href: string; children: string }) {
  return (
    <a href={href} download className="download-link">
      <Download size={16} aria-hidden="true" /> {children}
    </a>
  );
}

export default function VespaP200EPage() {
  return (
    <Layout className="vespa-journal" showAds={false}>
      <SchemaHead
        title="Electric Conversion of a 1979 Vespa P200E | Beckify"
        description="A workshop journal documenting the conversion of a 1979 Vespa P200E to 72V electric power."
        path="/projects/vespa-p200e"
        type="article"
        schema={{
          "@context": "https://schema.org",
          "@type": ["TechArticle", "HowTo"],
          name: "Electric Conversion of a 1979 Vespa P200E",
          url: `${SITE_URL}/projects/vespa-p200e`,
          author: { "@type": "Person", name: "Trevor Beck" },
        }}
      />
      <style>{`.vespa-journal{--paper:#f6f1e8;--ink:#1d2421;--muted:#59645d;--green:#184d3f;--red:#9f302b;--rule:#b9b3a8;background:var(--paper);color:var(--ink)}.vespa-journal .starfield{display:none}.vespa-journal .max-w-5xl{max-width:72rem;padding-top:1.5rem}.vespa-journal *{box-sizing:border-box}.vespa-journal a:focus-visible,.vespa-journal button:focus-visible{outline:3px solid var(--red);outline-offset:3px}.vespa-journal p{font-size:1rem;line-height:1.7}.journal-breakout{width:100vw;margin-left:calc(50% - 50vw)}.journal-hero{position:relative;min-height:min(78vh,54rem);display:flex;align-items:end;isolation:isolate;background:#192923}.journal-hero img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:center 37%;z-index:-2}.journal-hero:after{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(90deg,rgba(11,18,15,.8),rgba(11,18,15,.34) 58%,rgba(11,18,15,.08))}.hero-content{width:min(72rem,100%);margin:0 auto;padding:4rem 2rem;color:#fffaf0}.hero-content h1{max-width:52rem;margin:0;font-family:Georgia,serif;font-size:clamp(3rem,8vw,7rem);line-height:.93;letter-spacing:-.055em}.hero-content p{max-width:38rem;margin:1.5rem 0 0;font-size:clamp(1rem,2vw,1.3rem);line-height:1.55}.scroll-cue{display:inline-flex;align-items:center;gap:.55rem;margin-top:2.5rem;border-bottom:1px solid currentColor;padding-bottom:.5rem;color:#fffaf0;font-size:.875rem;font-weight:700;text-decoration:none}.spec-strip{display:grid;grid-template-columns:repeat(6,1fr);border-bottom:1px solid var(--rule);padding:1.4rem 0;gap:1rem}.spec-strip div{min-width:0}.spec-strip small,.section-index,.parts-table-wrap th,.parts-table-wrap td small{display:block;color:var(--muted);font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.64rem;font-weight:700;letter-spacing:.1em;text-transform:uppercase}.spec-strip strong{display:block;margin-top:.35rem;font-size:.92rem;line-height:1.25}.journal-nav{display:flex;flex-wrap:wrap;gap:1.25rem;border-bottom:1px solid var(--rule);padding:1rem 0}.journal-nav a{color:var(--ink);font-size:.82rem;font-weight:700;text-decoration:none}.journal-nav a:hover{color:var(--red)}.journal-section{padding:6.5rem 0;border-bottom:1px solid var(--rule)}.section-index{color:var(--red);margin:0 0 .8rem}.section-heading{max-width:39rem}.section-heading h2,.story-copy h2{margin:0;font-family:Georgia,serif;font-size:clamp(2.35rem,5vw,4.5rem);line-height:.95;letter-spacing:-.045em}.section-heading>p:not(.section-index){margin:1.35rem 0 0;color:var(--muted)}.story-grid{display:grid;grid-template-columns:repeat(12,minmax(0,1fr));gap:clamp(1.5rem,4vw,5rem);align-items:center}.story-media{grid-column:span 7;margin:0}.story-copy{grid-column:span 5}.story-copy p{color:var(--muted)}.story-grid.reverse .story-media{grid-column:6 / span 7;grid-row:1}.story-grid.reverse .story-copy{grid-column:1 / span 5;grid-row:1}figure{margin:0}.story-media img{display:block;width:100%;height:clamp(22rem,45vw,38rem);object-fit:cover}.story-media figcaption,.photo-caption{margin-top:.75rem;color:var(--muted);font-size:.78rem;line-height:1.45}.goal-list{margin:1.7rem 0 0;padding:0;list-style:none;border-top:1px solid var(--rule)}.goal-list li{display:grid;grid-template-columns:8rem 1fr;gap:1rem;border-bottom:1px solid var(--rule);padding:.8rem 0;color:var(--muted);font-size:.93rem;line-height:1.5}.goal-list strong{color:var(--ink)}.battery-layout{display:grid;grid-template-columns:7fr 5fr;gap:clamp(1.5rem,4vw,5rem);align-items:start;margin-top:2.75rem}.battery-main{position:relative;margin:0}.battery-main img{display:block;width:100%;height:clamp(28rem,50vw,45rem);object-fit:cover}.battery-callout{position:absolute;right:1rem;bottom:1rem;max-width:14rem;background:rgba(246,241,232,.95);border-left:4px solid var(--red);padding:1rem;color:var(--ink);font-size:.83rem;line-height:1.4}.battery-specs{margin:0;border-top:2px solid var(--ink)}.battery-specs div{border-bottom:1px solid var(--rule);padding:1rem 0}.battery-specs dt{color:var(--red);font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.67rem;font-weight:700;letter-spacing:.1em;text-transform:uppercase}.battery-specs dd{margin:.35rem 0 0;font-size:1rem;line-height:1.45}.battery-thumbs{display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin-top:1rem}.battery-thumbs img{width:100%;height:11rem;display:block;object-fit:cover}.tech-list{margin:1.5rem 0 0;padding:0;list-style:none}.tech-list li{border-top:1px solid var(--rule);padding:.9rem 0;color:var(--muted);font-size:.94rem;line-height:1.55}.tech-list strong{color:var(--ink)}.downloads{display:flex;flex-wrap:wrap;gap:.75rem;margin-top:1.75rem}.download-link{display:inline-flex;align-items:center;gap:.45rem;border:1px solid var(--ink);padding:.75rem .9rem;color:var(--ink);font-size:.8rem;font-weight:700;text-decoration:none}.download-link:hover{background:var(--ink);color:var(--paper)}.fabrication-pair{display:grid;grid-template-columns:1fr 1fr;gap:1rem}.fabrication-pair img{width:100%;height:28rem;object-fit:cover;display:block}.at-glance{display:grid;grid-template-columns:repeat(4,1fr);gap:1px;background:var(--rule);border:1px solid var(--rule);margin-top:2.5rem}.at-glance div{background:var(--paper);padding:1.25rem}.at-glance strong{display:block;font-family:Georgia,serif;font-size:1.35rem}.at-glance span{display:block;margin-top:.45rem;color:var(--muted);font-size:.84rem;line-height:1.45}.parts-section{padding-bottom:5rem}.affiliate-note{margin:2rem 0 0;border-left:3px solid var(--red);padding:.7rem 1rem;background:#efe6d7;color:var(--muted);font-size:.83rem}.part-filter{display:flex;flex-wrap:wrap;gap:.45rem;margin:2rem 0 1rem}.part-filter button{border:1px solid var(--rule);background:transparent;padding:.55rem .8rem;color:var(--ink);font-size:.75rem;font-weight:700}.part-filter button[aria-pressed="true"]{background:var(--green);border-color:var(--green);color:white}.parts-table-wrap{overflow:auto;border-top:2px solid var(--ink)}table{width:100%;min-width:40rem;border-collapse:collapse}th,td{border-bottom:1px solid var(--rule);padding:.9rem .75rem;text-align:left;vertical-align:top;font-size:.85rem}th{font-size:.64rem}td strong{display:block}td small{color:var(--red);margin-top:.3rem}td a{display:inline-flex;align-items:center;gap:.3rem;color:var(--red);font-weight:700}.unavailable{color:var(--muted);font-size:.78rem}.parts-catalog-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:1rem;margin-top:1.5rem}.part-card{display:flex;flex-direction:column;min-width:0;background:#efe6d7;border:1px solid var(--rule);box-shadow:0 1px 0 rgba(29,36,33,.08)}.part-card-image{position:relative;background:#1d2421;overflow:hidden}.part-card-image img{display:block;width:100%;height:12.5rem;object-fit:cover;transition:transform .35s ease}.part-card:hover .part-card-image img{transform:scale(1.035)}.part-card-image span{position:absolute;top:.7rem;left:.7rem;background:var(--paper);color:var(--ink);padding:.28rem .45rem;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.6rem;font-weight:700;letter-spacing:.08em;text-transform:uppercase}.part-card-body{display:flex;flex:1;flex-direction:column;padding:1rem}.part-card-supplier{margin:0;color:var(--red);font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.64rem!important;font-weight:700;letter-spacing:.07em;text-transform:uppercase;line-height:1.35!important}.part-card h3{margin:.55rem 0 0;font-family:Georgia,serif;font-size:1.35rem;line-height:1.05;letter-spacing:-.025em}.part-card-caption{margin:.65rem 0 1rem;color:var(--muted);font-size:.81rem!important;line-height:1.45!important}.part-card-footer{display:flex;align-items:center;justify-content:space-between;gap:.65rem;margin-top:auto;border-top:1px solid var(--rule);padding-top:.75rem;font-size:.8rem}.part-card-footer a{display:inline-flex;align-items:center;gap:.3rem;color:var(--red);font-weight:700;text-decoration:none}.part-card-footer a:hover{text-decoration:underline}.part-card-footer span{color:var(--muted);font-size:.72rem}.journal-cta{display:grid;grid-template-columns:1fr 1fr;gap:2rem;align-items:end;padding:6rem 0 2rem}.journal-cta h2{margin:0;font-family:Georgia,serif;font-size:clamp(2.4rem,5vw,4.8rem);line-height:.95;letter-spacing:-.05em}.journal-cta p{margin:0 0 1.5rem;color:var(--muted)}.cta-links{display:flex;gap:.75rem;flex-wrap:wrap}.cta-links a{padding:.8rem 1rem;background:var(--green);color:white;font-size:.82rem;font-weight:700;text-decoration:none}.cta-links a:last-child{background:transparent;border:1px solid var(--ink);color:var(--ink)}.sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}@media(max-width:900px){.parts-catalog-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:760px){.vespa-journal .max-w-5xl{padding-left:1.25rem;padding-right:1.25rem}.hero-content{padding:2rem 1.25rem}.journal-hero{min-height:38rem}.spec-strip{grid-template-columns:repeat(2,1fr);gap:1.25rem}.journal-nav{display:none}.journal-section{padding:4rem 0}.story-media,.story-copy,.story-grid.reverse .story-media,.story-grid.reverse .story-copy{grid-column:1/-1;grid-row:auto}.story-copy{order:2}.story-grid.reverse .story-media{order:1}.goal-list li{grid-template-columns:1fr}.battery-layout,.journal-cta{grid-template-columns:1fr}.battery-main img{height:31rem}.fabrication-pair{grid-template-columns:1fr}.fabrication-pair img{height:24rem}.at-glance{grid-template-columns:1fr 1fr}.parts-catalog-grid{grid-template-columns:1fr}.part-card-image img{height:15rem}.journal-cta{padding-top:4rem}}@media(prefers-reduced-motion:no-preference){.journal-hero img{animation:hero-settle 1.4s ease-out both}@keyframes hero-settle{from{transform:scale(1.035)}to{transform:scale(1)}}}`}</style>
      <style>{`
        .vespa-journal {
          --paper: var(--background);
          --ink: var(--foreground);
          --muted: var(--muted);
          --green: var(--accent);
          --red: var(--accent-2);
          --rule: var(--border);
        }
        .vespa-journal .affiliate-note,
        .vespa-journal .part-card {
          background: var(--surface);
          box-shadow: var(--shadow-card);
        }
        .vespa-journal .battery-callout {
          background: color-mix(in srgb, var(--background) 88%, transparent);
          backdrop-filter: blur(10px);
        }
        .vespa-journal .hero-content,
        .vespa-journal .scroll-cue {
          color: var(--foreground);
        }
        .vespa-journal .journal-nav {
          position: sticky;
          top: 0;
          z-index: 20;
          padding-block: .9rem;
          background: color-mix(in srgb, var(--background) 90%, transparent);
          backdrop-filter: blur(14px);
        }
        .vespa-journal .journal-nav a {
          color: var(--foreground);
        }
        .vespa-journal .journal-nav a:hover,
        .vespa-journal .journal-nav a:focus-visible {
          color: var(--accent-2);
        }
        .vespa-journal .system-visual {
          margin-top: clamp(2.5rem, 6vw, 5rem);
          padding-top: 1.25rem;
          border-top: 1px solid var(--border);
        }
        .vespa-journal .system-visual-heading {
          display: flex;
          align-items: baseline;
          justify-content: space-between;
          gap: 1rem;
          margin-bottom: 1rem;
        }
        .vespa-journal .system-visual-heading p {
          margin: 0;
          color: var(--accent-2);
          font-size: .78rem;
          font-weight: 700;
        }
        .vespa-journal .system-visual-heading h3 {
          margin: 0;
          font-family: var(--font-display);
          font-size: clamp(1.2rem, 2vw, 1.8rem);
          letter-spacing: -.02em;
          text-wrap: balance;
        }
        .vespa-journal .system-visual svg {
          display: block;
          width: 100%;
          height: auto;
          overflow: visible;
        }
        .vespa-journal .system-visual figcaption {
          max-width: 72ch;
          margin-top: .9rem;
          color: var(--muted);
          font-size: .88rem;
          line-height: 1.6;
        }
        @media (max-width: 760px) {
          .vespa-journal .journal-nav {
            display: flex;
            flex-wrap: nowrap;
            overflow-x: auto;
            gap: 1rem;
            scrollbar-width: thin;
          }
          .vespa-journal .journal-nav a { white-space: nowrap; }
          .vespa-journal .system-visual-heading { display: block; }
          .vespa-journal .system-visual-heading h3 { margin-top: .3rem; }
        }
      `}</style>
      <div className="journal-breakout">
        <section className="journal-hero" aria-labelledby="page-title">
          <img
            src={img.hero}
            alt="Finished dark green 1979 Vespa P200E electric conversion in side profile"
          />
          <div className="hero-content">
            <h1 id="page-title">Electric Conversion of a 1979 Vespa P200E</h1>
            <p>
              A documented conversion retaining the original steel body while
              replacing the two-stroke powertrain with a 72V battery,
              controller, hub motor, and fabricated rear structure.
            </p>
            <a className="scroll-cue" href="#story">
              Explore the conversion <ArrowDown size={17} aria-hidden="true" />
            </a>
          </div>
        </section>
      </div>
      <div className="spec-strip" aria-label="Project specifications">
        <div>
          <small>Year</small>
          <strong>1979</strong>
        </div>
        <div>
          <small>Model</small>
          <strong>Vespa P200E</strong>
        </div>
        <div>
          <small>Conversion</small>
          <strong>72V electric</strong>
        </div>
        <div>
          <small>Range</small>
          <strong>Project dependent</strong>
        </div>
        <div>
          <small>Pack voltage</small>
          <strong>72V nominal / 84V full</strong>
        </div>
        <div>
          <small>Status</small>
          <strong>Road-tested build</strong>
        </div>
      </div>
      <nav className="journal-nav" aria-label="Build guide sections">
        <a href="#story">Starting point</a>
        <a href="#battery">Battery &amp; power</a>
        <a href="#powertrain">Controller</a>
        <a href="#integration">Integration</a>
        <a href="#fabrication">Swingarm</a>
        <a href="#finished">Finished scooter</a>
        <a href="#parts">Parts list</a>
      </nav>
      <main id="story">
        <FadeIn>
          <section className="journal-section story-grid">
            <figure className="story-media">
              <img
                src={img.hero}
                alt="Finished dark green 1979 Vespa P200E electric conversion in side profile"
              />
              <figcaption>
                The finished P200E: original steel above, electric conversion
                below.
              </figcaption>
            </figure>
            <div className="story-copy">
              <p className="section-index">01 / starting point</p>
              <h2>Keep the body. Rebuild the system.</h2>
              <p>
                The P200E monocoque chassis is the defining part of the project.
                The conversion removes the two-stroke engine, fuel, exhaust, and
                drivetrain while keeping the scooter’s shell, riding position,
                and visual character.
              </p>
              <ul className="goal-list">
                <li>
                  <strong>Packaging</strong>
                  <span>
                    Keep the battery and power electronics within the scooter’s
                    usable volume.
                  </span>
                </li>
                <li>
                  <strong>Serviceability</strong>
                  <span>
                    Use a protected high-voltage path with accessible isolation
                    and a documented harness.
                  </span>
                </li>
                <li>
                  <strong>Structure</strong>
                  <span>
                    Replace the engine swing unit with a rear structure designed
                    around the hub motor.
                  </span>
                </li>
              </ul>
            </div>
          </section>
        </FadeIn>
        <FadeIn>
          <section className="journal-section" id="battery">
            <div className="section-heading">
              <p className="section-index">02 / battery pack</p>
              <h2>Battery and power electronics.</h2>
              <p>
                It starts with 200 Samsung 25R cells: twenty series groups of
                ten cells in parallel. The pack, BMS, breaker, contactor,
                precharge circuit, charger, and controller form one electrical
                system—not a loose collection of parts.
              </p>
            </div>
            <div className="battery-layout">
              <figure className="battery-main">
                <img
                  src={img.cells}
                  alt="Samsung 18650 cells arranged in holders before the battery pack is completed"
                />
                <div className="battery-callout">
                  <strong>20S10P</strong>
                  <br />
                  Twenty groups in series set voltage; ten cells in parallel
                  share current and establish capacity.
                </div>
                <figcaption className="photo-caption">
                  Cell layout before the battery pack is closed and protected.
                </figcaption>
              </figure>
              <div>
                <dl className="battery-specs">
                  <div>
                    <dt>Configuration</dt>
                    <dd>20 series groups × 10 cells in parallel</dd>
                  </div>
                  <div>
                    <dt>Nominal capacity</dt>
                    <dd>25Ah, based on 2.5Ah cells</dd>
                  </div>
                  <div>
                    <dt>Energy</dt>
                    <dd>Approximately 1.8kWh nominal</dd>
                  </div>
                  <div>
                    <dt>Voltage</dt>
                    <dd>72V nominal; 84V at 4.2V per cell</dd>
                  </div>
                  <div>
                    <dt>Placement</dt>
                    <dd>
                      Packaged in the Vespa body, ahead of the rear powertrain
                    </dd>
                  </div>
                  <div>
                    <dt>Protection</dt>
                    <dd>
                      BMS supervision, service disconnect, breaker/fuse,
                      contactor, and precharge are separate functions
                    </dd>
                  </div>
                  <div>
                    <dt>Charging</dt>
                    <dd>
                      20S lithium-ion charger; maximum voltage must match cell
                      chemistry and BMS configuration
                    </dd>
                  </div>
                </dl>
                <div className="battery-thumbs">
                  <figure>
                    <img
                      src={img.cells}
                      alt="Stacked blue cylindrical cells in holders before completion"
                    />
                    <figcaption className="photo-caption">
                      Cell layout
                    </figcaption>
                  </figure>
                  <figure>
                    <img
                      src={img.busbars}
                      alt="Nickel strip connections on grouped battery cells"
                    />
                    <figcaption className="photo-caption">
                      Interconnect work
                    </figcaption>
                  </figure>
                </div>
              </div>
            </div>
            <figure
              className="battery-wiring-reference"
              style={{ marginTop: "2rem" }}
            >
              <img
                src="/projects/vespa/20s10p-wiring-daly.svg"
                alt="20-series, 10-parallel battery wiring reference with BMS connections"
                style={{ display: "block", width: "100%", background: "#fff" }}
              />
              <figcaption className="photo-caption">
                Battery reference: 20 series groups, 10 cells per group, with
                the BMS sense-lead order shown as a build-check aid.
              </figcaption>
              <div className="downloads">
                <DownloadLink href="/projects/vespa/20s10p-wiring-daly.svg">
                  Download battery wiring reference
                </DownloadLink>
              </div>
            </figure>
            <PowerElectronicsMap />
          </section>
        </FadeIn>
        <VespaPartsCatalog />
        <FadeIn>
          <section
            className="journal-section story-grid reverse"
            id="powertrain"
          >
            <figure className="story-media">
              <img
                src={img.rearDetail}
                alt="Rear hub motor, disc brake, and suspension detail on the converted Vespa"
              />
              <figcaption>
                Rear-wheel detail: the QS hub motor, disc brake, and fabricated
                suspension structure.
              </figcaption>
            </figure>
            <div className="story-copy">
              <p className="section-index">03 / motor & controller</p>
              <h2>The VOTOL EM-100 is the brain.</h2>
              <p>
                The VOTOL EM-100 takes battery DC and turns it into carefully
                timed three-phase power for the hub motor. It reads throttle,
                Hall sensors, brake inputs, reverse, and the key signal, then
                controls current and switching timing to make the motor move.
              </p>
              <ul className="tech-list">
                <li>
                  <strong>72V / 100A rating.</strong> The supplied controller
                  documentation identifies the EM-100 as a 72V, 100A unit. That
                  is the battery-side envelope; motor phase current and usable
                  output depend on programming and temperature.
                </li>
                <li>
                  <strong>Inputs and feedback.</strong> The harness sheet
                  identifies throttle, Hall sensors, electric lock, speedometer,
                  reverse, braking, and programming connections.
                </li>
                <li>
                  <strong>Parameters.</strong> The manual covers low-voltage
                  protection, throttle thresholds, motor pole pairs, Hall phase
                  shift, speedometer output, electronic braking, and thermal
                  protection.
                </li>
              </ul>
              <div className="downloads">
                <DownloadLink href="/projects/vespa/documents/qs-motor-order-spec.pdf">
                  QS motor order/spec sheet
                </DownloadLink>
                <DownloadLink href="/projects/vespa/documents/votol-em-controller-manual.pdf">
                  VOTOL EM controller manual
                </DownloadLink>
                <DownloadLink href="/projects/vespa/documents/em100-wiring-harness.pdf">
                  EM-100 wiring harness sheet
                </DownloadLink>
              </div>
              <HubMotorVisual />
            </div>
          </section>
        </FadeIn>
        <FadeIn>
          <section className="journal-section story-grid" id="integration">
            <figure className="story-media">
              <img
                src={img.controllerBay}
                alt="Installed VOTOL controller and protected high-voltage wiring in the Vespa rear bay"
              />
              <figcaption>
                Installed controller, protection hardware, and cable routing at
                the rear of the conversion.
              </figcaption>
            </figure>
            <div className="story-copy">
              <p className="section-index">04 / integration</p>
              <h2>Separate power, control, and accessory circuits.</h2>
              <p>
                The high-voltage battery circuit carries power to the controller
                through protection and isolation hardware. The low-voltage
                branch is supplied by the DC/DC converter for lighting, horn,
                indicators, and other 12V accessories. The controller harness
                carries low-current command and feedback signals.
              </p>
              <ul className="goal-list">
                <li>
                  <strong>Throttle</strong>
                  <span>
                    A Hall-effect grip sends a variable signal to the
                    controller; it does not carry motor current.
                  </span>
                </li>
                <li>
                  <strong>Precharge</strong>
                  <span>
                    A resistor limits the controller capacitor inrush before the
                    main contactor closes.
                  </span>
                </li>
                <li>
                  <strong>Hall feedback</strong>
                  <span>
                    Motor Hall sensors report rotor position so the controller
                    can time phase current at low speed and startup.
                  </span>
                </li>
              </ul>
            </div>
          </section>
        </FadeIn>
        <FadeIn>
          <section className="journal-section" id="fabrication">
            <div className="section-heading">
              <p className="section-index">05 / fabrication</p>
              <h2>Rear structure designed around the wheel.</h2>
              <p>
                The original P200E engine and transmission hung from a single
                rear swing unit. A direct-drive hub motor has no place in that
                arrangement, so the replacement swingarm had to locate the axle,
                carry the brake reaction, retain the original pivot
                relationship, and give the shock a proper home.
              </p>
            </div>
            <div className="fabrication-pair" style={{ marginTop: "2.5rem" }}>
              <figure>
                <img
                  src={img.cad}
                  alt="CAD rendering of the custom swingarm, disc brake, hub motor and wheel"
                />
                <figcaption className="photo-caption">
                  CAD study of the custom swingarm, hub motor, wheel, and brake
                  assembly.
                </figcaption>
              </figure>
              <figure>
                <img
                  src={img.weld}
                  alt="Steel rectangular tube assembly being clamped during custom swingarm fabrication"
                />
                <figcaption className="photo-caption">
                  Fabrication of the structural tube assembly.
                </figcaption>
              </figure>
            </div>
            <div className="downloads">
              <DownloadLink href="/projects/vespa/swing-arm-v8.step">
                Download swingarm STEP file
              </DownloadLink>
            </div>
          </section>
        </FadeIn>
        <FadeIn>
          <section className="journal-section story-grid reverse" id="finished">
            <figure className="story-media">
              <img
                src={img.front}
                alt="Front portrait of the finished dark green Vespa P200E electric conversion"
              />
              <figcaption>
                Finished conversion: original P200E bodywork, hub motor
                drivetrain, and updated electrical system.
              </figcaption>
            </figure>
            <div className="story-copy">
              <p className="section-index">06 / finished result</p>
              <h2>Classic form, electric drivetrain.</h2>
              <p>
                Painted steel, chrome, floor rails, mirrors, legshield,
                spare-wheel cowl—the P200E keeps its old-world uniform. The
                changes are down low, where the engine used to be, and at the
                rear wheel where the quiet trouble begins.
              </p>
            </div>
          </section>
        </FadeIn>
        <FadeIn>
          <section className="journal-cta">
            <div>
              <p className="section-index">Next</p>
              <h2>More project notes and practical builds.</h2>
            </div>
            <div>
              <p>
                See the rest of the Beckify project archive, or get in touch to
                discuss a build, electrical documentation, or a related
                restoration.
              </p>
              <div className="cta-links">
                <Link href="/projects">Browse projects</Link>
                <Link href="/about#contact">Contact Beckify</Link>
              </div>
            </div>
          </section>
        </FadeIn>
      </main>
    </Layout>
  );
}
