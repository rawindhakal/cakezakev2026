import React, { useState, useEffect, useLayoutEffect, useRef } from "react";
import { createPortal } from "react-dom";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import { ChevronRight } from "lucide-react";
import { t } from "@/utils/translation";

const getName = (c: any): string | undefined => c?.translations?.name ?? c?.name;
const childrenOf = (c: any): any[] =>
  Array.isArray(c?.cat_active_childs) ? c.cat_active_childs : [];

interface LeafPillProps {
  node: any;
  onSelect: (node: any) => void;
}

const LeafPill = ({ node, onSelect }: LeafPillProps) => (
  <button
    type="button"
    onClick={() => onSelect(node)}
    className="rounded-full border border-slate-200 bg-white/70 px-3 py-1 text-xs font-medium text-slate-600 backdrop-blur transition hover:primaryColorBorder hover:primaryColor hover:primaryLightBack dark:border-zinc-700 dark:bg-zinc-800/70 dark:text-zinc-300"
  >
    {getName(node)}
  </button>
);

interface SubTreeProps {
  nodes: any[];
  onSelect: (node: any) => void;
  depth?: number;
}

// Branches: heading + indented children. Leaves: pill row.
const SubTree = ({ nodes, onSelect, depth = 0 }: SubTreeProps) => {
  const leaves = nodes.filter((n) => childrenOf(n).length === 0);
  const branches = nodes.filter((n) => childrenOf(n).length > 0);

  return (
    <div className="flex flex-col gap-3">
      {leaves.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {leaves.map((leaf) => (
            <LeafPill key={leaf.id} node={leaf} onSelect={onSelect} />
          ))}
        </div>
      )}

      {branches.map((branch) => (
        <div
          key={branch.id}
          className={
            depth > 0
              ? "border-s-2 border-slate-100 ps-3 dark:border-zinc-800"
              : ""
          }
        >
          <button
            type="button"
            onClick={() => onSelect(branch)}
            className={`mb-2 self-start text-start transition-colors hover:primaryColor ${
              depth === 0
                ? "text-sm font-semibold text-slate-700 dark:text-zinc-200"
                : "text-[13px] font-medium text-slate-600 dark:text-zinc-300"
            }`}
          >
            {getName(branch)}
          </button>
          <SubTree
            nodes={childrenOf(branch)}
            onSelect={onSelect}
            depth={depth + 1}
          />
        </div>
      ))}
    </div>
  );
};

interface CategoryPanelProps {
  category: any;
  onSelect: (category: any) => void;
}

interface PopoverPosition {
  top: number;
  left: number;
}

