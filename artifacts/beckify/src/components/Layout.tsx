import type { ReactNode } from "react";
import { Starfield } from "@/components/Starfield";
import { Nav } from "@/components/sections/Nav";
import { Footer } from "@/components/sections/Footer";
import { MinimalAdUnit } from "@/components/ads/MinimalAdUnit";

/**
 * Shared shell for every page: starfield backdrop, sticky nav, page
 * content, footer. Widened to max-w-5xl for a proper dashboard feel.
 * `cabinet` drops the footer and tightens chrome so a 16:9 game stage
 * can actually reach 1280×720 in the leftover viewport.
 */
export const Layout = ({
  children,
  showAds = true,
  className = "",
  variant = "default",
}: {
  children: ReactNode;
  showAds?: boolean;
  className?: string;
  variant?: "default" | "cabinet";
}) => (
  <div className={`relative min-h-[100dvh] ${className}`}>
    <Starfield />
    <div className="relative z-10">
      <Nav />
      <main
        className={
          variant === "cabinet"
            ? "mx-auto flex min-h-[calc(100dvh-5.5rem)] max-w-[1280px] flex-col px-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-2 sm:px-3"
            : "mx-auto max-w-5xl space-y-14 px-6 py-10 md:py-14"
        }
      >
        {children}
        {showAds ? <MinimalAdUnit type="adsense" placement="toolbox-sidebar" /> : null}
        {variant === "cabinet" ? null : <Footer />}
      </main>
    </div>
  </div>
);
