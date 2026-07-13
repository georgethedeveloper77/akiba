"use client";

import { useEffect, useState, useTransition } from "react";
import { addStock } from "./actions";
import { IconPlus, IconX } from "../_icons";

// "" is first and is the default. Segment is a fact we usually do NOT have: the
// NSE register carries sector reliably and MIM/AIM/GEMS unreliably. A dropdown
// that defaults to MIM turns "I did not fill this in" into "this company is on
// the main market", which is a claim nobody made.
const SEGMENTS: [string, string][] = [
  ["", "Not set"],
  ["MIM", "Main Investment Market"],
  ["AIM", "Alternative Investment Market"],
  ["GEMS", "Growth Enterprise Market"],
];

export function AddStock() {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [ticker, setTicker] = useState("");
  const [sector, setSector] = useState("");
  const [segment, setSegment] = useState("");
  const [pending, start] = useTransition();

  const valid = name.trim() !== "" && ticker.trim() !== "";

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  function reset() {
    setName("");
    setTicker("");
    setSector("");
    setSegment("");
  }

  function submit() {
    if (!valid) return;
    const fd = new FormData();
    fd.set("name", name.trim());
    fd.set("ticker", ticker.trim().toUpperCase());
    if (segment) fd.set("segment", segment);
    if (sector.trim()) fd.set("sector", sector.trim());
    start(async () => {
      await addStock(fd);
      reset();
      setOpen(false);
    });
  }

  const field =
    "w-full rounded-md border border-line bg-panel2 px-3 py-2 text-sm text-ink outline-none placeholder:text-faint focus:border-gold/60";
  const label = "mb-1 block text-[11px] uppercase tracking-wider text-faint";

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="inline-flex items-center gap-1.5 rounded-md border border-gold/50 bg-gold/10 px-3 py-1.5 text-sm font-medium text-gold hover:bg-gold/20"
      >
        <IconPlus size={14} /> Add stock
      </button>

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4"
          onMouseDown={(e) => { if (e.target === e.currentTarget) setOpen(false); }}
        >
          <div className="w-full max-w-md rounded-xl border border-line bg-panel p-5 shadow-xl">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-base font-semibold text-ink">Add stock</h2>
              <button onClick={() => setOpen(false)} className="text-faint hover:text-ink" aria-label="Close">
                <IconX size={16} />
              </button>
            </div>

            <div className="space-y-3">
              <div>
                <label className={label}>Company name</label>
                <input autoFocus value={name} onChange={(e) => setName(e.target.value)}
                  placeholder="Safaricom PLC" className={field} />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={label}>Ticker</label>
                  <input value={ticker} onChange={(e) => setTicker(e.target.value.toUpperCase())}
                    placeholder="SCOM" className={field + " font-mono"} />
                </div>
                <div>
                  <label className={label}>Segment</label>
                  <select value={segment} onChange={(e) => setSegment(e.target.value)} className={field}>
                    {SEGMENTS.map(([k, l]) => <option key={k} value={k}>{l}</option>)}
                  </select>
                </div>
              </div>

              <div>
                <label className={label}>Sector (optional)</label>
                <input value={sector} onChange={(e) => setSector(e.target.value)}
                  placeholder="Telecommunications" className={field} />
              </div>

              <p className="text-[11px] text-faint">
                The ticker is how the price lane joins a feed row to this company, so it must match the exchange exactly.
                Dividends, profile and shares outstanding are set on the edit page.
              </p>
            </div>

            <div className="mt-5 flex items-center justify-end gap-3">
              <button onClick={() => setOpen(false)} disabled={pending} className="text-sm text-faint hover:text-mute">
                Cancel
              </button>
              <button onClick={submit} disabled={!valid || pending}
                className="rounded-md border border-gold/50 bg-gold/10 px-4 py-1.5 text-sm font-medium text-gold hover:bg-gold/20 disabled:cursor-not-allowed disabled:opacity-40">
                {pending ? "Adding" : "Add stock"}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
