import { Shield } from "lucide-react";
import { Layout } from "@/components/Layout";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { SchemaHead, toCanonicalUrl } from "@/components/seo/SchemaHead";
import { PAGE_SEO } from "@/data/seo-copy.mjs";

const PRIVACY_URL = toCanonicalUrl("/games/kestrel-heavy/privacy");
const GAME_URL = "/games/kestrel-heavy/";
const CONTACT_EMAIL = "trevorjohnbeck@gmail.com";

const pageSchema = {
  "@context": "https://schema.org",
  "@type": "WebPage",
  "@id": `${PRIVACY_URL}#webpage`,
  url: PRIVACY_URL,
  name: "Kestrel Heavy Privacy Policy",
  about: {
    "@type": "VideoGame",
    name: "Kestrel Heavy",
    applicationCategory: "Game",
    operatingSystem: "iOS, iPadOS",
  },
};

const link = "text-[var(--accent)] underline-offset-4 hover:underline";

export default function KestrelHeavyPrivacyPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title={PAGE_SEO["/games/kestrel-heavy/privacy"].title}
        description={PAGE_SEO["/games/kestrel-heavy/privacy"].description}
        path="/games/kestrel-heavy/privacy"
        type="article"
        schema={pageSchema}
      />
      <FadeIn>
        <SectionHeader
          title="Kestrel Heavy Privacy Policy"
          level="h1"
          subtitle="Kestrel Heavy collects no data. No accounts, no ads, no analytics."
          icon={Shield}
        />
      </FadeIn>

      <FadeIn delay={0.05}>
        <article className="space-y-10 max-w-3xl text-[var(--foreground)]">
          <dl className="grid grid-cols-1 sm:grid-cols-[10rem_1fr] gap-x-6 gap-y-3 text-sm leading-relaxed">
            <dt className="text-[var(--muted)]">Product</dt>
            <dd>
              Kestrel Heavy — a rocket design and launch game for iPhone and iPad (bundle ID{" "}
              <code className="font-mono text-[0.9em]">com.beckify.kestrelheavy</code>)
            </dd>
            <dt className="text-[var(--muted)]">Developer</dt>
            <dd>Trevor Beck</dd>
            <dt className="text-[var(--muted)]">Contact</dt>
            <dd>
              <a className={link} href={`mailto:${CONTACT_EMAIL}`}>
                {CONTACT_EMAIL}
              </a>
            </dd>
            <dt className="text-[var(--muted)]">Public URL</dt>
            <dd>
              <a className={link} href={PRIVACY_URL}>
                {PRIVACY_URL}
              </a>
            </dd>
            <dt className="text-[var(--muted)]">Last updated</dt>
            <dd>11 November 2026</dd>
          </dl>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">What Kestrel Heavy collects: nothing</h2>
            <p className="text-base leading-relaxed">
              Kestrel Heavy does not collect, sell, share, or transmit personal data of any kind, from adults or
              from children. Its App Store privacy label is <strong>Data Not Collected</strong>.
            </p>
            <ul className="list-disc space-y-2 pl-5 text-base leading-relaxed">
              <li>No user accounts and no sign-in</li>
              <li>No ads and no in-app purchases</li>
              <li>No analytics, crash-reporting, or advertising SDKs</li>
              <li>No tracking across apps or websites, and no advertising identifier</li>
              <li>No Game Center</li>
              <li>Play needs no internet connection, and the game has no online features</li>
            </ul>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">What stays on your device</h2>
            <p className="text-base leading-relaxed">
              Your mission progress, saved rocket designs, flight results, and settings are stored only on your
              device. They are never uploaded. Deleting the app removes them, subject to your own device backup
              settings.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">AI-generated voices</h2>
            <p className="text-base leading-relaxed">
              The mission control and commentary voices were generated ahead of time by the developer with
              ElevenLabs text-to-speech and are bundled inside the app as audio files. The app does not contact
              ElevenLabs or any other voice service, and nothing you do in the game is sent anywhere to produce
              them.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">Children's privacy</h2>
            <p className="text-base leading-relaxed">
              Kestrel Heavy is made for a general audience, including kids. It collects no personal information
              from anyone, including children.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">The browser version</h2>
            <p className="text-base leading-relaxed">
              A browser build of the game is playable at{" "}
              <a className={link} href={GAME_URL}>
                beckify.com/games/kestrel-heavy
              </a>
              . The game itself collects nothing there either. As with any web page, the hosting provider sees the
              connection's IP address in transit; that is covered by the site-wide policy at{" "}
              <a className={link} href="/privacy/">
                beckify.com/privacy
              </a>
              .
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">Changes and contact</h2>
            <p className="text-base leading-relaxed">
              If this policy changes, the updated text will be published at{" "}
              <a className={link} href={PRIVACY_URL}>
                {PRIVACY_URL}
              </a>
              . Questions:{" "}
              <a className={link} href={`mailto:${CONTACT_EMAIL}`}>
                {CONTACT_EMAIL}
              </a>
              .
            </p>
          </section>
        </article>
      </FadeIn>
    </Layout>
  );
}
