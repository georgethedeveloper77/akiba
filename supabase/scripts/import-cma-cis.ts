// import-cma-cis.ts
// Parse a quarterly CMA "Collective Investment Schemes" report into the
// `cma_imports` staging table for admin review, then (with `apply`) promote it
// onto funds.composition/aum_kes + companies.aum_kes/market_share.
//
// Reads the PDF DIRECTLY. Table 18 (§2.7, per-fund asset-class composition) is
// a fully-ruled grid whose cells are vertically centred and whose fund names
// wrap across 2–3 lines, so naive line/regex parsing recovers nothing. Instead
// we:
//   1. read every text item with its (x,y) from pdfjs;
//   2. anchor each Table-18 row by matching its Total-column value to a known
//      per-fund AUM (Tables 11–15) — this pins the row regardless of wrapping
//      and drops scheme subtotals automatically;
//   3. bin the 8 asset-class numbers into columns by x, zipping tokens to rows
//      positionally within each column (immune to sub-row vertical offset);
//   4. reconcile every row's 8 classes against its own Total (<0.5%) so any
//      misparse is flagged, not written.
//
//   # test parsing only — no DB, no env:
//   deno run -A supabase/scripts/import-cma-cis.ts stage \
//       --pdf CISReportQ1-2026.pdf --period 2026-03-31 --dry --out cma.json
//
//   # stage to Supabase (env via --env-file):
//   deno run -A --env-file=fructa-admin/.env.local \
//       supabase/scripts/import-cma-cis.ts stage \
//       --pdf CISReportQ1-2026.pdf --period 2026-03-31 \
//       --source https://www.cmarcp.or.ke/.../CISReportQ1-2026.pdf
//
//   # promote reconciled rows onto funds/companies:
//   deno run -A --env-file=fructa-admin/.env.local \
//       supabase/scripts/import-cma-cis.ts apply --period 2026-03-31
//
// Env (either name works): SUPABASE_URL | NEXT_PUBLIC_SUPABASE_URL, and
// SUPABASE_SERVICE_ROLE_KEY (sb_secret_…).

import { createClient } from "npm:@supabase/supabase-js@2";
import { getDocumentProxy } from "npm:unpdf";

// ── CMA Table 18 columns, in PDF order → the 8 canonical app keys ──────────
const COMP_COLUMNS = [
  "cash", "fixed_deposits", "listed", "gok",
  "unlisted", "other_cis", "offshore", "alternative",
] as const;

// Table-18 column x-ranges in PDF points (derived from the ruled vertical
// borders; pdfjs and pdfplumber share this coordinate space). A number is
// assigned to a column by its horizontal CENTRE (x + width/2).
const CLASS_X: Record<(typeof COMP_COLUMNS)[number], [number, number]> = {
  cash:           [235, 295],
  fixed_deposits: [295, 355],
  listed:         [355, 412],
  gok:            [412, 482],
  unlisted:       [482, 545],
  other_cis:      [545, 599],
  offshore:       [599, 656],
  alternative:    [656, 716],
};
const TOTAL_X: [number, number] = [716, 795];
const FUNDS_X: [number, number] = [70, 167];   // "Funds" name column
const TYPE_X:  [number, number] = [167, 235];  // "Type of Fund" column

type Item = { x: number; y: number; w: number; s: string };
type FundAum = { scheme: string; fund: string; aum: number };
type CompRow = {
  fund: string;
  cma_type: string;          // CMA's own fund-table classification (review aid)
  type_tag: string;          // "Type of Fund" cell text in Table 18 (review aid)
  byClass: Record<string, number>;
  total: number;
  reconciles: boolean;        // 8 classes sum to Total within 0.5%
  review?: string;            // set → do NOT auto-apply; needs manual mapping
};
type Scheme = { name: string; aum: number; marketShare: number };
type Payload = {
  period: string;
  source_url: string | null;
  schemes: Scheme[];
  fund_aum: FundAum[];
  composition: CompRow[];
  stats: { comp_ok: number; comp_review: number };
};

// ── number parsing: "1,234", "(402,587)", "-", "" → number ─────────────────
function num(tok: string): number {
  const t = tok.trim();
  if (t === "" || t === "-") return 0;
  const neg = /^\(.*\)$/.test(t);
  const n = Number(t.replace(/[(),\s]/g, ""));
  if (!Number.isFinite(n)) return NaN;
  return neg ? -n : n;
}
const NUMRE = /^\(?-?[\d,]+(?:\.\d+)?\)?$/;

