import { Layout } from "@/components/Layout";
import { GearMatrix } from "@/components/GearMatrix";
import { SchemaHead } from "@/components/seo/SchemaHead";

const gearSchema = [
  {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: "Recommended Electrical Test Equipment for Bench and Field Work",
    description: "A practical list of recommended DMMs, insulation testers, oscilloscopes, clamp meters, and RF cable analyzers for electrical diagnostics.",
    about: ["electrical test equipment", "avionics test equipment", "insulation resistance testing", "oscilloscope diagnostics", "RF cable analysis"],
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
  return <Layout><SchemaHead title="Recommended Electrical Test Equipment for Bench and Field Work | Beckify" description="Recommended DMMs, insulation testers, oscilloscopes, clamp meters, and RF cable analyzers for electrical bench work and field diagnostics." path="/gear" type="article" schema={gearSchema} /><GearMatrix /></Layout>;
}
