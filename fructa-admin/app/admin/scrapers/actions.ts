"use server";

import { revalidatePath } from "next/cache";

export type RunResult = { ok: boolean; message: string };

// Edge functions gate on x-cron-secret. These run synchronously (the aggregator
// writes its scraper_runs row before responding), so a revalidate shows the
// result immediately.
//
// This used to swallow every failure. A bad CRON_SECRET, a function that was
// never deployed, a 500 from inside the scraper: all of them looked exactly
// like success, because the catch was empty and nothing was returned. The page
// then re-rendered showing the same stale run and no error, which is how
// "prices are on and the table is empty" survived unexplained. Now the caller
// gets the truth.
async function callFn(name: string, body?: unknown): Promise<RunResult> {
  let result: RunResult;
  try {
    const res = await fetch(`${process.env.SUPABASE_URL}/functions/v1/${name}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-cron-secret": process.env.CRON_SECRET ?? "",
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    if (res.ok) {
      result = { ok: true, message: "Done" };
    } else {
      // 401 here is almost always CRON_SECRET drift between Firebase and
      // Supabase, and 404 is a function that was never deployed. Both are worth
      // saying out loud rather than reporting as a generic failure.
      const body = (await res.text()).slice(0, 300);
      const hint =
        res.status === 401
          ? "CRON_SECRET does not match the one in Supabase secrets."
          : res.status === 404
          ? `The ${name} function is not deployed.`
          : body || res.statusText;
      result = { ok: false, message: `HTTP ${res.status}. ${hint}` };
    }
  } catch (e) {
    result = { ok: false, message: e instanceof Error ? e.message : "Network error" };
  }

  revalidatePath("/admin/scrapers");
  revalidatePath("/admin");
  return result;
}

// Tag the run as manual so the health check (which only counts scheduled runs)
// doesn't treat a hand-triggered run as the automatic one.
export async function runAggregator(): Promise<RunResult> {
  return callFn("scrape-aggregator", { trigger: "manual" });
}

// The NSE end-of-day price scraper. It had NO trigger anywhere in admin: it was
// deployed, its cron was registered, and the only way to find out whether it had
// ever run was to query stock_prices by hand. That is why this page existed at
// all for the MMF lane, and the price lane never got it.
export async function runNseScraper(): Promise<RunResult> {
  return callFn("scrape-nse", { trigger: "manual" });
}

export async function rebuildSnapshot(): Promise<RunResult> {
  const r = await callFn("publish-snapshot");
  revalidatePath("/admin/stocks");
  revalidatePath("/admin/funds");
  return r;
}
