import { useEffect, useMemo, useState } from "react";
import {
  BatteryCharging,
  BookOpen,
  Cable,
  ChevronRight,
  Command as CommandIcon,
  Factory,
  LayoutDashboard,
  Menu,
  Search,
  ShieldAlert,
} from "lucide-react";
import { CalcForm } from "./CalcForm";
import { VoltageDropCalculator } from "./VoltageDropCalculator";
import { Button } from "@/components/ui/button";
import { CommandDialog, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList, CommandShortcut } from "@/components/ui/command";
import { Input } from "@/components/ui/input";
import { Kbd } from "@/components/ui/kbd";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { ALL_TOOLS, TOOLS_BY_ID, searchTools } from "@/data/tools";
import type { CalcSpec, Tool, Values } from "@/lib/ee/types";
import { VOLTAGE_DROP_DEFAULTS } from "@/lib/ee/voltage-drop";

type ToolboxModuleId =
  | "power-distribution"
  | "machinery-generation"
  | "energy-protection"
  | "engineering-glossary";

interface ToolboxModule {
  id: ToolboxModuleId;
  label: string;
  description: string;
  icon: typeof Cable;
}

interface ToolboxState {
  selectedModuleId: ToolboxModuleId;
  selectedToolId: string;
  toolValuesById: Record<string, Values>;
}

const TOOLBOX_STATE_KEY = "beckify.toolbox.dashboard.v1";
const DEFAULT_TOOL_ID = "voltage-drop";
const DEFAULT_TOOL: Tool = (() => {
  const tool = TOOLS_BY_ID.get(DEFAULT_TOOL_ID);
  if (!tool) {
    throw new Error(
      `Default tool '${DEFAULT_TOOL_ID}' not found in TOOLS_BY_ID. Ensure it is registered in artifacts/beckify/src/data/tools.ts.`
    );
  }
  return tool;
})();

const MODULES: ToolboxModule[] = [
  {
    id: "power-distribution",
    label: "Power Distribution",
    description: "Cable sizing, voltage drop, demand, and conductor planning.",
    icon: Cable,
  },
  {
    id: "machinery-generation",
    label: "Machinery & Generation",
    description: "Motors, transformers, generators, and short-circuit studies.",
    icon: Factory,
  },
  {
    id: "energy-protection",
    label: "Energy Storage & Protection",
    description: "UPS, BESS, coordination, hazards, and power-quality tools.",
    icon: ShieldAlert,
  },
  {
    id: "engineering-glossary",
    label: "Engineering Glossary",
    description: "Reference tables, NEC lookups, and engineering quick references.",
    icon: BookOpen,
  },
];

function getToolModule(tool: Tool): ToolboxModuleId {
  if (tool.category === "Reference") {
    return "engineering-glossary";
  }

  if (
    tool.category === "Motors & Transformers" ||
    tool.id === "generator-sizing" ||
    tool.id === "short-circuit"
  ) {
    return "machinery-generation";
  }

  if (
    tool.id === "ups-sizing" ||
    tool.id === "bess-peak-shave" ||
    tool.id === "harmonics-thd" ||
    tool.id === "lsi-breaker" ||
    tool.category === "Lighting & Power Quality" ||
    tool.category === "Hazardous & Instrumentation"
  ) {
    return "energy-protection";
  }

  return "power-distribution";
}

function getDefaultState(): ToolboxState {
  return {
    selectedModuleId: "power-distribution",
    selectedToolId: DEFAULT_TOOL_ID,
    toolValuesById: {
      [DEFAULT_TOOL_ID]: { ...VOLTAGE_DROP_DEFAULTS },
    },
  };
}

function loadState(): ToolboxState {
  if (typeof window === "undefined") {
    return getDefaultState();
  }

  try {
    const raw = window.sessionStorage.getItem(TOOLBOX_STATE_KEY);
    if (!raw) {
      return getDefaultState();
    }

    const parsed = JSON.parse(raw) as Partial<ToolboxState>;
    return {
      ...getDefaultState(),
      ...parsed,
      toolValuesById: {
        ...getDefaultState().toolValuesById,
        ...(parsed.toolValuesById ?? {}),
      },
    };
  } catch {
    return getDefaultState();
  }
}

