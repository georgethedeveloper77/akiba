// CBK indicative USD/KES rate. Source URL is configuration (CBK_FX_URL), not
// hard-coded — set it to the CBK indicative-rates page after checking the page
// shape. Official page:
//   https://www.centralbank.go.ke/rates/forex-exchange-rates/
//
// ⚠️  VERIFY BEFORE TRUSTING: the parse below is a heuristic (find the US
//     DOLLAR row, take the mean rate). Test against a saved fixture and adjust
//     the selector/regex if the layout differs. Returns null on any failure so
//     a bad fetch never breaks the scrape run.

export interface FxPoint {
  pair: string; // 'USD/KES'
  rate: number;
  as_of: string; // YYYY-MM-DD (EAT)
}

// Pull the first plausible KES-per-USD figure (typically ~100–200).
function parseUsdKes(text: string): number | null {
  // Narrow to a line/segment mentioning the US dollar, then take a number
  // in the expected band. Falls back to scanning the whole doc.
  const seg =
    text.match(/US\s*DOLLAR[\s\S]{0,200}/i)?.[0] ??
    text.match(/\bUSD\b[\s\S]{0,200}/i)?.[0] ??
    text;
  const nums = [...seg.matchAll(/(\d{2,3}(?:\.\d{1,4})?)/g)].map((m) => Number(m[1]));
  const plausible = nums.filter((n) => n >= 90 && n <= 250);
  if (plausible.length === 0) return null;
  // Mean of the first two plausible figures (buy/sell) ≈ indicative mean.
  const take = plausible.slice(0, 2);
  return Number((take.reduce((a, b) => a + b, 0) / take.length).toFixed(4));
}

export async function fetchUsdKes(): Promise<FxPoint | null> {
  const url = Deno.env.get("CBK_FX_URL");
  if (!url) return null;
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "AkibaBot/0.1 (+https://akiba.app)" },
    });
    if (!res.ok) return null;
    const rate = parseUsdKes(await res.text());
    if (rate == null) return null;
    const as_of = new Date(Date.now() + 3 * 3_600_000).toISOString().slice(0, 10);
    return { pair: "USD/KES", rate, as_of };
  } catch {
    return null;
  }
}
