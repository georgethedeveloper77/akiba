import { adminClient } from "../_shared/supabase.ts";
import { publishSnapshot } from "../_shared/snapshot.ts";

// Thin HTTP entry point around publishSnapshot. Called by the CBK scraper
// after it writes, and runnable manually. The daily aggregator publishes
// inline, so it doesn't need to call this.
Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    return new Response("unauthorized", { status: 401 });
  }
  try {
    const result = await publishSnapshot(adminClient());
    return Response.json({ ok: true, ...result });
  } catch (e) {
    return Response.json(
      { ok: false, error: e instanceof Error ? e.message : String(e) },
      { status: 500 },
    );
  }
});
