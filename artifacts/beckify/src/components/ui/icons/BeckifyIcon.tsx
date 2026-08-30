import type { SVGProps } from "react";

export type BeckifyIconName =
  | "about"
  | "contact"
  | "games"
  | "home"
  | "map"
  | "projects"
  | "toolbox";

type BeckifyIconProps = SVGProps<SVGSVGElement> & {
  name: BeckifyIconName;
  title?: string;
};

const PATHS: Record<BeckifyIconName, string[]> = {
  home: ["M4 11.5 12 4l8 7.5", "M6.5 10v9h11v-9", "M10 19v-5h4v5"],
  about: ["M5 5h14v14H5z", "m8 9 2 2-2 2", "M12.5 13H16"],
  toolbox: ["M4 8h16v12H4z", "M8 8V5h8v3", "M8 13h8", "M10 11v4m4-4v4"],
  projects: ["M12 3c3.5 1.3 5.5 4.2 5.5 8.2L12 19l-5.5-7.8C6.5 7.2 8.5 4.3 12 3Z", "M9 20 7 22m8-2 2 2", "M10 11h.01M14 11h.01"],
  games: ["M7 9h10a3 3 0 0 1 2.8 4.1l-1.1 3.1a2 2 0 0 1-3.6.4L14 15h-4l-1.1 1.6a2 2 0 0 1-3.6-.4l-1.1-3.1A3 3 0 0 1 7 9Z", "M8 12v3m-1.5-1.5h3", "M16 12h.01M18 14h.01"],
  contact: ["M4 6h16v12H4z", "m5 7 7 6 7-6", "M8 15h3"],
  map: ["M4 5h5l3-2 3 2h5v14h-5l-3 2-3-2H4z", "M9 5v14m6-14v14"],
};

export function BeckifyIcon({ name, title, ...props }: BeckifyIconProps) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden={title ? undefined : true}
      role={title ? "img" : undefined}
      {...props}
    >
      {title ? <title>{title}</title> : null}
      {PATHS[name].map((path) => <path key={path} d={path} />)}
    </svg>
  );
}
