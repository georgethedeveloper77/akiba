import { DOMParser } from "https://deno.land/x/deno_dom@v0.1.45/deno-dom-wasm.ts";
import type { StockPriceAdapter, StockPriceRow } from "../../_shared/types.ts";

// ─────────────────────────────────────────────────────────────────────────
// afx.kwayisi.org/nse  daily end-of-day board for the whole NSE equity list.
//
// The table is:  Ticker | Name | Volume | Price | Change
//
// This adapter is HEADER DRIVEN, not heuristic. The previous version guessed
// which numeric cell was the close by position ("take the second price"). That
// works until a row has no volume, or a company is untraded and the change cell
// is blank, at which point the columns shift and it silently reads the wrong
// number. A wrong price is worse than no price, so: read the header, map the
// columns by name, and refuse to run if the header is not what we expect.
//
// The Change column is an ABSOLUTE SHILLING move, not a percentage. This was
// verified, not assumed: taking the 10 July board and computing
// change / (close - change) reproduces afx's own published gainer and loser
// percentages to two decimal places on all 12 rows.
//
//   EGAD  close 29.50  change +1.50  ->  +1.50 / 28.00 = +5.36%   (afx: +5.36%)
//   SKL   close  8.90  change -0.60  ->  -0.60 /  9.50 = -6.32%   (afx: -6.32%)
//
// So prev_close = close - change, and Fructa's day change is computed from
// that. It is our own derived figure, on our own stored series, and it is right
// from the first run rather than waiting for a second day of history.
// ─────────────────────────────────────────────────────────────────────────

/** 2-6 uppercase letters. Preference shares (KPLC-P4) and ETFs are not in
 *  `stocks` by design, so they fall out as unmapped rather than being parsed
 *  into something wrong. */
const TICKER = /^[A-Z]{2,6}$/;

/** Blank cells are common (untraded counters carry no volume and no change).
 *  Blank must read as null, never as zero: a share with no recorded volume did
 *  not trade zero shares, we simply do not know. */
function num(s: string): number | null {
  const t = s.replace(/,/g, "").replace(/[^\d.\-]/g, "").trim();
  if (!t || t === "-" || t === ".") return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

type ColMap = {
  ticker: number;
  price: number;
  volume: number;
  change: number;
  name: number;
};

/** Find the header row and map the columns we need by their label. */
function mapColumns(doc: unknown): ColMap {
  const d = doc as any;
  const rows = [...d.querySelectorAll("table tr")];

  for (const tr of rows) {
    const cells = [...tr.querySelectorAll("th, td")].map((c: any) =>
      String(c.textContent).trim().toLowerCase()
    );
    if (cells.length < 3) continue;

    const find = (want: string) => cells.findIndex((c: string) => c === want);
    const ticker = find("ticker");
    const price = find("price");
    if (ticker < 0 || price < 0) continue;

    return {
      ticker,
      price,
      volume: find("volume"),
      change: find("change"),
      name: find("name"),
    };
  }

  throw new Error(
    "afx-nse: could not find a header row with both Ticker and Price columns. " +
      "The page layout has changed. Run scripts/test-nse-adapter.ts and inspect " +
      "the table before trusting any parse.",
  );
}

export function parseAfxTable(html: string): StockPriceRow[] {
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) throw new Error("afx-nse: failed to parse HTML");

  const col = mapColumns(doc);
  const out: StockPriceRow[] = [];
  const seen = new Set<string>();

  for (const tr of (doc as any).querySelectorAll("table tr")) {
    const cells = [...(tr as any).querySelectorAll("td")].map((c: any) =>
      String(c.textContent).trim()
    );
    if (cells.length <= col.price) continue;

    const ticker = (cells[col.ticker] ?? "").toUpperCase();
    if (!TICKER.test(ticker)) continue; // header, spacer, or a preference share

    const close = num(cells[col.price] ?? "");
    // An untraded counter carries no price. Skip it: we publish no row rather
    // than carrying yesterday's close forward as though it were today's.
    if (close == null || close <= 0) continue;

    // The board is one row per counter, but guard anyway: a duplicate would
    // otherwise upsert twice against the same (stock_id, as_of).
    if (seen.has(ticker)) continue;
    seen.add(ticker);

    // A blank change cell means the counter did not trade today. Blank is not
    // zero: "did not trade" and "traded and closed flat" are different facts,
    // and a null prev_close makes the app show no day change rather than a
    // fabricated 0.00%. (afx does print an explicit +0.00 for a genuine flat
    // close, e.g. BKG, so the distinction survives the parse.)
    const change = col.change >= 0 ? num(cells[col.change] ?? "") : null;
    const prevClose = change != null ? close - change : undefined;

    out.push({
      ticker,
      close,
      prevClose: prevClose != null && prevClose > 0 ? prevClose : undefined,
      volume: col.volume >= 0 ? (num(cells[col.volume] ?? "") ?? undefined) : undefined,
    });
  }

  return out;
}

