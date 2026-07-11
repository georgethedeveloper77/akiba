import type { ReactNode } from "react";
import { supabaseAdmin } from "@/lib/supabase/server";
import {
  createInsurer, updateInsurer, deleteInsurer,
  createInsuranceType, updateInsuranceType, deleteInsuranceType,
} from "./actions";

export const dynamic = "force-dynamic";

type InsClass = { code: string; label: string };
type InsSignal = { tag: string; label: string; text: string };
type TravelRegions = { ea?: number; af?: number; ww?: number; sch?: number };

type Insurer = {
  id: string;
  name: string;
  company_id: string | null;
  currency: string;
  motor_rate: number | null;
  min_premium: number | null;
  excess_pct: number | null;
  excess_min: number | null;
  claims_days: number | null;
  rating: number | null;
  benefits: string[] | null;
  logo_domain: string | null;
  settle_pct: number | null;
  licensed_since: number | null;
  phone: string | null;
  whatsapp: string | null;
  email: string | null;
  paybill: string | null;
  website: string | null;
  brand_color: string | null;
  classes: InsClass[] | null;
  signals: InsSignal[] | null;
  travel_regions: TravelRegions | null;
  travel_cover: string | null;
};
type Company = { id: string; name: string };
type InsType = { key: string; label: string; icon: string | null; status: string; ord: number; sub: string | null; active: boolean };

const ICONS = ["motor", "travel", "life", "medical", "home", "business", "marine"];

const INSURER_COLS =
  "id,name,company_id,currency,motor_rate,min_premium,excess_pct,excess_min,claims_days,rating,benefits,logo_domain," +
  "settle_pct,licensed_since,phone,whatsapp,email,paybill,website,brand_color,classes,signals,travel_regions,travel_cover";

