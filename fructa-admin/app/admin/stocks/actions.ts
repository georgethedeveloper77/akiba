"use server";

import { supabaseAdmin } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import { slugify } from "@/lib/publish";

// Every mutation republishes, same as the funds lane: the app reads the
// snapshot, not these tables.
async function republishSnapshot() {
  try {
    await fetch(`${process.env.SUPABASE_URL}/functions/v1/publish-snapshot`, {
      method: "POST",
      headers: { "x-cron-secret": process.env.CRON_SECRET ?? "" },
    });
  } catch { /* ignore */ }
}

function refresh(id?: string) {
  revalidatePath("/admin/stocks");
  revalidatePath("/admin");
  if (id) revalidatePath(`/admin/stocks/${id}`);
}

const numOrNull = (v: FormDataEntryValue | null) => {
  const n = Number(v);
  return v === null || v === "" || !Number.isFinite(n) ? null : n;
};
const strOrNull = (v: FormDataEntryValue | null) => {
  const s = String(v ?? "").trim();
  return s === "" ? null : s;
};

const SEGMENTS = ["MIM", "AIM", "GEMS"];
const DIV_KINDS = ["interim", "final", "special"];

// Create a listed company. Ticker is the join key the price lane maps on, so it
// is uppercased and required.
export async function addStock(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const ticker = String(formData.get("ticker") ?? "").trim().toUpperCase();
  if (!name || !ticker) return;

  const id = slugify(name);
  if (!id) return;

  const segRaw = strOrNull(formData.get("segment"));
  await supabaseAdmin().from("stocks").insert({
    id,
    ticker,
    name,
    sector: strOrNull(formData.get("sector")),
    segment: segRaw && SEGMENTS.includes(segRaw) ? segRaw : "MIM",
    active: true,
  });
  await republishSnapshot();
  refresh(id);
}

// Full profile edit. Section-scoped: touches ONLY the fields this form carries.
// Dividends and prices are owned by their own writers and never ride here.
export async function updateStock(formData: FormData) {
  const id = String(formData.get("id"));
  if (!id) return;

  const segRaw = strOrNull(formData.get("segment"));
  const sharesRaw = numOrNull(formData.get("shares_outstanding"));

  await supabaseAdmin().from("stocks").update({
    name: String(formData.get("name")),
    ticker: String(formData.get("ticker") ?? "").trim().toUpperCase(),
    sector: strOrNull(formData.get("sector")),
    segment: segRaw && SEGMENTS.includes(segRaw) ? segRaw : null,
    isin: strOrNull(formData.get("isin")),
    about: strOrNull(formData.get("about")),
    logo_url: strOrNull(formData.get("logo_url")),
    brand_color: strOrNull(formData.get("brand_color")),
    website: strOrNull(formData.get("website")),
    ir_url: strOrNull(formData.get("ir_url")),
    listed_on: strOrNull(formData.get("listed_on")),
    // bigint column, so no stray decimals
    shares_outstanding: sharesRaw == null ? null : Math.round(sharesRaw),
  }).eq("id", id);

  await republishSnapshot();
  refresh(id);
}

export async function toggleStockActive(formData: FormData) {
  const id = String(formData.get("id"));
  const value = formData.get("value") === "true";
  if (!id) return;
  await supabaseAdmin().from("stocks").update({ active: value }).eq("id", id);
  await republishSnapshot(); // inactive stocks drop out of the snapshot
  refresh(id);
}

export async function deleteStock(formData: FormData) {
  const id = String(formData.get("id"));
  if (!id) return;
  // dividends and prices cascade (0047)
  await supabaseAdmin().from("stocks").delete().eq("id", id);
  await republishSnapshot();
  refresh();
}

// ── Dividends ───────────────────────────────────────────────────────────────
// Public data (company announcements / annual reports). Not licence gated, so
// this is the lane that makes a stock page useful with no price feed at all.
// Upserts on (stock_id, financial_year, kind), so re-entering a year corrects
// it rather than duplicating.
export async function saveDividend(formData: FormData) {
  const stock_id = String(formData.get("stock_id"));
  const fy = numOrNull(formData.get("financial_year"));
  const dps = numOrNull(formData.get("dps_kes"));
  const kindRaw = String(formData.get("kind") ?? "final");
  if (!stock_id || fy == null || dps == null || dps <= 0) return;

  const kind = DIV_KINDS.includes(kindRaw) ? kindRaw : "final";

  await supabaseAdmin().from("stock_dividends").upsert({
    stock_id,
    financial_year: Math.round(fy),
    kind,
    dps_kes: dps,
    declared_on: strOrNull(formData.get("declared_on")),
    book_closure: strOrNull(formData.get("book_closure")),
    payment_date: strOrNull(formData.get("payment_date")),
    source_url: strOrNull(formData.get("source_url")),
  }, { onConflict: "stock_id,financial_year,kind" });

  await republishSnapshot();
  refresh(stock_id);
}

export async function deleteDividend(formData: FormData) {
  const id = String(formData.get("id"));
  const stock_id = String(formData.get("stock_id"));
  if (!id) return;
  await supabaseAdmin().from("stock_dividends").delete().eq("id", id);
  await republishSnapshot();
  refresh(stock_id);
}
