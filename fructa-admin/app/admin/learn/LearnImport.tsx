"use client";

import { useMemo, useRef, useState, useTransition } from "react";
import { importLearn, type ImportResult } from "./actions";
import {
  IconDownload,
  IconUpload,
  IconFile,
  IconX,
  IconCheck,
  IconAlert,
} from "../_icons";

// A real, importable example — doubles as the format spec and fills the
// "inflation" gap. Stringified so the newline escapes are valid JSON.
const EXAMPLE = {
  units: [
    {
      title: "Inflation & real returns",
      subtitle: "Why 10% earned can still lose to rising prices.",
      accent: "emerald",
      unlock_after: "u_rate",
      lessons: [
        {
          title: "What is inflation?",
          xp: 20,
          steps: [
            {
              kind: "explainer",
              payload: {
                title: "What is inflation?",
                body:
                  "Inflation is the rate at which prices rise over time. If a loaf costs KES 60 today and KES 66 next year, that's about 10% inflation.\n\nIt matters because the same shilling buys less over time. Kenya's inflation has recently hovered around 6–7%.",
                note: "fructa shows current inflation as a benchmark next to fund rates.",
              },
            },
            {
              kind: "chart",
              payload: {
                chart: "bars",
                title: "A top MMF vs inflation, today",
                unit: "%",
                caption:
                  "The fund's yield clears inflation — the gap is your real gain.",
                series: [
                  { label: "Etica MMF", value: 10.67, highlight: true },
                  { label: "Inflation", value: 6.7 },
                ],
              },
            },
            {
              kind: "quiz",
              payload: {
                prompt:
                  "Prices rose from KES 100 to KES 107 over a year. Roughly what was inflation?",
                options: [
                  { text: "About 7%", correct: true },
                  { text: "About 107%", correct: false },
                  { text: "Prices don't measure inflation", correct: false },
                ],
                explain_ok: "Right — a 7-shilling rise on 100 is about 7%.",
                explain_no: "Inflation is the percent change: 7 on 100 ≈ 7%.",
              },
            },
          ],
        },
        {
          title: "Real vs nominal return",
          xp: 30,
          steps: [
            {
              kind: "explainer",
              payload: {
                title: "Real vs nominal return",
                body:
                  "Your nominal return is the headline yield — say 10%. Your real return is what's left after inflation takes its share.\n\nIf a fund pays 10% and inflation is 7%, your real return is only about 3% — the true growth in what your money can buy.",
                note: "A high rate in a high-inflation year can still be a small real gain.",
              },
            },
            {
              kind: "quiz",
              payload: {
                prompt: "A fund pays 10% and inflation is 7%. Your real return is about…",
                options: [
                  { text: "About 3%", correct: true },
                  { text: "17%", correct: false },
                  { text: "10%", correct: false },
                ],
                explain_ok: "Right — 10% earned minus ~7% inflation ≈ 3% real.",
                explain_no: "Subtract inflation from the yield: 10% − 7% ≈ 3%.",
              },
            },
          ],
        },
      ],
    },
  ],
};
const EXAMPLE_TEXT = JSON.stringify(EXAMPLE, null, 2);

// Mirrors the server's KINDS set so the preview verdict matches the import.
const KINDS = new Set(["explainer", "interactive", "quiz", "image", "chart"]);

interface TreeLesson {
  title: string;
  xp: number;
  kinds: string[];
}
interface TreeUnit {
  title: string;
  accent: string | null;
  lessons: TreeLesson[];
}
type Analysis =
  | { ok: false; message: string }
  | { ok: true; units: number; lessons: number; steps: number; xp: number; tree: TreeUnit[] };

const asObj = (v: unknown): Record<string, unknown> =>
  v !== null && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
const asArr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
const asStr = (v: unknown): string => (typeof v === "string" ? v : "");

