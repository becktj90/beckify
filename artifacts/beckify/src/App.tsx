import { Suspense, lazy } from "react";
import { Switch, Route, Redirect, Router as WouterRouter } from "wouter";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { StoreRedirect } from "@/components/StoreRedirect";
import Home from "@/pages/home";

/**
 * Every route besides Home is code-split: without this, visiting the
 * voltage-drop calculator (or any single page) downloaded recharts and the
 * control-systems simulator in one oversized chunk.
 * Home stays a static import — it's the most common entry point, and lazy-
 * loading it would add a chunk fetch to the very first paint for no benefit.
 */
const NotFound = lazy(() => import("@/pages/not-found"));
const AboutPage = lazy(() => import("@/pages/about"));
const ContactPage = lazy(() => import("@/pages/contact"));
const PrivacyPage = lazy(() => import("@/pages/privacy"));
const ProjectsPage = lazy(() => import("@/pages/projects"));
const AppsPage = lazy(() => import("@/pages/apps"));
const GamesPage = lazy(() => import("@/pages/games"));
const SiteMapPage = lazy(() => import("@/pages/sitemap"));
const KestrelHeavyPage = lazy(() => import("@/pages/kestrel-heavy"));
const NumberBlocksPage = lazy(() => import("@/pages/number-blocks"));
const CubeSquadPrivacyPage = lazy(() => import("@/pages/cube-squad-privacy"));
const VespaP200EPage = lazy(() => import("@/pages/vespa-p200e"));
const HondaXR650RPage = lazy(() => import("@/pages/honda-xr650r"));
const ControlSystemsPage = lazy(() => import("@/pages/control-systems"));
const SharePage = lazy(() => import("@/pages/share"));
const ToolboxPage = lazy(() => import("@/pages/toolbox"));

const queryClient = new QueryClient();

/** Minimal, on-brand loading state for the moment a route chunk is fetching. */
function RouteFallback() {
  return (
    <div className="flex min-h-[60vh] items-center justify-center" role="status" aria-label="Loading page">
      <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--border)] border-t-[var(--accent)] motion-reduce:animate-none" />
    </div>
  );
}

/**
 * Site is multi-page, not a single scroll. The home page is a hub with a
 * hero + cards; each card links to its own page. Page order/paths here
 * should match NAV_LINKS / HOME_NAV_CARDS in src/data/site-content.ts.
 *
 * To change page CONTENT: edit src/data/site-content.ts
 * To change page LAYOUT: edit the relevant file in src/pages/
 * To change visual DESIGN (colors/fonts/spacing): edit src/index.css
 */
function Router() {
  return (
    <Suspense fallback={<RouteFallback />}>
      <Switch>
        <Route path="/" component={Home} />
        <Route path="/about" component={AboutPage} />
        <Route path="/about/" component={AboutPage} />
        <Route path="/privacy" component={PrivacyPage} />
        <Route path="/privacy/" component={PrivacyPage} />
        <Route path="/contact" component={ContactPage} />
        <Route path="/contact/" component={ContactPage} />
        <Route path="/apps" component={AppsPage} />
        <Route path="/apps/" component={AppsPage} />
        <Route path="/projects" component={ProjectsPage} />
        <Route path="/projects/" component={ProjectsPage} />
        <Route path="/projects/vespa-p200e" component={VespaP200EPage} />
        <Route path="/projects/vespa-p200e/" component={VespaP200EPage} />
        <Route path="/projects/honda-xr650r" component={HondaXR650RPage} />
        <Route path="/projects/honda-xr650r/" component={HondaXR650RPage} />
        <Route path="/control-systems" component={ControlSystemsPage} />
        <Route path="/control-systems/" component={ControlSystemsPage} />
        <Route path="/games" component={GamesPage} />
        <Route path="/games/" component={GamesPage} />
        <Route path="/games/kestrel-heavy" component={KestrelHeavyPage} />
        <Route path="/games/kestrel-heavy/" component={KestrelHeavyPage} />
        <Route path="/games/number-blocks" component={NumberBlocksPage} />
        <Route path="/games/number-blocks/" component={NumberBlocksPage} />
        <Route path="/games/number-blocks/privacy" component={CubeSquadPrivacyPage} />
        <Route path="/games/number-blocks/privacy/" component={CubeSquadPrivacyPage} />
        <Route path="/games/new-glenn-runner">{() => <Redirect to="/games/kestrel-heavy/" />}</Route>
        <Route path="/games/new-glenn-runner/">{() => <Redirect to="/games/kestrel-heavy/" />}</Route>
        <Route path="/toolbox" component={ToolboxPage} />
        <Route path="/toolbox/" component={ToolboxPage} />
        <Route path="/gear">{() => <Redirect to="/toolbox/" />}</Route>
        <Route path="/gear/">{() => <Redirect to="/toolbox/" />}</Route>
        <Route path="/products">{() => <Redirect to="/toolbox/" />}</Route>
        <Route path="/products/">{() => <Redirect to="/toolbox/" />}</Route>
        <Route path="/shop" component={StoreRedirect} />
        <Route path="/shop/" component={StoreRedirect} />
        <Route path="/store" component={StoreRedirect} />
        <Route path="/store/" component={StoreRedirect} />
        <Route path="/sitemap" component={SiteMapPage} />
        <Route path="/sitemap/" component={SiteMapPage} />
        <Route path="/share/:token" component={SharePage} />
        <Route path="/share/:token/" component={SharePage} />
        <Route component={NotFound} />
      </Switch>
    </Suspense>
  );
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <WouterRouter base={import.meta.env.BASE_URL.replace(/\/$/, "")}>
        <Router />
      </WouterRouter>
    </QueryClientProvider>
  );
}

export default App;
