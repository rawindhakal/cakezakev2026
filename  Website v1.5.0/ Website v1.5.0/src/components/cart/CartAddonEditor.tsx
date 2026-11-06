import { useEffect, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "react-toastify";
import * as api from "@/api/apiRoutes";
import { t } from "@/utils/translation";
import AddonGroupsList from "../addonsmodal/AddonGroupsList";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import {
  addtoGuestCart,
  setCart,
  setCartProducts,
  setCartSubTotal,
  setGuestCartTotal,
} from "@/redux/slices/cartSlice";
import {
  addonFingerprint,
  addonUnitTotal,
  cartLineKey,
  draftFromLine,
  draftToLineAddons,
  lineAddonPayload,
  toAddonPayload,
  validateAddonDraft,
} from "@/utils/addons";
import type { AddonDraft, AddonGroup } from "@/types/api/addons";

interface CartAddonEditorProps {
  /** Cart row being re-customised; its picks seed the screen. */
  line: any;
  money: (value: number) => string;
  onBack: () => void;
  /** Server edits hand back the latest cart; guest edits hand back the rows. */
  onSaved: (payload?: any) => void;
}

// Full-screen step inside the cart drawer — the row's picks are changed here
// and the drawer returns to the cart once they are saved.
const CartAddonEditor = ({
  line,
  money,
  onBack,
  onSaved,
}: CartAddonEditorProps) => {
  const dispatch = useDispatch();
  const cart = useSelector((state: any) => state.Cart);
  const city = useSelector((state: any) => state.City.city);

  const [groups, setGroups] = useState<AddonGroup[]>([]);
  const [draft, setDraft] = useState<AddonDraft>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const productId = line?.product_id ?? line?.id;
  const variantId = line?.product_variant_id ?? line?.variant_id;
  const lineQty = Number(line?.qty ?? line?.variants?.[0]?.quantity) || 1;
  const currency = line?.currency ?? "";

  // Cart rows carry the chosen options, never the groups they came from.
  useEffect(() => {
    let cancelled = false;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- groups arrive only after this fetch
    setLoading(true);
    api
      .getProductById({
        id: productId,
        latitude: city?.latitude,
        longitude: city?.longitude,
      })
      .then((response: any) => {
        if (cancelled) return;
        const row = Array.isArray(response?.data)
          ? response.data[0]
          : response?.data;
        const fetched = row?.addon_groups ?? [];
        setGroups(fetched);
        setDraft(draftFromLine(fetched, line));
      })
      .catch((error: any) => console.log("addon groups error", error))
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [productId]);

  const unitAddonTotal = addonUnitTotal(groups, draft);
  const unitPrice =
    line?.discounted_price && line?.discounted_price !== 0
      ? line.discounted_price
      : line?.price;
  const total = ((Number(unitPrice) || 0) + unitAddonTotal) * lineQty;

  const saveGuest = (addons: ReturnType<typeof toAddonPayload>) => {
    const key = cartLineKey(line);
    const rows = (cart?.guestCart ?? []).map((row: any) =>
      cartLineKey(row) === key
        ? {
            ...row,
            productPrice: (Number(unitPrice) || 0) + unitAddonTotal,
            addons: draftToLineAddons(groups, draft),
            addon_total: unitAddonTotal * lineQty,
            addon_fingerprint: addonFingerprint(addons),
          }
        : row,
    );
    const subTotal = rows.reduce(
      (sum: number, row: any) =>
        sum + Number(row?.productPrice || 0) * Number(row?.qty || 0),
      0,
    );
    dispatch(addtoGuestCart({ data: rows }));
    dispatch(setGuestCartTotal({ data: subTotal }));
    dispatch(setCartSubTotal({ data: subTotal }));
    onSaved({ guestCart: rows });
  };

  const saveServer = async (addons: ReturnType<typeof toAddonPayload>) => {
    setSaving(true);
    try {
      const added = await api.addToCart({
        product_id: productId,
        product_variant_id: variantId,
        qty: lineQty,
        latitude: city?.latitude,
        longitude: city?.longitude,
        addons,
      });
      if (added?.status !== 1) {
        toast.error(added?.message);
        return;
      }
      // The old line goes only once the new one exists, so a failed call
      // never leaves the cart short of the item.
      const removed = await api.removeFromCart({
        product_id: productId,
        product_variant_id: variantId,
        qty: lineQty,
        addons: lineAddonPayload(line),
      });
      const latest = removed?.status === 1 ? removed : added;
      const serverCart = latest?.data?.cart?.map((item: any) => ({
        product_id: item?.id,
        product_variant_id: item?.variant_id,
        addons: item?.addons ?? [],
        qty: item?.variants?.[0]?.quantity ?? item?.quantity,
      }));
      dispatch(setCart({ data: latest }));
      dispatch(setCartProducts({ data: serverCart ?? [] }));
      dispatch(setCartSubTotal({ data: latest?.data?.sub_total }));
      onSaved(latest);
    } catch (error) {
      console.log("addon edit error", error);
    } finally {
      setSaving(false);
    }
  };

  const handleDone = async () => {
    const error = validateAddonDraft(groups, draft);
    if (error) {
      toast.error(error);
      return;
    }
    const addons = toAddonPayload(draft);
    // Nothing moved — no call, straight back to the cart.
    if (addonFingerprint(addons) === addonFingerprint(lineAddonPayload(line))) {
      onBack();
      return;
    }
    if (cart?.isGuest) {
      saveGuest(addons);
      return;
    }
    await saveServer(addons);
  };

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="flex items-center gap-3 border-b border-gray-100 px-4 py-3 dark:border-zinc-800">
        <span className="h-12 w-12 shrink-0 overflow-hidden rounded-lg border border-gray-100 bg-white dark:border-zinc-800">
          <ImageWithPlaceholder
            src={line?.image_url ?? line?.images?.[0]?.image_url}
            alt={line?.name}
            width={96}
            height={96}
            className="h-full w-full object-contain"
          />
        </span>
        <div className="min-w-0 flex-1">
          <p className="line-clamp-1 text-sm font-bold capitalize textColor">
            {line?.name}
          </p>
          <p className="mt-0.5 text-xs text-gray-500">
            {lineQty} × {money(Number(unitPrice) || 0)}
          </p>
        </div>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto custom-scrollbar px-4 py-4">
        <AddonGroupsList
          groups={groups}
          draft={draft}
          setDraft={setDraft}
          currency={currency}
          loading={loading}
        />
      </div>

      <div className="flex shrink-0 items-center justify-between gap-4 border-t border-gray-100 bg-white px-4 py-4 dark:border-zinc-800 dark:bg-zinc-900">
        <div className="flex min-w-0 flex-col gap-0.5">
          <span className="text-xs text-gray-500">{t("total")}</span>
          <span className="truncate text-xl font-bold primaryColor">
            {money(total)}
          </span>
        </div>
        <button
          type="button"
          onClick={handleDone}
          disabled={saving || loading}
          className="h-11 shrink-0 rounded-lg primaryBackColor px-6 text-sm font-bold uppercase text-white transition active:scale-95 disabled:opacity-60"
        >
          {t("done")}
        </button>
      </div>
    </div>
  );
};

export default CartAddonEditor;
