import Link from "next/link";
import { notFound } from "next/navigation";
import { supabaseAdmin } from "@/lib/supabase/server";
import { addFund, setRate, toggleRetail } from "../../funds/actions";
import { updateCustody } from "../actions";
import { IconCheck } from "../../_icons";

export const dynamic = "force-dynamic";

type Fund = {
  id: string; name: string; fund_type: string | null; category: string | null;
  currency: string; current_rate: number | null; status: string;
  verified: boolean; featured: boolean; retail: boolean; aum_kes: number | null;
};

const FT_ORDER = ["mmf", "fixed_income", "equity", "balanced", "special"];
const FT_LABEL: Record<string, string> = {
  mmf: "Money Market", fixed_income: "Fixed Income", equity: "Equity",
  balanced: "Balanced", special: "Special",
};
const LEGACY_LABEL: Record<string, string> = {
  tbill: "T-Bills", bond: "Bonds", sacco: "SACCO", stock: "NSE", other: "Other",
};
const TYPE_LABEL: Record<string, string> = {
  fund_manager: "Fund manager", insurer: "Insurer", sacco: "SACCO", government: "Government",
};

function kesShort(n: number | null): string {
  if (n == null) return "—";
  if (n >= 1e9) return `KES ${(n / 1e9).toFixed(1)}B`;
  if (n >= 1e6) return `KES ${(n / 1e6).toFixed(0)}M`;
  return `KES ${Math.round(n).toLocaleString()}`;
}

