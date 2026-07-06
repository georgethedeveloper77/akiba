"use server";

import { supabaseAdmin } from "@/lib/supabase/server";
import { republishSnapshot } from "@/lib/publish";
import { revalidatePath } from "next/cache";

const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "");

// Tolerant matching so casual sheet names (MoneyVersations, factsheets) resolve
// to the official DB names without hand-editing every row.
const STOP = new Set("money market fund funds the and of a kes usd dollar shilling".split(" "));
const BRAND: Record<string, string> = { gulfcap: "gcib" };        // same manager, different mark
const ALIAS: Record<string, string> = {                            // norm(sheet) -> norm(official DB name)
  equitymoneymarketfund: "eibmoneymarketfund",                     // Equity = EIB
  naboafricamoneymarketfund: "nabokesmoneymarketfund",             // KES sheet uses "Africa"
  sanlamallianzdollarfund: "sanlamusdmoneymarketfund",
};
function tokset(s: string): Set<string> {
  const t = s.toLowerCase().replace(/\bmmf\b/g, " money market fund ").replace(/[^a-z0-9 ]/g, " ");
  const out = new Set<string>();
  for (const w of t.split(/\s+/)) { if (!w || STOP.has(w)) continue; out.add(BRAND[w] ?? w); }
  return out;
}
function jaccard(a: Set<string>, b: Set<string>): number {
  let i = 0; for (const x of a) if (b.has(x)) i++;
  const u = a.size + b.size - i; return u ? i / u : 0;
}
const guessCur = (s: string) => (/usd|dollar/i.test(s) ? "USD" : "KES");

export interface ImportResult {
  matched: number;
  matches: { name: string; fund: string; rate: number }[];
  unmatched: string[];
  error: string | null;
  asOf: string;
}

export async function importRates(formData: FormData): Promise<ImportResult> {
  const asOf = String(formData.get("as_of") ?? "").trim();
  const file = formData.get("file") as File | null;
  const pasted = String(formData.get("pasted") ?? "");
  const text = file && file.size > 0 ? await file.text() : pasted;

  if (!/^\d{4}-\d{2}-\d{2}$/.test(asOf)) return { matched: 0, matches: [], unmatched: [], error: "Pick a valid date.", asOf };
  if (!text.trim()) return { matched: 0, matches: [], unmatched: [], error: "Paste rows or choose a CSV.", asOf };

  const rows: { name: string; rate: number }[] = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    const cols = line.split(/[,\t]/).map((c) => c.trim().replace(/^"|"$/g, ""));
    if (cols.length < 2) continue;
    const name = cols[0];
    const rate = Number(String(cols[1]).replace(/[^0-9.]/g, ""));
    if (!name || !Number.isFinite(rate) || rate <= 0) continue; // skips header
    rows.push({ name, rate });
  }

  const db = supabaseAdmin();
  const { data: funds } = await db.from("funds").select("id,name,currency").eq("kind", "fund");
  const list = funds ?? [];
  const byNorm = new Map<string, { id: string; name: string }>(list.map((f) => [norm(f.name), { id: f.id, name: f.name }]));
  const idx = list.map((f) => ({ id: f.id, name: f.name, cur: f.currency as string, tok: tokset(f.name) }));

  function resolve(name: string): { id: string; name: string } | null {
    const exact = byNorm.get(norm(name));
    if (exact) return exact;
    const aliased = ALIAS[norm(name)];
    if (aliased && byNorm.get(aliased)) return byNorm.get(aliased)!;
    const rc = guessCur(name), rt = tokset(name);
    let best: typeof idx[number] | null = null, bs = 0, second = 0;
    for (const f of idx) {
      let s = jaccard(rt, f.tok);
      if (f.cur === rc) s += 0.15;               // currency-aware tie-break
      if (s > bs) { second = bs; bs = s; best = f; } else if (s > second) second = s;
    }
    return best && bs >= 0.6 && bs - second >= 0.1 ? { id: best.id, name: best.name } : null;
  }

  const points: { fund_id: string; rate: number; as_of: string; source: string }[] = [];
  const matches: { name: string; fund: string; rate: number }[] = [];
  const unmatched: string[] = [];
  for (const r of rows) {
    const m = resolve(r.name);
    if (!m) { unmatched.push(r.name); continue; }
    points.push({ fund_id: m.id, rate: r.rate, as_of: asOf, source: "admin-import" });
    matches.push({ name: r.name, fund: m.name, rate: r.rate });
  }

  if (points.length) {
    await db.from("rate_history").upsert(points, { onConflict: "fund_id,as_of" });
    const today = new Date(Date.now() + 3 * 3_600_000).toISOString().slice(0, 10); // EAT
    if (asOf >= today) {
      for (const p of points) await db.from("funds").update({ current_rate: p.rate, status: "live" }).eq("id", p.fund_id);
    }
    await republishSnapshot();
  }

  revalidatePath("/admin/import");
  revalidatePath("/admin/sources");
  revalidatePath("/admin");
  return { matched: points.length, matches, unmatched, error: null, asOf };
}
// ── CMA composition import ────────────────────────────────────────────────

