"use client";
import { useDispatch, useSelector } from "react-redux";
import { setGift } from "@/redux/slices/checkoutSlice";
import { useEffect, useState } from "react";
import useGiftingMeta from "./useGiftingMeta";
import { getDeliverySchedule, getDeliverySlots } from "@/api/apiRoutes";

const inputCls =
  "w-full cardBorder rounded-lg px-3 py-2 text-sm bg-transparent outline-none focus:primaryColorBorder transition";
const labelCls = "mb-1 block text-xs font-semibold textColor";

const todayISO = () => new Date().toISOString().slice(0, 10);


// Gift options captured at checkout; sent with the order by api.placeOrder.
export default function GiftDetails() {
  const dispatch = useDispatch();
  const gift: Record<string, any> = useSelector((s: any) => s.Checkout.gift) || {};
  const { occasions, relationships, delivery_types } = useGiftingMeta();
  const set = (k: string, v: any) => dispatch(setGift({ data: { ...gift, [k]: v } }));
  const setMany = (patch: Record<string, any>) => dispatch(setGift({ data: { ...gift, ...patch } }));

  // Booking window (min/max date, closed days) and the slots for the chosen date.
  const [cfg, setCfg] = useState<any>(null);
  const [slots, setSlots] = useState<any[]>([]);
  const [loadingSlots, setLoadingSlots] = useState(false);
  useEffect(() => {
    getDeliverySchedule().then((r) => r?.status === 1 && setCfg(r.data)).catch(() => {});
  }, []);
  const type = gift.gift_delivery_type || "";
  const needsSlot = type !== "express" && type !== "midnight";
  useEffect(() => {
    if (!gift.delivery_date || !needsSlot) { setSlots([]); return; }
    let live = true;
    setLoadingSlots(true);
    getDeliverySlots(gift.delivery_date)
      .then((r) => { if (live && r?.status === 1) setSlots(r.data || []); })
      .catch(() => {})
      .finally(() => live && setLoadingSlots(false));
    return () => { live = false; };
  }, [gift.delivery_date, needsSlot]);
  const closed: string[] = cfg?.closed_dates || [];
  const dateClosed = !!gift.delivery_date && closed.includes(gift.delivery_date);
  const pickDate = (v: string) => setMany({ delivery_date: v, delivery_slot_id: "", delivery_slot: "" });
  const pickType = (v: string) => {
    const patch: Record<string, any> = { gift_delivery_type: v, delivery_slot_id: "", delivery_slot: "" };
    if (v === "express" && cfg?.today) patch.delivery_date = cfg.today;
    setMany(patch);
  };
  const reasonText = (r: string | null) =>
    r === "full" ? "Fully booked" : r === "too_late" ? "Too soon" : r === "closed" ? "Closed" : "Unavailable";

  return (
    <div className="border-t p-4 md:px-5">
      <h3 className="mb-3 text-base font-semibold textColor">🎁 Gift details</h3>
      <div className="grid gap-3 md:grid-cols-2">
        <div>
          <label className={labelCls}>Recipient name</label>
          <input className={inputCls} value={gift.recipient_name || ""} onChange={(e) => set("recipient_name", e.target.value)} />
        </div>
        <div>
          <label className={labelCls}>Recipient phone</label>
          <input className={inputCls} inputMode="tel" value={gift.recipient_phone || ""} onChange={(e) => set("recipient_phone", e.target.value)} />
        </div>
        <div>
          <label className={labelCls}>Your relationship</label>
          <select className={inputCls} value={gift.recipient_relationship || ""} onChange={(e) => set("recipient_relationship", e.target.value)}>
            <option value="">Select</option>
            {relationships.map((r) => <option key={r.slug} value={r.name}>{r.name}</option>)}
          </select>
        </div>
        <div>
          <label className={labelCls}>Occasion</label>
          <select className={inputCls} value={gift.occasion || ""} onChange={(e) => set("occasion", e.target.value)}>
            <option value="">Select</option>
            {occasions.map((o) => <option key={o.slug} value={o.name}>{o.name}</option>)}
          </select>
        </div>
        <div className="md:col-span-2 rounded-xl border border-[color-mix(in_srgb,var(--primary-color)_25%,transparent)] p-3">
          <p className="mb-2 text-sm font-semibold textColor">When should it arrive? <span className="text-red-500">*</span></p>
          <div className="grid gap-3 md:grid-cols-2">
            <div>
              <label className={labelCls}>Delivery type</label>
              <select className={inputCls} value={type} onChange={(e) => pickType(e.target.value)}>
                <option value="">Scheduled (choose date &amp; time)</option>
                {delivery_types.filter((d) => d.slug !== "standard").map((d) => (
                  <option key={d.slug} value={d.slug}>
                    {d.name}{d.time_window ? ` (${d.time_window})` : ""}{Number(d.extra_charge) > 0 ? ` +Rs ${Number(d.extra_charge)}` : ""}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className={labelCls}>Delivery date</label>
              <input
                type="date"
                className={inputCls}
                min={cfg?.min_date}
                max={cfg?.max_date}
                disabled={type === "express"}
                value={gift.delivery_date || ""}
                onChange={(e) => pickDate(e.target.value)}
              />
              {cfg?.max_date && (
                <p className="mt-1 text-[11px] SecondaryTextColor">You can order up to {Math.round((new Date(cfg.max_date).getTime() - new Date(cfg.min_date).getTime()) / 86400000)} days ahead.</p>
              )}
              {dateClosed && <p className="mt-1 text-xs text-red-500">We are not delivering on this date. Please pick another day.</p>}
            </div>
          </div>
          {type === "express" && (
            <p className="mt-2 text-xs SecondaryTextColor">Express orders are delivered today within the promised time, so no time slot is needed.</p>
          )}
          {type === "midnight" && gift.delivery_date && (
            <p className="mt-2 text-xs SecondaryTextColor">Delivered at midnight on the chosen date.</p>
          )}
          {needsSlot && gift.delivery_date && !dateClosed && (
            <div className="mt-3">
              <label className={labelCls}>Time slot</label>
              {loadingSlots ? (
                <p className="text-xs SecondaryTextColor">Checking availability…</p>
              ) : slots.length === 0 ? (
                <p className="text-xs text-red-500">No time slots are available on this date.</p>
              ) : (
                <div className="flex flex-wrap gap-2">
                  {slots.map((sl) => {
                    const active = Number(gift.delivery_slot_id) === sl.id;
                    return (
                      <button
                        key={sl.id}
                        type="button"
                        disabled={!sl.available}
                        onClick={() => setMany({ delivery_slot_id: sl.id, delivery_slot: sl.label })}
                        className={`rounded-lg border px-3 py-2 text-left text-xs font-semibold transition ${
                          active ? "primaryBackColor text-white border-transparent" : sl.available ? "cardBorder textColor hover:primaryColorBorder" : "cardBorder opacity-45 cursor-not-allowed line-through"
                        }`}
                      >
                        <span className="block">{sl.label}</span>
                        <span className="block text-[10px] font-normal no-underline">
                          {sl.available ? (sl.extra_charge > 0 ? `+Rs ${sl.extra_charge}` : "Free") : reasonText(sl.unavailable_reason)}
                        </span>
                      </button>
                    );
                  })}
                </div>
              )}
            </div>
          )}
          {cfg?.required && (!gift.delivery_date && type !== "express") && (
            <p className="mt-2 text-[11px] text-amber-600">A delivery date and time are required to place your order.</p>
          )}
        </div>
        <div>
          <label className={labelCls}>From (sender name)</label>
          <input className={inputCls} value={gift.sender_name || ""} onChange={(e) => set("sender_name", e.target.value)} />
        </div>
        <div className="md:col-span-2">
          <label className={labelCls}>Name / text to print on the gift (if personalised)</label>
          <input className={inputCls} maxLength={500} value={gift.personalization || ""} onChange={(e) => set("personalization", e.target.value)} />
        </div>
        <div className="md:col-span-2">
          <label className={labelCls}>Message on the card</label>
          <textarea rows={3} maxLength={500} className={inputCls + " resize-none"} value={gift.gift_message || ""} onChange={(e) => set("gift_message", e.target.value)} />
        </div>
        <label className="md:col-span-2 flex items-center gap-2 text-sm textColor">
          <input type="checkbox" checked={!!gift.is_surprise} onChange={(e) => set("is_surprise", e.target.checked)} />
          Keep it a surprise (don&apos;t reveal sender or price)
        </label>
      </div>
    </div>
  );
}
