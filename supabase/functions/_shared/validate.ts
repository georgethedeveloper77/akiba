import type { RatePoint } from "./types.ts";

// Overnight move (pp) beyond which a scraped rate is HELD for manual approval
// instead of applied. Small daily drift applies automatically; a surprising
// jump waits in rate_review. Impossible values (<=0, >=30) are dropped outright.
const REVIEW_DELTA_PP = 1.5;

export interface ReviewPoint {
  point: RatePoint;
  old_rate: number;
  delta_bps: number;
  reason: "jump" | "conflict";
}

// Sanity gate. Returns:
//   ok       -> apply now (rate_history + current_rate)
//   review   -> hold in rate_review for manual approval
//   rejected -> impossible value, dropped
export function validate(points: RatePoint[], prev: Record<string, number>) {
  const ok: RatePoint[] = [];
  const rejected: { point: RatePoint; reason: string }[] = [];
  const review: ReviewPoint[] = [];

  for (const p of points) {
    if (!Number.isFinite(p.rate) || p.rate <= 0 || p.rate >= 30) {
      rejected.push({ point: p, reason: "rate outside 0-30%" });
      continue;
    }
    const last = prev[p.fund_id];
    if (last != null && Math.abs(p.rate - last) > REVIEW_DELTA_PP) {
      review.push({
        point: p,
        old_rate: last,
        delta_bps: Math.round((p.rate - last) * 100),
        reason: "jump",
      });
      continue;
    }
    ok.push(p);
  }
  return { ok, rejected, review };
}
