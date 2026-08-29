import type { ReactNode, SVGProps } from "react";

type IconProps = SVGProps<SVGSVGElement> & { title?: string };

function Icon({ title, children, ...props }: IconProps & { children: ReactNode }) {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden={title ? undefined : true} role={title ? "img" : undefined} {...props}>{title ? <title>{title}</title> : null}{children}</svg>;
}

export function CircuitIcon(props: IconProps) { return <Icon {...props} title={props.title ?? "Circuit"}><path d="M3 12h4m10 0h4M7 8v8m10-8v8" /><path d="M7 9h10M7 15h10" /><circle cx="12" cy="12" r="2.4" /></Icon>; }
export function ScopeTraceIcon(props: IconProps) { return <Icon {...props} title={props.title ?? "Oscilloscope trace"}><path d="M3 12h3l2-6 3 12 3-9 2 3h5" /><path d="M3 4v16h18" /></Icon>; }
export function RelayIcon(props: IconProps) { return <Icon {...props} title={props.title ?? "Relay"}><path d="M4 7h6v10H4zM14 7h6v10h-6zM10 10h4M10 14h4" /><path d="M7 4v3m10-3v3" /></Icon>; }
export function RocketBadgeIcon(props: IconProps) { return <Icon {...props} title={props.title ?? "Rocket badge"}><path d="M12 3c4 1 6 4 6 8l-6 7-6-7c0-4 2-7 6-8Z" /><path d="M9 19 7 21m8-2 2 2M9 11h.01M15 11h.01" /><circle cx="12" cy="14" r="1.5" /></Icon>; }
