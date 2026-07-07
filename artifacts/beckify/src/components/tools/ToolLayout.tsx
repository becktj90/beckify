/**
 * ============================================================================
 * TOOL LAYOUT
 * ============================================================================
 * Main layout for toolbox: sidebar navigation, fuzzy search, category filters,
 * and responsive grid of tool cards. Mobile-first design.
 * ============================================================================
 */

import { useState, useMemo } from "react";
import { Search, X } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import type { Tool, ToolCategory } from "@/lib/ee/types";
import { ALL_TOOLS, TOOLS_BY_CATEGORY, searchTools } from "@/data/tools";

interface ToolLayoutProps {
  selectedToolId?: string;
  onSelectTool: (toolId: string) => void;
}

export function ToolLayout({ selectedToolId, onSelectTool }: ToolLayoutProps) {
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<ToolCategory | null>(
    null
  );

  const categories = Array.from(TOOLS_BY_CATEGORY.keys()) as ToolCategory[];

  const filteredTools = useMemo(() => {
    let results = searchQuery ? searchTools(searchQuery) : ALL_TOOLS;

    if (selectedCategory) {
      results = results.filter((t) => t.category === selectedCategory);
    }

    return results;
  }, [searchQuery, selectedCategory]);

  const handleClearSearch = () => {
    setSearchQuery("");
    setSelectedCategory(null);
  };

  return (
    <div className="flex h-full bg-[var(--background)]">
      {/* Sidebar: Search & Categories */}
      <aside className="w-full md:w-64 border-b md:border-b-0 md:border-r border-[var(--border)] bg-[var(--surface)] p-4 md:p-6 overflow-y-auto">
        <div className="space-y-6">
          {/* Search */}
          <div className="space-y-3">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--muted)]">
              Search
            </h2>
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--muted)]" />
              <Input
                type="text"
                placeholder="Find a tool..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-9 pr-8"
              />
              {searchQuery && (
                <button
                  onClick={() => setSearchQuery("")}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--muted)] hover:text-[var(--foreground)]"
                  aria-label="Clear search"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>
          </div>

          {/* Categories */}
          <div className="space-y-3">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--muted)]">
              Category
            </h2>
            <div className="space-y-2">
              <Button
                variant={selectedCategory === null ? "default" : "outline"}
                size="sm"
                onClick={() => setSelectedCategory(null)}
                className="w-full justify-start"
              >
                All Tools
              </Button>
              {categories.map((cat) => (
                <Button
                  key={cat}
                  variant={selectedCategory === cat ? "default" : "outline"}
                  size="sm"
                  onClick={() => setSelectedCategory(cat)}
                  className="w-full justify-start text-sm"
                >
                  {cat}
                </Button>
              ))}
            </div>
          </div>

          {/* Clear Filters */}
          {(searchQuery || selectedCategory) && (
            <Button
              variant="outline"
              size="sm"
              onClick={handleClearSearch}
              className="w-full"
            >
              Clear Filters
            </Button>
          )}
        </div>
      </aside>

      {/* Main Content: Tool Cards */}
      <main className="flex-1 p-6 md:p-8 overflow-y-auto">
        {filteredTools.length === 0 ? (
          <div className="flex items-center justify-center min-h-[400px]">
            <div className="text-center">
              <p className="text-lg font-semibold text-[var(--foreground)]">
                No tools found
              </p>
              <p className="text-sm text-[var(--muted)]">
                Try adjusting your search or filters
              </p>
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {filteredTools.map((tool) => (
              <ToolCard
                key={tool.id}
                tool={tool}
                isSelected={tool.id === selectedToolId}
                onSelect={() => onSelectTool(tool.id)}
              />
            ))}
          </div>
        )}
      </main>
    </div>
  );
}

interface ToolCardProps {
  tool: Tool;
  isSelected: boolean;
  onSelect: () => void;
}

function ToolCard({ tool, isSelected, onSelect }: ToolCardProps) {
  const Icon = tool.icon;

  return (
    <button
      onClick={onSelect}
      className={`group relative p-4 rounded-xl border transition-all duration-200 text-left ${
        isSelected
          ? "border-[var(--accent)] bg-[var(--accent-soft)] shadow-md"
          : "border-[var(--border)] bg-[var(--surface)] hover:border-[var(--accent)]/50 hover:shadow-sm"
      }`}
    >
      <div className="flex items-start gap-3 mb-2">
        <div
          className={`p-2 rounded-lg ${
            isSelected
              ? "bg-[var(--accent)] text-[var(--background)]"
              : "bg-[var(--background)] text-[var(--accent)]"
          }`}
        >
          <Icon className="w-5 h-5" />
        </div>
        <div className="flex-1">
          <h3 className="font-semibold text-sm leading-tight text-[var(--foreground)]">
            {tool.name}
          </h3>
        </div>
      </div>
      <p className="text-xs text-[var(--muted)] line-clamp-2">
        {tool.description}
      </p>
      <div className="mt-3 pt-3 border-t border-[var(--border)]">
        <p className="text-xs font-medium text-[var(--accent)] uppercase tracking-wider">
          {tool.category}
        </p>
      </div>
    </button>
  );
}
