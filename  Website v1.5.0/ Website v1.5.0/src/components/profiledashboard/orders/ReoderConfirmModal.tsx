import React from "react";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { LuRotateCcw } from "react-icons/lu";
import * as api from "@/api/apiRoutes";
import { toast } from "react-toastify";
import { t } from "@/utils/translation";
import { bulkCartItems, rowsHaveAddons } from "@/utils/addons";
import { useSelector, useDispatch } from "react-redux";
import {
  setCartProducts,
  setCartSubTotal,
  setDoorStepDeliveryMode,
  setSelfPickupMode,
} from "@/redux/slices/cartSlice";

interface ReoderConfirmModalProps {
  showReoderModal: boolean;
  setShowReorderModal: (open: boolean) => void;
  order: any;
  // Channel of original order ("quick" | "allShop")
  orderChannel?: string;
}

const ReoderConfirmModal = ({
  showReoderModal,
  setShowReorderModal,
  order,
  orderChannel = "allShop",
}: ReoderConfirmModalProps) => {
  const dispatch = useDispatch();
  const theme = useSelector((state: any) => state.Theme.theme);
  const city = useSelector((state: any) => state.City.city);
  // Serviceable modes for current city location
  const availableModes = useSelector((state: any) => state.ShopMode.availableModes);

  const handleHideReorder = () => {
    setShowReorderModal(false);
  };

  const handleReoder = async () => {
    // Quick orders can only be re-ordered when quick delivery is available
    const isQuickOrder = orderChannel === "quick";
    const locationSupportsQuick =
      availableModes === "both" || availableModes === "quick";
    if (isQuickOrder && !locationSupportsQuick) {
      toast.error(t("quick_not_available_at_location"));
      setShowReorderModal(false);
      return;
    }
    try {
      const variantIds = order?.items
        ?.map((prdct) => prdct?.variant_id)
        ?.join(",");
      const quantity = order?.items?.map((prdct) => prdct?.quantity)?.join(",");
      // Bulk add items to original channel cart
      const isQuick = isQuickOrder;
      // Re-order carries each item's addon snapshot, which only items can hold.
      const items = rowsHaveAddons(order?.items ?? [])
        ? bulkCartItems(order?.items ?? [])
        : undefined;
      const response = await api.addToBulkCart({
        quick_items: isQuick ? items : undefined,
        ecommerce_items: isQuick ? undefined : items,
        quick_variant_ids: isQuick && !items ? variantIds : undefined,
        quick_quantities: isQuick && !items ? quantity : undefined,
        ecommerce_variant_ids: !isQuick && !items ? variantIds : undefined,
        ecommerce_quantities: !isQuick && !items ? quantity : undefined,
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      if (response.status == 1) {
        toast.success(t("items_added_to_cart"));
        setShowReorderModal(false);
        await fetchCart();
      } else {
        // Surface raw error message from server response
        toast.error(response?.message || t("something_went_wrong"));
        setShowReorderModal(false);
      }
    } catch (error: any) {
      // Handle request failure and hide modal
      console.log("Error", error);
      toast.error(error?.response?.data?.message || t("something_went_wrong"));
      setShowReorderModal(false);
    }
  };

  const fetchCart = async () => {
    try {
      const cartData = await api.getCart({
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      if (cartData.status == 1) {
        dispatch(setCartSubTotal({ data: cartData?.data?.sub_total }));
        dispatch(setSelfPickupMode({ data: cartData?.data?.self_pickup_mode }));
        dispatch(setDoorStepDeliveryMode({data:cartData?.data?.doorstep_delivery_mode}))
        const productsData = cartData?.data?.cart?.map((item) => ({
          product_id: item?.id,
          product_variant_id: item?.variant_id,
          addons: item?.addons ?? [],
          qty: item?.variants?.[0]?.quantity ?? item?.quantity,
        }));
        dispatch(setCartProducts({ data: productsData }));
      } else {
        dispatch(setCartProducts({ data: [] }));
        dispatch(setCartSubTotal({ data: 0 }));
      }
    } catch (error: any) {
      console.log("Error", error);
    }
  };

  return (
    <Dialog open={showReoderModal} onOpenChange={setShowReorderModal}>
      {/* DialogContent portals its own overlay; a second one rendered here sits
          inside the order card, whose transform makes `fixed` resolve against
          the card and dims just that card. */}
      <DialogContent
        className="max-w-sm overflow-hidden rounded-2xl border border-[var(--border-color)] p-0"
        overlayClassName={`${theme == "light" ? "bg-black/50" : "bg-black/70"} backdrop-blur-sm`}
        title={t("reorder")}
      >
        <div className="flex flex-col items-center px-6 pt-7 pb-6 text-center">
          <span
            className="mb-4 flex h-14 w-14 items-center justify-center rounded-full textPrimaryColor"
            style={{
              backgroundColor:
                "color-mix(in srgb, var(--primary-color) 12%, transparent)",
            }}
          >
            <LuRotateCcw size={26} />
          </span>

          <h2 className="font-bold text-lg textColor">{t("reorder")}</h2>
          <p className="mt-1.5 text-sm SecondaryTextColor">
            {t("reOrder_warning")}
          </p>

          <div className="mt-6 grid w-full grid-cols-2 gap-3">
            <button
              className="rounded-xl border border-[var(--border-color)] px-4 py-2.5 text-sm font-semibold transition-colors hover:bg-black/5"
              onClick={handleHideReorder}
            >
              {t("cancel")}
            </button>
            <button
              className="rounded-xl primaryBackColor px-4 py-2.5 text-sm font-semibold text-white transition-opacity hover:opacity-90"
              onClick={handleReoder}
            >
              {t("Ok")}
            </button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default ReoderConfirmModal;
