"use client";

import { useState } from "react";
import { updatePricing } from "./actions";

// Field-scoped Pricing card. Owns `basis` and the NAV price fields only; the
// yield rate stays with the Rate box / setRate. Choosing NAV reveals the price
// inputs; Yield/None hides them and a save clears them server-side, so a fund
// flipped off NAV can't keep a stale unit price. Mirrors the updateContact /
// updateCustody field-scoping pattern.
const BASES: [string, string][] = [
  ["yield", "Yield (quotes an annual rate)"],
  ["nav", "NAV (quotes a unit price)"],
  ["none", "None (no headline figure)"],
];

type Props = {
  id: string;
  basis: string | null;
  pricePerUnit: number | null;
  priceAsOf: string | null;
  distributionPct: number | null;
};

export function FundPricing({ id, basis, pricePerUnit, priceAsOf, distributionPct }: Props) {
  const [b, setB] = useState((basis ?? "yield") as string);
  const isNav = b === "nav";

  return (
    <form action={updatePricing} className="panelc">
      <input type="hidden" name="id" value={id} />
      <div className="ph">
        <h3>Pricing</h3>
        <span className="sub">basis · publishes to snapshot</span>
      </div>

      <div className="pb" style={{ display: "grid", gap: 14 }}>
        <label className="field">
          <span>Basis</span>
          <select name="basis" value={b} onChange={(e) => setB(e.target.value)} className="select">
            {BASES.map(([k, l]) => (
              <option key={k} value={k}>{l}</option>
            ))}
          </select>
        </label>

        {isNav ? (
          <>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
              <label className="field">
                <span>Price per unit</span>
                <input
                  name="price_per_unit"
                  type="number"
                  step="any"
                  defaultValue={pricePerUnit ?? ""}
                  className="input num-input"
                  placeholder="13.36"
                />
              </label>
              <label className="field">
                <span>Priced as of</span>
                <input
                  name="price_as_of"
                  type="date"
                  defaultValue={priceAsOf ?? ""}
                  className="input"
                />
              </label>
            </div>
            <label className="field">
              <span>Distribution % (optional)</span>
              <input
                name="distribution_pct"
                type="number"
                step="any"
                defaultValue={distributionPct ?? ""}
                className="input num-input"
                placeholder="4.00"
              />
            </label>
            <p style={{ fontSize: 12, color: "var(--faint)", margin: 0 }}>
              This fund quotes a unit price, not a yield. Leave the Rate box above empty; the app shows the price and
              distribution instead.
            </p>
          </>
        ) : (
          <p style={{ fontSize: 12, color: "var(--faint)", margin: 0 }}>
            Yield funds set their rate in the Rate box above. Switch to NAV for bond / equity / priced special funds
            that quote a unit price.
          </p>
        )}
      </div>

      <div className="pb" style={{ paddingTop: 0 }}>
        <button className="btn gold">Save pricing</button>
      </div>
    </form>
  );
}
