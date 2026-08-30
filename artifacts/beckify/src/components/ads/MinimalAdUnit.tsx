import { useEffect, useRef, useState } from "react";

interface AdProps {
  placement?: "toolbox-sidebar" | "build-footer";
  type?: "ethicalads" | "carbon" | "adsense";
}

const AD_TIMEOUT_MS = 8000;
const ADSENSE_CLIENT_ID = "ca-pub-5333275222472637";

export function MinimalAdUnit({ placement = "toolbox-sidebar", type = "ethicalads" }: AdProps) {
  const adRef = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);

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
    const collapse = () => {
      if (!settled) {
        settled = true;
        setVisible(false);
      }
    };
    const timeout = window.setTimeout(collapse, AD_TIMEOUT_MS);
    const script = document.createElement("script");
    script.async = true;
    script.src = type === "ethicalads"
      ? "https://media.ethicalads.io/media/client/ethicalads.min.js"
      : type === "carbon"
        ? "https://cdn.carbonads.com/carbon.js?serve=CKYIK27J&placement=beckifycom"
        : `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_CLIENT_ID}`;
    if (type === "adsense") script.crossOrigin = "anonymous";
    script.addEventListener("load", reveal, { once: true });
    script.addEventListener("error", collapse, { once: true });
    window.addEventListener("ea-publisher-empty", collapse, { once: true });
    target.appendChild(script);

    return () => {
      window.clearTimeout(timeout);
      window.removeEventListener("ea-publisher-empty", collapse);
      script.remove();
    };
  }, [type]);

  if (process.env.NODE_ENV !== "production") return null;

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
