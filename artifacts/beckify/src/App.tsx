import { Suspense, lazy } from "react";
import { Switch, Route, Router as WouterRouter } from "wouter";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import Home from "@/pages/home";

/**
 * Every route besides Home is code-split: without this, visiting the
 * voltage-drop calculator (or any single page) downloaded every game engine,
 * three.js, recharts, and the control-systems simulator in one 1.7MB chunk.
 * Home stays a static import — it's the most common entry point, and lazy-
 * loading it would add a chunk fetch to the very first paint for no benefit.
 */
const NotFound = lazy(() => import("@/pages/not-found"));
const AboutPage = lazy(() => import("@/pages/about"));
const ProjectsPage = lazy(() => import("@/pages/projects"));
const GamesPage = lazy(() => import("@/pages/games"));
const SiteMapPage = lazy(() => import("@/pages/sitemap"));
const CosmicCadetPage = lazy(() => import("@/pages/cosmic-cadet"));
const BootyButtScooterPage = lazy(() => import("@/pages/booty-butt-scooter"));
const FingerRunnerPage = lazy(() => import("@/pages/finger-runner"));
const TootTroopersPage = lazy(() => import("@/pages/toot-troopers"));
const ApolloRoccoRunPage = lazy(() => import("@/pages/apollo-rocco-run"));
const PupPlanetPage = lazy(() => import("@/pages/pup-planet"));
const HexGLPage = lazy(() => import("@/pages/hexgl"));
const NewGlennRunnerPage = lazy(() => import("@/pages/new-glenn-runner"));
const VespaP200EPage = lazy(() => import("@/pages/vespa-p200e"));
const HondaXR650RPage = lazy(() => import("@/pages/honda-xr650r"));
const GearPage = lazy(() => import("@/pages/gear"));
const MadeInAmericaPage = lazy(() => import("@/pages/made-in-america"));
const ControlSystemsPage = lazy(() => import("@/pages/control-systems"));

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
        <Route path="/projects" component={ProjectsPage} />
        <Route path="/projects/vespa-p200e" component={VespaP200EPage} />
        <Route path="/projects/honda-xr650r" component={HondaXR650RPage} />
        <Route path="/gear" component={GearPage} />
        <Route path="/made-in-america" component={MadeInAmericaPage} />
        <Route path="/control-systems" component={ControlSystemsPage} />
        <Route path="/games" component={GamesPage} />
        <Route path="/games/cosmic-cadet" component={CosmicCadetPage} />
        <Route path="/games/booty-butt-scooter" component={BootyButtScooterPage} />
        <Route path="/games/finger-runner" component={FingerRunnerPage} />
        <Route path="/games/toot-troopers" component={TootTroopersPage} />
        <Route path="/games/apollo-rocco-run" component={ApolloRoccoRunPage} />
        <Route path="/games/apollo-rocco-run/" component={ApolloRoccoRunPage} />
        <Route path="/games/pup-planet" component={PupPlanetPage} />
        <Route path="/games/hexgl" component={HexGLPage} />
        <Route path="/games/new-glenn-runner" component={NewGlennRunnerPage} />
        <Route path="/sitemap" component={SiteMapPage} />
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
