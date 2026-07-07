import { Starfield } from "@/components/Starfield";
import { Nav } from "@/components/sections/Nav";
import { ToolboxPage as ToolboxContent } from "@/components/tools/ToolboxPage";

export default function ToolboxPage() {
  return (
    <div className="relative min-h-[100dvh] flex flex-col">
      <Starfield />
      <div className="relative z-10 flex flex-col flex-1">
        <Nav />
        <div className="flex-1 overflow-hidden">
          <ToolboxContent />
        </div>
      </div>
    </div>
  );
}
