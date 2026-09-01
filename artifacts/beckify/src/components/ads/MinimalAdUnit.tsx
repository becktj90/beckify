import { useEffect, useRef, useState } from "react";
import { ArrowRight } from "lucide-react";

interface AdProps {
  placement?: "toolbox-sidebar" | "build-footer";
  type?: "ethicalads" | "carbon" | "adsense";
}

const AD_TIMEOUT_MS = 8000;
const ADSENSE_UNFILLED_CHECK_MS = 2500;
const ADSENSE_CLIENT_ID = "ca-pub-5333275222472637";

// Cross-promotion shown in place of a paid ad slot when the network
// returns no fill or an ad blocker prevents the script from loading —
// common on a low-traffic site, and better than an empty reserved box.
const HOUSE_ADS = [
  {
    title: "EE Toolbox",
    description: "40+ NEC-referenced calculators — voltage drop, conduit fill, ampacity, transformer sizing, and more.",
    linkText: "Open the toolbox",
    href: "/toolbox/",
  },
  {
    title: "Control System Toolbox",
    description: "Model plants, inspect Bode and root-locus behavior, and compare PID, LQR, and MPC workflows in your browser.",
    linkText: "Try it live",
    href: "/control-systems",
  },
  {
    title: "USA-made gear picks",
    description: "Recommended electrical tools and test equipment, filtered to manufacturer-verified American-made options.",
    linkText: "See the picks",
    href: "/gear?filter=usa-made",
  },
  {
    title: "Beckify is open source",
    description: "Browse the source for every calculator, page, and game on this site on GitHub.",
    linkText: "View the repo",
    href: "https://github.com/becktj90/beckify",
    external: true,
  },
];

export function MinimalAdUnit({ placement = "toolbox-sidebar", type = "ethicalads" }: AdProps) {
  const adRef = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);
  const [showHouseAd, setShowHouseAd] = useState(false);
  const [houseAdIndex] = useState(() => Math.floor(Math.random() * HOUSE_ADS.length));

  useEffect(() => {
    if (process.env.NODE_ENV !== "production" || !adRef.current) return;

    const target = adRef.current;
    let settled = false;
    const reveal = () => {
      if (!settled) {
        settled = true;
        setVisible(true);
      }
    };
    const fallBackToHouseAd = () => {
      settled = true;
      setVisible(false);
      setShowHouseAd(true);
    };
    const timeout = window.setTimeout(fallBackToHouseAd, AD_TIMEOUT_MS);
    const script = document.createElement("script");
    script.async = true;
    script.src = type === "ethicalads"
      ? "https://media.ethicalads.io/media/client/ethicalads.min.js"
      : type === "carbon"
        ? "https://cdn.carbonads.com/carbon.js?serve=CKYIK27J&placement=beckifycom"
        : `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_CLIENT_ID}`;
    if (type === "adsense") script.crossOrigin = "anonymous";
    script.addEventListener("load", reveal, { once: true });
    script.addEventListener("error", fallBackToHouseAd, { once: true });
    window.addEventListener("ea-publisher-empty", fallBackToHouseAd, { once: true });
    target.appendChild(script);

    // AdSense loads its script successfully even on a no-fill response —
    // the actual fill result only shows up afterward as data-ad-status on
    // the <ins> element ("unfilled" vs "filled"), so check that directly
    // rather than trusting the script's load event alone.
    let unfilledCheck: number | undefined;
    if (type === "adsense") {
      unfilledCheck = window.setTimeout(() => {
        if (settled) return;
        const ins = target.querySelector("ins.adsbygoogle");
        if (ins?.getAttribute("data-ad-status") === "unfilled") fallBackToHouseAd();
      }, ADSENSE_UNFILLED_CHECK_MS);
    }

    return () => {
      window.clearTimeout(timeout);
      if (unfilledCheck) window.clearTimeout(unfilledCheck);
      window.removeEventListener("ea-publisher-empty", fallBackToHouseAd);
      script.remove();
    };
  }, [type]);

  if (process.env.NODE_ENV !== "production") return null;

  if (showHouseAd) {
    const houseAd = HOUSE_ADS[houseAdIndex];
    return (
      <aside className="my-6 flex justify-center" aria-label="Beckify feature">
        <a
          href={houseAd.href}
          {...(houseAd.external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
          className="card-surface group flex w-full max-w-[320px] flex-col justify-between gap-3 rounded-lg p-4 transition hover:border-[var(--accent)]/60"
          data-ad-placement={placement}
        >
          <div>
            <p className="text-[10px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">On Beckify</p>
            <h4 className="mt-1 text-sm font-bold text-[var(--foreground)]">{houseAd.title}</h4>
            <p className="mt-1 text-xs leading-snug text-[var(--muted)]">{houseAd.description}</p>
          </div>
          <span className="inline-flex items-center gap-1 text-xs font-semibold text-[var(--accent)] group-hover:text-[var(--accent-2)]">
            {houseAd.linkText} <ArrowRight className="h-3 w-3" />
          </span>
        </a>
      </aside>
    );
  }

  return (
    <aside className={`my-6 flex justify-center transition-opacity duration-200 ${visible ? "opacity-100" : "opacity-0"}`} aria-label="Sponsored" aria-busy={!visible}>
      <div
        ref={adRef}
        className="h-[120px] w-full max-w-[320px] overflow-hidden rounded-lg border border-slate-800 bg-slate-900/50 p-3 text-xs text-slate-400 shadow-sm"
        data-ad-placement={placement}
      >
        {type === "adsense" ? (
          <ins
            className="adsbygoogle"
            style={{ display: "block", minHeight: 90, width: "100%" }}
            data-ad-client={ADSENSE_CLIENT_ID}
            data-ad-format="auto"
            data-full-width-responsive="true"
          />
        ) : (
          <div
            className="horizontal flat"
            data-ea-publisher="beckify-com"
            data-ea-type="image"
            data-ea-style="stickybox"
          />
        )}
      </div>
    </aside>
  );
}