// Category tile with an expandable subcategory tree.
const CategoryPanel = ({ category, onSelect }: CategoryPanelProps) => {
  const columns = childrenOf(category);
  const hasChildren = columns.length > 0;
  const [expanded, setExpanded] = useState(false);
  // Portals to <body> after mount — a transformed ancestor would trap
  // position: fixed.
  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMounted(true);
  }, []);

  // Popover left clamped to the viewport so edge cards don't overflow.
  const cardRef = useRef<HTMLDivElement>(null);
  const [pos, setPos] = useState<PopoverPosition | null>(null);
  const POPOVER_W = 256; // matches w-64

  useLayoutEffect(() => {
    if (!expanded || !cardRef.current) return;
    const measure = () => {
      const r = cardRef.current?.getBoundingClientRect();
      if (!r) return;
      const centered = r.left + r.width / 2 - POPOVER_W / 2;
      const left = Math.max(
        8,
        Math.min(centered, window.innerWidth - POPOVER_W - 8),
      );
      setPos({ top: r.bottom + 8, left });
    };
    measure();
    window.addEventListener("resize", measure);
    window.addEventListener("scroll", measure, true);
    return () => {
      window.removeEventListener("resize", measure);
      window.removeEventListener("scroll", measure, true);
    };
  }, [expanded]);

  return (
    <div
      ref={cardRef}
      data-expanded={expanded}
      className="categoryCardBackground group/card relative z-0 flex h-full min-h-[6.5rem] flex-col items-center justify-start gap-1 rounded-2xl px-2 pb-3 pt-10 text-center shadow-[0_0_20px_rgba(0,0,0,0.1)] transition-all duration-300 hover:-translate-y-0.5 hover:shadow-[0_0_28px_rgba(0,0,0,0.16)] dark:shadow-[0_0_20px_rgba(0,0,0,0.5)] sm:min-h-[8rem] sm:px-3 sm:pb-4 sm:pt-14"
    >
      <span className="pointer-events-none absolute -right-10 -top-10 h-28 w-28 rounded-full primaryLightBack opacity-60 blur-2xl transition-opacity duration-300 group-hover/card:opacity-100" />

      <button
        type="button"
        onClick={() => onSelect(category)}
        className="group/head flex w-full flex-col items-center"
      >
        <span className="absolute left-1/2 top-0 flex h-14 w-14 shrink-0 -translate-x-1/2 -translate-y-1/2 items-center justify-center transition-transform duration-300 group-hover/head:scale-105 group-hover/head:-translate-y-[55%] sm:h-20 sm:w-20">
          <ImageWithPlaceholder
            src={category.image_url}
            width={160}
            height={160}
            alt={getName(category) ?? "Category"}
            className="max-h-full max-w-full object-contain drop-shadow-md"
          />
        </span>

        <span className="min-w-0 max-w-full">
          <h2 className="truncate text-sm font-bold text-slate-900 transition-colors group-hover/head:primaryColor dark:text-zinc-50 sm:text-base">
            {getName(category)}
          </h2>
        </span>
      </button>

      {/* Overlay, not inline, so cards stay uniform size. */}
      {hasChildren && (
        <>
          <button
            type="button"
            onClick={() => setExpanded((v) => !v)}
            aria-expanded={expanded}
            className="mt-auto inline-flex max-w-full items-center justify-center gap-1 whitespace-nowrap rounded-full border border-slate-200 bg-white/60 px-3 py-1 text-[11px] font-semibold text-slate-600 backdrop-blur transition hover:primaryColorBorder hover:primaryColor dark:border-zinc-700 dark:bg-zinc-800/60 dark:text-zinc-300"
          >
            {expanded
              ? t("hide_subcategories") || "Hide"
              : t("show_subcategories") || "View all"}
            <ChevronRight
              className={`h-3.5 w-3.5 transition-transform duration-200 ${
                expanded ? "rotate-90" : ""
              }`}
            />
          </button>

          {/* Desktop popover. */}
          {expanded &&
            mounted &&
            pos &&
            createPortal(
              <div className="hidden sm:block">
                <button
                  type="button"
                  aria-label={t("close") || "Close"}
                  className="fixed inset-0 z-30 cursor-default"
                  onClick={() => setExpanded(false)}
                />
                <div
                  className="categoryDropdownIn categoryCardBackground fixed z-40 max-h-72 w-64 overflow-y-auto rounded-2xl border border-slate-200/70 p-4 text-start shadow-xl dark:border-zinc-800"
                  style={{ top: pos.top, left: pos.left }}
                >
                  <SubTree nodes={columns} onSelect={onSelect} />
                </div>
              </div>,
              document.body,
            )}

          {/* Mobile centered sheet. */}
          {expanded &&
            mounted &&
            createPortal(
              <div className="sm:hidden">
                <button
                  type="button"
                  aria-label={t("close") || "Close"}
                  className="fixed inset-0 z-[70] cursor-default bg-black/40 animate-in fade-in-0"
                  onClick={() => setExpanded(false)}
                />
                <div
                  role="dialog"
                  aria-modal="true"
                  aria-label={getName(category) ?? "Category"}
                  className="categoryCardBackground fixed inset-x-4 top-1/2 z-[71] max-h-[70vh] max-w-sm mx-auto -translate-y-1/2 overflow-y-auto rounded-2xl border border-slate-200/70 p-4 text-start shadow-2xl animate-in fade-in-0 zoom-in-95 dark:border-zinc-800"
                >
                  <SubTree nodes={columns} onSelect={onSelect} />
                </div>
              </div>,
              document.body,
            )}
        </>
      )}
    </div>
  );
};

export default CategoryPanel;
