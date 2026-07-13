import { adminClient } from "../_shared/supabase.ts";
import { oneSignalEnabled, sendToTag } from "../_shared/onesignal.ts";

// Book-closure alerts.
//
// ── WHY THIS AND NOT A PRICE ALERT ─────────────────────────────────────────
// The obvious stock notification is "SCOM moved 2% today". It is also useless.
// The NSE has 64 counters and a daily price alert is noise a user turns off in
// a week, and it teaches exactly the wrong instinct: watch the ticker, react to
// the wiggle. Fructa's Learn course spends a whole unit arguing against that.
//
// The alert worth sending is the one with a DEADLINE. To receive a dividend you
// must be on the register when the books close. Miss that date by one day and
// you get nothing, however long you then hold the share. That fact is printed
// in an image-only PDF on the exchange's website and nowhere a retail investor
// would ever look, which is precisely the information asymmetry this app exists
// to close.
//
//   "Safaricom books close in 3 days. Own SCOM by 4 Aug to receive the
//    1.15 final dividend for FY2026."
//
// Actionable, time-bound, and rare: about a dozen a year across the whole
// market, so it can never become spam.
//
// ── HOW IT FIRES ───────────────────────────────────────────────────────────
// Once a day. For every dividend whose book closure is exactly LEAD_DAYS away,
// push to the users tagged `follow_stock_<id>`. Idempotent: a `push_log` row
// per (stock, financial_year, kind, lead) means a re-run, a retry or a double
// cron never sends the same alert twice. Getting this wrong sends a user the
// same push every morning for three days, which is how you get uninstalled.

const LEAD_DAYS = [7, 3, 1];

function tagKey(stockId: string): string {
  // Must match Push.stockTagKey in the app EXACTLY. If these two drift, the
  // filter matches nobody and the push silently goes to zero devices.
  return `follow_stock_${stockId.replace(/[^a-zA-Z0-9]/g, "_")}`;
}

/// EAT is UTC+3. The deadline is a calendar date in Nairobi, so the countdown
/// has to be computed in Nairobi's day, not the server's.
function eatToday(): Date {
  const s = new Date(Date.now() + 3 * 3_600_000).toISOString().slice(0, 10);
  return new Date(`${s}T00:00:00Z`);
}

function daysUntil(iso: string): number | null {
  const d = new Date(`${iso}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) return null;
  return Math.round((d.getTime() - eatToday().getTime()) / 86_400_000);
}

function kindLabel(kind: string): string {
  if (kind === "interim") return "interim";
  if (kind === "special") return "special";
  return "final";
}

/// "in 3 days" / "tomorrow". Never "in 0 days".
function whenPhrase(n: number): string {
  if (n === 1) return "tomorrow";
  return `in ${n} days`;
}

/// 4 Aug. Short, unambiguous, no locale surprises.
function shortDate(iso: string): string {
  const M = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  const d = new Date(`${iso}T00:00:00Z`);
  return `${d.getUTCDate()} ${M[d.getUTCMonth()]}`;
}

Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    return new Response("unauthorized", { status: 401 });
  }

  const db = adminClient();
  const source = "dividend-alerts";
  const startedAt = new Date().toISOString();
  const errors: string[] = [];
  const sent: string[] = [];

  if (!oneSignalEnabled()) {
    return Response.json({ source, skipped: "OneSignal keys not set" });
  }

  // Only dividends with an announced book closure. A null date is a company
  // that has said "subject to approval", and we do not invent a deadline it
  // has not set.
  const { data: divs, error } = await db
    .from("stock_dividends")
    .select("stock_id,financial_year,kind,dps_kes,book_closure")
    .not("book_closure", "is", null);

  if (error) {
    return Response.json({ source, errors: [error.message] }, { status: 500 });
  }

  const due = (divs ?? [])
    .map((d) => ({ ...d, lead: daysUntil(String(d.book_closure)) }))
    .filter((d) => d.lead != null && LEAD_DAYS.includes(d.lead));

  if (due.length === 0) {
    await db.from("scraper_runs").insert({
      source,
      trigger: "cron",
      started_at: startedAt,
      finished_at: new Date().toISOString(),
      written: 0,
      rejected: 0,
      unmapped: [],
      errors: [],
      ok: true,
    });
    return Response.json({ source, due: 0, sent: 0 });
  }

  const ids = [...new Set(due.map((d) => d.stock_id))];
  const { data: stockRows } = await db
    .from("stocks")
    .select("id,ticker,name,active")
    .in("id", ids);
  const byId = new Map((stockRows ?? []).map((s) => [s.id, s]));

  for (const d of due) {
    const s = byId.get(d.stock_id);
    // A hidden stock is hidden. Never push about something the app will not
    // then show, or the deep link lands on nothing.
    if (!s || !s.active) continue;

    const dedupe = `div_${d.stock_id}_${d.financial_year}_${d.kind}_${d.lead}`;

    // Idempotency. Checked BEFORE sending, written after, so a crash between
    // the two re-sends at worst once rather than never alerting again.
    const { data: already } = await db
      .from("dividend_alert_log")
      .select("dedupe_key")
      .eq("dedupe_key", dedupe)
      .maybeSingle();
    if (already) continue;

    const dps = Number(d.dps_kes).toFixed(2);
    const heading = `${s.name}: books close ${whenPhrase(d.lead!)}`;
    const body =
      `Own ${s.ticker} by ${shortDate(String(d.book_closure))} to receive the ` +
      `${dps} KES ${kindLabel(d.kind)} dividend for FY${d.financial_year}. ` +
      `Buying after that date does not qualify.`;

    const res = await sendToTag(tagKey(d.stock_id), "true", {
      heading,
      body,
      target: `stock/${d.stock_id}`,
    });

    if (!res.ok) {
      errors.push(`${s.ticker}: ${res.error}`);
      continue;
    }

    await db.from("dividend_alert_log").insert({
      dedupe_key: dedupe,
      stock_id: d.stock_id,
      financial_year: d.financial_year,
      kind: d.kind,
      lead_days: d.lead,
      heading,
      body,
      recipients: res.recipients ?? 0,
      onesignal_id: res.id ?? null,
    });

    sent.push(`${s.ticker} T-${d.lead}`);
  }

  await db.from("scraper_runs").insert({
    source,
    trigger: "cron",
    started_at: startedAt,
    finished_at: new Date().toISOString(),
    written: sent.length,
    rejected: 0,
    unmapped: [],
    errors,
    ok: errors.length === 0,
  });

  return Response.json({ source, due: due.length, sent, errors });
});
