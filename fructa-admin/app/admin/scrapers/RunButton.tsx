"use client";

import { useState, useTransition } from "react";
import type { RunResult } from "./actions";

/**
 * A trigger that reports back.
 *
 * The old buttons were bare `<form action={serverAction}>` posts. They gave no
 * pending state, no success, and above all no ERROR: the action swallowed every
 * exception, so a 401 from a stale CRON_SECRET and a clean run were pixel
 * identical. You pressed the button, the page re-rendered showing the same old
 * run, and you were left to guess whether it had fired.
 *
 * That is not a cosmetic complaint. It is how a scraper sits un-run for weeks
 * with nobody able to tell.
 *
 * No icon here on purpose: the icon set is the single source of truth for
 * glyphs (no emoji, no unicode symbols), and this component does not need one
 * to say what it is doing.
 */
export function RunButton({
  action,
  label = "Re-run",
  variant = "quiet",
}: {
  action: () => Promise<RunResult>;
  label?: string;
  variant?: "quiet" | "gold";
}) {
  const [pending, start] = useTransition();
  const [result, setResult] = useState<RunResult | null>(null);

  const base =
    "inline-flex items-center gap-1.5 rounded-md border px-3 py-1.5 text-xs transition-colors disabled:cursor-not-allowed disabled:opacity-60";
  const skin =
    variant === "gold"
      ? "border-gold/50 bg-gold/10 font-medium text-gold hover:bg-gold/20"
      : "border-line text-mute hover:border-gold/60 hover:text-gold";

  return (
    <div className="flex flex-col items-end gap-1.5">
      <button
        disabled={pending}
        onClick={() => {
          setResult(null);
          start(async () => setResult(await action()));
        }}
        className={base + " " + skin}
      >
        {pending && (
          <span
            className="h-3 w-3 shrink-0 animate-spin rounded-full border border-current border-t-transparent"
            aria-hidden
          />
        )}
        {pending ? "Running" : label}
      </button>

      {result && !pending && (
        <span
          className={
            "max-w-[16rem] text-right text-[11px] leading-snug " +
            (result.ok ? "text-live" : "text-bad")
          }
        >
          {result.message}
        </span>
      )}
    </div>
  );
}
