"use client";

/*
 * A small Markdown renderer for the page preview.
 *
 * No dependency, and no dangerouslySetInnerHTML: the body of a legal page is
 * operator-authored, but it is still stored in a database and rendered in the
 * admin, so it goes through React nodes rather than raw HTML injection.
 *
 * Supports what these pages actually use: headings, paragraphs, bullet and
 * numbered lists, links, bold, italic, inline code and rules. Anything else
 * renders as plain text rather than silently disappearing.
 */

import type { ReactNode } from "react";

const INLINE = /(\[[^\]]+\]\([^)]+\)|\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)/g;

/** bold, italic, inline code and links inside a line */
function inline(text: string, keyBase: string): ReactNode[] {
  return text.split(INLINE).filter(Boolean).map((part, i) => {
    const k = `${keyBase}-${i}`;
    const link = /^\[([^\]]+)\]\(([^)]+)\)$/.exec(part);
    if (link) {
      return (
        <a key={k} href={link[2]} target="_blank" rel="noreferrer" className="text-gold hover:underline">
          {link[1]}
        </a>
      );
    }
    if (part.startsWith("**") && part.endsWith("**")) {
      return <b key={k} className="font-semibold text-ink">{part.slice(2, -2)}</b>;
    }
    if (part.startsWith("*") && part.endsWith("*")) {
      return <i key={k}>{part.slice(1, -1)}</i>;
    }
    if (part.startsWith("`") && part.endsWith("`")) {
      return (
        <code key={k} className="rounded bg-panel2 px-1 py-0.5 font-mono text-[12px] text-ink">
          {part.slice(1, -1)}
        </code>
      );
    }
    return <span key={k}>{part}</span>;
  });
}

export function Markdown({ source }: { source: string }) {
  const lines = source.replace(/\r\n/g, "\n").split("\n");
  const out: ReactNode[] = [];
  let list: { ordered: boolean; items: string[] } | null = null;
  let para: string[] = [];

  const flushList = () => {
    if (!list) return;
    const Tag = list.ordered ? "ol" : "ul";
    out.push(
      <Tag
        key={`l${out.length}`}
        className={
          "mb-3 space-y-1.5 pl-5 text-[13px] leading-relaxed text-mute " +
          (list.ordered ? "list-decimal" : "list-disc")
        }
      >
        {list.items.map((it, i) => (
          <li key={i}>{inline(it, `li${out.length}-${i}`)}</li>
        ))}
      </Tag>,
    );
    list = null;
  };
  const flushPara = () => {
    if (para.length === 0) return;
    const text = para.join(" ");
    out.push(
      <p key={`p${out.length}`} className="mb-3 text-[13px] leading-relaxed text-mute">
        {inline(text, `p${out.length}`)}
      </p>,
    );
    para = [];
  };
  const flush = () => {
    flushList();
    flushPara();
  };

  for (const raw of lines) {
    const line = raw.trimEnd();

    if (!line.trim()) {
      flush();
      continue;
    }
    if (/^(-{3,}|\*{3,}|_{3,})$/.test(line.trim())) {
      flush();
      out.push(<hr key={`hr${out.length}`} className="my-5 border-line" />);
      continue;
    }

    const h = /^(#{1,4})\s+(.*)$/.exec(line);
    if (h) {
      flush();
      const level = h[1].length;
      const cls =
        level === 1
          ? "mb-3 text-[20px] font-semibold tracking-tight text-ink"
          : level === 2
            ? "mb-2.5 text-[17px] font-semibold tracking-tight text-ink"
            : "mb-2 mt-5 text-[14px] font-semibold text-ink";
      out.push(
        <p key={`h${out.length}`} className={cls}>
          {inline(h[2], `h${out.length}`)}
        </p>,
      );
      continue;
    }

    const ul = /^\s*[-*+]\s+(.*)$/.exec(line);
    const ol = /^\s*\d+[.)]\s+(.*)$/.exec(line);
    if (ul || ol) {
      flushPara();
      const ordered = !!ol;
      const item = (ul ?? ol)![1];
      if (list && list.ordered !== ordered) flushList();
      if (!list) list = { ordered, items: [] };
      list.items.push(item);
      continue;
    }

    flushList();
    para.push(line.trim());
  }
  flush();

  if (out.length === 0) {
    return <p className="text-[13px] text-faint">Nothing to preview yet.</p>;
  }
  return <div>{out}</div>;
}
