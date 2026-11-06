import { t } from "@/utils/translation";
import type {
  AddonDraft,
  AddonGroup,
  AddonOption,
  AddonSelectionItem,
} from "@/types/api/addons";

/** A product only asks questions when it is food and has at least one group. */
export const hasAddonGroups = (product: any): boolean =>
  Array.isArray(product?.addon_groups) && product.addon_groups.length > 0;

/** Listing cards carry has_addons instead of the groups themselves. */
export const cardHasAddons = (product: any): boolean =>
  product?.has_addons === true || Number(product?.has_addons) === 1;

export const optionQty = (draft: AddonDraft, groupId: number, optionId: number): number =>
  draft?.[groupId]?.[optionId] ?? 0;

/** Count of different options picked in one group, not their quantities. */
export const groupPickCount = (draft: AddonDraft, groupId: number): number =>
  Object.values(draft?.[groupId] ?? {}).filter((qty) => qty > 0).length;

export const isGroupFull = (group: AddonGroup, draft: AddonDraft): boolean =>
  group.max_select > 0 && groupPickCount(draft, group.id) >= group.max_select;

/** Radio is always exactly one pick, whatever the numbers say. */
export const setRadioPick = (
  draft: AddonDraft,
  group: AddonGroup,
  optionId: number,
): AddonDraft => ({ ...draft, [group.id]: { [optionId]: 1 } });

export const setOptionQty = (
  draft: AddonDraft,
  group: AddonGroup,
  option: AddonOption,
  qty: number,
): AddonDraft => {
  const capped = Math.max(0, Math.min(qty, option.max_qty || 1));
  const next = { ...(draft?.[group.id] ?? {}) };
  if (capped === 0) delete next[option.id];
  else next[option.id] = capped;
  return { ...draft, [group.id]: next };
};

/** Required groups open with their first option(s) already picked. */
export const defaultAddonDraft = (groups: AddonGroup[]): AddonDraft =>
  (groups ?? []).reduce<AddonDraft>((draft, group) => {
    if (group.is_required !== 1) return draft;
    const wanted =
      group.input_type === "radio"
        ? 1
        : Math.max(group.min_select || 1, 1);
    const capped = group.max_select > 0 ? Math.min(wanted, group.max_select) : wanted;
    const picks = (group.options ?? []).slice(0, capped);
    if (!picks.length) return draft;
    draft[group.id] = Object.fromEntries(picks.map((option) => [option.id, 1]));
    return draft;
  }, {});

/** A cart row's picks back as an editable draft, dropping options that went away. */
export const draftFromLine = (groups: AddonGroup[], row: any): AddonDraft => {
  const draft: AddonDraft = {};
  (row?.addons ?? []).forEach((addon: any) => {
    const group = (groups ?? []).find((item) => item.id === addon?.group_id);
    const option = (group?.options ?? []).find(
      (item) => item.id === addon?.option_id,
    );
    if (!group || !option) return;
    draft[group.id] = {
      ...(draft[group.id] ?? {}),
      [option.id]: Math.max(1, Number(addon?.qty) || 1),
    };
  });
  return draft;
};

/** Option ids and quantities for /cart/add and /cart/remove. */
export const toAddonPayload = (draft: AddonDraft): AddonSelectionItem[] =>
  Object.values(draft ?? {})
    .flatMap((options) =>
      Object.entries(options ?? {}).map(([id, qty]) => ({ id: Number(id), qty })),
    )
    .filter((item) => item.qty > 0)
    .sort((a, b) => a.id - b.id);

/** Stable key telling two lines of the same variant apart in local state. */
export const addonFingerprint = (items: AddonSelectionItem[] = []): string =>
  [...items]
    .sort((a, b) => a.id - b.id)
    .map((item) => `${item.id}x${item.qty}`)
    .join("|");

/** Addon money per unit of the dish. Every pick is charged on its own. */
export const addonUnitTotal = (groups: AddonGroup[], draft: AddonDraft): number =>
  (groups ?? []).reduce(
    (total, group) =>
      total +
      (group.options ?? []).reduce(
        (sum, option) =>
          sum + option.price * optionQty(draft, group.id, option.id),
        0,
      ),
    0,
  );

/**
 * The four client-side checks from the API doc. Returns a message to show, or
 * null when the selection can be sent. The server re-checks either way.
 */
export const validateAddonDraft = (
  groups: AddonGroup[],
  draft: AddonDraft,
): string | null => {
  for (const group of groups ?? []) {
    const picks = groupPickCount(draft, group.id);

    if (group.is_required === 1 && picks === 0) {
      return `${t("addon_choose_option_for")} ${group.name}`;
    }
    if (group.input_type === "radio" && picks > 1) {
      return t("addon_only_one_option");
    }
    if (picks > 0 && picks < (group.min_select || 0)) {
      return `${t("addon_choose_at_least")} ${group.min_select}`;
    }
    if (group.max_select > 0 && picks > group.max_select) {
      return t("addon_too_many_options");
    }
    for (const option of group.options ?? []) {
      if (optionQty(draft, group.id, option.id) > (option.max_qty || 1)) {
        return t("addon_too_many_of_one_option");
      }
    }
  }
  return null;
};

