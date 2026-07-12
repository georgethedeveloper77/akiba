"use server";

import { supabaseAdmin } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import { slugify } from "@/lib/publish";

async function republishSnapshot() {
  try {
    await fetch(`${process.env.SUPABASE_URL}/functions/v1/publish-snapshot`, {
      method: "POST",
      headers: { "x-cron-secret": process.env.CRON_SECRET ?? "" },
    });
  } catch { /* ignore */ }
}

function refresh() {
  revalidatePath("/admin/brokers");
  revalidatePath("/admin/stocks");
  revalidatePath("/admin");
}

const numOrNull = (v: FormDataEntryValue | null) => {
  const n = Number(v);
  return v === null || v === "" || !Number.isFinite(n) ? null : n;
};
const strOrNull = (v: FormDataEntryValue | null) => {
  const s = String(v ?? "").trim();
  return s === "" ? null : s;
};

// CMA-licensed stockbrokers. This is a directory, not an order path: Fructa
// routes the user out and never holds money or places a trade.
export async function addBroker(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  if (!name) return;
  const id = slugify(name);
  if (!id) return;

  await supabaseAdmin().from("brokers").insert({
    id,
    name,
    license_no: strOrNull(formData.get("license_no")),
    blurb: strOrNull(formData.get("blurb")),
    website: strOrNull(formData.get("website")),
    active: true,
  });
  await republishSnapshot();
  refresh();
}

export async function updateBroker(formData: FormData) {
  const id = String(formData.get("id"));
  if (!id) return;
  const ordRaw = numOrNull(formData.get("sort_order"));

  await supabaseAdmin().from("brokers").update({
    name: String(formData.get("name")),
    license_no: strOrNull(formData.get("license_no")),
    blurb: strOrNull(formData.get("blurb")),
    phone: strOrNull(formData.get("phone")),
    email: strOrNull(formData.get("email")),
    website: strOrNull(formData.get("website")),
    app_url: strOrNull(formData.get("app_url")),
    logo_url: strOrNull(formData.get("logo_url")),
    sort_order: ordRaw == null ? null : Math.round(ordRaw),
  }).eq("id", id);

  await republishSnapshot();
  refresh();
}

export async function toggleBrokerActive(formData: FormData) {
  const id = String(formData.get("id"));
  const value = formData.get("value") === "true";
  if (!id) return;
  await supabaseAdmin().from("brokers").update({ active: value }).eq("id", id);
  await republishSnapshot();
  refresh();
}

export async function deleteBroker(formData: FormData) {
  const id = String(formData.get("id"));
  if (!id) return;
  await supabaseAdmin().from("brokers").delete().eq("id", id);
  await republishSnapshot();
  refresh();
}