function normName(s: string): string {
  return s.toLowerCase()
    .replace(/\bfund\b/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}
// collapse pdfjs' spaced hyphens: "Mansa - X" → "Mansa-X", "Co - op" → "Co-op"
function cleanName(s: string): string {
  return s.replace(/\s*-\s*/g, "-").replace(/\s+/g, " ").trim();
}
function classOf(xc: number): (typeof COMP_COLUMNS)[number] | null {
  for (const k of COMP_COLUMNS) {
    const [a, b] = CLASS_X[k];
    if (xc >= a && xc < b) return k;
  }
  return null;
}

// ── PDF → per-page text items, and a layout-preserving text join ───────────
// deno-lint-ignore no-explicit-any
async function pageItems(doc: any, p: number): Promise<Item[]> {
  const page = await doc.getPage(p);
  const tc = await page.getTextContent();
  const items: Item[] = [];
  // deno-lint-ignore no-explicit-any
  for (const it of tc.items as any[]) {
    const s: string = it.str ?? "";
    if (s === "") continue;
    items.push({ x: it.transform[4], y: it.transform[5], w: it.width ?? 0, s });
  }
  return items;
}
function itemsToText(items: Item[]): string {
  const a = [...items].sort((p, q) => q.y - p.y || p.x - q.x);
  const lines: Item[][] = [];
  let cur: Item[] = [];
  let cy = Infinity;
  for (const it of a) {
    if (cur.length && Math.abs(it.y - cy) > 2.5) { lines.push(cur); cur = []; }
    if (!cur.length) cy = it.y;
    cur.push(it);
  }
  if (cur.length) lines.push(cur);
  return lines
    .map((ln) => { ln.sort((p, q) => p.x - q.x); return ln.map((i) => i.s).join(" ").replace(/\s+/g, " "); })
    .join("\n");
}

// ── Table 1: CIS Market Share (bounded to the table, not the whole doc) ────
function parseMarketShare(text: string): Scheme[] {
  const out: Scheme[] = [];
  const seen = new Set<string>();
  let inT1 = false;
  for (const line of text.split("\n")) {
    if (/Unit Trust Scheme\s+Mar\s*-?\s*26\s+Market Share/i.test(line)) { inT1 = true; continue; }
    if (inT1 && /TOTAL\s+AUM/i.test(line)) break;
    if (!inT1) continue;
    const m = line.match(/^\s*\d+\.\s+(.+?)\s+([\d,]{6,})\s+([\d.]+)\s*%/);
    if (!m) continue;
    const name = cleanName(m[1].trim());
    if (/TOTAL/i.test(name)) continue;
    const key = normName(name);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ name, aum: num(m[2]), marketShare: num(m[3]) });
  }
  return out;
}

// ── Tables 11–15 (§2.4): per-fund AUM + CMA fund-type classification ───────
const SECTIONS: [RegExp, string][] = [
  [/Money Market Funds/i, "mmf"], [/Fixed Income Funds/i, "fixed_income"],
  [/Equity Funds/i, "equity"], [/Balanced Funds/i, "balanced"], [/Special Funds/i, "special"],
];
function parseAnchors(text: string, schemeNames: string[]): (FundAum & { cma_type: string })[] {
  // bound to the "Analysis of Funds" region (Tables 11–15), before Table 18.
  const s = text.search(/Analysis of Funds/i);
  const e = text.search(/Investment Vehicles by Different Funds/i);
  const region = s >= 0 ? text.slice(s, e > s ? e : undefined) : text;

  const schemes = [...schemeNames].sort((a, b) => b.length - a.length);
  const stripScheme = (body: string) => {
    for (const sc of schemes) if (body.startsWith(sc + " ")) return body.slice(sc.length).trim();
    return body;
  };

  const out: (FundAum & { cma_type: string })[] = [];
  const seen = new Set<string>();
  let cur: string | null = null;
  for (const line of region.split("\n")) {
    const h = line.match(/^\s*(i{1,3}v?|v)\.\s+(.+?Funds)\s*$/i);
    if (h) { for (const [re, tag] of SECTIONS) if (re.test(h[2])) { cur = tag; break; } }
    const m = line.match(/^\s*(\d+)\.\s+(.+?)\s+([\d,]{4,})\s+([\d.]+)\s*%?\s*$/);
    if (!m || !cur) continue;
    const scheme = (schemes.find((sc) => m[2].trim().startsWith(sc)) ?? "").trim();
    let fund = cleanName(stripScheme(m[2].trim()));
    fund = fund.replace(/^(?:Scheme|Trust|Unit|Funds)\s+/i, "").trim(); // wrapped-scheme residue
    if (normName(fund).replace(/\s/g, "").length < 3) continue; // drop junk like bare "usd"
    const aum = num(m[3]);
    const k = normName(fund) + "|" + aum;
    if (seen.has(k)) continue;
    seen.add(k);
    out.push({ scheme, fund, aum, cma_type: cur });
  }
  return out;
}

