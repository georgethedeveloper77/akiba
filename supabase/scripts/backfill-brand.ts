// backfill-brand.ts
// Resolve each company's brand colour + logo from its domain via Brandfetch,
// and write them to companies.brand_color / logo_url. One weekend job.
// Idempotent; skips companies that already have a brand_color unless --force.
//
// Brandfetch returns colour + logo directly, so no image processing is needed
// in Deno. Get a key at https://brandfetch.com (free tier is fine).
//
// Usage:
//   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... BRANDFETCH_API_KEY=... \
//     deno run --allow-env --allow-net backfill-brand.ts [--force]
//
// Without BRANDFETCH_API_KEY it no-ops (prints a hint). After running,
// re-publish the snapshot so the app picks up the new colours.

import { createClient } from "jsr:@supabase/supabase-js@2";

const FORCE = Deno.args.includes("--force");

function domainOf(website: string | null, fallback: string | null): string | null {
  const raw = website ?? (fallback ? `https://${fallback}` : null);
  if (!raw) return null;
  try {
    return new URL(raw).hostname.replace(/^www\./, "");
  } catch {
    return website?.replace(/^www\./, "") ?? fallback ?? null;
  }
}

interface Brand {
  colors?: { hex: string; type?: string }[];
  logos?: { type?: string; formats?: { src?: string; format?: string }[] }[];
}

function pickColor(b: Brand): string | null {
  const cs = b.colors ?? [];
  return (
    cs.find((c) => c.type === "accent")?.hex ??
    cs.find((c) => c.type === "brand")?.hex ??
    cs.find((c) => c.type === "primary")?.hex ??
    cs[0]?.hex ??
    null
  );
}

function pickLogo(b: Brand): string | null {
  const ls = b.logos ?? [];
  const prefer = ls.find((l) => l.type === "icon") ?? ls.find((l) => l.type === "logo") ?? ls[0];
  const fmts = prefer?.formats ?? [];
  return (
    fmts.find((f) => f.format === "png")?.src ??
    fmts.find((f) => f.format === "svg")?.src ??
    fmts[0]?.src ??
    null
  );
}

async function main() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const bf = Deno.env.get("BRANDFETCH_API_KEY");
  if (!url || !key) {
    console.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required");
    Deno.exit(1);
  }
  if (!bf) {
    console.error("BRANDFETCH_API_KEY not set — nothing to do. Get one at brandfetch.com.");
    Deno.exit(0);
  }
  const db = createClient(url, key, { auth: { persistSession: false } });

  const { data: companies } = await db
    .from("companies")
    .select("id,name,website,brand_color");
  const { data: funds } = await db.from("funds").select("company_id,logo_domain");

  // A company's fallback domain: any of its funds' logo_domain.
  const fallback = new Map<string, string>();
  for (const f of funds ?? []) {
    const r = f as { company_id: string | null; logo_domain: string | null };
    if (r.company_id && r.logo_domain && !fallback.has(r.company_id)) {
      fallback.set(r.company_id, r.logo_domain);
    }
  }

  let updated = 0;
  for (const co of companies ?? []) {
    const c = co as { id: string; name: string; website: string | null; brand_color: string | null };
    if (c.brand_color && !FORCE) continue;
    const domain = domainOf(c.website, fallback.get(c.id) ?? null);
    if (!domain) {
      console.log(`  skip ${c.id}: no domain`);
      continue;
    }
    try {
      const res = await fetch(`https://api.brandfetch.io/v2/brands/${domain}`, {
        headers: { Authorization: `Bearer ${bf}` },
      });
      if (!res.ok) {
        console.log(`  ${c.id} (${domain}): HTTP ${res.status}`);
        continue;
      }
      const brand = (await res.json()) as Brand;
      const brand_color = pickColor(brand);
      const logo_url = pickLogo(brand);
      if (!brand_color && !logo_url) {
        console.log(`  ${c.id} (${domain}): no colour/logo`);
        continue;
      }
      await db
        .from("companies")
        .update({
          ...(brand_color ? { brand_color } : {}),
          ...(logo_url ? { logo_url } : {}),
        })
        .eq("id", c.id);
      updated++;
      console.log(`  ${c.id}: ${brand_color ?? "—"} ${logo_url ? "+logo" : ""}`);
    } catch (e) {
      console.log(`  ${c.id} (${domain}): ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  console.log(`done: ${updated} companies updated. Re-run publish-snapshot to ship.`);
}

if (import.meta.main) await main();
