import { supabaseAdmin } from "@/lib/supabase/server";
import { addBroker, updateBroker, toggleBrokerActive, deleteBroker } from "./actions";

export const dynamic = "force-dynamic";

type Broker = {
  id: string;
  name: string;
  license_no: string | null;
  blurb: string | null;
  phone: string | null;
  email: string | null;
  website: string | null;
  app_url: string | null;
  logo_url: string | null;
  active: boolean;
  sort_order: number | null;
};

export default async function BrokersPage() {
  const db = supabaseAdmin();
  const { data, error } = await db.from("brokers").select("*")
    .order("sort_order", { ascending: true, nullsFirst: false })
    .order("name");
  const rows = (data ?? []) as Broker[];

  const live = rows.filter((b) => b.active).length;
  const withApp = rows.filter((b) => b.app_url).length;

  const field = "w-full rounded-md border border-line bg-panel2 px-3 py-2 text-sm text-ink outline-none placeholder:text-faint focus:border-gold/60";
  const label = "mb-1 block text-[11px] uppercase tracking-wider text-faint";

  return (
    <div className="mx-auto max-w-5xl space-y-4">
      {error && (
        <p className="rounded-lg border border-bad/40 bg-bad/10 px-4 py-3 text-sm text-bad">{error.message}</p>
      )}

      <div className="rounded-xl border border-line bg-panel px-4 py-3">
        <div className="text-[11px] uppercase tracking-wider text-faint">Where to buy</div>
        <p className="mt-1 text-sm leading-relaxed text-mute">
          The broker list on every stock page. Fructa does not hold money and does not place trades, so this is a
          directory that routes the user out to a CMA-licensed firm. Verify each entry against the CMA licensee register
          before making it live.
        </p>
      </div>

      <div className="grid grid-cols-3 gap-3">
        {[
          { label: "Brokers", value: rows.length },
          { label: "Live", value: live },
          { label: "With app link", value: withApp },
        ].map((k) => (
          <div key={k.label} className="rounded-xl border border-line bg-panel px-4 py-3">
            <div className="text-[10px] uppercase tracking-wider text-faint">{k.label}</div>
            <div className="tnum mt-0.5 text-2xl font-semibold text-ink">{k.value}</div>
          </div>
        ))}
      </div>

      {/* Add */}
      <form action={addBroker} className="rounded-xl border border-line bg-panel p-5">
        <h2 className="mb-4 text-base font-semibold text-ink">Add broker</h2>
        <div className="grid gap-3 sm:grid-cols-4">
          <div>
            <label className={label}>Name</label>
            <input name="name" placeholder="Dyer and Blair" className={field} />
          </div>
          <div>
            <label className={label}>License no</label>
            <input name="license_no" className={field + " font-mono"} />
          </div>
          <div>
            <label className={label}>Website</label>
            <input name="website" className={field} />
          </div>
          <div className="flex items-end">
            <button className="w-full rounded-md border border-gold/50 bg-gold/10 px-4 py-2 text-sm font-medium text-gold hover:bg-gold/20">
              Add broker
            </button>
          </div>
          <div className="sm:col-span-4">
            <label className={label}>Blurb</label>
            <input name="blurb" placeholder="Licensed stockbroker, mobile app" className={field} />
          </div>
        </div>
      </form>

      {/* Edit each */}
      {rows.map((b) => (
        <div key={b.id} className="rounded-xl border border-line bg-panel p-5">
          <div className="mb-4 flex items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <h2 className="text-base font-semibold text-ink">{b.name}</h2>
              <span className={"text-xs " + (b.active ? "text-live" : "text-faint")}>{b.active ? "live" : "hidden"}</span>
            </div>
            <div className="flex items-center gap-2">
              <form action={toggleBrokerActive}>
                <input type="hidden" name="id" value={b.id} />
                <input type="hidden" name="value" value={(!b.active).toString()} />
                <button className="rounded-md border border-line px-2.5 py-1 text-xs text-mute hover:text-ink">
                  {b.active ? "Hide" : "Show"}
                </button>
              </form>
              <form action={deleteBroker}>
                <input type="hidden" name="id" value={b.id} />
                <button className="rounded-md border border-bad/40 px-2.5 py-1 text-xs text-bad hover:bg-bad/10">
                  Delete
                </button>
              </form>
            </div>
          </div>

          <form action={updateBroker} className="grid gap-3 sm:grid-cols-3">
            <input type="hidden" name="id" value={b.id} />
            <div>
              <label className={label}>Name</label>
              <input name="name" defaultValue={b.name} className={field} />
            </div>
            <div>
              <label className={label}>License no</label>
              <input name="license_no" defaultValue={b.license_no ?? ""} className={field + " font-mono"} />
            </div>
            <div>
              <label className={label}>Sort order</label>
              <input name="sort_order" inputMode="numeric" defaultValue={b.sort_order ?? ""} className={field + " tnum"} />
            </div>
            <div className="sm:col-span-3">
              <label className={label}>Blurb</label>
              <input name="blurb" defaultValue={b.blurb ?? ""} className={field} />
            </div>
            <div>
              <label className={label}>Phone</label>
              <input name="phone" defaultValue={b.phone ?? ""} className={field} />
            </div>
            <div>
              <label className={label}>Email</label>
              <input name="email" defaultValue={b.email ?? ""} className={field} />
            </div>
            <div>
              <label className={label}>Logo URL</label>
              <input name="logo_url" defaultValue={b.logo_url ?? ""} className={field} />
            </div>
            <div>
              <label className={label}>Website</label>
              <input name="website" defaultValue={b.website ?? ""} className={field} />
            </div>
            <div>
              <label className={label}>App or trade URL</label>
              <input name="app_url" defaultValue={b.app_url ?? ""} className={field} />
            </div>
            <div className="flex items-end">
              <button className="w-full rounded-md border border-gold/50 bg-gold/10 px-4 py-2 text-sm font-medium text-gold hover:bg-gold/20">
                Save
              </button>
            </div>
          </form>
        </div>
      ))}

      {rows.length === 0 && (
        <p className="rounded-xl border border-line bg-panel px-4 py-10 text-center text-sm text-mute">
          No brokers yet. Add one above and it appears under Where to buy on every stock page.
        </p>
      )}
    </div>
  );
}
