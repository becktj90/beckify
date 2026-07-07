import { Layout } from "@/components/Layout";
import { About as AboutSection } from "@/components/sections/About";
import { Contact } from "@/components/sections/Contact";

export default function AboutPage() {
  return (
    <Layout>
      <AboutSection />
      <Contact />
    </Layout>
  );
}
