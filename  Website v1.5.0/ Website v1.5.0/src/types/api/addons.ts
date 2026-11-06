// Food addons: product -> group (one question) -> option (one answer).
// Shapes mirror /customer/product_by_id and /customer/cart responses.

export interface AddonOption {
  id: number;
  name: string;
  /** Per-store price after any offer. 0 = free. */
  price: number;
  /** Price before the offer; equal to price when there is no offer. */
  original_price: number;
  /** Diet mark on the product_type scale: 0 none, 1 veg, 2 non-veg, 4 egg. */
  product_type: number;
  /** Group's max_qty_per_option, lowered to real stock for a linked option. */
  max_qty: number;
  /** Always 1 — unservable options are dropped server-side. */
  in_stock: 0 | 1;
  /** 1 when the option is a real catalogue product. */
  is_linked: 0 | 1;
  /** Thumbnail, present mainly on linked options. */
  image?: string;
  linked_variant_id: number | null;
}

export interface AddonGroup {
  id: number;
  name: string;
  /** Rules as a translated sentence. Render as-is, never recompose. */
  selection_text: string;
  input_type: "radio" | "checkbox";
  is_required: 0 | 1;
  min_select: number;
  /** 0 = no limit. */
  max_select: number;
  /** Repeats of one option per unit of the dish. 1 = plain tick. */
  max_qty_per_option: number;
  options: AddonOption[];
}

/** What /cart/add and /cart/remove take: option ids only, never group ids. */
export interface AddonSelectionItem {
  id: number;
  /** Per unit of the dish, not the line total. */
  qty: number;
}

/** In-progress selection in the addon sheet, keyed by group id. */
export type AddonDraft = Record<number, Record<number, number>>;

/** One addon on a cart line or order item snapshot. */
export interface CartLineAddon {
  group_id: number;
  group_name: string;
  input_type: "radio" | "checkbox";
  option_id: number;
  option_name: string;
  qty: number;
  unit_price: number;
  /** What this option adds per unit of the dish. */
  line_price: number;
  /** 1 only when the admin priced the option at nothing. */
  is_free: 0 | 1;
  /** Linked options carry the catalogue product's image. */
  image?: string;
  /** 0 once the option stopped being servable. */
  available: 0 | 1;
  linked_variant_id: number | null;
}