// ── Table 18 (§2.7): per-fund composition, reconciled against Total ────────
// Positional zip within each column (tokens are in row order), anchored to the
// per-fund AUMs so wrapping and subtotals can't misalign rows.
function alignMono(col: [number, number][], spineY: number[]): number[] {
  const out = new Array(spineY.length).fill(0);
  let i = 0;
  for (let r = 0; r < spineY.length; r++) {
    const lo = r > 0 ? (spineY[r - 1] + spineY[r]) / 2 : Infinity;
    const hi = r + 1 < spineY.length ? (spineY[r] + spineY[r + 1]) / 2 : -Infinity;
    while (i < col.length && col[i][0] > lo) i++;
    if (i < col.length && col[i][0] <= lo && col[i][0] > hi) { out[r] = col[i][1]; i++; }
  }
  return out;
}
function parseComposition(
  pages: Item[][],
  anchors: (FundAum & { cma_type: string })[],
): CompRow[] {
  const aumMap = new Map<number, (FundAum & { cma_type: string })[]>();
  for (const a of anchors) {
    const k = Math.round(a.aum);
    (aumMap.get(k) ?? aumMap.set(k, []).get(k)!).push(a);
  }

  const results: CompRow[] = [];
  for (const items of pages) {
    const perCol: Record<string, [number, number][]> = {};
    const spine: [number, number][] = [];
    const funds: [number, number, string][] = [];
    const types: [number, string][] = [];
    for (const it of items) {
      const xc = it.x + it.w / 2;
      const s = it.s.trim();
      const isNum = NUMRE.test(s) || s === "-";
      if (isNum) {
        const v = num(s);
        const val = Number.isFinite(v) ? v : 0;
        if (xc >= TOTAL_X[0] && xc < TOTAL_X[1]) spine.push([it.y, val]);
        else { const c = classOf(xc); if (c) (perCol[c] ??= []).push([it.y, val]); }
      } else if (/[A-Za-z]/.test(s)) {
        if (xc >= FUNDS_X[0] && xc < FUNDS_X[1]) funds.push([it.y, it.x, s]);
        else if (xc >= TYPE_X[0] && xc < TYPE_X[1]) types.push([it.y, s]);
      }
    }
    spine.sort((a, b) => b[0] - a[0]);              // top → down
    for (const c in perCol) perCol[c].sort((a, b) => b[0] - a[0]);
    const N = spine.length;
    if (!N) continue;
    const spineY = spine.map((s) => s[0]);

    const colVals: Record<string, number[]> = {};
    for (const name of COMP_COLUMNS) {
      const col = perCol[name] ?? [];
      colVals[name] = col.length === N ? col.map((c) => c[1]) : alignMono(col, spineY);
    }

    for (let r = 0; r < N; r++) {
      const [ty, tv] = spine[r];
      let cand = aumMap.get(Math.round(tv));
      if (!cand) {
        for (const [aum, lst] of aumMap) {
          if (aum > 0 && Math.abs(aum - tv) / aum < 0.001) { cand = lst; break; }
        }
      }
      if (!cand) continue;                          // scheme subtotal row
      const byClass: Record<string, number> = {};
      for (const name of COMP_COLUMNS) byClass[name] = colVals[name][r] ?? 0;
      const sum = COMP_COLUMNS.reduce((a, k) => a + (byClass[k] || 0), 0);
      const reconciles = tv > 0 && Math.abs(sum - tv) / tv < 0.005;

      let typeTag = "";
      let bd = Infinity;
      for (const [yy, t] of types) { const d = Math.abs(yy - ty); if (d < bd) { bd = d; typeTag = t; } }

      let an = cand[0];
      if (cand.length > 1) {
        const ft = [...funds].sort((a, b) => Math.abs(a[0] - ty) - Math.abs(b[0] - ty))
          .slice(0, 5).map((f) => f[2]).join(" ").toLowerCase();
        an = cand.find((a) => ft.includes(a.fund.split(" ")[0].toLowerCase())) ?? cand[0];
      }
      results.push({
        fund: an.fund, cma_type: an.cma_type, type_tag: typeTag.trim(),
        byClass, total: tv, reconciles,
      });
    }
  }

  // Drop currency-only junk, then split into unique vs colliding names.
  const JUNK = new Set(["usd", "kes", "total", ""]);
  const clean = results.filter((r) => {
    const k = normName(r.fund);
    return !JUNK.has(k) && k.replace(/\s/g, "").length >= 4;
  });

  // Distinct (name,total) rows — a fund can legitimately recur once per page,
  // so collapse exact duplicates first.
  const distinct = new Map<string, CompRow>();
  for (const r of clean) {
    const key = normName(r.fund) + "|" + Math.round(r.total);
    const prev = distinct.get(key);
    if (!prev || (r.reconciles && !prev.reconciles)) distinct.set(key, r);
  }

  // Ambiguity guard: two DIFFERENT totals sharing a normalised name can't be
  // mapped safely by apply() (both resolve to the same DB row). Keep every such
  // row but flag needs-review, so nothing is silently mis-written. Catches the
  // pdfjs-mangled African Alliance names and the genuine Enwealth / GenAfrica
  // same-name collisions.
  const nameCount = new Map<string, number>();
  for (const r of distinct.values()) nameCount.set(normName(r.fund), (nameCount.get(normName(r.fund)) ?? 0) + 1);

  const out: CompRow[] = [];
  const takenUnique = new Set<string>();
  for (const r of distinct.values()) {
    const n = normName(r.fund);
    if ((nameCount.get(n) ?? 0) > 1) { r.review = "ambiguous-name"; out.push(r); } // keep all, flag
    else if (!takenUnique.has(n)) { takenUnique.add(n); out.push(r); }        // unique
  }
  return out;
}

