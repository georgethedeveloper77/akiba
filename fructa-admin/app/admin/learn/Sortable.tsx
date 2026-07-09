"use client";

import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  useTransition,
  type ReactNode,
  type DragEvent as RDragEvent,
  type KeyboardEvent as RKeyboardEvent,
  type MouseEvent as RMouseEvent,
} from "react";

// Six-dot grip. Canonical home is app/admin/_icons.tsx; kept here so the
// sortable primitive ships self-contained. Lift it into the registry when
// convenient and swap the import.
export function IconGrip({ size = 16 }: { size?: number }) {
  const r = 1.5;
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <circle cx="9" cy="5" r={r} />
      <circle cx="15" cy="5" r={r} />
      <circle cx="9" cy="12" r={r} />
      <circle cx="15" cy="12" r={r} />
      <circle cx="9" cy="19" r={r} />
      <circle cx="15" cy="19" r={r} />
    </svg>
  );
}

// A 1x1 transparent gif used as the drag image, so the browser paints no ghost.
// The moved row stays in place, dimmed, while a gold insertion line shows where
// it will land. This reads clearly within a list and across lists alike.
const TRANSPARENT_GIF =
  "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==";
let dragImg: HTMLImageElement | null = null;
function transparentImage(): HTMLImageElement | null {
  if (!dragImg && typeof Image !== "undefined") {
    dragImg = new Image();
    dragImg.src = TRANSPARENT_GIF;
  }
  return dragImg;
}

function sameOrder(a: string[], b: string[]) {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
  return true;
}

// Move `id` so it sits before original position `insertBefore` (0..n).
function reorderTo(ids: string[], id: string, insertBefore: number): string[] {
  const from = ids.indexOf(id);
  if (from === -1) return ids;
  const without = ids.slice(0, from).concat(ids.slice(from + 1));
  let at = insertBefore > from ? insertBefore - 1 : insertBefore;
  at = Math.max(0, Math.min(at, without.length));
  without.splice(at, 0, id);
  return without;
}

const handleCls =
  "-ml-1 flex h-7 w-5 shrink-0 cursor-grab touch-none select-none items-center " +
  "justify-center rounded text-faint hover:bg-panel2 hover:text-mute active:cursor-grabbing " +
  "focus:outline-none focus-visible:ring-1 focus-visible:ring-gold/60";

function Line() {
  return <div className="mx-1 h-0.5 rounded bg-gold" aria-hidden="true" />;
}

interface Target {
  group: string;
  index: number;
}

interface BoardCtx {
  activeId: string | null;
  fromGroup: string | null;
  target: Target | null;
  pending: boolean;
  begin: (id: string, group: string) => void;
  hover: (group: string, index: number) => void;
  end: (dropped: boolean) => void;
  register: (group: string, ids: string[]) => void;
  commitOrder: (group: string, ids: string[]) => void;
}

export interface SortableInstance {
  Board: (p: {
    reorder: (group: string, ids: string[]) => void | Promise<unknown>;
    move?: (id: string, toGroup: string, index: number) => void | Promise<unknown>;
    children: ReactNode;
  }) => ReactNode;
  Group: <T extends { id: string }>(p: {
    groupId: string;
    items: T[];
    className?: string;
    emptyHint?: string;
    handleLabel?: (item: T) => string;
    renderItem: (
      item: T,
      args: { handle: ReactNode; dragging: boolean },
    ) => ReactNode;
  }) => ReactNode;
  useHeaderDrop: (
    groupId: string,
    endIndex: number,
  ) => { onDragOver: (e: RDragEvent) => void; onDragEnter: (e: RDragEvent) => void; isTarget: boolean };
  Pending: () => ReactNode;
}

