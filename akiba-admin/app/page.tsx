import Link from "next/link";

export const revalidate = 3600; // refresh the live board hourly

type Fund = {
  id: string; name: string; manager: string; category: string;
  currency: string; current_rate: number | null;
};

async function topMmfRates(): Promise<Fund[]> {
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL;
  try {
    const res = await fetch(`${base}/storage/v1/object/public/snapshots/funds-snapshot.json`, {
      next: { revalidate: 3600 },
    });
    if (!res.ok) return [];
    const data = await res.json();
    return ((data.funds ?? []) as Fund[])
      .filter((f) => f.category === "mmf_kes" && f.current_rate != null)
      .sort((a, b) => (b.current_rate ?? 0) - (a.current_rate ?? 0))
      .slice(0, 6);
  } catch {
    return [];
  }
}

export default async function Landing() {
  const rates = await topMmfRates();

  return (
    <div className="min-h-screen">
      {/* nav */}
      <header className="mx-auto flex max-w-6xl items-center justify-between px-6 py-6">
        <div>
          <span className="text-lg font-bold tracking-tight text-ink">akiba</span>
          <span className="text-lg font-bold text-gold"> .</span>
        </div>
        <Link href="/login" className="text-sm text-mute hover:text-ink">Admin</Link>
      </header>

      {/* hero */}
      <section className="mx-auto grid max-w-6xl gap-12 px-6 pb-20 pt-10 lg:grid-cols-2 lg:items-center lg:pt-16">
        <div>
          <p className="mb-4 text-xs font-medium uppercase tracking-[0.2em] text-gold">Kenya · investing</p>
          <h1 className="text-4xl font-bold leading-[1.05] tracking-tight text-ink sm:text-5xl">
            Every Kenyan investment rate,<br />
            <span className="text-gold">in one place.</span>
          </h1>
          <p className="mt-5 max-w-md text-lg leading-relaxed text-mute">
            Money market funds, T-bills, bonds and SACCOs — live yields side by side,
            with your own balance and daily earnings on top. Stop opening a dozen apps
            to check a rate.
          </p>

          <div className="mt-8 flex flex-wrap items-center gap-3">
            <StoreBadge label="App Store" sub="Coming soon" />
            <StoreBadge label="Google Play" sub="Coming soon" />
          </div>

          <p className="mt-6 text-sm text-faint">
            Your money stays on your phone. No account, no tracking.
          </p>
        </div>

        {/* live rate board — the product, right here */}
        <div className="rounded-2xl border border-line bg-panel p-6 shadow-2xl shadow-black/40">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-ink">Money market funds</h2>
            <span className="flex items-center gap-1.5 text-xs text-mute">
              <span className="h-1.5 w-1.5 rounded-full bg-live" /> live · updated daily
            </span>
          </div>

          {rates.length > 0 ? (
            <ul className="divide-y divide-line">
              {rates.map((f) => (
                <li key={f.id} className="flex items-center gap-3 py-3 first:pt-0 last:pb-0">
                  <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gold/10 text-xs font-semibold text-gold">
                    {f.manager?.[0] ?? f.name[0]}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm text-ink">{f.name}</p>
                    <p className="truncate text-xs text-faint">{f.manager}</p>
                  </div>
                  <span className="tnum text-base font-semibold text-gold">
                    {f.current_rate!.toFixed(2)}%
                  </span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="py-10 text-center text-sm text-mute">Live rates arriving soon.</p>
          )}

          <p className="mt-4 border-t border-line pt-3 text-[11px] text-faint">
            Gross effective annual yield, before the 15% withholding tax.
          </p>
        </div>
      </section>

      {/* features */}
      <section className="border-t border-line bg-panel/30">
        <div className="mx-auto grid max-w-6xl gap-8 px-6 py-16 sm:grid-cols-2 lg:grid-cols-4">
          <Feature title="Rates first" body="Every fund's current yield in one directory, refreshed daily. Compare them net of tax." />
          <Feature title="Your money, overlaid" body="Add a balance and watch daily earnings and projections — no spreadsheets." />
          <Feature title="Private by default" body="Portfolios live on your phone. No sign-up, nothing to leak." />
          <Feature title="Works offline" body="Last-known rates when you're off the grid, synced when you're back." />
        </div>
      </section>

      {/* footer */}
      <footer className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-3 px-6 py-10 text-sm text-faint sm:flex-row">
        <div>
          <span className="font-bold text-ink">akiba</span>
          <span className="font-bold text-gold"> .</span>
          <span className="ml-3">Made for Kenya.</span>
        </div>
        <Link href="/login" className="hover:text-mute">Admin</Link>
      </footer>
    </div>
  );
}

function StoreBadge({ label, sub }: { label: string; sub: string }) {
  return (
    <div className="rounded-xl border border-line bg-panel px-4 py-2.5">
      <p className="text-[10px] uppercase tracking-wider text-faint">{sub}</p>
      <p className="text-sm font-medium text-ink">{label}</p>
    </div>
  );
}

function Feature({ title, body }: { title: string; body: string }) {
  return (
    <div>
      <h3 className="mb-2 text-sm font-semibold text-gold">{title}</h3>
      <p className="text-sm leading-relaxed text-mute">{body}</p>
    </div>
  );
}