export default async function InsurersPage() {
  const db = supabaseAdmin();
  const [{ data: insurers, error }, { data: companies }, { data: types }] =
    await Promise.all([
      db.from("funds").select(INSURER_COLS).eq("kind", "insurance").order("name"),
      db.from("companies").select("id,name").order("name"),
      db.from("insurance_types").select("key,label,icon,status,ord,sub,active").order("ord"),
    ]);

  const rows = (insurers ?? []) as Insurer[];
  const cos = (companies ?? []) as Company[];
  const tps = (types ?? []) as InsType[];

  return (
    <div className="mx-auto max-w-4xl">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold tracking-tight">Insurers</h1>
        <p className="mt-1 text-sm text-mute">
          {rows.length} products. Motor uses a % of vehicle value; travel is region-priced per traveller. Edits publish to the app.
        </p>
      </header>

      {/* insurance types (Insure home grid) */}
      <section className="mb-8 rounded-xl border border-line bg-panel p-4">
        <div className="mb-3">
          <h2 className="text-sm font-semibold tracking-tight">Insurance types</h2>
          <p className="mt-0.5 text-xs text-mute">
            Cards on the Insure home. Motor and Travel have live comparison flows; any other type shows as coming soon until its pricing lands.
          </p>
        </div>

        <form action={createInsuranceType} className="mb-4 flex flex-wrap items-end gap-2">
          <F label="Label" name="label" placeholder="Medical" required w="w-40" />
          <F label="Key (optional)" name="key" placeholder="medical" w="w-32" />
          <label className="flex flex-col gap-1">
            <span className="text-[11px] uppercase tracking-wider text-faint">Icon</span>
            <select name="icon" defaultValue="" className="rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none focus:border-gold/60">
              <option value="">shield (default)</option>
              {ICONS.map((n) => <option key={n} value={n}>{n}</option>)}
            </select>
          </label>
          <label className="flex flex-col gap-1">
            <span className="text-[11px] uppercase tracking-wider text-faint">Status</span>
            <select name="status" defaultValue="soon" className="rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none focus:border-gold/60">
              <option value="soon">soon</option><option value="live">live</option>
            </select>
          </label>
          <F label="Order" name="ord" placeholder="2" w="w-20" />
          <button className="rounded-md border border-gold/50 bg-gold/10 px-4 py-1.5 text-sm font-medium text-gold hover:bg-gold/20">Add type</button>
        </form>

        <div className="space-y-2">
          {tps.map((tp) => (
            <form key={tp.key} action={updateInsuranceType} className="flex flex-wrap items-end gap-2 rounded-lg border border-line bg-panel2 p-3">
              <input type="hidden" name="key" value={tp.key} />
              <F label="Label" name="label" defaultVal={tp.label} w="w-36" />
              <label className="flex flex-col gap-1">
                <span className="text-[11px] uppercase tracking-wider text-faint">Icon</span>
                <select name="icon" defaultValue={tp.icon ?? ""} className="rounded-md border border-line bg-panel px-2 py-1.5 text-xs text-ink outline-none focus:border-gold/60">
                  <option value="">shield</option>
                  {ICONS.map((n) => <option key={n} value={n}>{n}</option>)}
                </select>
              </label>
              <label className="flex flex-col gap-1">
                <span className="text-[11px] uppercase tracking-wider text-faint">Status</span>
                <select name="status" defaultValue={tp.status} className="rounded-md border border-line bg-panel px-2 py-1.5 text-xs text-ink outline-none focus:border-gold/60">
                  <option value="soon">soon</option><option value="live">live</option>
                </select>
              </label>
              <F label="Order" name="ord" defaultVal={String(tp.ord)} w="w-16" />
              <F label="Subtitle" name="sub" defaultVal={tp.sub ?? ""} placeholder="optional" w="w-44" />
              <label className="flex items-center gap-1.5 pb-1.5 text-xs text-mute">
                <input type="checkbox" name="active" defaultChecked={tp.active} className="accent-gold" /> active
              </label>
              <span className="pb-1.5 text-[11px] text-faint">{tp.key}</span>
              <div className="ml-auto flex items-center gap-2">
                <button className="rounded-md border border-gold/50 bg-gold/10 px-3 py-1.5 text-xs font-medium text-gold hover:bg-gold/20">Save</button>
                <button formAction={deleteInsuranceType} className="rounded-md border border-bad/40 px-2.5 py-1.5 text-xs text-bad hover:bg-bad/10">Delete</button>
              </div>
            </form>
          ))}
          {tps.length === 0 && (
            <p className="rounded-lg border border-line bg-panel2 px-4 py-6 text-center text-xs text-mute">No types yet. Motor and Travel are seeded by migration 0041.</p>
          )}
        </div>
      </section>

      {/* create */}
      <form action={createInsurer} className="mb-6 flex flex-wrap items-end gap-2 rounded-xl border border-line bg-panel p-4">
        <F label="Name" name="name" placeholder="CIC General" required w="w-52" />
        <label className="flex flex-col gap-1">
          <span className="text-[11px] uppercase tracking-wider text-faint">Company</span>
          <select name="company_id" defaultValue="" className="rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none focus:border-gold/60">
            <option value="">none</option>
            {cos.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-[11px] uppercase tracking-wider text-faint">Currency</span>
          <select name="currency" defaultValue="KES" className="rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none focus:border-gold/60">
            <option>KES</option><option>USD</option>
          </select>
        </label>
        <button className="rounded-md border border-gold/50 bg-gold/10 px-4 py-1.5 text-sm font-medium text-gold hover:bg-gold/20">Add insurer</button>
      </form>

      {error && <p className="mb-4 rounded-lg border border-bad/40 bg-bad/10 px-4 py-3 text-sm text-bad">{error.message}</p>}

      <div className="space-y-4">
        {rows.map((i) => (
          <form key={i.id} action={updateInsurer} className="rounded-xl border border-line bg-panel p-4">
            <input type="hidden" name="id" value={i.id} />
            <div className="mb-3 flex items-center gap-2">
              <input name="name" defaultValue={i.name} className="w-64 rounded-md border border-line bg-panel2 px-2.5 py-1 text-sm font-medium text-ink outline-none focus:border-gold/60" />
              <select name="company_id" defaultValue={i.company_id ?? ""} className="rounded-md border border-line bg-panel2 px-2 py-1 text-xs text-mute outline-none focus:border-gold/60">
                <option value="">no company</option>
                {cos.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
              <select name="currency" defaultValue={i.currency} className="rounded-md border border-line bg-panel2 px-2 py-1 text-xs text-mute">
                <option>KES</option><option>USD</option>
              </select>
              <span className="ml-auto text-[11px] text-faint">{i.id}</span>
            </div>

            <Legend>Motor</Legend>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
              <Num label="Motor rate %" name="motor_rate" v={i.motor_rate} />
              <Num label="Min premium" name="min_premium" v={i.min_premium} />
              <Num label="Excess %" name="excess_pct" v={i.excess_pct} />
              <Num label="Excess min" name="excess_min" v={i.excess_min} />
              <Num label="Claims (days)" name="claims_days" v={i.claims_days} />
              <Num label="Rating (1-5)" name="rating" v={i.rating} />
            </div>

            <label className="mt-3 flex flex-col gap-1">
              <span className="text-[11px] uppercase tracking-wider text-faint">Benefits (comma-separated)</span>
              <input name="benefits" defaultValue={(i.benefits ?? []).join(", ")} placeholder="Courtesy car 14d, Windscreen 75k, Roadside" className="rounded-md border border-line bg-panel2 px-2.5 py-1 text-sm text-ink outline-none focus:border-gold/60" />
            </label>

            <Legend>Trust &amp; identity</Legend>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <Num label="Claims paid % (IRA)" name="settle_pct" v={i.settle_pct} />
              <Num label="Licensed since" name="licensed_since" v={i.licensed_since} />
              <Txt label="Brand colour (hex)" name="brand_color" v={i.brand_color} placeholder="#4E8FE8" />
              <Txt label="Logo domain" name="logo_domain" v={i.logo_domain} placeholder="cic.co.ke" />
            </div>

            <Legend>Reach them</Legend>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
              <Txt label="Phone" name="phone" v={i.phone} placeholder="+254 703 099 000" />
              <Txt label="WhatsApp" name="whatsapp" v={i.whatsapp} placeholder="+254 703 099 120" />
              <Txt label="Email" name="email" v={i.email} placeholder="callc@cic.co.ke" />
              <Txt label="Paybill" name="paybill" v={i.paybill} placeholder="600118" />
              <Txt label="Website" name="website" v={i.website} placeholder="cic.co.ke" />
            </div>

            <label className="mt-3 flex flex-col gap-1">
              <span className="text-[11px] uppercase tracking-wider text-faint">Licensed classes (one per line: code, label)</span>
              <textarea
                name="classes"
                rows={3}
                defaultValue={(i.classes ?? []).map((c) => `${c.code}, ${c.label}`).join("\n")}
                placeholder={"07, Motor Priv\n08, Motor Comm\n09, Personal Acc"}
                className="rounded-md border border-line bg-panel2 px-2.5 py-2 font-mono text-xs text-ink outline-none focus:border-gold/60"
              />
            </label>

            <label className="mt-3 flex flex-col gap-1">
              <span className="text-[11px] uppercase tracking-wider text-faint">Signals (one per line: TAG | text, TAG in STRENGTH/WATCH/NOTE)</span>
              <textarea
                name="signals"
                rows={3}
                defaultValue={(i.signals ?? []).map((s) => `${s.tag} | ${s.text}`).join("\n")}
                placeholder={"STRENGTH | Fastest claims settlement in the set plus a courtesy car.\nWATCH | 3% excess is the trade-off."}
                className="rounded-md border border-line bg-panel2 px-2.5 py-2 font-mono text-xs text-ink outline-none focus:border-gold/60"
              />
            </label>

            <Legend>Travel (region base price per traveller, standard trip)</Legend>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <Num label="East Africa" name="travel_ea" v={i.travel_regions?.ea ?? null} />
              <Num label="Africa" name="travel_af" v={i.travel_regions?.af ?? null} />
              <Num label="Worldwide" name="travel_ww" v={i.travel_regions?.ww ?? null} />
              <Num label="Schengen" name="travel_sch" v={i.travel_regions?.sch ?? null} />
            </div>
            <label className="mt-3 flex flex-col gap-1">
              <span className="text-[11px] uppercase tracking-wider text-faint">Travel cover headline</span>
              <input name="travel_cover" defaultValue={i.travel_cover ?? ""} placeholder="KES 5M med" className="rounded-md border border-line bg-panel2 px-2.5 py-1 text-sm text-ink outline-none focus:border-gold/60" />
            </label>

            <div className="mt-4 flex items-center gap-3">
              <button className="rounded-md border border-gold/50 bg-gold/10 px-4 py-1.5 text-sm font-medium text-gold hover:bg-gold/20">Save</button>
              <button
                formAction={deleteInsurer}
                className="rounded-md border border-bad/40 px-3 py-1.5 text-xs text-bad hover:bg-bad/10"
              >
                Delete
              </button>
            </div>
          </form>
        ))}
        {rows.length === 0 && (
          <p className="rounded-xl border border-line bg-panel px-4 py-10 text-center text-sm text-mute">No insurers yet.</p>
        )}
      </div>
    </div>
  );
}

function Legend({ children }: { children: ReactNode }) {
  return <div className="mt-4 mb-2 text-[11px] font-semibold uppercase tracking-wider text-faint">{children}</div>;
}

function F({ label, name, placeholder, required, w, defaultVal }: { label: string; name: string; placeholder?: string; required?: boolean; w: string; defaultVal?: string }) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[11px] uppercase tracking-wider text-faint">{label}</span>
      <input name={name} defaultValue={defaultVal} placeholder={placeholder} required={required} className={`${w} rounded-md border border-line bg-panel2 px-3 py-1.5 text-sm text-ink outline-none focus:border-gold/60`} />
    </label>
  );
}

function Num({ label, name, v }: { label: string; name: string; v: number | null }) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[11px] uppercase tracking-wider text-faint">{label}</span>
      <input name={name} defaultValue={v ?? ""} inputMode="decimal" className="rounded-md border border-line bg-panel2 px-2.5 py-1 text-sm text-ink outline-none focus:border-gold/60" />
    </label>
  );
}

function Txt({ label, name, v, placeholder }: { label: string; name: string; v: string | null; placeholder?: string }) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[11px] uppercase tracking-wider text-faint">{label}</span>
      <input name={name} defaultValue={v ?? ""} placeholder={placeholder} className="rounded-md border border-line bg-panel2 px-2.5 py-1 text-sm text-ink outline-none focus:border-gold/60" />
    </label>
  );
}