async function parseCisReport(
  // deno-lint-ignore no-explicit-any
  doc: any,
  period: string,
  sourceUrl: string | null,
): Promise<Payload> {
  const NP = doc.numPages;
  const pageTexts: string[] = [];
  const allItems: Item[][] = [];
  for (let p = 1; p <= NP; p++) {
    const items = await pageItems(doc, p);
    allItems.push(items);
    pageTexts.push(itemsToText(items));
  }
  const text = pageTexts.join("\n");

  // Table 18 spans from its section header to the end of the document.
  const t18Start = pageTexts.findIndex((t) => /Investment Vehicles by Different Funds/i.test(t));
  const t18Pages = t18Start >= 0 ? allItems.slice(t18Start) : allItems;

  const schemes = parseMarketShare(text);
  const anchors = parseAnchors(text, schemes.map((s) => s.name));
  const composition = parseComposition(t18Pages, anchors);
  const fund_aum: FundAum[] = anchors.map((a) => ({ scheme: a.scheme, fund: a.fund, aum: a.aum }));

  return {
    period,
    source_url: sourceUrl,
    schemes,
    fund_aum,
    composition,
    stats: {
      comp_ok: composition.filter((c) => c.reconciles && !c.review).length,
      comp_review: composition.filter((c) => !c.reconciles || c.review).length,
    },
  };
}

// ── db ─────────────────────────────────────────────────────────────────────
function db() {
  const url = Deno.env.get("SUPABASE_URL") ?? Deno.env.get("NEXT_PUBLIC_SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error(
      "Set SUPABASE_URL (or NEXT_PUBLIC_SUPABASE_URL) + SUPABASE_SERVICE_ROLE_KEY " +
      "— or pass --env-file=fructa-admin/.env.local, or use --dry to skip the DB.",
    );
  }
  return createClient(url, key, { auth: { persistSession: false } });
}

function arg(flag: string): string | undefined {
  const i = Deno.args.indexOf(flag);
  return i >= 0 ? Deno.args[i + 1] : undefined;
}
const has = (flag: string) => Deno.args.includes(flag);

