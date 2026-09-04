import { Shield } from "lucide-react";
import { Layout } from "@/components/Layout";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { SchemaHead, SITE_URL } from "@/components/seo/SchemaHead";

const PRIVACY_URL = `${SITE_URL}/privacy`;
const CONTACT_EMAIL = "trevorjohnbeck@gmail.com";

const pageSchema = {
  "@context": "https://schema.org",
  "@type": "WebPage",
  "@id": `${PRIVACY_URL}#webpage`,
  url: PRIVACY_URL,
  name: "Privacy Policy — Beckify iOS",
  about: {
    "@type": "MobileApplication",
    name: "Beckify",
    operatingSystem: "iOS, iPadOS",
    applicationCategory: "ProductivityApplication",
    isAccessibleForFree: true,
    identifier: "com.beckify.toolbox",
  },
};

export default function PrivacyPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title="Privacy Policy | Beckify iOS"
        description="Privacy policy for the Beckify iOS and iPadOS app (bundle ID com.beckify.toolbox). Look Check uploads a photo only when you tap Analyze Look. Sensors and Saved Jobs stay on the device. No analytics, ads, tracking, or accounts."
        path="/privacy"
        type="article"
        schema={pageSchema}
      />
      <FadeIn>
        <SectionHeader
          title="Privacy Policy"
          level="h1"
          subtitle="Beckify for iPhone and iPad. Look Check uploads only when you tap Analyze Look."
          icon={Shield}
        />
      </FadeIn>

      <FadeIn delay={0.05}>
        <article className="space-y-10 max-w-3xl text-[var(--foreground)]">
          <dl className="grid grid-cols-1 sm:grid-cols-[10rem_1fr] gap-x-6 gap-y-3 text-sm leading-relaxed">
            <dt className="text-[var(--muted)]">Product</dt>
            <dd>Beckify (bundle ID <code className="font-mono text-[0.9em]">com.beckify.toolbox</code>)</dd>
            <dt className="text-[var(--muted)]">Platforms</dt>
            <dd>iPhone and iPad</dd>
            <dt className="text-[var(--muted)]">Developer</dt>
            <dd>Trevor Beck</dd>
            <dt className="text-[var(--muted)]">Contact</dt>
            <dd>
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={`mailto:${CONTACT_EMAIL}`}>
                {CONTACT_EMAIL}
              </a>
            </dd>
            <dt className="text-[var(--muted)]">Public URL</dt>
            <dd>
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={PRIVACY_URL}>
                {PRIVACY_URL}
              </a>
            </dd>
            <dt className="text-[var(--muted)]">Last updated</dt>
            <dd>4 September 2026</dd>
          </dl>

          <p className="text-base leading-relaxed text-[var(--muted)]">
            This is the privacy policy for the native Beckify iOS and iPadOS app. It is hosted at{" "}
            <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={PRIVACY_URL}>
              {PRIVACY_URL}
            </a>{" "}
            (and https://beckify.com/privacy/). It describes the app, not the beckify.com website.
          </p>

          <p className="text-base leading-relaxed">
            Apple’s App Privacy nutrition label for this app is <strong>Photos</strong> (App Functionality)
            when you use Look Check <strong>Analyze Look</strong>. That upload is user-initiated, not linked
            to an account, and not used for tracking. Sensor readings, Saved Jobs, Motor Nameplate OCR, and
            Panel Directory stay on the device.
          </p>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">What the app does not collect</h2>
            <p className="text-base leading-relaxed">
              Beckify does not collect, sell, share, or transmit personal data for advertising, analytics, or
              tracking.
            </p>
            <ul className="list-disc space-y-2 pl-5 text-base leading-relaxed">
              <li>No analytics or crash-reporting SDKs</li>
              <li>No advertising identifier (IDFA) and no tracking across apps or websites</li>
              <li>No user accounts, sign-in, or cloud sync</li>
              <li>No ads, store checkout, or Amazon links</li>
              <li>The app does not wrap or load beckify.com in a web view</li>
              <li>
                The app is a toolbox of field calculators, homework calculators, and sensors. It is not a
                website project gallery.
              </li>
            </ul>
            <p className="text-base leading-relaxed">
              Optional links the user may tap (
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={SITE_URL}>
                {SITE_URL}
              </a>{" "}
              and{" "}
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={`mailto:${CONTACT_EMAIL}`}>
                mailto:{CONTACT_EMAIL}
              </a>
              ) open in the system browser or mail app. Those destinations are not part of in-app data
              collection.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">
              Sensors and permissions (on-device only)
            </h2>
            <p className="text-base leading-relaxed">
              Permissions are requested only when the related tool is used, not at launch (except iOS may show
              the system sheet the first time that tool starts).
            </p>
            <div className="overflow-x-auto rounded-xl border border-[var(--border)]">
              <table className="w-full min-w-[32rem] text-left text-sm">
                <caption className="sr-only">
                  App permissions, the tools that use them, and what happens on device
                </caption>
                <thead>
                  <tr>
                    <th className="border-b border-[var(--border)] p-3 font-semibold">Permission</th>
                    <th className="border-b border-[var(--border)] p-3 font-semibold">Tools</th>
                    <th className="border-b border-[var(--border)] p-3 font-semibold">What happens</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td className="border-b border-[var(--border)] p-3 align-top">Microphone</td>
                    <td className="border-b border-[var(--border)] p-3 align-top">Noise Meter</td>
                    <td className="border-b border-[var(--border)] p-3 align-top">
                      Relative dBFS from live audio. Not recorded, not uploaded, not a calibrated SLM.
                    </td>
                  </tr>
                  <tr>
                    <td className="border-b border-[var(--border)] p-3 align-top">Bluetooth</td>
                    <td className="border-b border-[var(--border)] p-3 align-top">BLE Scanner</td>
                    <td className="border-b border-[var(--border)] p-3 align-top">
                      Nearby BLE advertisements (name, identifier, RSSI, advertised service UUIDs). Not
                      uploaded.
                    </td>
                  </tr>
                  <tr>
                    <td className="border-b border-[var(--border)] p-3 align-top">Location (When In Use)</td>
                    <td className="border-b border-[var(--border)] p-3 align-top">Position; Wi-Fi Path (SSID / 0…1 amplitude / optional GPS coverage sketch)</td>
                    <td className="border-b border-[var(--border)] p-3 align-top">
                      Coordinates, current SSID, Apple <code className="font-mono text-[0.9em]">signalStrength</code>{" "}
                      0…1, on-device heatmap samples. Not used at launch. Not uploaded.
                    </td>
                  </tr>
                  <tr>
                    <td className="border-b border-[var(--border)] p-3 align-top">Local Network</td>
                    <td className="border-b border-[var(--border)] p-3 align-top">Wi-Fi Path (optional); Cellular Path (optional)</td>
                    <td className="border-b border-[var(--border)] p-3 align-top">
                      TCP connect timing to a LAN or default-gateway host you choose. Public hosts such as
                      1.1.1.1, and Online / Captive to captive.apple.com, do not need this permission.
                    </td>
                  </tr>
                  <tr>
                    <td className="p-3 align-top">Camera</td>
                    <td className="p-3 align-top">Motor Nameplate OCR; Look Check</td>
                    <td className="p-3 align-top">
                      Nameplate photos stay on this device. A Look Check photo uploads only when you tap
                      Analyze Look.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p className="text-base leading-relaxed">
              CoreMotion (level, magnetometer, barometer, g-force) does not use those permission strings.
              Battery and thermal state are local diagnostics.
            </p>
            <p className="text-base leading-relaxed">
              iOS does <strong>not</strong> give third-party apps Wi-Fi RSSI in dBm. The Wi-Fi Path tool leads
              with <strong>Online / Captive</strong> (Apple hotspot-detect) and shows Apple’s public 0…1{" "}
              <code className="font-mono text-[0.9em]">signalStrength</code> (percent and bars) and an
              on-device coverage sketch. It does not invent dBm. Catalog Look Check is a separate photo tool.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">Look Check (iOS photo tool)</h2>
            <p className="text-base leading-relaxed">
              Catalog Look Check is the website photo product — not the Wi-Fi / Cellular{" "}
              <strong>Online / Captive</strong> hotspot-detect card. Taking or choosing a photo does not
              upload it. <strong>Analyze Look</strong> POSTs an upright JPEG to{" "}
              <code className="font-mono text-[0.9em]">https://beckify.com/api/analyze-look</code> (or a
              HTTPS endpoint you enter). The Beckify API may forward that photo to OpenAI and/or Anthropic.
              Entertainment only — not medical or dating advice. Anyone who appears under 18 is not rated.
              The photo is not saved in Saved Jobs.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">What stays on the device</h2>
            <p className="text-base leading-relaxed">
              Named <strong>Saved Jobs</strong> are lightweight on-device notes (homework or field snapshots of
              calculator inputs/results or sensor numbers the user chooses to save). They use Apple’s{" "}
              <code className="font-mono text-[0.9em]">UserDefaults</code>. They are not a project gallery and
              are not uploaded. Deleting the app removes them, subject to the user’s device backup settings.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">Children’s privacy</h2>
            <p className="text-base leading-relaxed">
              The app is rated 4+ and does not collect data from anyone, including children.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">Changes</h2>
            <p className="text-base leading-relaxed">
              If this policy changes, the updated text will be published at{" "}
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={PRIVACY_URL}>
                {PRIVACY_URL}
              </a>
              .
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">Website toolbox photos (beckify.com)</h2>
            <p className="text-base leading-relaxed">
              This section describes the <strong>website</strong> toolbox at{" "}
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={`${SITE_URL}/toolbox/`}>
                {SITE_URL}/toolbox/
              </a>
              . The native iOS Look Check tool uses the same Analyze Look upload rule.
            </p>
            <p className="text-base leading-relaxed">
              Motor nameplate and panel directory tools default to on-device Tesseract.js. Choosing a photo does
              not upload it. The image stays in the browser and is discarded on reset or when you leave the page.
            </p>
            <p className="text-base leading-relaxed">
              Optional <strong>Enhance with AI</strong> on the motor nameplate and panel directory tools uploads
              the photo only after you turn the toggle on and click Read. You may point that request at a HTTPS
              endpoint you control, or at the Beckify proxy when it is configured (
              <code className="font-mono text-[0.9em]">/api/analyze-nameplate</code>
              {" "}
              or{" "}
              <code className="font-mono text-[0.9em]">/api/analyze-panel</code>
              ). The Beckify proxy may forward that photo to OpenAI and/or Anthropic (the configured downstream
              vision providers). A personal API key stays in session storage on this device and is not sent to
              Beckify. The result is an assistive draft for you to review — not perfect OCR and not an AI
              electrician. NEC math and directory metrics still wait for the review checkbox.
            </p>
            <p className="text-base leading-relaxed">
              Megger TDR Analyzer and Look Check are cloud vision tools. Choosing a photo still does not upload
              it. The image leaves this device only when you click Analyze Trace or Analyze Look (
              <code className="font-mono text-[0.9em]">/api/analyze-tdr</code>
              {" "}
              or{" "}
              <code className="font-mono text-[0.9em]">/api/analyze-look</code>
              ). The Beckify proxy may forward those photos to OpenAI and/or Anthropic. Look Check is
              entertainment only — not medical or dating advice — and will not rate a photo if anyone appears
              under 18.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">Contact</h2>
            <p className="text-base leading-relaxed">
              Questions:{" "}
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={`mailto:${CONTACT_EMAIL}`}>
                {CONTACT_EMAIL}
              </a>
            </p>
          </section>
        </article>
      </FadeIn>
    </Layout>
  );
}
