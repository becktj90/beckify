import { Switch, Route, Router as WouterRouter } from "wouter";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import NotFound from "@/pages/not-found";
import Home from "@/pages/home";
import AboutPage from "@/pages/about";
import ProjectsPage from "@/pages/projects";
import GamesPage from "@/pages/games";
import SiteMapPage from "@/pages/sitemap";
import CosmicCadetPage from "@/pages/cosmic-cadet";
import BootyButtScooterPage from "@/pages/booty-butt-scooter";
import FingerRunnerPage from "@/pages/finger-runner";
import VespaP200EPage from "@/pages/vespa-p200e";
import GearPage from "@/pages/gear";

const queryClient = new QueryClient();

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
    <Switch>
      <Route path="/" component={Home} />
      <Route path="/about" component={AboutPage} />
      <Route path="/projects" component={ProjectsPage} />
      <Route path="/projects/vespa-p200e" component={VespaP200EPage} />
      <Route path="/gear" component={GearPage} />
      <Route path="/games" component={GamesPage} />
      <Route path="/games/cosmic-cadet" component={CosmicCadetPage} />
      <Route path="/games/booty-butt-scooter" component={BootyButtScooterPage} />
      <Route path="/games/finger-runner" component={FingerRunnerPage} />
      <Route path="/sitemap" component={SiteMapPage} />
      <Route component={NotFound} />
    </Switch>
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