const CMA_CLASSES = [
  "cash", "fixed_deposits", "listed", "gok",
  "unlisted", "other_cis", "offshore", "alternative",
] as const;

export interface CmaImportResult {
  matched: number;
  /** CMA fund names with no Akiba fund — mostly funds we don't track. */
  unmatchedCma: string[];
  /** Akiba MMF/bond funds that received NO composition — the actionable
   *  list: likely name mismatches between the CMA report and our funds. */
  uncovered: { id: string; name: string }[];
  error: string | null;
  period: string;
}

/// Import per-fund composition from the CMA CIS quarterly extraction JSON
/// (`cma_qX_YYYY_composition.json`: `{ period, funds: [{fund, aum, comp_kes}] }`,
/// or a bare array of the same rows). Rows are name-matched to funds and
/// applied directly to the 0017 columns — the JSON has already passed the
/// parser's reconciliation gate (Σ classes ≈ stated AUM), so no re-staging.
/// Unmatched CMA names are reported, never guessed.
export async function importCmaComposition(
  formData: FormData,
): Promise<CmaImportResult> {
  const period = String(formData.get("period") ?? "").trim();
  const sourceUrl =
    String(formData.get("source_url") ?? "").trim() || "https://cmarcp.or.ke";
  const file = formData.get("file") as File | null;
  const pasted = String(formData.get("pasted") ?? "");
  const text = file && file.size > 0 ? await file.text() : pasted;

  if (!/^\d{4}-\d{2}-\d{2}$/.test(period)) {
    return { matched: 0, unmatchedCma: [], uncovered: [], error: "Pick the quarter-end date (YYYY-MM-DD).", period };
  }
  if (!text.trim()) {
    return { matched: 0, unmatchedCma: [], uncovered: [], error: "Paste the extraction JSON or choose the file.", period };
  }

  // Parse — accept {funds:[...]} (extraction output) or a bare array.
  type Row = { name: string; aum: number | null; comp: Record<string, number> };
  const rows: Row[] = [];
  try {
    const doc = JSON.parse(text);
    const list: unknown[] = Array.isArray(doc) ? doc : (doc.funds ?? []);
    for (const raw of list) {
      const r = raw as Record<string, unknown>;
      const name = String(r.fund ?? r.name ?? "").trim();
      const compRaw = (r.comp_kes ?? r.classes ?? r.comp) as
        | Record<string, unknown>
        | undefined;
      if (!name || !compRaw) continue;
      const comp: Record<string, number> = {};
      for (const k of CMA_CLASSES) {
        const v = compRaw[k];
        if (typeof v === "number" && Number.isFinite(v) && v > 0) comp[k] = v;
      }
      if (Object.keys(comp).length === 0) continue;
      const aum = typeof r.aum === "number" ? r.aum : (typeof r.total === "number" ? r.total : null);
      rows.push({ name, aum, comp });
    }
  } catch {
    return { matched: 0, unmatchedCma: [], uncovered: [], error: "That isn't valid JSON.", period };
  }
  if (rows.length === 0) {
    return { matched: 0, unmatchedCma: [], uncovered: [], error: "No composition rows found in the JSON.", period };
  }

  const db = supabaseAdmin();
  const { data: funds } = await db
    .from("funds")
    .select("id,name,category")
    .eq("kind", "fund");
  const byNorm = new Map<string, string>(
    (funds ?? []).map((f) => [norm(f.name), f.id]),
  );

  const matchedIds = new Set<string>();
  const unmatchedCma: string[] = [];
  for (const r of rows) {
    const id = byNorm.get(norm(r.name));
    if (!id) { unmatchedCma.push(r.name); continue; }
    await db.from("funds").update({
      composition: r.comp,
      aum_kes: r.aum,
      aum_as_of: period,
      composition_source_url: sourceUrl,
    }).eq("id", id);
    matchedIds.add(id);
  }

  // Actionable inverse: our CMA-coverable funds still without a match.
  const COVERABLE = new Set(["mmf_kes", "mmf_usd", "bond", "balanced", "equity"]);
  const uncovered = (funds ?? [])
    .filter((f) => COVERABLE.has(f.category) && !matchedIds.has(f.id))
    .map((f) => ({ id: f.id, name: f.name }));

  if (matchedIds.size) await republishSnapshot();

  revalidatePath("/admin/import");
  revalidatePath("/admin/funds");
  revalidatePath("/admin");
  return { matched: matchedIds.size, unmatchedCma, uncovered, error: null, period };
}