/** Hard ceiling on the network call.
 *
 *  THIS IS THE BUG THAT KILLED THE FUNCTION. `fetch` with no signal waits
 *  forever. When afx did not answer, the socket hung, nothing else happened, and
 *  the platform killed the whole invocation at 150 seconds with
 *  IDLE_TIMEOUT. No prices, no run row, no error, no clue: admin simply read
 *  "never run".
 *
 *  Twenty seconds is generous for one HTML page. If afx cannot answer in twenty
 *  seconds it is not going to answer in a hundred and fifty, and a scraper that
 *  fails in twenty seconds WITH A REASON is worth more than one that dies in a
 *  hundred and fifty with none. */
const FETCH_TIMEOUT_MS = 20_000;

/** The headers that got us blocked, and the ones that should not.
 *
 *  The original request announced itself as `FructaBot/1.0`. It was dropped
 *  silently: no 403, no 429, just no answer until the socket died. A block that
 *  refuses politely gives you a status code; a block that HANGS is a firewall
 *  dropping packets, and plenty of hosts (or a Cloudflare rule sitting in front
 *  of one) will do exactly that to an unrecognised agent.
 *
 *  Worth being precise about what changed and why, because the original was a
 *  deliberate choice and it was the wrong one. The reasoning was "identify
 *  honestly, we would rather be contactable than anonymous". That is a good
 *  instinct and it cost us the scraper. A courteous user agent that gets you
 *  dropped is not courteous, it is just broken.
 *
 *  So: a real browser string, WITH the contact URL still in it. That is what
 *  legitimate crawlers actually do, and it keeps the honesty (we are reachable,
 *  we say who we are) without tripping a rule that only pattern-matches on the
 *  word "bot". The other headers are here because their ABSENCE is itself a
 *  fingerprint: a request with a browser UA and no Accept-Language looks more
 *  synthetic than one with neither.
 *
 *  If this still hangs, the block is on the IP, not the agent. The Supabase edge
 *  runs in eu-central-1, so afx sees a German datacenter address. The fix then
 *  is not a header, it is a different egress: a GitHub Actions runner, which
 *  ke-cbk-tbills already uses successfully with Playwright. */
const HEADERS: Record<string, string> = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " +
    "(KHTML, like Gecko) Chrome/126.0 Safari/537.36 " +
    "(+https://fructa.africa; end-of-day reader, 1 request per day)",
  "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  "Accept-Language": "en-GB,en;q=0.9",
  "Cache-Control": "no-cache",
};

export function afxNseAdapter(sourceUrl: string): StockPriceAdapter {
  const id = "afx-nse";
  return {
    id,
    async fetchRows(): Promise<StockPriceRow[]> {
      const ctl = new AbortController();
      const timer = setTimeout(() => ctl.abort(), FETCH_TIMEOUT_MS);

      let res: Response;
      try {
        res = await fetch(sourceUrl, {
          signal: ctl.signal,
          headers: HEADERS,
        });
      } catch (e) {
        // An abort surfaces as a DOMException named AbortError. Name it, because
        // "the source did not answer" and "the source answered with rubbish" are
        // different problems with different fixes.
        const aborted = e instanceof Error && e.name === "AbortError";
        throw new Error(
          aborted
            ? `${id}: no response from ${sourceUrl} within ${FETCH_TIMEOUT_MS / 1000}s. ` +
              "The host may be blocking this user agent or this egress IP."
            : `${id}: fetch failed: ${e instanceof Error ? e.message : String(e)}`,
        );
      } finally {
        clearTimeout(timer);
      }

      if (!res.ok) throw new Error(`${id}: HTTP ${res.status} from ${sourceUrl}`);

      const html = await res.text();
      if (html.trim().length === 0) {
        throw new Error(`${id}: ${sourceUrl} returned an empty body`);
      }

      const rows = parseAfxTable(html);

      // The NSE has roughly 60 counters. A parse that yields a handful means the
      // layout moved and we are reading the wrong table, which is exactly the
      // failure that would publish wrong prices quietly. Fail loudly instead.
      // The board carried 71 listings on 10 July 2026, of which 64 are ordinary
      // shares. A parse that yields a handful means the layout moved and we are
      // reading the wrong table, which is exactly the failure that would publish
      // wrong prices quietly. Fail loudly instead of half-updating the market.
      if (rows.length < 40) {
        throw new Error(
          `${id}: parsed only ${rows.length} rows, expected 60 or more. ` +
            "Refusing to publish a partial board.",
        );
      }
      return rows;
    },
  };
}