function toolKeywordPreview(tool: Tool): string {
  return tool.keywords.slice(0, 3).join(" · ");
}

function formatModuleName(moduleId: ToolboxModuleId): string {
  return moduleId.replace(/-/g, " ");
}

function NavigationPane({
  selectedModuleId,
  selectedToolId,
  searchQuery,
  onSelectModule,
  onSelectTool,
}: {
  selectedModuleId: ToolboxModuleId;
  selectedToolId: string;
  searchQuery: string;
  onSelectModule: (moduleId: ToolboxModuleId) => void;
  onSelectTool: (toolId: string) => void;
}) {
  const visibleTools = searchQuery.trim()
    ? searchTools(searchQuery)
    : ALL_TOOLS.filter((tool) => getToolModule(tool) === selectedModuleId);

  return (
    <div className="flex h-full flex-col gap-6">
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.28em] text-[var(--accent)]">
          Toolbox Modules
        </p>
        <h2 className="mt-3 text-2xl font-semibold text-[var(--foreground)]">
          Production navigation shell
        </h2>
        <p className="mt-2 text-sm text-[var(--muted)]">
          Search globally, jump by module, and keep active inputs in session state.
        </p>
      </div>

      <div className="space-y-3">
        {MODULES.map((module) => {
          const Icon = module.icon;
          const toolCount = ALL_TOOLS.filter((tool) => getToolModule(tool) === module.id).length;

          return (
            <button
              key={module.id}
              onClick={() => onSelectModule(module.id)}
              className={`w-full rounded-2xl border p-4 text-left transition ${
                selectedModuleId === module.id
                  ? "border-[var(--accent)] bg-[var(--accent-soft)]"
                  : "border-[var(--border)] bg-[var(--surface)] hover:border-[var(--accent)]/40"
              }`}
            >
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-start gap-3">
                  <div className="rounded-xl border border-[var(--border)] bg-[var(--background)] p-2 text-[var(--accent)]">
                    <Icon className="h-5 w-5" />
                  </div>
                  <div>
                    <p className="font-semibold text-[var(--foreground)]">{module.label}</p>
                    <p className="mt-1 text-xs leading-5 text-[var(--muted)]">
                      {module.description}
                    </p>
                  </div>
                </div>
                <span className="rounded-full border border-[var(--border)] px-2 py-1 text-xs text-[var(--muted)]">
                  {toolCount}
                </span>
              </div>
            </button>
          );
        })}
      </div>

      <div className="min-h-0 flex-1 rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-4">
        <div className="mb-3 flex items-center justify-between gap-3">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.24em] text-[var(--accent)]">
              Quick access
            </p>
            <p className="mt-1 text-sm text-[var(--muted)]">
              {searchQuery.trim() ? "Matching tools across all modules" : "Current module tools"}
            </p>
          </div>
          <span className="text-xs text-[var(--muted)]">{visibleTools.length} items</span>
        </div>

        <div className="space-y-2">
          {visibleTools.slice(0, 10).map((tool) => (
            <button
              key={tool.id}
              onClick={() => onSelectTool(tool.id)}
              className={`w-full rounded-2xl border px-3 py-3 text-left transition ${
                selectedToolId === tool.id
                  ? "border-[var(--accent)] bg-[var(--accent-soft)]"
                  : "border-[var(--border)] bg-[var(--background)] hover:border-[var(--accent)]/35"
              }`}
            >
              <div className="flex items-center justify-between gap-3">
                <div>
                  <p className="font-medium text-[var(--foreground)]">{tool.name}</p>
                  <p className="mt-1 text-xs text-[var(--muted)]">{toolKeywordPreview(tool)}</p>
                </div>
                <ChevronRight className="h-4 w-4 text-[var(--muted)]" />
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

function ToolCard({
  tool,
  active,
  onSelect,
}: {
  tool: Tool;
  active: boolean;
  onSelect: () => void;
}) {
  const Icon = tool.icon;

  return (
    <button
      onClick={onSelect}
      className={`rounded-3xl border p-5 text-left transition ${
        active
          ? "border-[var(--accent)] bg-[var(--accent-soft)] shadow-[0_0_0_1px_rgba(139,123,255,0.15)]"
          : "border-[var(--border)] bg-[var(--surface)] hover:border-[var(--accent)]/40"
      }`}
    >
      <div className="flex items-start justify-between gap-4">
        <div className="rounded-2xl border border-[var(--border)] bg-[var(--background)] p-3 text-[var(--accent)]">
          <Icon className="h-5 w-5" />
        </div>
        <span className="rounded-full border border-[var(--border)] px-2 py-1 text-[10px] uppercase tracking-[0.24em] text-[var(--muted)]">
          {formatModuleName(getToolModule(tool))}
        </span>
      </div>
      <h3 className="mt-4 text-lg font-semibold text-[var(--foreground)]">{tool.name}</h3>
      <p className="mt-2 text-sm leading-6 text-[var(--muted)]">{tool.description}</p>
      <p className="mt-4 text-xs uppercase tracking-[0.24em] text-[var(--accent)]">
        {toolKeywordPreview(tool)}
      </p>
    </button>
  );
}

export function ToolboxPage() {
  const [state, setState] = useState<ToolboxState>(() => loadState());
  const [searchQuery, setSearchQuery] = useState("");
  const [commandOpen, setCommandOpen] = useState(false);
  const selectedTool = TOOLS_BY_ID.get(state.selectedToolId) ?? DEFAULT_TOOL;
  const activeModule = MODULES.find((module) => module.id === state.selectedModuleId) ?? MODULES[0];

  useEffect(() => {
    window.sessionStorage.setItem(TOOLBOX_STATE_KEY, JSON.stringify(state));
  }, [state]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setCommandOpen((open) => !open);
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  const visibleTools = useMemo(() => {
    if (searchQuery.trim()) {
      return searchTools(searchQuery);
    }

    return ALL_TOOLS.filter((tool) => getToolModule(tool) === state.selectedModuleId);
  }, [searchQuery, state.selectedModuleId]);

  const handleSelectTool = (toolId: string) => {
    const tool = TOOLS_BY_ID.get(toolId);
    if (!tool) {
      return;
    }

    setState((current) => ({
      ...current,
      selectedToolId: toolId,
      selectedModuleId: getToolModule(tool),
    }));
    setCommandOpen(false);
  };

  const handleValuesChange = (toolId: string, values: Values) => {
    setState((current) => ({
      ...current,
      toolValuesById: {
        ...current.toolValuesById,
        [toolId]: values,
      },
    }));
  };

  const selectedToolValues = state.toolValuesById[state.selectedToolId];

  return (
    <div className="min-h-screen bg-[var(--background)] text-[var(--foreground)]">
      <CommandDialog open={commandOpen} onOpenChange={setCommandOpen}>
        <CommandInput placeholder="Search calculators, acronyms, glossary terms…" />
        <CommandList>
          <CommandEmpty>No matching engineering tools.</CommandEmpty>
          {MODULES.map((module) => {
            const tools = ALL_TOOLS.filter((tool) => getToolModule(tool) === module.id);

            return (
              <CommandGroup key={module.id} heading={module.label}>
                {tools.map((tool) => (
                  <CommandItem
                    key={tool.id}
                    value={`${tool.name} ${tool.description} ${tool.keywords.join(" ")}`}
                    onSelect={() => handleSelectTool(tool.id)}
                  >
                    <tool.icon className="h-4 w-4" />
                    <span>{tool.name}</span>
                    <CommandShortcut>{tool.category}</CommandShortcut>
                  </CommandItem>
                ))}
              </CommandGroup>
            );
          })}
        </CommandList>
      </CommandDialog>

      <div className="flex min-h-screen">
        <aside className="hidden w-[340px] shrink-0 border-r border-[var(--border)] bg-[rgba(8,10,20,0.9)] p-6 lg:block">
          <NavigationPane
            selectedModuleId={state.selectedModuleId}
            selectedToolId={state.selectedToolId}
            searchQuery={searchQuery}
            onSelectModule={(selectedModuleId) =>
              setState((current) => ({ ...current, selectedModuleId }))
            }
            onSelectTool={handleSelectTool}
          />
        </aside>

        <main className="flex-1">
          <header className="sticky top-0 z-20 border-b border-[var(--border)] bg-[rgba(5,6,15,0.82)] backdrop-blur-xl">
            <div className="mx-auto flex max-w-[1600px] items-center gap-3 px-4 py-4 md:px-6">
              <Sheet>
                <SheetTrigger asChild>
                  <Button variant="outline" size="icon" className="lg:hidden">
                    <Menu className="h-4 w-4" />
                    <span className="sr-only">Open toolbox navigation</span>
                  </Button>
                </SheetTrigger>
                <SheetContent side="left" className="border-[var(--border)] bg-[var(--background)] p-5">
                  <SheetHeader className="mb-4">
                    <SheetTitle>Toolbox navigation</SheetTitle>
                  </SheetHeader>
                  <NavigationPane
                    selectedModuleId={state.selectedModuleId}
                    selectedToolId={state.selectedToolId}
                    searchQuery={searchQuery}
                    onSelectModule={(selectedModuleId) =>
                      setState((current) => ({ ...current, selectedModuleId }))
                    }
                    onSelectTool={handleSelectTool}
                  />
                </SheetContent>
              </Sheet>

              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-3">
                  <div className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-3 text-[var(--accent)]">
                    <LayoutDashboard className="h-5 w-5" />
                  </div>
                  <div className="min-w-0">
                    <p className="text-xs font-semibold uppercase tracking-[0.28em] text-[var(--accent)]">
                      Beckify Engineering
                    </p>
                    <h1 className="truncate text-lg font-semibold md:text-2xl">
                      Electrical calculation platform
                    </h1>
                  </div>
                </div>
              </div>

              <div className="hidden flex-1 items-center gap-3 md:flex">
                <div className="relative flex-1">
                  <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--muted)]" />
                  <Input
                    value={searchQuery}
                    onChange={(event) => setSearchQuery(event.target.value)}
                    placeholder="Search calculators, acronyms, or glossary terms…"
                    className="h-11 border-[var(--border)] bg-[var(--surface)] pl-10"
                  />
                </div>
                <Button variant="outline" className="gap-2" onClick={() => setCommandOpen(true)}>
                  <CommandIcon className="h-4 w-4" />
                  Command palette
                  <Kbd>Ctrl K</Kbd>
                </Button>
              </div>
            </div>

            <div className="mx-auto max-w-[1600px] px-4 pb-4 md:hidden">
              <div className="relative">
                <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--muted)]" />
                <Input
                  value={searchQuery}
                  onChange={(event) => setSearchQuery(event.target.value)}
                  placeholder="Search calculators, acronyms, or glossary terms…"
                  className="h-11 border-[var(--border)] bg-[var(--surface)] pl-10"
                />
              </div>
            </div>
          </header>

          <div className="mx-auto max-w-[1600px] space-y-6 px-4 py-6 md:px-6 md:py-8">
            <section className="grid gap-4 xl:grid-cols-[minmax(0,1.35fr)_minmax(0,0.95fr)]">
              <div className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-6">
                <p className="text-xs font-semibold uppercase tracking-[0.28em] text-[var(--accent)]">
                  Dashboard architecture
                </p>
                <h2 className="mt-3 text-3xl font-semibold text-[var(--foreground)]">
                  Modern shell for deep electrical engineering workflows
                </h2>
                <p className="mt-4 max-w-3xl text-sm leading-7 text-[var(--muted)]">
                  The toolbox now centers on global search, module-based navigation, and
                  persistent calculator state so engineers can jump between references
                  without losing partially completed studies.
                </p>
              </div>

              <div className="grid gap-4 sm:grid-cols-2">
                {MODULES.map((module) => {
                  const Icon = module.icon;
                  const count = ALL_TOOLS.filter((tool) => getToolModule(tool) === module.id).length;

                  return (
                    <div
                      key={module.id}
                      className={`rounded-3xl border p-5 ${
                        module.id === state.selectedModuleId
                          ? "border-[var(--accent)] bg-[var(--accent-soft)]"
                          : "border-[var(--border)] bg-[var(--surface)]"
                      }`}
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="rounded-2xl border border-[var(--border)] bg-[var(--background)] p-3 text-[var(--accent)]">
                          <Icon className="h-5 w-5" />
                        </div>
                        <span className="text-xs text-[var(--muted)]">{count} tools</span>
                      </div>
                      <h3 className="mt-4 font-semibold text-[var(--foreground)]">{module.label}</h3>
                      <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
                        {module.description}
                      </p>
                    </div>
                  );
                })}
              </div>
            </section>

            <section className="grid gap-6 2xl:grid-cols-[minmax(0,0.74fr)_minmax(0,1.26fr)]">
              <div className="space-y-6">
                <div className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 md:p-6">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <p className="text-xs font-semibold uppercase tracking-[0.24em] text-[var(--accent)]">
                        Discoverable tool grid
                      </p>
                      <h3 className="mt-2 text-2xl font-semibold text-[var(--foreground)]">
                        {searchQuery.trim() ? "Search results" : activeModule.label}
                      </h3>
                      <p className="mt-2 text-sm text-[var(--muted)]">
                        {searchQuery.trim()
                          ? `Showing calculators and references matching “${searchQuery}”.`
                          : activeModule.description}
                      </p>
                    </div>
                    <span className="rounded-full border border-[var(--border)] px-3 py-1 text-xs text-[var(--muted)]">
                      {visibleTools.length} visible
                    </span>
                  </div>

                  <div className="mt-5 grid gap-4 md:grid-cols-2">
                    {visibleTools.map((tool) => (
                      <ToolCard
                        key={tool.id}
                        tool={tool}
                        active={tool.id === state.selectedToolId}
                        onSelect={() => handleSelectTool(tool.id)}
                      />
                    ))}
                  </div>
                </div>
              </div>

              <div className="space-y-6">
                <div className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 md:p-6">
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div>
                      <p className="text-xs font-semibold uppercase tracking-[0.24em] text-[var(--accent)]">
                        Active workspace
                      </p>
                      <h3 className="mt-2 text-2xl font-semibold text-[var(--foreground)]">
                        {selectedTool.name}
                      </h3>
                      <p className="mt-2 text-sm leading-7 text-[var(--muted)]">
                        {selectedTool.description}
                      </p>
                    </div>
                    <div className="rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 py-3 text-right">
                      <p className="text-xs uppercase tracking-[0.2em] text-[var(--muted)]">
                        Module
                      </p>
                      <p className="mt-1 text-sm font-medium text-[var(--foreground)]">
                        {MODULES.find((module) => module.id === getToolModule(selectedTool))?.label}
                      </p>
                    </div>
                  </div>
                </div>

                {selectedTool.id === "voltage-drop" ? (
                  <VoltageDropCalculator
                    values={selectedToolValues}
                    onValuesChange={(values) => handleValuesChange(selectedTool.id, values)}
                  />
                ) : selectedTool.kind === "calc" ? (
                  <div className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 md:p-6">
                    <CalcForm
                      spec={selectedTool as CalcSpec}
                      values={selectedToolValues}
                      onValuesChange={(values) => handleValuesChange(selectedTool.id, values)}
                    />
                  </div>
                ) : (
                  <div className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-8 text-center">
                    <BatteryCharging className="mx-auto h-8 w-8 text-[var(--accent)]" />
                    <p className="mt-4 text-lg font-semibold text-[var(--foreground)]">
                      Custom reference module queued
                    </p>
                    <p className="mt-2 text-sm text-[var(--muted)]">
                      This shell keeps your place while richer custom experiences are filled in.
                    </p>
                  </div>
                )}

                {selectedTool.kind === "calc" && (selectedTool as CalcSpec).reference && (
                  <div className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5">
                    <p className="text-xs font-semibold uppercase tracking-[0.24em] text-[var(--accent)]">
                      Reference basis
                    </p>
                    <p className="mt-3 text-sm leading-7 text-[var(--muted)]">
                      {(selectedTool as CalcSpec).reference}
                    </p>
                  </div>
                )}
              </div>
            </section>
          </div>
        </main>
      </div>
    </div>
  );
}