// Each call builds an isolated board (its own context), so nesting a lessons
// board inside a units board never crosses wires.
export function createSortable(): SortableInstance {
  const Ctx = createContext<BoardCtx | null>(null);
  const useBoard = () => {
    const c = useContext(Ctx);
    if (!c) throw new Error("Sortable.Group/useHeaderDrop used outside its Board");
    return c;
  };

  function Board({
    reorder,
    move,
    children,
  }: {
    reorder: (group: string, ids: string[]) => void | Promise<unknown>;
    move?: (id: string, toGroup: string, index: number) => void | Promise<unknown>;
    children: ReactNode;
  }) {
    const [activeId, setActiveId] = useState<string | null>(null);
    const [fromGroup, setFromGroup] = useState<string | null>(null);
    const [target, setTarget] = useState<Target | null>(null);
    const [pending, start] = useTransition();

    const activeRef = useRef<string | null>(null);
    const fromRef = useRef<string | null>(null);
    const targetRef = useRef<Target | null>(null);
    const groups = useRef<Map<string, string[]>>(new Map());
    const reorderRef = useRef(reorder);
    const moveRef = useRef(move);
    reorderRef.current = reorder;
    moveRef.current = move;

    const begin = (id: string, group: string) => {
      activeRef.current = id;
      fromRef.current = group;
      targetRef.current = null;
      setActiveId(id);
      setFromGroup(group);
      setTarget(null);
    };

    const hover = (group: string, index: number) => {
      const t = targetRef.current;
      if (t && t.group === group && t.index === index) return;
      const next = { group, index };
      targetRef.current = next;
      setTarget(next);
    };

    const clear = () => {
      activeRef.current = null;
      fromRef.current = null;
      targetRef.current = null;
      setActiveId(null);
      setFromGroup(null);
      setTarget(null);
    };

    const commitOrder = (group: string, ids: string[]) => {
      const current = groups.current.get(group) ?? [];
      if (sameOrder(ids, current)) return;
      start(async () => {
        await reorderRef.current(group, ids);
      });
    };

    const end = (dropped: boolean) => {
      const id = activeRef.current;
      const from = fromRef.current;
      const t = targetRef.current;
      if (dropped && id && from && t) {
        if (t.group === from) {
          const ids = groups.current.get(from) ?? [];
          const next = reorderTo(ids, id, t.index);
          if (!sameOrder(next, ids)) {
            start(async () => {
              await reorderRef.current(from, next);
            });
          }
        } else if (moveRef.current) {
          const to = t.group;
          const idx = t.index;
          start(async () => {
            await moveRef.current!(id, to, idx);
          });
        }
      }
      clear();
    };

    const register = (group: string, ids: string[]) => {
      groups.current.set(group, ids);
    };

    const value: BoardCtx = {
      activeId,
      fromGroup,
      target,
      pending,
      begin,
      hover,
      end,
      register,
      commitOrder,
    };
    return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
  }

  function Group<T extends { id: string }>({
    groupId,
    items,
    className,
    emptyHint,
    handleLabel,
    renderItem,
  }: {
    groupId: string;
    items: T[];
    className?: string;
    emptyHint?: string;
    handleLabel?: (item: T) => string;
    renderItem: (
      item: T,
      args: { handle: ReactNode; dragging: boolean },
    ) => ReactNode;
  }) {
    const ctx = useBoard();
    const ids = items.map((i) => i.id);
    const signature = ids.join("|");

    useEffect(() => {
      ctx.register(groupId, signature ? signature.split("|") : []);
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [groupId, signature]);

    const active = ctx.activeId != null;
    const atEnd =
      ctx.target != null && ctx.target.group === groupId && ctx.target.index >= items.length;

    function onKey(e: RKeyboardEvent, index: number) {
      if (e.key !== "ArrowUp" && e.key !== "ArrowDown") return;
      e.preventDefault();
      e.stopPropagation();
      const to = index + (e.key === "ArrowUp" ? -1 : 1);
      if (to < 0 || to >= ids.length) return;
      const next = ids.slice();
      const [moved] = next.splice(index, 1);
      next.splice(to, 0, moved);
      ctx.commitOrder(groupId, next);
    }

    function makeHandle(item: T) {
      return (
        <button
          type="button"
          draggable
          onDragStart={(e: RDragEvent) => {
            ctx.begin(item.id, groupId);
            e.dataTransfer.effectAllowed = "move";
            e.dataTransfer.setData("text/plain", item.id);
            const img = transparentImage();
            if (img) e.dataTransfer.setDragImage(img, 0, 0);
          }}
          onDragEnd={(e: RDragEvent) => ctx.end(e.dataTransfer.dropEffect !== "none")}
          onKeyDown={(e) => onKey(e, ids.indexOf(item.id))}
          onClick={(e: RMouseEvent) => {
            e.preventDefault();
            e.stopPropagation();
          }}
          aria-label={handleLabel ? handleLabel(item) : "Drag to reorder"}
          title="Drag to reorder or move; or focus and use the arrow keys"
          className={handleCls}
        >
          <IconGrip size={16} />
        </button>
      );
    }

    return (
      <div className={className} role="list">
        {items.map((item, index) => {
          const showLine =
            ctx.target != null &&
            ctx.target.group === groupId &&
            ctx.target.index === index;
          const dragging = ctx.activeId === item.id;
          return (
            <div key={item.id} role="listitem">
              {showLine && <Line />}
              <div
                onDragEnter={(e) => {
                  if (!active) return;
                  e.preventDefault();
                }}
                onDragOver={(e) => {
                  if (!active) return;
                  e.preventDefault();
                  e.dataTransfer.dropEffect = "move";
                  const rect = e.currentTarget.getBoundingClientRect();
                  const before = e.clientY - rect.top < rect.height / 2;
                  ctx.hover(groupId, before ? index : index + 1);
                }}
                className={dragging ? "opacity-60" : undefined}
              >
                {renderItem(item, { handle: makeHandle(item), dragging })}
              </div>
            </div>
          );
        })}

        <div
          onDragEnter={(e) => {
            if (!active) return;
            e.preventDefault();
          }}
          onDragOver={(e) => {
            if (!active) return;
            e.preventDefault();
            e.dataTransfer.dropEffect = "move";
            ctx.hover(groupId, items.length);
          }}
          className={
            items.length === 0 && active
              ? "rounded-lg border border-dashed border-gold/50 px-3 py-3 text-[11px] text-faint"
              : "h-2"
          }
        >
          {atEnd && <Line />}
          {items.length === 0 && active && (emptyHint ?? "Drop here")}
        </div>
      </div>
    );
  }

  function useHeaderDrop(groupId: string, endIndex: number) {
    const ctx = useBoard();
    const onDragOver = (e: RDragEvent) => {
      if (ctx.activeId == null) return;
      e.preventDefault();
      e.dataTransfer.dropEffect = "move";
      ctx.hover(groupId, endIndex);
    };
    const onDragEnter = (e: RDragEvent) => {
      if (ctx.activeId == null) return;
      e.preventDefault();
    };
    const isTarget =
      ctx.activeId != null &&
      ctx.fromGroup !== groupId &&
      ctx.target != null &&
      ctx.target.group === groupId;
    return { onDragOver, onDragEnter, isTarget };
  }

  function Pending() {
    const ctx = useBoard();
    if (!ctx.pending) return null;
    return (
      <div
        role="status"
        className="pointer-events-none flex items-center gap-1.5 pt-0.5 text-[11px] text-faint"
      >
        <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-gold" />
        Saving order
      </div>
    );
  }

  return { Board, Group, useHeaderDrop, Pending };
}

// One isolated board per level. Lessons can cross units; steps can cross
// lessons; units reorder within the single root group.
export const UnitsDnd = createSortable();
export const LessonsDnd = createSortable();
export const StepsDnd = createSortable();
