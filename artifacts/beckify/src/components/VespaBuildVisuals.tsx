type FlowNodeProps = {
  x: number;
  y: number;
  title: string;
  detail: string;
  accent?: boolean;
};

function FlowNode({ x, y, title, detail, accent = false }: FlowNodeProps) {
  return (
    <g transform={`translate(${x} ${y})`}>
      <rect
        width="152"
        height="70"
        rx="10"
        fill={accent ? "var(--accent-soft)" : "var(--surface)"}
        stroke={accent ? "var(--accent)" : "var(--border)"}
      />
      <text x="14" y="29" fill="var(--foreground)" fontSize="13" fontWeight="700">
        {title}
      </text>
      <text x="14" y="49" fill="var(--muted)" fontSize="10">
        {detail}
      </text>
    </g>
  );
}

export function PowerElectronicsMap() {
  return (
    <figure className="system-visual" aria-labelledby="power-map-title">
      <div className="system-visual-heading">
        <p>Power path</p>
        <h3 id="power-map-title">One protected path, two jobs.</h3>
      </div>
      <svg viewBox="0 0 900 280" role="img" aria-label="Battery power and low-voltage accessory paths in the Vespa conversion">
        <defs>
          <marker id="vespa-flow-arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
            <path d="M0 0L8 4L0 8Z" fill="var(--accent)" />
          </marker>
        </defs>
        <path d="M164 87H202M354 87H392M544 87H582M734 87H772" fill="none" stroke="var(--accent)" strokeWidth="2" markerEnd="url(#vespa-flow-arrow)" />
        <path d="M468 122V193H582" fill="none" stroke="var(--accent-2)" strokeWidth="2" markerEnd="url(#vespa-flow-arrow)" />
        <path d="M734 228H772" fill="none" stroke="var(--accent-2)" strokeWidth="2" markerEnd="url(#vespa-flow-arrow)" />
        <text x="190" y="65" fill="var(--muted)" fontSize="10">isolate</text>
        <text x="372" y="65" fill="var(--muted)" fontSize="10">connect</text>
        <text x="552" y="65" fill="var(--muted)" fontSize="10">switch</text>
        <text x="532" y="178" fill="var(--muted)" fontSize="10">step down</text>
        <FlowNode x={12} y={52} title="20S10P battery" detail="72V nominal • 25Ah" accent />
        <FlowNode x={202} y={52} title="BMS + breaker" detail="monitor and isolate" />
        <FlowNode x={392} y={52} title="Precharge + contactor" detail="controlled connection" />
        <FlowNode x={582} y={52} title="VOTOL EM-100" detail="three-phase switching" accent />
        <FlowNode x={772} y={52} title="QS hub motor" detail="rear-wheel drive" />
        <FlowNode x={582} y={193} title="DC-DC converter" detail="72V to 12V" />
        <FlowNode x={772} y={193} title="Lights + horn" detail="accessory circuits" />
      </svg>
      <figcaption>
        The high-voltage battery path is isolated and controlled before it reaches the controller; a separate converter serves the original-style 12V equipment.
      </figcaption>
    </figure>
  );
}

export function HubMotorVisual() {
  return (
    <figure className="system-visual hub-visual" aria-labelledby="hub-visual-title">
      <div className="system-visual-heading">
        <p>Rear-wheel architecture</p>
        <h3 id="hub-visual-title">The motor lives inside the wheel.</h3>
      </div>
      <svg viewBox="0 0 900 330" role="img" aria-label="Simplified hub-motor rear-wheel architecture with brake, wheel, motor, and swingarm labels">
        <circle cx="230" cy="165" r="120" fill="var(--surface)" stroke="var(--border)" strokeWidth="16" />
        <circle cx="230" cy="165" r="77" fill="color-mix(in srgb, var(--accent) 18%, transparent)" stroke="var(--accent)" strokeWidth="2" />
        <circle cx="230" cy="165" r="41" fill="var(--background)" stroke="var(--foreground)" strokeWidth="2" />
        <circle cx="230" cy="165" r="56" fill="none" stroke="var(--accent-2)" strokeWidth="8" strokeDasharray="3 7" />
        <path d="M270 170H500" stroke="var(--foreground)" strokeWidth="34" strokeLinecap="round" />
        <path d="M500 170H700" stroke="var(--accent)" strokeWidth="20" strokeLinecap="round" />
        <path d="M230 42V18H385" stroke="var(--border)" fill="none" />
        <path d="M180 100L90 64H38" stroke="var(--border)" fill="none" />
        <path d="M286 218L412 270H550" stroke="var(--border)" fill="none" />
        <text x="392" y="22" fill="var(--foreground)" fontSize="13" fontWeight="700">Tire and 10-inch wheel</text>
        <text x="42" y="58" fill="var(--foreground)" fontSize="13" fontWeight="700">Disc brake</text>
        <text x="554" y="277" fill="var(--foreground)" fontSize="13" fontWeight="700">Fabricated swingarm</text>
        <text x="187" y="159" fill="var(--foreground)" fontSize="12" fontWeight="700">QS</text>
        <text x="177" y="176" fill="var(--foreground)" fontSize="12" fontWeight="700">MOTOR</text>
        <text x="395" y="160" fill="var(--background)" fontSize="13" fontWeight="700">AXLE</text>
        <text x="706" y="175" fill="var(--foreground)" fontSize="13" fontWeight="700">PIVOT</text>
      </svg>
      <figcaption>
        Unlike the original engine-and-transmission unit, the direct-drive hub motor concentrates propulsion at the wheel. The fabricated arm carries axle location, braking reaction, pivot alignment, and shock mounting.
      </figcaption>
    </figure>
  );
}
