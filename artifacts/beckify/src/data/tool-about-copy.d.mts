export interface AboutSection {
  heading: string;
  paragraphs?: string[];
  code?: string[];
  bullets?: string[];
  after?: string[];
}
export const ABOUT_DISCLAIMER: string;
export const TOOL_ABOUT_COPY: Record<string, AboutSection[]>;
export const RELATED_TOOLS: Record<string, { heading: string; links: { slug: string; label: string }[] }>;