export default async function CompanyDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const db = supabaseAdmin();

  const { data: c } = await db.from("companies")
    .select("id,name,type,brand_color,logo_url,website,verified,manager,aum_kes,market_share,rank,aum_as_of,trustee,custodian,auditor")
    .eq("id", id).maybeSingle();
  if (!c) notFound();

  const { data: fundsData } = await db.from("funds")
    .select("id,name,fund_type,category,currency,current_rate,status,verified,featured,retail,aum_kes")
    .eq("company_id", id).order("name");
  const funds = (fundsData ?? []) as Fund[];

  const groups = new Map<string, Fund[]>();
  for (const f of funds) {
    const k = f.fund_type ?? f.category ?? "other";
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k)!.push(f);
  }
  const orderedKeys = [
    ...FT_ORDER.filter((k) => groups.has(k)),
    ...[...groups.keys()].filter((k) => !FT_ORDER.includes(k)),
  ];

  const color = c.brand_color ?? "#8A92A3";

  return (
    <div className="mx-auto max-w-5xl">
      <Link href="/admin/companies" className="text-sm text-mute hover:text-gold">← Companies</Link>

      <header className="mt-3 flex items-start gap-4 rounded-xl border border-line bg-panel p-5">
        <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full border border-line bg-white">
          {c.logo_url
            ? <img src={c.logo_url} alt="" className="h-14 w-14 rounded-full object-contain p-1" />
            : <span className="text-lg font-semibold" style={{ color }}>{(c.name || "?").slice(0, 1).toUpperCase()}</span>}
        </div>

        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <h1 className="text-xl font-semibold tracking-tight text-ink">{c.name}</h1>
            {c.verified && (
              <span className="inline-flex h-5 w-5 items-center justify-center rounded-md border border-gold/50 bg-gold/10 text-gold" title="Verified">
                <IconCheck size={12} />
              </span>
            )}
          </div>
          <div className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-faint">
            <span>{TYPE_LABEL[c.type] ?? c.type}</span>
            <span>·</span>
            <span>{c.id}</span>
            {c.website && (<><span>·</span>
              <a href={c.website} target="_blank" rel="noreferrer" className="text-mute hover:text-gold">
                {c.website.replace(/^https?:\/\//, "")}
              </a></>)}
          </div>
          {c.manager && c.manager !== c.name && (
            <div className="mt-1 text-xs text-mute">Managed by {c.manager}</div>
          )}
        </div>

        <div className="grid grid-cols-2 gap-x-6 gap-y-2 text-right">
          <Stat label="AUM" value={kesShort(c.aum_kes)} />
          <Stat label="Share" value={c.market_share != null ? `${c.market_share}%` : "—"} />
          <Stat label="Rank" value={c.rank != null ? `#${c.rank}` : "—"} />
          <Stat label="Funds" value={String(funds.length)} />
        </div>
      </header>

      {/* governance / custody — manager-level trust signals for the app detail page */}
      <form action={updateCustody} className="mt-4 rounded-xl border border-line bg-panel p-4">
        <input type="hidden" name="id" value={c.id} />
        <div className="mb-3 flex items-start justify-between gap-4">
          <div>
            <h2 className="text-sm font-medium text-ink">Governance &amp; custody</h2>
            <p className="mt-0.5 text-xs text-faint">
              Trustee · custodian · auditor. Surfaced on the app fund detail as trust signals, shared across this manager&rsquo;s funds.
            </p>
          </div>
          <button className="shrink-0 rounded-md border border-gold/50 bg-gold/10 px-4 py-1.5 text-sm font-medium text-gold hover:bg-gold/20">Save</button>
        </div>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <label className="flex flex-col gap-1">
            <span className="text-[10px] uppercase tracking-wider text-faint">Trustee</span>
            <input name="trustee" defaultValue={c.trustee ?? ""} placeholder="KCB Bank"
              className="rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none placeholder:text-faint focus:border-gold/60" />
          </label>
          <label className="flex flex-col gap-1">
            <span className="text-[10px] uppercase tracking-wider text-faint">Custodian</span>
            <input name="custodian" defaultValue={c.custodian ?? ""} placeholder="Stanbic Bank"
              className="rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none placeholder:text-faint focus:border-gold/60" />
          </label>
          <label className="flex flex-col gap-1">
            <span className="text-[10px] uppercase tracking-wider text-faint">Auditor</span>
            <input name="auditor" defaultValue={c.auditor ?? ""} placeholder="Grant Thornton"
              className="rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none placeholder:text-faint focus:border-gold/60" />
          </label>
        </div>
      </form>

      {/* inline add fund, scoped to this company */}
      <form action={addFund} className="mt-4 flex flex-wrap items-center gap-2 rounded-xl border border-line bg-panel p-3">
        <input type="hidden" name="company_id" value={c.id} />
        <input name="name" required placeholder="New fund name"
          className="min-w-[200px] flex-1 rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none placeholder:text-faint focus:border-gold/60" />
        <select name="fund_type" defaultValue="mmf"
          className="rounded-md border border-line bg-panel2 px-2.5 py-1.5 text-sm text-mute outline-none focus:border-gold/60">
          {FT_ORDER.map((k) => <option key={k} value={k}>{FT_LABEL[k]}</option>)}
        </select>
        <select name="currency" defaultValue="KES"
          className="rounded-md border border-line bg-panel2 px-2.5 py-1.5 text-sm text-mute outline-none focus:border-gold/60">
          <option value="KES">KES</option><option value="USD">USD</option>
        </select>
        <input name="min_invest" type="number" min="0" placeholder="Min"
          className="w-20 rounded-md border border-line bg-panel2 px-2.5 py-1.5 text-sm text-mute outline-none placeholder:text-faint focus:border-gold/60" />
        <input name="mgmt_fee" type="number" step="0.01" min="0" placeholder="Fee %"
          className="w-20 rounded-md border border-line bg-panel2 px-2.5 py-1.5 text-sm text-mute outline-none placeholder:text-faint focus:border-gold/60" />
        <button className="rounded-md border border-gold/50 bg-gold/10 px-4 py-1.5 text-sm font-medium text-gold hover:bg-gold/20">Add fund</button>
      </form>

      <div className="mt-4 space-y-5">
        {orderedKeys.map((k) => {
          const list = groups.get(k)!;
          return (
            <section key={k} className="overflow-hidden rounded-xl border border-line bg-panel">
              <div className="flex items-center justify-between border-b border-line px-4 py-2.5">
                <h2 className="text-sm font-medium text-ink">{FT_LABEL[k] ?? LEGACY_LABEL[k] ?? k}</h2>
                <span className="text-xs text-faint">{list.length} {list.length === 1 ? "fund" : "funds"}</span>
              </div>
              <table className="w-full text-sm">
                <tbody>
                  {list.map((f) => (
                    <tr key={f.id} className="border-b border-line/60 last:border-0 hover:bg-panel2/30">
                      <td className="px-4 py-2.5">
                        <div className="font-medium text-ink">{f.name}</div>
                        <div className="text-xs text-faint">
                          {f.currency}{!f.retail ? " · dormant" : ""}{f.aum_kes ? ` · ${kesShort(f.aum_kes)}` : ""}
                        </div>
                      </td>
                      <td className="w-40 px-3 py-2.5">
                        <form action={setRate} className="flex items-center gap-1.5">
                          <input type="hidden" name="id" value={f.id} />
                          <input name="rate" type="number" step="0.01" min="0" max="30"
                            defaultValue={f.current_rate ?? ""} placeholder="—"
                            className="w-20 rounded-md border border-line bg-panel2 px-2 py-1 text-sm tnum text-ink outline-none placeholder:text-faint focus:border-gold/60" />
                          <button className="rounded-md border border-line px-2.5 py-1 text-xs text-mute hover:border-gold/60 hover:text-gold">Set</button>
                        </form>
                      </td>
                      <td className="w-20 px-3 py-2.5">
                        <span className={"text-xs " + (f.status === "live" ? "text-live" : f.status === "stale" ? "text-warn" : "text-faint")}>{f.status}</span>
                      </td>
                      <td className="w-44 px-3 py-2.5 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <form action={toggleRetail}>
                            <input type="hidden" name="id" value={f.id} />
                            <input type="hidden" name="value" value={(!f.retail).toString()} />
                            <button title="Show in the consumer app"
                              className={"rounded-md border px-2 py-1 text-xs " + (f.retail ? "border-gold/40 text-gold" : "border-line text-faint hover:text-mute")}>
                              {f.retail ? "In app" : "Off app"}
                            </button>
                          </form>
                          <Link href={`/admin/funds/${f.id}`} className="text-xs text-mute hover:text-gold">Edit</Link>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>
          );
        })}
        {funds.length === 0 && (
          <div className="rounded-xl border border-line bg-panel px-4 py-10 text-center text-sm text-mute">
            No funds yet. Add one above.
          </div>
        )}
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wider text-faint">{label}</div>
      <div className="tnum text-sm font-medium text-ink">{value}</div>
    </div>
  );
}
