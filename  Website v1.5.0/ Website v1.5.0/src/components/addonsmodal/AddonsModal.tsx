import { useEffect, useMemo, useRef, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "react-toastify";
import { RiCloseFill } from "react-icons/ri";
import {
  Dialog as DialogRaw,
  DialogContent as DialogContentRaw,
} from "@/components/ui/dialog";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";
import * as api from "@/api/apiRoutes";
import { t } from "@/utils/translation";
import useCurrency from "@/hooks/useCurrency";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import AddonGroupsList from "./AddonGroupsList";
import useHydratedMediaQuery from "@/hooks/useHydratedMediaQuery";
import { flyToCart } from "@/utils/flyToCart";
import {
  addGuestCartTotal,
  addtoGuestCart,
  setCart,
  setCartProducts,
  setCartSubTotal,
} from "@/redux/slices/cartSlice";
import {
  addonFingerprint,
  addonUnitTotal,
  defaultAddonDraft,
  draftToLineAddons,
  toAddonPayload,
  validateAddonDraft,
} from "@/utils/addons";
import type { AddonDraft, AddonGroup, AddonOption } from "@/types/api/addons";

// dialog.tsx exports are untyped forwardRef components, so TS infers overly
// narrow prop types. Same cast VariantsModal uses.
const Dialog = DialogRaw as any;
const DialogContent = DialogContentRaw as any;

interface AddonsModalProps {
  /** Card row or full product — shapes vary, no shared exported type yet. */
  product: any;
  showAddons: boolean;
  setShowAddons: (show: boolean) => void;
  /** Variant the caller already picked; defaults to the first in-stock one. */
  variant?: any;
  /** Dish quantity to add, 1 unless the caller is a detail-page stepper. */
  qty?: number;
  /** Runs after the line actually reaches the cart, not on open. */
  onAdded?: (response?: any) => void;
  /** Opened over another dialog: that one already dims the page. */
  stacked?: boolean;
}

const AddonsModal = ({
  product,
  showAddons,
  setShowAddons,
  variant,
  qty = 1,
  onAdded,
  stacked = false,
}: AddonsModalProps) => {
  const dispatch = useDispatch();
  const cart = useSelector((state: any) => state.Cart);
  const city = useSelector((state: any) => state.City.city);
  const isMobile = useHydratedMediaQuery("(max-width: 767px)") === true;
  const { currency: liveCurrency } = useCurrency();
  const currency = product?.currency || liveCurrency;

  const [groups, setGroups] = useState<AddonGroup[]>(product?.addon_groups ?? []);
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [draft, setDraft] = useState<AddonDraft>({});
  const addButtonRef = useRef<HTMLButtonElement>(null);

  const variants = product?.variants ?? [];
  const [pickedVariant, setPickedVariant] = useState<any>(null);
  const activeVariant = useMemo(
    () => pickedVariant ?? variant ?? variants[0],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [pickedVariant, variant, product?.variants],
  );

  // Listing cards only carry has_addons, so the groups are fetched on open.
  // Same coordinates as the add call below — the store decides which options
  // exist and what they cost.
  useEffect(() => {
    if (!showAddons) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- resets the selection whenever the sheet opens (or opens for a different product)
    setPickedVariant(null);
    if (product?.addon_groups?.length) {
      setGroups(product.addon_groups);
      setDraft(defaultAddonDraft(product.addon_groups));
      return;
    }
    setDraft({});
    let cancelled = false;
    setLoading(true);
    api
      .getProductById({
        id: product?.id,
        latitude: city?.latitude,
        longitude: city?.longitude,
      })
      .then((response: any) => {
        if (cancelled) return;
        const row = Array.isArray(response?.data) ? response.data[0] : response?.data;
        const fetched = row?.addon_groups ?? [];
        setGroups(fetched);
        setDraft(defaultAddonDraft(fetched));
      })
      .catch((error: any) => console.log("addon groups error", error))
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [product?.id, showAddons]);

  const unitAddonTotal = addonUnitTotal(groups, draft);
  const variantPrice =
    activeVariant?.discounted_price && activeVariant?.discounted_price !== 0
      ? activeVariant.discounted_price
      : activeVariant?.price;
  // Display only — the server folds addon money into the line price itself.
  const lineTotal = ((Number(variantPrice) || 0) + unitAddonTotal) * qty;

  const close = () => setShowAddons(false);

  // Same label rule VariantsModal uses.
  const variantLabel = (row: any) => {
    const at = row?.attributes_text;
    if (at && Number.isNaN(Number(at))) return at;
    const tail = row?.name?.split("||").pop()?.trim();
    return (
      tail ||
      `${row?.measurement ?? ""} ${row?.unit?.translations?.short_code ?? row?.unit?.short_code ?? ""}`.trim() ||
      row?.name
    );
  };

  const addGuestLine = (addons: ReturnType<typeof toAddonPayload>) => {
    const row = {
      product_id: product?.id,
      product_variant_id: activeVariant?.id,
      qty,
      productPrice: (Number(variantPrice) || 0) + unitAddonTotal,
      // Cart-line shape, so a guest row renders like a server row.
      addons: draftToLineAddons(groups, draft),
      addon_total: unitAddonTotal * qty,
      // Two lines of the same variant differ only by their picks.
      addon_fingerprint: addonFingerprint(addons),
    };
    dispatch(addtoGuestCart({ data: [...(cart?.guestCart ?? []), row] }));
    dispatch(addGuestCartTotal({ data: row.productPrice * qty }));
    toast.success(t("product_added_successfully"));
    launchFlight();
    close();
    onAdded?.();
  };

  // Fired while the sheet is still mounted — flyToCart measures the hero image
  // at call time, so closing first would leave nothing to fly.
  const launchFlight = () => {
    flyToCart(addButtonRef.current, "[data-addon-fly-image]");
  };

  const syncServerCart = (response: any) => {
    const serverCart = response?.data?.cart?.map((item: any) => ({
      product_id: item?.id,
      product_variant_id: item?.variant_id,
      addons: item?.addons ?? [],
      qty: item?.variants?.[0]?.quantity ?? item?.quantity,
    }));
    dispatch(setCart({ data: response }));
    dispatch(setCartProducts({ data: serverCart ?? [] }));
    dispatch(setCartSubTotal({ data: response?.data?.sub_total }));
  };

  const handleAdd = async () => {
    const error = validateAddonDraft(groups, draft);
    if (error) {
      toast.error(error);
      return;
    }
    const addons = toAddonPayload(draft);
    if (cart?.isGuest) {
      addGuestLine(addons);
      return;
    }
    setSubmitting(true);
    try {
      const response = await api.addToCart({
        product_id: product?.id,
        product_variant_id: activeVariant?.id,
        qty,
        latitude: city?.latitude,
        longitude: city?.longitude,
        addons,
      });
      // A rejected add is still HTTP 200 — check status, not the code.
      if (response?.status === 1) {
        syncServerCart(response);
        toast.success(t("product_added_successfully"));
        launchFlight();
        close();
        onAdded?.(response);
      } else {
        toast.error(response?.message);
      }
    } catch (err) {
      console.log("addon add to cart error", err);
    } finally {
      setSubmitting(false);
    }
  };

  const body = (
    <div className="min-h-0 flex-1 overflow-y-auto custom-scrollbar px-4 pb-4 pt-4 md:px-6">
      {variants.length > 1 && (
        <div className="pb-4">
          <div className="mb-2 text-sm font-semibold text-gray-500">
            {t("variants")}
          </div>
          <div className="flex flex-wrap gap-2">
            {variants.map((row: any) => (
              <button
                key={row?.id}
                type="button"
                onClick={() => setPickedVariant(row)}
                className={`rounded-lg border px-3 py-1.5 text-xs font-medium capitalize transition ${
                  row?.id === activeVariant?.id
                    ? "primaryColorBorder primaryLightBack primaryColor"
                    : "border-gray-100 dark:border-zinc-800 textColor hover:border-gray-200 dark:hover:border-zinc-700"
                }`}
              >
                {variantLabel(row)}
              </button>
            ))}
          </div>
        </div>
      )}

      <AddonGroupsList
        groups={groups}
        draft={draft}
        setDraft={setDraft}
        currency={currency}
        loading={loading}
      />
    </div>
  );

  // Mirrors VariantsModal's bottom bar: price on the left, action on the right.
  const footer = (
    <div className="flex shrink-0 items-center justify-between gap-4 border-t border-gray-100 bg-white px-4 py-4 dark:border-zinc-800 dark:bg-zinc-900 md:px-6">
      <div className="flex min-w-0 flex-col gap-0.5">
        <span className="text-xs text-gray-500">{t("total")}</span>
        <span className="truncate text-xl font-bold primaryColor">
          {currency}
          {lineTotal}
        </span>
      </div>
      <button
        ref={addButtonRef}
        type="button"
        onClick={handleAdd}
        disabled={submitting || loading}
        className="h-11 shrink-0 rounded-lg primaryBackColor px-6 text-sm font-bold uppercase text-white transition active:scale-95 disabled:opacity-60"
      >
        {t("add_to_cart")}
      </button>
    </div>
  );

  // product rows carry the variant label in name; product_name is the dish.
  const title =
    product?.translations?.name ?? product?.product_name ?? product?.name;

  const heroImage =
    activeVariant?.image ??
    product?.images?.[0]?.image_url ??
    product?.image_url;

  const hasVariantDiscount =
    activeVariant?.discounted_price !== 0 &&
    activeVariant?.discounted_price !== activeVariant?.price;

  if (isMobile) {
    return (
      <Sheet open={showAddons} onOpenChange={(open: boolean) => !open && close()}>
        <SheetContent
          side="bottom"
          className={`flex max-h-[85dvh] flex-col gap-0 overflow-hidden rounded-t-3xl border-0 bg-white p-0 duration-300 dark:bg-zinc-900 ${
            stacked ? "z-[61]" : ""
          }`}
        >
          <div className="flex justify-center pt-2.5 pb-1">
            <span className="h-1 w-10 rounded-full bg-gray-300 dark:bg-zinc-700" />
          </div>
          <SheetTitle className="flex items-center gap-3 px-4 pb-3 pt-2 text-start">
            <span
              data-addon-fly-image
              className="h-14 w-14 shrink-0 overflow-hidden rounded-xl border border-gray-100 bg-gray-50 dark:border-zinc-800 dark:bg-zinc-800"
            >
              <ImageWithPlaceholder
                src={heroImage}
                alt={title}
                width={96}
                height={96}
                className="h-full w-full object-contain"
              />
            </span>
            <span className="min-w-0 flex-1">
              <span className="line-clamp-1 text-base font-bold capitalize textColor">
                {title}
              </span>
              <span className="mt-0.5 flex items-baseline gap-1.5">
                <span className="text-sm font-semibold textColor">
                  {currency}
                  {variantPrice}
                </span>
                {hasVariantDiscount && (
                  <span className="text-xs text-gray-400 line-through">
                    {currency}
                    {activeVariant?.price}
                  </span>
                )}
              </span>
            </span>
          </SheetTitle>
          {body}
          {footer}
        </SheetContent>
      </Sheet>
    );
  }

  return (
    <Dialog open={showAddons} onOpenChange={(open: boolean) => !open && close()}>
      <DialogContent
        className={`flex max-h-[85vh] max-w-lg flex-col gap-0 overflow-hidden p-0 duration-300 ${
          stacked ? "z-[61]" : ""
        }`}
        overlayClassName={stacked ? "bg-transparent backdrop-blur-0" : undefined}
        title={title}
      >
        {/* compact header — thumb beside the dish, no letterboxed hero */}
        <div className="relative flex shrink-0 items-center gap-3 border-b border-gray-100 px-4 py-4 pe-14 dark:border-zinc-800 md:px-6 md:pe-14">
          <span
            data-addon-fly-image
            className="h-16 w-16 shrink-0 overflow-hidden rounded-xl border border-gray-100 bg-gray-50 dark:border-zinc-800 dark:bg-zinc-800"
          >
            <ImageWithPlaceholder
              src={heroImage}
              alt={title}
              width={160}
              height={160}
              className="h-full w-full object-cover"
            />
          </span>
          <div className="min-w-0 flex-1">
            <div className="line-clamp-2 text-base font-bold capitalize textColor">
              {title}
            </div>
            <div className="mt-0.5 flex items-baseline gap-1.5">
              <span className="text-sm font-semibold textColor">
                {currency}
                {variantPrice}
              </span>
              {hasVariantDiscount && (
                <span className="text-xs text-gray-400 line-through">
                  {currency}
                  {activeVariant?.price}
                </span>
              )}
            </div>
          </div>
          <button
            type="button"
            aria-label={t("close")}
            onClick={close}
            className="absolute end-3 top-3 flex h-8 w-8 items-center justify-center rounded-full text-gray-500 transition hover:bg-gray-100 dark:hover:bg-zinc-800"
          >
            <RiCloseFill size={20} />
          </button>
        </div>

        {body}
        {footer}
      </DialogContent>
    </Dialog>
  );
};

export default AddonsModal;
