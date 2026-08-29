interface SolverRequest {
  resistance: number;
  sourceVoltage: number;
}

self.onmessage = ({ data }: MessageEvent<SolverRequest>) => {
  const resistance = Math.max(0.001, Number(data.resistance) || 1);
  const sourceVoltage = Number(data.sourceVoltage) || 0;
  const current = sourceVoltage / resistance;
  self.postMessage({
    sourceVoltage,
    resistance,
    current,
    power: sourceVoltage * current,
  });
};
