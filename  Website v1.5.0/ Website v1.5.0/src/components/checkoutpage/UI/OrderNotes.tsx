"use client";
import { useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { FiPlus } from "react-icons/fi";
import { t } from "@/utils/translation";
import { setOrderNote } from "@/redux/slices/checkoutSlice";

// Optional delivery instruction attached to the order.
const OrderNotes = () => {
  const dispatch = useDispatch();
  const orderNote = useSelector((state: any) => state.Checkout.orderNote);
  const [open, setOpen] = useState(false);

  return (
    <div className="border-t p-4 md:px-5">
      {!open && !orderNote ? (
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="flex items-center gap-2 text-sm font-semibold primaryColor dark:text-white hover:opacity-80 transition"
        >
          <span className="flex h-6 w-6 items-center justify-center rounded-full primaryLightBack">
            <FiPlus size={15} />
          </span>
          {t("add_delivery_instruction") ||
            t("order_notes") ||
            "Add delivery instruction"}
        </button>
      ) : (
        <div>
          <div className="flex items-center justify-between gap-2">
            <span className="text-sm font-semibold textColor">
              {t("order_notes")}
            </span>
            <button
              type="button"
              onClick={() => {
                setOpen(false);
                dispatch(setOrderNote({ data: "" }));
              }}
              className="text-xs font-medium text-red-500 hover:text-red-600 transition"
            >
              {t("delete")}
            </button>
          </div>
          <p className="text-xs SecondaryTextColor mt-0.5">
            {t("order_notes_hint")}
          </p>
          <textarea
            rows={3}
            autoFocus
            aria-label={t("order_notes_placeholder")}
            value={orderNote || ""}
            onChange={(e) => dispatch(setOrderNote({ data: e.target.value }))}
            placeholder={t("order_notes_placeholder")}
            className="mt-2 w-full cardBorder rounded-lg px-3 py-2 text-sm bg-transparent outline-none resize-none focus:primaryColorBorder transition"
          />
        </div>
      )}
    </div>
  );
};

export default OrderNotes;
