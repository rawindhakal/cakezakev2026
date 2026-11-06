"use client";

import React, { useRef, useState } from "react";
import Image from "next/image";
import { useDispatch } from "react-redux";
import { useRouter } from "next/navigation";
import {
  setListingSource,
  setCategorySlug,
  setCategoryBreadcrumb,
  setBlockSource,
} from "@/redux/slices/productFilterSlice";
import { toCssRadius, pickDeviceImage, pickDeviceNumber, toCssAspectRatio } from "@/utils/helperFunction";
import { resolveIdCsvToSlugCsv } from "@/utils/categorySlugResolver";
import useZoneHref from "@/hooks/useZoneHref";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useNavClick from "@/hooks/useNavClick";
import useProductsRedirect from "@/hooks/useProductsRedirect";

interface GridBannerSectionProps {
  block: any;
  borderRadius?: string | number;
  device?: string;
  priority?: boolean;
  // Resolves category tree for navigation.
  resolveCategoryTree?: () => Promise<any[]>;
}

const GridBannerSection = ({
  block,
  borderRadius,
  device = "web",
  priority = false,
  resolveCategoryTree,
}: GridBannerSectionProps) => {
  const zoneHref = useZoneHref();
  const { buildQueryPatch } = useUrlProductFilters();
  const openProductsRedirect = useProductsRedirect(resolveCategoryTree);
  const router = useRouter();
  const dispatch = useDispatch();
  const { run: runNavClick } = useNavClick();

  const config = block?.config || {};
  const items = (block?.items || []).filter(
    (item: any) => pickDeviceImage(item?.images, device, item?.image_url)
  );

  const gridGap = pickDeviceNumber(config?.grid_gap, device, 0);
  const scrolls = ["scroll", "horizontal"].includes(
    String(config?.grid_layout_type || "").toLowerCase()
  );
  const rows = Math.max(1, pickDeviceNumber(config?.grid_rows, device, 1));
  const configColumns = Math.max(
    1,
    pickDeviceNumber(config?.grid_columns, device, 0) ||
      pickDeviceNumber(config?.columns, device, 0) ||
      2
  );
  const columns = configColumns;
  const tileRadius = toCssRadius(config?.tile_radius);
  const imageAspectRaw =
    config?.image_aspect && typeof config.image_aspect === "object"
      ? pickDeviceImage(config.image_aspect, device)
      : config?.image_aspect;
  const aspectRatio = toCssAspectRatio(imageAspectRaw) ?? null;

  const variant = config?.variant;
  const isDefault = !variant || variant === "default";
  const isColorVariant = variant === "with_color";
  const title = isDefault ? null : config?.section_title || null;

  const bgImageUrl =
    config?.background_image_url && typeof config.background_image_url === "object"
      ? pickDeviceImage(config.background_image_url, device)
      : config?.background_image_url;
  const hasBg =
    !isDefault && variant !== "with_title" && variant !== "with_color"
      ? !!bgImageUrl
      : false;

  const backgroundColor = isColorVariant ? config?.background_color || null : null;
  const textColor = isDefault ? null : config?.text_color || null;

  const blockPadding = Number.isFinite(Number(config?.block_padding))
    ? Number(config.block_padding)
    : 0;
  const blockPaddingStyle = {
    paddingTop: blockPadding,
    paddingBottom: blockPadding,
    paddingLeft: blockPadding,
    paddingRight: blockPadding,
  };

  const bgAspectPadding = (() => {
    if (!hasBg) return undefined;
    const bgAspectRaw =
      config?.bg_image_aspect && typeof config.bg_image_aspect === "object"
        ? pickDeviceImage(config.bg_image_aspect, device)
        : config?.bg_image_aspect;
    const ratio = toCssAspectRatio(bgAspectRaw);
    if (!ratio) return undefined;
    const [w, h] = ratio.split("/").map((n: string) => Number(n.trim()));
    if (!w || !h) return undefined;
    return `${(h / w) * 100}%`;
  })();

  const scrollerRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef({
    active: false,
    startX: 0,
    startScroll: 0,
    moved: 0,
    pointerId: undefined as number | undefined,
  });
  const [dragging, setDragging] = useState(false);

  const onPointerDown = (event: React.PointerEvent) => {
    if (event.button !== 0) return;
    const el = scrollerRef.current;
    if (!el) return;
    if (event.pointerType === "touch") return;
    dragRef.current = {
      active: true,
      startX: event.clientX,
      startScroll: el.scrollLeft,
      moved: 0,
      pointerId: event.pointerId,
    };
  };

  const onPointerMove = (event: React.PointerEvent) => {
    const drag = dragRef.current;
    const el = scrollerRef.current;
    if (!drag.active || !el) return;
    event.preventDefault();
    const delta = event.clientX - drag.startX;
    const wasDragging = drag.moved > 5;
    drag.moved = Math.max(drag.moved, Math.abs(delta));
    if (!wasDragging && drag.moved > 5) {
      event.currentTarget.setPointerCapture?.(event.pointerId);
      setDragging(true);
    }
    el.scrollLeft = drag.startScroll - delta;
  };

  const endDrag = (event?: React.PointerEvent) => {
    const drag = dragRef.current;
    if (!drag.active) return;
    drag.active = false;
    if (
      drag.pointerId != null &&
      event?.currentTarget?.hasPointerCapture?.(drag.pointerId)
    ) {
      event.currentTarget.releasePointerCapture(drag.pointerId);
    }
    setDragging(false);
  };

  const onClickCapture = (event: React.MouseEvent) => {
    if (dragRef.current.moved > 5) {
      event.preventDefault();
      event.stopPropagation();
    }
    dragRef.current.moved = 0;
  };

  const navigate = async (item: any) => {
    if (item?.redirect_type === "url" && item?.redirect_url) {
      window.open(item.redirect_url, "_blank");
    } else if (item?.redirect_type === "product" && item?.redirect_slug) {
      router.push(zoneHref(`/product/${item.redirect_slug}`));
    } else if (item?.redirect_type === "category" && item?.redirect_id) {
      let slug = item?.redirect_slug || "";
      if (!slug) {
        const tree = await resolveCategoryTree?.().catch(() => []);
        slug =
          resolveIdCsvToSlugCsv(tree || [], item.redirect_id.toString()) ||
          item.redirect_id.toString();
      }
      dispatch(setListingSource({ data: "category" }));
      dispatch(setCategorySlug({ data: slug }));
      dispatch(setCategoryBreadcrumb({ data: [] }));
      dispatch(setBlockSource());
      const qs = new URLSearchParams(
        buildQueryPatch({ category_id: slug }),
      ).toString();
      const dest = zoneHref("/products");
      router.push(qs ? `${dest}?${qs}` : dest);
    } else if (item?.redirect_type === "brand" && item?.redirect_id) {
      const qs = new URLSearchParams(
        buildQueryPatch({ brand_ids: [Number.parseInt(item.redirect_id, 10)] }),
      ).toString();
      const dest = zoneHref("/products");
      router.push(qs ? `${dest}?${qs}` : dest);
    } else if (item?.redirect_type === "products") {
      await openProductsRedirect(item);
    } else if (item?.redirect_type === "page" && item?.redirect_slug) {
      router.push(zoneHref(`/page/${item.redirect_slug}`));
    }
  };

  const handleClick = (item: any, index: number) =>
    runNavClick(() => navigate(item), index);

  if (items.length === 0) return null;

  const renderPanel = (children: React.ReactNode) => (
    <div
      className="relative overflow-hidden"
      style={{
        borderRadius,
        ...(hasBg
          ? {
              backgroundImage: `url(${bgImageUrl})`,
              backgroundSize: "cover",
              backgroundPosition: "center",
              backgroundRepeat: "no-repeat",
            }
          : {}),
        ...(backgroundColor ? { backgroundColor } : {}),
        ...(textColor ? { color: textColor } : {}),
      }}
    >
      {bgAspectPadding && (
        <div
          aria-hidden
          className="float-left w-0"
          style={{ paddingTop: bgAspectPadding }}
        />
      )}
      <div className="relative" style={blockPaddingStyle}>
        {title && (
          <h2
            className={`text-xl sm:text-3xl font-extrabold leading-[1.1] m-0 mb-3 ${
              textColor ? "" : "text-gray-900 dark:text-zinc-100"
            }`}
            style={textColor ? { color: textColor } : undefined}
          >
            {title}
          </h2>
        )}
        {children}
      </div>
    </div>
  );

  const renderTile = (item: any, index: number) => {
    const src = pickDeviceImage(item?.images, device, item?.image_url);
    const clickable =
      (item?.redirect_type === "url" && item?.redirect_url) ||
      (item?.redirect_type === "product" && item?.redirect_slug) ||
      (item?.redirect_type === "category" && item?.redirect_id) ||
      (item?.redirect_type === "brand" && item?.redirect_id) ||
      (item?.redirect_type === "page" && item?.redirect_slug) ||
      // An all-blank filter set is valid: it opens the unfiltered listing.
      item?.redirect_type === "products";
    return (
      <button
        key={index}
        type="button"
        disabled={!clickable}
        className={`relative w-full overflow-hidden border-0 bg-transparent p-0 text-left disabled:cursor-default ${
          scrolls ? "snap-start" : ""
        } ${clickable ? "cursor-pointer" : ""}`}
        style={{ borderRadius: tileRadius, ...(aspectRatio ? { aspectRatio } : {}) }}
        onClick={() => handleClick(item, index)}
      >
        <Image
          src={src}
          alt="Grid banner image"
          // Disable native image drag — it hijacks drag-to-scroll.
          draggable={false}
          onDragStart={(event: React.DragEvent) => event.preventDefault()}
          priority={priority && index === 0}
          className={`w-full ${aspectRatio ? "h-full object-cover" : "h-auto object-contain"}`}
          width={1920}
          height={1920}
          sizes={`(max-width: 768px) ${Math.round(100 / columns)}vw, ${Math.round(1280 / columns)}px`}
          quality={75}
        />
      </button>
    );
  };

  // Horizontal scrolling strip or CSS grid layout.
  if (scrolls) {
    return (
      <section>
        {renderPanel(
        <div className="relative">
          <div
            ref={scrollerRef}
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={endDrag}
            onPointerCancel={endDrag}
            onClickCapture={onClickCapture}
            className={`grid grid-flow-col overflow-x-auto overscroll-x-contain touch-pan-x touch-pan-y select-none [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden ${
              dragging ? "cursor-grabbing" : "cursor-grab"
            }`}
            style={{
              gridTemplateRows: `repeat(${rows}, minmax(0, auto))`,
              gridAutoColumns: `calc((100% - ${(columns - 1) * gridGap}px) / ${columns})`,
              gap: gridGap,
            }}
          >
            {items.map(renderTile)}
          </div>
        </div>
        )}
      </section>
    );
  }

  return (
    <section>
      {renderPanel(
        <div
          className="grid"
          style={{
            gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))`,
            gap: gridGap,
          }}
        >
          {items.map(renderTile)}
        </div>
      )}
    </section>
  );
};

export default React.memo(GridBannerSection);
