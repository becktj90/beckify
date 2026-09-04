import { useRef, useState } from "react";
import { Download } from "lucide-react";
import { Button } from "@/components/ui/button";
import { downloadElementAsPng } from "@/utils/downloadChartPng";

/** Share/save control for engineer plots — downloads a PNG of the chart panel. */
export function ChartExportButton({
  fileName,
  label = "Save PNG",
}: {
  fileName: string;
  label?: string;
}) {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  return (
    <div ref={hostRef} className="flex flex-col items-end gap-1">
      <Button
        type="button"
        size="sm"
        variant="outline"
        className="gap-1.5"
        disabled={busy}
        onClick={async () => {
          const panel = hostRef.current?.closest("[data-chart-export-root]") as HTMLElement | null;
          if (!panel) {
            setError("Chart panel not found.");
            return;
          }
          setBusy(true);
          setError(null);
          try {
            await downloadElementAsPng(panel, fileName);
          } catch (err) {
            setError(err instanceof Error ? err.message : "Export failed.");
          } finally {
            setBusy(false);
          }
        }}
      >
        <Download className="h-3.5 w-3.5" />
        {busy ? "Exporting…" : label}
      </Button>
      {error ? <p className="text-[11px] text-red-400">{error}</p> : null}
    </div>
  );
}
