import React, { useEffect, useState } from "react";
import StatusOne from "@/assets/statusIcons/status_icon_awaiting_payment.svg";
import StatusTwo from "@/assets/statusIcons/status_icon_received.svg";
import StatusThree from "@/assets/statusIcons/status_icon_process.svg";
import StatusFour from "@/assets/statusIcons/status_icon_shipped.svg";
import StatusFive from "@/assets/statusIcons/status_icon_out_for_delivery.svg";
import StatusSix from "@/assets/statusIcons/status_icon_delivered.svg";
import StatusSeven from "@/assets/statusIcons/status_icon_cancel.svg";
import StatusReturned from "@/assets/statusIcons/status_icon_returned.svg";
import Image from "next/image";
import { t } from "@/utils/translation";
import { formatDateTime } from "@/utils/helperFunction";
import type { StaticImageData } from "next/image";

interface OrderStepperProps {
  // Payload shape varies by order type, no shared type — see AGENTS.md rule 4.
  orderDetail: any;
}

interface StatusStep {
  icon: StaticImageData;
  label: string;
  timestamp: string;
  isDone: boolean;
}

const OrderStepper = ({ orderDetail }: OrderStepperProps) => {
  const statusMappings: Record<number, { icon: StaticImageData; label: string }> = {
    1: { icon: StatusOne, label: t("paymentPending") },
    2: { icon: StatusTwo, label: t("order_status_display_name_recieved") },
    3: { icon: StatusThree, label: t("processed") },
    4: { icon: StatusFour, label: t("shipped") },
    5: { icon: StatusFive, label: t("out_for_delivery") },
    6: { icon: StatusSix, label: t("order_status_display_name_delivered") },
    7: { icon: StatusSeven, label: t("cancelled") },
    8: { icon: StatusReturned, label: t("returned") },
    9: { icon: StatusThree, label: t("order_status_display_name_recieved") },
    10: { icon: StatusTwo, label: t("ready_to_pickup") },
    11: { icon: StatusSix, label: t("picked") },
    12: { icon: StatusReturned, label: t("refund_completed") },
    13: { icon: StatusReturned, label: t("refund_completed") },
  };

  // Return/refund pipeline codes not in statusMappings get an icon guessed from status_name.
  const iconFromLabel = (name = ""): StaticImageData => {
    const s = name.toLowerCase();
    if (/refund/.test(s)) return StatusSix; // ✓ money back / done
    if (/return|received from customer|to store/.test(s)) return StatusReturned;
    if (/pickup|out for/.test(s)) return StatusFive; // out for delivery/pickup
    if (/assign|delivery boy|partner/.test(s)) return StatusFour; // shipped/assigned
    if (/accept|approve|process/.test(s)) return StatusThree;
    if (/cancel|reject/.test(s)) return StatusSeven;
    if (/deliver|complete/.test(s)) return StatusSix;
    if (/ship/.test(s)) return StatusFour;
    if (/receiv|request|placed/.test(s)) return StatusTwo;
    return StatusSix;
  };

  const [steps, setSteps] = useState<StatusStep[]>([]);

  const handleGetSteps = () => {
    // datetime may be raw SQL timestamp or already-formatted; normalize raw ones only.
    const displayDate = (value: string | null | undefined) => {
      if (!value) return "";
      const isRaw = /^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/.test(
        String(value).trim(),
      );
      if (!isRaw) return value;
      return formatDateTime(value) || value;
    };

    const updatedSteps = orderDetail?.timeline?.map((entry: any) => {
      const mapped = statusMappings[entry?.status] || {};
      const label = entry?.status_name || mapped.label || "";
      return {
        icon: mapped.icon || iconFromLabel(label),
        label: `${t("your_order_has_been")} ${label}`,
        timestamp: displayDate(entry?.datetime),
        // Missing is_done defaults to done (older payloads keep the all-green look).
        isDone: entry?.is_done !== false,
      };
    });
    setSteps(updatedSteps || []);
  };

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- derives steps from orderDetail prop
    handleGetSteps();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- handleGetSteps is a plain closure, re-run only on orderDetail change
  }, [orderDetail]);

  // Latest reached step pulses; earlier ones are settled.
  const currentIndex = steps.reduce((acc, step, i) => (step.isDone ? i : acc), -1);

  return (
    <div className="rounded-lg border border-[var(--border-color)] p-5">
      {steps?.map((status, index) => (
        <div
          key={index}
          className="relative flex items-start gap-4 pb-8 last:pb-0"
          style={{ "--step": index } as React.CSSProperties}
        >
          {/* Grey track, with the primary fill drawing down once the next step
              is reached. Anchored to the row, not the icon, so it reaches the
              next bubble however tall the label wraps. */}
          {index < steps.length - 1 && (
            <div
              className="absolute top-11 bottom-0 w-0.5 overflow-hidden bg-gray-300 dark:bg-zinc-700"
              style={{ insetInlineStart: 21 }}
            >
              {status.isDone && steps[index + 1]?.isDone && (
                <div className="stepLineFill h-full w-full primaryBackColor" />
              )}
            </div>
          )}

          {/* Icon — gray when is_done is false, primary color otherwise. */}
          <div className="relative shrink-0">
            <div
              className={`stepPopIn relative ${
                status.isDone
                  ? "flex h-11 w-11 items-center justify-center rounded-full primaryBackColor ring-4 ring-[color-mix(in_srgb,var(--primary-color)_18%,transparent)]"
                  : "flex h-11 w-11 items-center justify-center rounded-full bg-gray-300 ring-4 ring-gray-100 dark:bg-zinc-700 dark:ring-zinc-800"
              }`}
            >
              {index === currentIndex && index < steps.length - 1 && (
                <span aria-hidden="true" className="stepPulse absolute inset-0 rounded-full primaryBackColor" />
              )}
              <Image
                src={status?.icon?.src}
                alt="icon"
                height={22}
                width={22}
                className={
                  status.isDone
                    ? "relative h-3/5 w-auto"
                    : "relative h-3/5 w-auto grayscale opacity-70"
                }
              />
            </div>
          </div>

          {/* Text */}
          <div className="stepTextIn flex-1 pt-1.5">
            <p className="font-semibold text-sm">{status.label}</p>
            <p className="mt-0.5 text-xs SecondaryTextColor">
              {status.timestamp}
            </p>
          </div>
        </div>
      ))}
    </div>
  );
};

export default OrderStepper;
