import type { ReactNode } from "react";
import { Starfield } from "@/components/Starfield";
import { Nav } from "@/components/sections/Nav";
import { Footer } from "@/components/sections/Footer";
import { MinimalAdUnit } from "@/components/ads/MinimalAdUnit";

/**
 * Shared shell for every page: starfield backdrop, sticky nav, page
 * content, footer. Widened to max-w-5xl for a proper dashboard feel.
 */
export const Layout = ({ children, showAds = true, className = "" }: { children: ReactNode; showAds?: boolean; className?: string }) => (
  <div className={`relative min-h-[100dvh] ${className}`}>
    <Starfield />
    <div className="relative z-10">
      <Nav />
      <div className="max-w-5xl mx-auto px-6 py-10 md:py-14 space-y-14">
        {children}
        {showAds ? <MinimalAdUnit type="adsense" placement="toolbox-sidebar" /> : null}
        <Footer />
      </div>
    </div>
  </div>
);
