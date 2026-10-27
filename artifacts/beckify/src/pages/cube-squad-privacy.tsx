import { Shield } from "lucide-react";
import { Layout } from "@/components/Layout";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { SchemaHead, toCanonicalUrl } from "@/components/seo/SchemaHead";
import { PAGE_SEO } from "@/data/seo-copy.mjs";

const PRIVACY_URL = toCanonicalUrl("/games/number-blocks/privacy");
const GAME_URL = "/games/number-blocks/";
const CONTACT_EMAIL = "trevorjohnbeck@gmail.com";

const pageSchema = {
  "@context": "https://schema.org",
  "@type": "WebPage",
  "@id": `${PRIVACY_URL}#webpage`,
  url: PRIVACY_URL,
  name: "Cube Squad Privacy Policy",
  about: {
    "@type": "VideoGame",
    name: "Cube Squad",
    applicationCategory: "Game",
    isAccessibleForFree: true,
  },
};

export default function CubeSquadPrivacyPage() {
  return (
    <Layout showAds={false}>
      <SchemaHead
        title={PAGE_SEO["/games/number-blocks/privacy"].title}
        description={PAGE_SEO["/games/number-blocks/privacy"].description}
        path="/games/number-blocks/privacy"
        type="article"
        schema={pageSchema}
      />
      <FadeIn>
        <SectionHeader
          title="Cube Squad Privacy Policy"
          level="h1"
          subtitle="Cube Squad collects nothing. No accounts, no ads, no analytics."
          icon={Shield}
        />
      </FadeIn>

      <FadeIn delay={0.05}>
        <article className="space-y-10 max-w-3xl text-[var(--foreground)]">
          <dl className="grid grid-cols-1 sm:grid-cols-[10rem_1fr] gap-x-6 gap-y-3 text-sm leading-relaxed">
            <dt className="text-[var(--muted)]">Product</dt>
            <dd>Cube Squad — a kids' math game played in the browser</dd>
            <dt className="text-[var(--muted)]">Play it at</dt>
            <dd>
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={GAME_URL}>
                beckify.com/games/number-blocks
              </a>
            </dd>
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
            <dd>27 October 2026</dd>
          </dl>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">What Cube Squad collects: nothing</h2>
            <p className="text-base leading-relaxed">
              Cube Squad does not collect, sell, share, or transmit personal data of any kind — from adults
              or from children.
            </p>
            <ul className="list-disc space-y-2 pl-5 text-base leading-relaxed">
              <li>No user accounts and no sign-in</li>
              <li>No ads</li>
              <li>No analytics or crash-reporting SDKs</li>
              <li>No third-party SDKs</li>
              <li>No tracking across apps or websites</li>
              <li>No cookies or trackers set by the game</li>
              <li>Nothing is uploaded from the game to any server</li>
            </ul>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">The name prompt is session-only</h2>
            <p className="text-base leading-relaxed">
              When the game starts it may ask for a name so it can talk to the player. That name is kept
              only in the page's memory for that session. It is never sent anywhere, never stored on the
              device, and it is gone when the page is closed or reloaded.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">Children's privacy</h2>
            <p className="text-base leading-relaxed">
              Cube Squad is a game for kids and collects no data from anyone, including children.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">Hosting note</h2>
            <p className="text-base leading-relaxed">
              As with any web request, the hosting provider's infrastructure sees the connection's IP
              address in transit. That is not data the game collects, stores, or uses. The separate
              site-wide policy for beckify.com is at{" "}
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href="/privacy/">
                beckify.com/privacy
              </a>
              .
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="font-display text-xl font-bold tracking-tight">Changes and contact</h2>
            <p className="text-base leading-relaxed">
              If this policy changes, the updated text will be published at{" "}
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={PRIVACY_URL}>
                {PRIVACY_URL}
              </a>
              . Questions:{" "}
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={`mailto:${CONTACT_EMAIL}`}>
                {CONTACT_EMAIL}
              </a>
              .{" "}
              <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={GAME_URL}>
                Play Cube Squad
              </a>
            </p>
          </section>
        </article>
      </FadeIn>
    </Layout>
  );
}
