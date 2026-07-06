// Sends one OneSignal push per changed fund, targeted by the per-fund tag so
// only users who follow that fund are notified. Called by the scrapers after
// a rate moves. Gated by x-cron-secret.

const APP_ID = Deno.env.get("ONESIGNAL_APP_ID");
const REST = Deno.env.get("ONESIGNAL_REST_KEY");

// Must match the app's Push.tagKey() exactly.
function tagKey(id: string): string {
  return "follow_" + id.replace(/[^a-zA-Z0-9]/g, "_");
}

interface Change {
  fundId: string;
  name?: string;
  oldRate: number;
  newRate: number;
}

Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    return new Response("unauthorized", { status: 401 });
  }
  if (!APP_ID || !REST) {
    return Response.json({ ok: false, error: "ONESIGNAL_APP_ID / ONESIGNAL_REST_KEY not set" }, { status: 500 });
  }

  const { changes } = (await req.json().catch(() => ({ changes: [] }))) as { changes: Change[] };
  let sent = 0;
  const errors: string[] = [];

  for (const c of changes ?? []) {
    const up = c.newRate > c.oldRate;
    try {
      const res = await fetch("https://onesignal.com/api/v1/notifications", {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": `Basic ${REST}` },
        body: JSON.stringify({
          app_id: APP_ID,
          filters: [{ field: "tag", key: tagKey(c.fundId), relation: "=", value: "true" }],
          headings: { en: c.name ?? "Rate update" },
          contents: {
            en: `${up ? "▲" : "▼"} Rate ${up ? "rose" : "fell"} to ${Number(c.newRate).toFixed(2)}% (was ${Number(c.oldRate).toFixed(2)}%)`,
          },
        }),
      });
      if (res.ok) sent++;
      else errors.push(`${c.fundId}: HTTP ${res.status}`);
    } catch (e) {
      errors.push(`${c.fundId}: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  return Response.json({ ok: errors.length === 0, sent, errors });
});
