import { DOMParser } from "https://deno.land/x/deno_dom@v0.1.45/deno-dom-wasm.ts";
import type { StockPriceAdapter, StockPriceRow } from "../../_shared/types.ts";

// ─────────────────────────────────────────────────────────────────────────
// Source-AGNOSTIC price adapter, same shape as industry-table.ts. It parses a
// server-rendered table of (ticker, close [, prev] [, volume]) rows. The URL is
// configuration (NSE_PRICES_URL), never hard-coded, because WHICH feed this
// points at is a licensing decision, not a coding one.
//
// WARNING - LICENCE, not a footnote. NSE price data is licensed. Point this at the
//     feed your NSE redistribution agreement covers. The parent function
//     refuses to run at all until app_config `stocks.prices_enabled` is true,
//     so nothing here executes by accident.
//
// WARNING - VERIFY BEFORE TRUSTING. Column detection below is a reasonable default,
//     not confirmed against a live feed. Save a response to a fixture and check
//     it first (see scripts/test-adapter.ts for the MMF equivalent). If the
//     feed is JSON rather than HTML, write a sibling adapter to this interface
//     instead of bending this one.
// ─────────────────────────────────────────────────────────────────────────

// A ticker is 2-6 uppercase letters. Guards against picking up a row number.
const TICKER = /^[A-Z]{2,6}$/;

function num(s: string): number | null {
  const t = s.replace(/,/g, "").replace(/[^\d.]/g, "").trim();
  if (!t) return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

export function parsePriceTable(html: string, source: string): StockPriceRow[] {
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) throw new Error(`${source}: failed to parse HTML`);

  const rows: StockPriceRow[] = [];
  for (const tr of doc.querySelectorAll("table tr")) {
    const cells = [...(tr as any).querySelectorAll("td")].map((c: any) =>
      c.textContent.trim()
    );
    if (cells.length < 2) continue; // header / spacer

    // ticker = first cell that reads like one
    const ticker = cells.find((c: string) => TICKER.test(c));
    if (!ticker) continue;

    // numbers = every remaining numeric cell, in document order. On a standard
    // NSE-style board that is [prev, close, change, volume] or [close, volume].
    // We take the LAST plausible price as the close and, when a second price is
    // present before it, treat that as the previous close.
    const nums = cells
      .filter((c: string) => c !== ticker)
      .map(num)
      .filter((n: number | null): n is number => n != null);
    if (nums.length === 0) continue;

    const prices = nums.filter((n) => n > 0 && n <= 100_000);
    if (prices.length === 0) continue;

    const close = prices.length >= 2 ? prices[1] : prices[0];
    const prevClose = prices.length >= 2 ? prices[0] : undefined;
    const volume = nums.find((n) => Number.isInteger(n) && n > 100_000);

    rows.push({ ticker, close, prevClose, volume });
  }
  return rows;
}

export function nsePriceTableAdapter(sourceUrl: string): StockPriceAdapter {
  const id = "nse-price-table";
  return {
    id,
    async fetchRows(): Promise<StockPriceRow[]> {
      const res = await fetch(sourceUrl, {
        headers: { "User-Agent": "fructaBot/0.1 (+https://fructa.app)" },
      });
      if (!res.ok) throw new Error(`${id}: HTTP ${res.status}`);
      const rows = parsePriceTable(await res.text(), id);
      if (rows.length === 0) {
        throw new Error(`${id}: no rows parsed (check fixture)`);
      }
      return rows;
    },
  };
}
