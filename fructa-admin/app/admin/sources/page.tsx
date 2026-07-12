import { supabaseAdmin } from "@/lib/supabase/server";
import { SourcesClient, type Src } from "./SourcesClient";

export const dynamic = "force-dynamic";

const SPARK_DAYS = 180;

export default async function SourcesPage() {
  const db = supabaseAdmin();

  const since = new Date();
  since.setDate(since.getDate() - SPARK_DAYS);

  const [fundsRes, histRes] = await Promise.all([
    db
      .from("funds")
      .select("id,name,manager,category,current_rate,updated_at,status,source_type,rate_source_url,site_url")
      .neq("status", "hidden"),
    // the lane a rate arrived through, and the shape of where it has been
    db
      .from("rate_history")
      .select("fund_id,rate,as_of,source")
      .gte("as_of", since.toISOString().slice(0, 10))
      .order("as_of", { ascending: true }),
  ]);

  const funds = (fundsRes.data ?? []) as Omit<Src, "spark" | "lane" | "lastSource">[];
  const hist = (histRes.data ?? []) as { fund_id: string; rate: number | null; as_of: string; source: string | null }[];

  const byFund = new Map<string, { rate: number; source: string | null }[]>();
  for (const h of hist) {
    if (h.rate == null) continue;
    const list = byFund.get(h.fund_id) ?? [];
    list.push({ rate: h.rate, source: h.source });
    byFund.set(h.fund_id, list);
  }

  const rows: Src[] = funds.map((f) => {
    const points = byFund.get(f.id) ?? [];
    const last = points[points.length - 1];
    const source = last?.source ?? null;
    // rate_history.source is the truth about how a number arrived. source_type
    // is only the operator's intent, so it is the fallback, not the answer.
    const lane: Src["lane"] =
      source === "manual"
        ? "manual"
        : source === "import"
          ? "imported"
          : source === "consensus"
            ? "consensus"
            : source
              ? "scraped"
              : f.source_type === "manual"
                ? "manual"
                : "scraped";

    return {
      ...f,
      lane,
      lastSource: source,
      spark: points.slice(-24).map((p) => p.rate),
    };
  });

  return (
    <div className="mx-auto max-w-6xl">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold tracking-tight">Sources</h1>
        <p className="mt-1 max-w-[72ch] text-sm text-mute">
          Every rate in Fructa, and where it came from. Scraped rates look after themselves. The ones
          in the queue need you.
        </p>
      </header>
      <SourcesClient rows={rows} />
    </div>
  );
}