/**
 * Cart-line shaped picks, so a guest row carries the same addon detail a
 * server row does and both render through one component.
 */
export const draftToLineAddons = (groups: AddonGroup[], draft: AddonDraft) =>
  (groups ?? []).flatMap((group) =>
    (group.options ?? [])
      .filter((option) => optionQty(draft, group.id, option.id) > 0)
      .map((option) => {
        const qty = optionQty(draft, group.id, option.id);
        return {
          group_id: group.id,
          group_name: group.name,
          input_type: group.input_type,
          option_id: option.id,
          option_name: option.name,
          qty,
          unit_price: option.price,
          line_price: option.price * qty,
          // Nothing but an admin-set price of 0 makes an option free.
          is_free: option.price === 0 ? 1 : 0,
          available: 1,
          linked_variant_id: option.linked_variant_id,
        };
      }),
  );

/** One-line recap of a line's picks, for the repeat prompt. */
export const addonSummary = (row: any): string =>
  (row?.addons ?? [])
    .map((addon: any) =>
      addon?.qty > 1 ? `${addon.qty} × ${addon.option_name}` : addon?.option_name,
    )
    .filter(Boolean)
    .join(", ");

/** Every cart line of one product, server or guest, newest last. */
export const productCartLines = (cart: any, productId: any): any[] => {
  const rows = cart?.isGuest ? cart?.guestCart : cart?.cartProducts;
  return (rows ?? []).filter((row: any) => row?.product_id == productId);
};

/** Dish quantity across all of a product's lines, whatever their picks. */
export const productCartQty = (cart: any, productId: any): number =>
  productCartLines(cart, productId).reduce(
    (total: number, row: any) => total + (Number(row?.qty) || 0),
    0,
  );

/**
 * A cart row's own picks, in the shape /cart/add and /cart/remove take. Sent
 * on every mutation of that row so the server hits the right line when the
 * same product sits in the cart more than once.
 */
export const lineAddonPayload = (row: any): AddonSelectionItem[] =>
  (row?.addons ?? [])
    .map((addon: any) => ({ id: addon?.option_id, qty: addon?.qty }))
    .filter((item: AddonSelectionItem) => item.id != null && item.qty > 0)
    .sort((a: AddonSelectionItem, b: AddonSelectionItem) => a.id - b.id);

/**
 * React key for a cart row. Two lines of the same product and variant differ
 * only by their picks, so the variant id alone collides.
 */
export const cartLineKey = (row: any): string => {
  const picks = (row?.addons ?? [])
    .map((addon: any) => `${addon?.option_id}x${addon?.qty}`)
    .sort()
    .join("|");
  return `${row?.product_variant_id ?? row?.variant_id ?? row?.id}:${picks}`;
};

/**
 * The cart row matching one line. Falls back to the variant when the stored
 * rows carry no picks, so an older row shape never reads as quantity 0.
 */
export const findCartLine = (rows: any[] = [], row: any): any => {
  const key = cartLineKey(row);
  const exact = (rows ?? []).find((item: any) => cartLineKey(item) == key);
  if (exact) return exact;
  const variantId = row?.product_variant_id ?? row?.variant_id;
  const sameVariant = (rows ?? []).filter(
    (item: any) => (item?.product_variant_id ?? item?.variant_id) == variantId,
  );
  return sameVariant.length === 1 ? sameVariant[0] : undefined;
};

/**
 * guest_cart's items parameter. The legacy variant_ids/quantities CSV pair
 * cannot hold a per-item addon list, so rows go as JSON instead.
 */
export const guestCartItemsParam = (rows: any[] = []): string =>
  JSON.stringify(
    rows.map((row) => ({
      variant_id: row?.product_variant_id,
      qty: row?.qty,
      addons: Array.isArray(row?.addons) ? row.addons : [],
    })),
  );

/**
 * bulk_add_to_cart_items rows. Its addons array is option ids, an id repeated
 * to mean two of it, so {id,qty} pairs expand.
 */
export const bulkCartItems = (rows: any[] = []) =>
  rows.map((row) => {
    const addons = (row?.addons ?? []).flatMap((addon: any) => {
      const id = addon?.option_id ?? addon?.id;
      const qty = Number(addon?.qty) || 0;
      return id == null ? [] : Array.from({ length: qty }, () => Number(id));
    });
    const item: Record<string, any> = {
      variant_id: row?.product_variant_id ?? row?.variant_id,
      qty: row?.qty ?? row?.quantity,
    };
    if (addons.length > 0) item.addons = addons;
    return item;
  });

/** Any row carrying addons forces the items form of a bulk call. */
export const rowsHaveAddons = (rows: any[] = []): boolean =>
  rows.some((row) => Array.isArray(row?.addons) && row.addons.length > 0);

/** Any guest row carrying addons forces the items parameter. */
export const guestRowsHaveAddons = (rows: any[] = []): boolean =>
  rows.some((row) => Array.isArray(row?.addons) && row.addons.length > 0);
