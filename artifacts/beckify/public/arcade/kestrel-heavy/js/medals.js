/**
 * Bronze / silver / gold medals per KH-n flight, graded on Haven landing
 * quality: touchdown sink rate, offset from the paint, and tilt.
 *
 * Thresholds scale with the difficulty's own landing limits (landingVy /
 * landingTol), so a KID gold and a PAD RAT gold both mean "well inside
 * what this mode calls a soft catch". Best medal per flight is stored on
 * settings.missionBests[id].medal and persisted with the rest of settings.
 */
export const MEDALS = ['bronze', 'silver', 'gold'];
export const MEDAL_RANK = { none: 0, bronze: 1, silver: 2, gold: 3 };
export const MEDAL_LABEL = { bronze: 'BRONZE', silver: 'SILVER', gold: 'GOLD' };
export const MEDAL_ICON = { bronze: '🥉', silver: '🥈', gold: '🥇' };

/** Fractions of the mode's soft-catch limits. */
export const MEDAL_RULES = {
  gold: { vy: 0.55, dx: 0.4, tilt: 4 },
  silver: { vy: 0.8, dx: 0.75, tilt: 8 },
};

/**
 * @param {{kind:'deck'|'water'|'rud', vy:number, dx:number, tilt:number, landingVy:number, landingTol:number, recovered?:boolean}} t
 * @returns {'gold'|'silver'|'bronze'|null}
 */
export function gradeLanding(t) {
  if (!t || t.kind !== 'deck') return null;
  const vy = Math.abs(Number(t.vy) || 0);
  const dx = Math.abs(Number(t.dx) || 0);
  const tilt = Math.abs(Number(t.tilt) || 0);
  const limVy = Math.max(0.1, Number(t.landingVy) || 6);
  const limDx = Math.max(1, Number(t.landingTol) || 36);
  if (!t.recovered) return 'bronze';
  const meets = (rule) => vy <= limVy * rule.vy && dx <= limDx * rule.dx && tilt <= rule.tilt;
  if (meets(MEDAL_RULES.gold)) return 'gold';
  if (meets(MEDAL_RULES.silver)) return 'silver';
  return 'bronze';
}

export function betterMedal(a, b) {
  return (MEDAL_RANK[b] || 0) > (MEDAL_RANK[a] || 0) ? b : (a || null);
}

export function normalizeMedal(m) {
  return MEDALS.includes(m) ? m : null;
}

/** Keep the best medal on the flight's row; returns {best, improved}. */
export function recordMedal(settings, missionId, medal) {
  if (!settings.missionBests) settings.missionBests = {};
  const row = settings.missionBests[missionId] || (settings.missionBests[missionId] = { score: 0, recovered: false });
  const prev = normalizeMedal(row.medal);
  const next = normalizeMedal(medal);
  const best = betterMedal(prev, next);
  row.medal = best;
  return { best, improved: Boolean(next) && best === next && next !== prev };
}

export function medalText(medal) {
  const m = normalizeMedal(medal);
  return m ? `${MEDAL_ICON[m]} ${MEDAL_LABEL[m]}` : '— no medal';
}

/** One-line medal shelf for the Hangar: "KH-1 🥇 · KH-2 🥉 · KH-3 —". */
export function medalShelf(settings, missionIds) {
  return missionIds
    .map((id) => {
      const m = normalizeMedal(settings?.missionBests?.[id]?.medal);
      return `${id} ${m ? MEDAL_ICON[m] : '—'}`;
    })
    .join('  ·  ');
}