// deno-lint-ignore no-explicit-any
async function loadDoc(): Promise<any> {
  const pdfPath = arg("--pdf");
  if (!pdfPath) { console.error("Provide --pdf <file.pdf>"); Deno.exit(1); }
  return getDocumentProxy(await Deno.readFile(pdfPath));
}

async function stage() {
  const period = arg("--period");
  const source = arg("--source") ?? null;
  if (!period) {
    console.error("usage: stage --pdf report.pdf --period YYYY-MM-DD [--source URL] [--dry] [--out f.json]");
    Deno.exit(1);
  }
  const doc = await loadDoc();
  const payload = await parseCisReport(doc, period, source);
  console.log(
    `Parsed: ${payload.schemes.length} schemes, ${payload.fund_aum.length} fund AUMs, ` +
    `${payload.composition.length} composition rows ` +
    `(${payload.stats.comp_ok} ok / ${payload.stats.comp_review} need review)`,
  );

  const outPath = arg("--out");
  if (outPath) {
    await Deno.writeTextFile(outPath, JSON.stringify(payload, null, 2));
    console.log(`Wrote ${outPath}`);
  }
  if (has("--dry")) {
    console.log("--dry: skipped DB write.");
    for (const c of payload.composition.filter((c) => !c.reconciles || c.review)) {
      const sum = COMP_COLUMNS.reduce((a, k) => a + (c.byClass[k] || 0), 0);
      console.log(`  review${c.review ? " (" + c.review + ")" : ""}: ${c.fund}  total=${c.total}  sum=${sum}`);
    }
    return;
  }
  const { error } = await db().from("cma_imports").upsert(
    { period, source_url: source, status: "staged", payload },
    { onConflict: "period" },
  );
  if (error) throw error;
  console.log(`Staged for ${period}. Review, then: apply --period ${period}`);
}

async function apply() {
  const period = arg("--period");
  if (!period) { console.error("usage: apply --period YYYY-MM-DD"); Deno.exit(1); }
  const sb = db();

  const { data: row, error } = await sb.from("cma_imports")
    .select("payload,source_url").eq("period", period).maybeSingle();
  if (error) throw error;
  if (!row) { console.error(`No staged import for ${period}`); Deno.exit(1); }
  const p = row.payload as Payload;

  const { data: funds } = await sb.from("funds").select("id,name,company_id");
  // deno-lint-ignore no-explicit-any
  const byName = new Map((funds ?? []).map((f: any) => [normName(f.name), f]));
  const aumByFund = new Map(p.fund_aum.map((f) => [normName(f.fund), f.aum]));

  let applied = 0;
  const unmapped: string[] = [];
  for (const c of p.composition) {
    if (!c.reconciles || c.review) continue;
    const f = byName.get(normName(c.fund));
    if (!f) { unmapped.push(c.fund); continue; }
    const { error: e } = await sb.from("funds").update({
      composition: c.byClass,
      aum_kes: aumByFund.get(normName(c.fund)) ?? c.total,
      aum_as_of: period,
      composition_source_url: row.source_url,
    }).eq("id", f.id);
    if (e) { console.warn(`  ${c.fund}: ${e.message}`); continue; }
    applied++;
  }

  const { data: cos } = await sb.from("companies").select("id,name");
  // deno-lint-ignore no-explicit-any
  const coByName = new Map((cos ?? []).map((c: any) => [normName(c.name), c]));
  let coApplied = 0;
  for (const s of p.schemes) {
    const co = coByName.get(normName(s.name));
    if (!co) continue;
    await sb.from("companies").update({
      aum_kes: s.aum, market_share: s.marketShare, aum_as_of: period,
    }).eq("id", co.id);
    coApplied++;
  }

  await sb.from("cma_imports").update({ status: "applied" }).eq("period", period);
  console.log(`Applied composition to ${applied} funds, AUM/share to ${coApplied} companies.`);
  if (unmapped.length) {
    console.log(`Unmapped funds (add to fund-name-map): ${unmapped.join(" · ")}`);
  }
}

if (import.meta.main) {
  const cmd = Deno.args[0];
  if (cmd === "stage") await stage();
  else if (cmd === "apply") await apply();
  else { console.error("commands: stage | apply"); Deno.exit(1); }
}