// Same order of checks as importLearn: unknown-kind first, then missing titles.
function analyze(raw: string): Analysis | null {
  const text = raw.trim();
  if (!text) return null;

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { ok: false, message: "That isn't valid JSON." };
  }

  const unitsRaw = Array.isArray(parsed) ? parsed : asArr(asObj(parsed).units);
  if (unitsRaw.length === 0) {
    return { ok: false, message: 'Expected { "units": [ … ] } with at least one unit.' };
  }

  let lessons = 0;
  let steps = 0;
  let xp = 0;
  let missingUnitTitle = false;
  let missingLessonTitle = false;
  const tree: TreeUnit[] = [];

  for (const uRaw of unitsRaw) {
    const u = asObj(uRaw);
    const uTitle = asStr(u.title).trim();
    if (!uTitle) missingUnitTitle = true;

    const tLessons: TreeLesson[] = [];
    for (const lRaw of asArr(u.lessons)) {
      const l = asObj(lRaw);
      const lTitle = asStr(l.title).trim();
      if (!lTitle) missingLessonTitle = true;
      const lXp = Number.isFinite(Number(l.xp)) ? Number(l.xp) : 20;

      const kinds: string[] = [];
      for (const sRaw of asArr(l.steps)) {
        const kind = asStr(asObj(sRaw).kind).trim();
        if (!KINDS.has(kind)) {
          return {
            ok: false,
            message: `Unknown step kind "${kind}" in lesson "${lTitle || "untitled"}".`,
          };
        }
        kinds.push(kind);
        steps++;
      }

      lessons++;
      xp += lXp;
      tLessons.push({ title: lTitle, xp: lXp, kinds });
    }

    tree.push({ title: uTitle, accent: asStr(u.accent).trim() || null, lessons: tLessons });
  }

  if (missingUnitTitle) return { ok: false, message: "Every unit needs a title." };
  if (missingLessonTitle) return { ok: false, message: "Every lesson needs a title." };

  return { ok: true, units: unitsRaw.length, lessons, steps, xp, tree };
}

const btnGold =
  "rounded-md border border-gold/50 bg-gold/10 px-3 py-1.5 text-xs font-medium text-gold hover:bg-gold/20 disabled:cursor-not-allowed disabled:opacity-40";
const btnGhost =
  "flex items-center gap-1 rounded-md border border-line bg-panel2 px-2.5 py-1 text-xs text-mute hover:text-ink";
const chip =
  "rounded-md border border-line bg-panel px-2 py-1 text-[11px] text-mute tnum";

function fmtBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / 1024 / 1024).toFixed(1)} MB`;
}

export function LearnImport() {
  const [json, setJson] = useState("");
  const [fileName, setFileName] = useState<string | null>(null);
  const [fileSize, setFileSize] = useState(0);
  const [replace, setReplace] = useState(false);
  const [drag, setDrag] = useState(false);
  const [fileErr, setFileErr] = useState<string | null>(null);
  const [result, setResult] = useState<ImportResult | null>(null);
  const [pending, start] = useTransition();
  const inputRef = useRef<HTMLInputElement>(null);

  const analysis = useMemo(() => analyze(json), [json]);
  const importable = !!analysis && analysis.ok;

  function loadFile(file: File | undefined | null) {
    if (!file) return;
    setResult(null);
    if (!/\.json$/i.test(file.name) && file.type !== "application/json") {
      setFileErr("That isn't a .json file.");
      return;
    }
    setFileErr(null);
    file.text().then((t) => {
      setJson(t);
      setFileName(file.name);
      setFileSize(file.size);
    });
  }

  function clearFile() {
    setJson("");
    setFileName(null);
    setFileSize(0);
    setFileErr(null);
    setResult(null);
    if (inputRef.current) inputRef.current.value = "";
  }

  function onTextChange(v: string) {
    setJson(v);
    if (fileName) {
      setFileName(null);
      setFileSize(0);
    }
    setResult(null);
  }

  function downloadExample() {
    const blob = new Blob([EXAMPLE_TEXT], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "fructa-learn-example.json";
    a.click();
    URL.revokeObjectURL(url);
  }

  function run() {
    const fd = new FormData();
    fd.set("json", json);
    fd.set("replace", String(replace));
    start(async () => setResult(await importLearn(fd)));
  }

  return (
    <details className="mb-4 rounded-xl border border-line bg-panel [&_summary::-webkit-details-marker]:hidden">
      <summary className="flex cursor-pointer list-none items-center gap-2 px-4 py-3">
        <IconDownload size={15} />
        <span className="text-sm font-semibold text-ink">Import</span>
        <span className="text-[11px] text-faint">
          drop a file or paste JSON — great for AI-generated content
        </span>
      </summary>

      <div className="space-y-3 px-4 pb-4">
        {/* Editor: toolbar + textarea, the whole thing is the drop target */}
        <div
          onDragOver={(e) => {
            e.preventDefault();
            setDrag(true);
          }}
          onDragLeave={(e) => {
            e.preventDefault();
            setDrag(false);
          }}
          onDrop={(e) => {
            e.preventDefault();
            setDrag(false);
            loadFile(e.dataTransfer.files?.[0]);
          }}
          className={
            "relative overflow-hidden rounded-lg border bg-panel2 transition-colors focus-within:border-gold/60 " +
            (drag ? "border-gold" : "border-line")
          }
        >
          <div className="flex items-center gap-2 border-b border-line px-3 py-2">
            {fileName ? (
              <span className="flex items-center gap-2">
                <IconFile size={13} />
                <span className="font-mono text-[11px] text-ink">{fileName}</span>
                <span className="text-[11px] text-faint tnum">{fmtBytes(fileSize)}</span>
                <button
                  onClick={clearFile}
                  className="rounded p-0.5 text-faint hover:text-ink"
                  aria-label="Clear"
                >
                  <IconX size={13} />
                </button>
              </span>
            ) : (
              <span className="text-[11px] text-faint">
                Paste a <code className="text-mute">{`{ "units": [ … ] }`}</code> document
              </span>
            )}
            <button
              onClick={() => inputRef.current?.click()}
              className={btnGhost + " ml-auto"}
            >
              <IconUpload size={13} />
              {fileName ? "Replace" : "Browse file"}
            </button>
          </div>

          <textarea
            rows={10}
            value={json}
            onChange={(e) => onTextChange(e.target.value)}
            spellCheck={false}
            placeholder={`{ "units": [ … ] }`}
            className="block w-full resize-y bg-transparent px-3 py-2.5 font-mono text-xs leading-relaxed text-ink outline-none placeholder:text-faint"
          />

          {drag && (
            <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-gold bg-panel/90">
              <span className="text-gold">
                <IconUpload size={22} />
              </span>
              <span className="text-xs font-medium text-gold">Drop to load</span>
            </div>
          )}

          <input
            ref={inputRef}
            type="file"
            accept="application/json,.json"
            className="hidden"
            onChange={(e) => loadFile(e.target.files?.[0])}
          />
        </div>
        {fileErr && <p className="text-xs text-bad">{fileErr}</p>}

        {/* Live preview — same verdict the server will give */}
        {analysis && !analysis.ok && (
          <div className="flex items-start gap-2 rounded-lg border border-bad/40 bg-bad/5 px-3 py-2">
            <span className="mt-0.5 text-bad">
              <IconAlert size={14} />
            </span>
            <p className="text-xs text-bad">{analysis.message}</p>
          </div>
        )}

        {analysis && analysis.ok && (
          <div className="rounded-lg border border-line bg-panel2 p-3">
            <div className="mb-2.5 flex flex-wrap items-center gap-2">
              <span className="flex items-center gap-1.5 text-live">
                <IconCheck size={14} />
                <span className="text-xs font-medium text-ink">Ready to import</span>
              </span>
              <span className="ml-auto flex gap-1.5">
                <span className={chip}>{analysis.units} units</span>
                <span className={chip}>{analysis.lessons} lessons</span>
                <span className={chip}>{analysis.steps} steps</span>
                <span className={chip}>{analysis.xp} XP</span>
              </span>
            </div>

            <ul className="max-h-56 space-y-2 overflow-auto">
              {analysis.tree.map((u, i) => (
                <li key={i}>
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-medium text-ink">{u.title}</span>
                    {u.accent && (
                      <span className="rounded border border-line px-1 text-[10px] uppercase tracking-wider text-faint">
                        {u.accent}
                      </span>
                    )}
                    <span className="text-[11px] text-faint">
                      {u.lessons.length} {u.lessons.length === 1 ? "lesson" : "lessons"}
                    </span>
                  </div>
                  <ul className="mt-1 space-y-1 border-l border-line pl-3">
                    {u.lessons.map((l, j) => (
                      <li key={j} className="flex items-baseline gap-2 text-[11px]">
                        <span className="text-mute">{l.title || "untitled"}</span>
                        <span className="text-faint tnum">{l.xp} XP</span>
                        <span className="text-faint">{l.kinds.join(" · ") || "no steps"}</span>
                      </li>
                    ))}
                  </ul>
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Actions */}
        <div className="flex flex-wrap items-center gap-3">
          <button onClick={run} disabled={pending || !importable} className={btnGold}>
            {pending ? "Importing…" : "Import & republish"}
          </button>
          <label className="flex items-center gap-2 text-xs text-mute">
            <input
              type="checkbox"
              checked={replace}
              onChange={(e) => setReplace(e.target.checked)}
              className="accent-gold"
            />
            Replace all existing content
          </label>
          {replace && (
            <span className="text-[11px] text-warn">Wipes every current unit first.</span>
          )}
          {result?.ok && (
            <span className="text-xs text-gold">
              Imported {result.units} units · {result.lessons} lessons · {result.steps} steps.
            </span>
          )}
          {result && !result.ok && <span className="text-xs text-bad">{result.error}</span>}
        </div>

        {/* Format & example — collapsed by default so it stays out of the way */}
        <details className="rounded-lg border border-dashed border-line bg-panel2 [&_summary::-webkit-details-marker]:hidden">
          <summary className="flex cursor-pointer list-none items-center gap-2 px-3 py-2">
            <span className="text-[11px] uppercase tracking-wider text-faint">
              Format &amp; example
            </span>
            <span className="ml-auto flex gap-1.5" onClick={(e) => e.preventDefault()}>
              <button onClick={() => setJson(EXAMPLE_TEXT)} className={btnGhost}>
                Use example
              </button>
              <button
                onClick={() => navigator.clipboard.writeText(EXAMPLE_TEXT)}
                className={btnGhost}
              >
                Copy
              </button>
              <button onClick={downloadExample} className={btnGhost}>
                <IconDownload size={13} />
                File
              </button>
            </span>
          </summary>
          <div className="space-y-2 px-3 pb-3">
            <p className="text-[11px] leading-relaxed text-mute">
              Prompt your AI to output exactly this shape. Step{" "}
              <code className="text-faint">kind</code> is{" "}
              <code className="text-faint">explainer</code>,{" "}
              <code className="text-faint">interactive</code>,{" "}
              <code className="text-faint">quiz</code>,{" "}
              <code className="text-faint">image</code> or{" "}
              <code className="text-faint">chart</code> (bars · line · growth); an explainer may
              also carry an inline <code className="text-faint">image</code> or{" "}
              <code className="text-faint">chart</code>. A lesson&rsquo;s{" "}
              <code className="text-faint">fund_id</code> (optional) lights up the live badge.
            </p>
            <pre className="max-h-64 overflow-auto rounded-md bg-panel px-3 py-2 font-mono text-[11px] leading-relaxed text-mute">
{EXAMPLE_TEXT}
            </pre>
          </div>
        </details>
      </div>
    </details>
  );
}