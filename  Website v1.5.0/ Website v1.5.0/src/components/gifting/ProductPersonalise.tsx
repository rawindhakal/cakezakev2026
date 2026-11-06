"use client";
import { useDispatch, useSelector } from "react-redux";
import { setGift } from "@/redux/slices/checkoutSlice";

// "Personalise this gift" field for products flagged personalisable.
// The text travels with the order (Checkout.gift.personalization).
export default function ProductPersonalise({ product }: { product: any }) {
  const dispatch = useDispatch();
  const gift: Record<string, any> = useSelector((s: any) => s.Checkout.gift) || {};
  if (Number(product?.is_personalizable) !== 1) return null;
  return (
    <div className="my-3 w-full max-w-[360px]">
      <label className="mb-1 block text-xs font-semibold textColor">
        ✨ Personalise this gift (name or message to print)
      </label>
      <input
        maxLength={500}
        value={gift.personalization || ""}
        onChange={(e) =>
          dispatch(setGift({ data: { ...gift, personalization: e.target.value } }))
        }
        placeholder="e.g. Happy Birthday Sita"
        className="w-full cardBorder rounded-lg px-3 py-2 text-sm bg-transparent outline-none focus:primaryColorBorder transition"
      />
    </div>
  );
}
