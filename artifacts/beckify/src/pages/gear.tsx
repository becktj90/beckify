import { Layout } from "@/components/Layout";
import { GearMatrix } from "@/components/GearMatrix";
import { SchemaHead } from "@/components/seo/SchemaHead";

const gearSchema = [
  {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: "Recommended Tools for High-Consequence Electrical Work",
    description: "A practical list of hand tools, DMMs, insulation testers, oscilloscopes, clamp meters, and RF cable analyzers for electrical workers and engineers.",
    about: ["electrical hand tools", "electrical test equipment", "insulation resistance testing", "oscilloscope diagnostics", "RF cable analysis"],
  },
  {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: [
      {
        "@type": "Question",
        name: "What is the best first electrical test tool for field troubleshooting?",
        acceptedAnswer: { "@type": "Answer", text: "A professional True-RMS handheld DMM is the most broadly useful first tool for voltage, resistance, continuity, and current troubleshooting. A dedicated insulation tester, oscilloscope, clamp meter, or RF analyzer should be added only when the task requires it." },
      },
      {
        "@type": "Question",
        name: "Can an insulation tester or hipot tester be used on any aircraft circuit?",
        acceptedAnswer: { "@type": "Answer", text: "No. The applicable aircraft and component maintenance data determines whether testing is permitted, the required isolation, and the allowed test voltage. Sensitive equipment must be protected or disconnected exactly as specified." },
      },
      {
        "@type": "Question",
        name: "When do I need a cable and antenna analyzer instead of a multimeter?",
        acceptedAnswer: { "@type": "Answer", text: "Use a cable and antenna analyzer for RF-path measurements such as return loss, VSWR, cable loss, and distance-to-fault. A multimeter cannot perform those RF measurements." },
      },
    ],
  },
];

export default function GearPage() {
  return <Layout><SchemaHead title="Recommended Electrical Tools for Engineers and Field Workers | Beckify" description="Recommended hand tools, DMMs, insulation testers, oscilloscopes, clamp meters, and RF cable analyzers for high-consequence electrical work." path="/gear" type="article" schema={gearSchema} /><GearMatrix /></Layout>;
}
