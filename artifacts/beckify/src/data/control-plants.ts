import type { PidGains, StateSpaceSystem, TransferFunction } from "@/utils/controlEngine";

export type PlantCategory = "Building blocks" | "Machines" | "Hard to control" | "Multi-state";

export interface Plant {
  id: string;
  name: string;
  category: PlantCategory;
  /** One line on what the plant physically is. */
  summary: string;
  /** Rendered form of G(s), e.g. "4 / (s² + 1.2s + 4)". */
  display: string;
  transferFunction: TransferFunction;
  /** Sensible starting gains so the tuner opens somewhere reasonable. */
  suggested: PidGains;
  /** Seconds of step response worth showing for this plant's timescale. */
  duration: number;
  /** What to notice while tuning it. */
  teaches: string;
  /**
   * Physically meaningful state-space, when one exists. Everything else derives
   * its state-space from the transfer function so the two can never disagree.
   */
  stateSpace?: StateSpaceSystem;
}

export const PLANTS: Plant[] = [
  {
    id: "first-order",
    name: "First-order lag",
    category: "Building blocks",
    summary: "An RC filter, a tank level, a room warming up — one storage element, no oscillation.",
    display: "1 / (2s + 1)",
    transferFunction: { numerator: [1], denominator: [2, 1] },
    suggested: { kp: 2, ki: 1, kd: 0 },
    duration: 15,
    teaches: "Proportional gain alone leaves a permanent offset. Add integral action and the error goes to zero.",
  },
  {
    id: "second-order",
    name: "Second-order, lightly damped",
    category: "Building blocks",
    summary: "ζ = 0.3, ωₙ = 2 rad/s. The textbook ringing response.",
    display: "4 / (s² + 1.2s + 4)",
    transferFunction: { numerator: [4], denominator: [1, 1.2, 4] },
    suggested: { kp: 1, ki: 0.5, kd: 0.4 },
    duration: 20,
    teaches: "Derivative action damps the ringing. Push Kp up without Kd and the overshoot grows fast.",
  },
  {
    id: "integrator",
    name: "Integrator",
    category: "Building blocks",
    summary: "Velocity in, position out. The output never settles on its own.",
    display: "1 / s",
    transferFunction: { numerator: [1], denominator: [1, 0] },
    suggested: { kp: 1, ki: 0, kd: 0 },
    duration: 12,
    teaches: "The plant already integrates, so proportional control alone tracks a step with no offset — adding Ki here mostly buys overshoot.",
  },
  {
    id: "double-integrator",
    name: "Double integrator",
    category: "Building blocks",
    summary: "A rigid mass in free space — force in, position out, nothing to damp it.",
    display: "1 / s²",
    transferFunction: { numerator: [1], denominator: [1, 0, 0] },
    suggested: { kp: 1, ki: 0, kd: 1.5 },
    duration: 25,
    teaches: "Pure proportional control oscillates forever. Derivative action is what makes it stable at all.",
  },
  {
    id: "dc-motor-speed",
    name: "DC motor speed",
    category: "Machines",
    summary: "Armature dynamics with inertia, damping, and back-EMF. Fast electrical pole, slow mechanical one.",
    display: "0.6 / (0.002s² + 0.08s + 0.52)",
    transferFunction: { numerator: [0.6], denominator: [0.002, 0.08, 0.52] },
    suggested: { kp: 2, ki: 8, kd: 0 },
    duration: 2,
    teaches: "A stiff plant: the two poles are decades apart, so the loop reacts far faster than the mechanical settling suggests.",
  },
  {
    id: "motor-position",
    name: "Motor position",
    category: "Machines",
    summary: "The same motor driving a position axis — a lag in series with an integrator.",
    display: "1 / (0.5s² + s)",
    transferFunction: { numerator: [1], denominator: [0.5, 1, 0] },
    suggested: { kp: 2, ki: 0, kd: 1 },
    duration: 12,
    teaches: "Classic servo shape. Integral action is rarely needed and usually costs you phase margin.",
  },
  {
    id: "mass-spring-damper",
    name: "Mass-spring-damper",
    category: "Machines",
    summary: "A compliant mechanism or suspension: m = 1, c = 1.4, k = 12.",
    display: "1 / (s² + 1.4s + 12)",
    transferFunction: { numerator: [1], denominator: [1, 1.4, 12] },
    suggested: { kp: 12, ki: 8, kd: 2 },
    duration: 12,
    teaches: "The plant DC gain is only 1/12, so it takes a large Kp just to reach the setpoint without integral action.",
  },
  {
    id: "thermal",
    name: "Thermal process",
    category: "Machines",
    summary: "Two cascaded thermal masses, heavily overdamped — an oven or heat exchanger.",
    display: "1 / (20s² + 12s + 1)",
    transferFunction: { numerator: [1], denominator: [20, 12, 1] },
    suggested: { kp: 3, ki: 0.4, kd: 0 },
    duration: 90,
    teaches: "Slow and forgiving. PI is almost always enough; derivative action mostly amplifies sensor noise here.",
  },
  {
    id: "dead-time",
    name: "Process with dead time",
    category: "Hard to control",
    summary: "A slow first-order lag (τ = 4 s) plus 2 s of transport delay, via a first-order Padé.",
    display: "(−s + 1) / (4s² + 5s + 1)",
    transferFunction: { numerator: [-1, 1], denominator: [4, 5, 1] },
    suggested: { kp: 0.8, ki: 0.2, kd: 0 },
    duration: 40,
    teaches: "Delay eats phase margin. Gains that would be fine without it will happily go unstable here.",
  },
  {
    id: "non-minimum-phase",
    name: "Non-minimum phase",
    category: "Hard to control",
    summary: "A right-half-plane zero — boiler drum level, or a bicycle steering into a turn.",
    display: "(−s + 2) / (s² + 3s + 2)",
    transferFunction: { numerator: [-1, 2], denominator: [1, 3, 2] },
    suggested: { kp: 0.6, ki: 0.3, kd: 0 },
    duration: 25,
    teaches: "The output initially moves the wrong way. Turning up the gain to fight that undershoot destabilises the loop.",
  },
  {
    id: "unstable-first-order",
    name: "Unstable first-order",
    category: "Hard to control",
    summary: "A pole in the right half plane — it runs away unless feedback holds it.",
    display: "1 / (s − 1)",
    transferFunction: { numerator: [1], denominator: [1, -1] },
    suggested: { kp: 4, ki: 2, kd: 0 },
    duration: 12,
    teaches: "Open loop diverges. Feedback is not an improvement here, it is the only thing making the system usable.",
  },
  {
    id: "aircraft-pitch",
    name: "Aircraft pitch",
    category: "Multi-state",
    summary: "Short-period pitch dynamics: elevator deflection to pitch angle.",
    display: "(1.2s + 0.8) / (s³ + 1.4s² + 3.2s + 0.9)",
    transferFunction: { numerator: [1.2, 0.8], denominator: [1, 1.4, 3.2, 0.9] },
    suggested: { kp: 1.5, ki: 0.4, kd: 0.8 },
    duration: 30,
    teaches: "Third order, so there is a real gain limit before the loop rings itself unstable — watch the stability badge.",
    stateSpace: {
      A: [[0, 1, 0], [0, -0.8, 1], [0, -3.2, -0.6]],
      B: [[0], [0.5], [3.4]],
      C: [[1, 0, 0]],
      D: [[0]],
      sampleTime: 0.1,
    },
  },
  {
    id: "inverted-pendulum",
    name: "Inverted pendulum on a cart",
    category: "Multi-state",
    summary: "The standard unstable benchmark for state feedback, LQR, and predictive control.",
    display: "1 / (s⁴ − 1.15s³ − 6.2s² − 2.1s + 0.8)",
    transferFunction: { numerator: [1], denominator: [1, -1.15, -6.2, -2.1, 0.8] },
    suggested: { kp: 12, ki: 0, kd: 6 },
    duration: 12,
    teaches: "A single PID loop struggles with four states. This is the plant that motivates LQR and MPC in the advanced section.",
    stateSpace: {
      A: [[0, 1, 0, 0], [0, -0.18, 2.67, 0], [0, 0, 0, 1], [0, -0.44, 31.18, 0]],
      B: [[0], [1.81], [0], [4.55]],
      C: [[1, 0, 0, 0]],
      D: [[0]],
      sampleTime: 0.1,
    },
  },
];

export const PLANT_CATEGORIES: PlantCategory[] = ["Building blocks", "Machines", "Hard to control", "Multi-state"];

export const DEFAULT_PLANT_ID = "second-order";

export function findPlant(id: string): Plant {
  return PLANTS.find((plant) => plant.id === id) ?? PLANTS[0];
}
