"use client";

import { useState, useEffect, useRef } from "react";
import { createPortal } from "react-dom";
import { FocusScope } from "@radix-ui/react-focus-scope";
import { LuX, LuPhone, LuChevronRight } from "react-icons/lu";
import { IoChatbubblesOutline } from "react-icons/io5";
import { TbMotorbike } from "react-icons/tb";

import { cn } from "@/lib/utils";
import { t } from "@/utils/translation";
import useIsRtl from "@/hooks/useIsRtl";
import useDeliveryChat, {
  type UseDeliveryChatOptions,
} from "@/hooks/useDeliveryChat";
import {
  MessageList,
  ChatInput,
  type ChatInputSendArgs,
} from "@/components/chat/shared/ChatPrimitives";

const Avatar = ({ name }: { name?: string }) => (
  <div className="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center text-white font-semibold shrink-0">
    {(name || "?").trim().charAt(0).toUpperCase()}
  </div>
);

interface LauncherProps {
  variant?: "row" | "glass" | "solid";
  mode?: "delivery" | "orderAdmin";
  label?: string;
  subtitle?: string;
  onOpen: () => void;
}

// Launcher button component variants
const Launcher = ({ variant, mode, label, subtitle, onOpen }: LauncherProps) => {
  if (variant === "row") {
    return (
      <button
        type="button"
        onClick={onOpen}
        className="flex w-full items-center gap-3 rounded-2xl border border-[var(--border-color)] bg-white dark:bg-zinc-900 px-4 py-3.5 text-left shadow-sm"
      >
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full primaryLightBack primaryColor">
          {mode === "orderAdmin" ? (
            <IoChatbubblesOutline size={20} />
          ) : (
            <TbMotorbike size={21} />
          )}
        </span>
        <span className="min-w-0 flex-grow">
          <span className="block text-sm font-bold textColor">{label}</span>
          <span className="block text-xs SecondaryTextColor">{subtitle}</span>
        </span>
        <LuChevronRight size={20} className="shrink-0 SecondaryTextColor" />
      </button>
    );
  }
  return (
    <button
      type="button"
      onClick={onOpen}
      className={cn(
        "inline-flex h-11 shrink-0 items-center justify-center gap-2 rounded-xl px-4 text-sm font-semibold transition",
        variant === "glass"
          ? "bg-white/15 text-white ring-1 ring-white/25 backdrop-blur-sm hover:bg-white/25"
          : "primaryBackColor text-white hover:opacity-90",
      )}
    >
      <IoChatbubblesOutline size={18} />
      {label}
    </button>
  );
};

interface ChatFooterProps {
  closed?: boolean;
  sendMessage: (args: ChatInputSendArgs) => void;
  notifyTyping?: () => void;
  available?: boolean;
}

// Chat footer input or closed banner component
const ChatFooter = ({
  closed,
  sendMessage,
  notifyTyping,
  available,
}: ChatFooterProps) => {
  if (closed) {
    return (
      <div className="border-t border-gray-200 dark:border-white/10 bg-gray-50 dark:bg-zinc-900 text-center text-xs text-gray-400 dark:text-gray-500 py-3.5">
        Order delivered. This chat is now closed.
      </div>
    );
  }
  return (
    <ChatInput
      onSend={sendMessage}
      onTyping={notifyTyping}
      disabled={!available}
      placeholder="Share a landmark or instruction…"
    />
  );
};

/** Order-scoped delivery partner chat component */
export interface DeliveryChatProps {
  orderId?: number | string;
  orderItemId?: number | string;
  orderStatus?: number | string;
  deliveryBoy?: UseDeliveryChatOptions["deliveryBoy"];
  /** Launcher button variant */
  variant?: "row" | "glass" | "solid";
  // "delivery" (default) or "orderAdmin" (always-on order-level store chat).
  mode?: "delivery" | "orderAdmin";
  label?: string;
  subtitle?: string;
}

export default function DeliveryChat({
  orderId,
  orderItemId,
  orderStatus,
  deliveryBoy,
  variant = "solid",
  // "delivery" (default) or "orderAdmin" (always-on order-level store chat).
  mode = "delivery",
  label,
  subtitle,
}: DeliveryChatProps) {
  const [open, setOpen] = useState(false);
  const [mounted, setMounted] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMounted(true);
  }, []);

  // Drawer portals to body, so a host Radix modal's focus trap would steal focus
  // back from the composer. Keep focusin from reaching its document listener.
  useEffect(() => {
    const node = panelRef.current;
    if (!open || !node) return;
    const stop = (e: Event) => e.stopPropagation();
    node.addEventListener("focusin", stop);
    const focusTimer = setTimeout(
      () => node.querySelector<HTMLTextAreaElement>("textarea")?.focus(),
      320,
    );
    return () => {
      clearTimeout(focusTimer);
      node.removeEventListener("focusin", stop);
    };
  }, [open]);
  const rtl = useIsRtl();
  const {
    agent,
    agentTyping,
    available,
    closed,
    messages,
    sendMessage,
    notifyTyping,
  } = useDeliveryChat({ orderId, orderItemId, orderStatus, deliveryBoy, mode });
  // Pass deliveryBoy to hook for immediate launcher display

  // Return null if no agent is assigned
  if (!agent) return null;

  // Row cards use warmer titles; chip launchers keep the plain action labels.
  const rowVariant = variant === "row";
  let defaultLauncherLabel;
  if (mode === "orderAdmin") {
    defaultLauncherLabel = rowVariant
      ? t("chat_store_title") || "We're Here for You"
      : t("need_help") || "Need Help?";
  } else {
    defaultLauncherLabel = rowVariant
      ? t("chat_delivery_title") || "Stay Connected"
      : t("chat_with_delivery_partner") || "Chat with delivery partner";
  }
  const launcherLabel = label || defaultLauncherLabel;
  const launcherSubtitle =
    subtitle ||
    (mode === "orderAdmin"
      ? t("chat_store_subtitle") ||
        "Whether you have a question or need assistance, our support team is ready to help."
      : t("chat_delivery_subtitle") ||
        "Chat directly with your delivery partner for a smooth delivery experience.");
  // Portaled slide-over drawer content. Mounted only while open: its own
  // FocusScope then sits on top of the stack and pauses a host modal's trap,
  // which would otherwise pull focus out of the composer on focusout.
  const slideOver = (
    <div
      data-chat-drawer=""
      className="fixed inset-0 z-[1100] pointer-events-auto"
    >
      <button
        type="button"
        aria-label={t("close") || "Close"}
        className="absolute inset-0 cursor-default bg-black/40 backdrop-blur-[1px] animate-in fade-in-0 duration-300"
        onClick={() => setOpen(false)}
      />
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-label={launcherLabel || "Delivery chat"}
        className={cn(
          "absolute top-0 h-full w-full sm:w-[420px] bg-white dark:bg-zinc-900 shadow-2xl flex flex-col animate-in duration-300 ease-out",
          // RTL → panel enters from the LEFT; LTR → from the RIGHT.
          rtl
            ? "left-0 slide-in-from-left-[100%]"
            : "right-0 slide-in-from-right-[100%]",
        )}
      >
        {/* Header */}
        <header className="primaryBackColor text-white px-4 py-3 flex items-center gap-3 shadow-sm">
          <Avatar name={agent.name} />
          <div className="flex-1 min-w-0">
            <p className="font-semibold truncate">{agent.name}</p>
            <p className="text-xs text-white/80 truncate">
              {closed ? "Delivered · chat closed" : `Order #${orderId}`}
            </p>
          </div>
          {agent.phone && !closed && (
            <a
              href={`tel:${agent.phone}`}
              className="p-2 rounded-full hover:bg-white/15 transition"
              title="Call"
            >
              <LuPhone size={18} />
            </a>
          )}
          <button
            type="button"
            onClick={() => setOpen(false)}
            className="p-2 rounded-full hover:bg-white/15 transition"
            title="Close"
          >
            <LuX size={20} />
          </button>
        </header>

        <MessageList
          messages={messages}
          typing={agentTyping}
          typingLabel={`${agent.name?.split(" ")[0] || "Partner"} is typing`}
          empty="Share delivery instructions or a landmark to help your partner find you."
        />

        <ChatFooter
          closed={closed}
          sendMessage={sendMessage}
          notifyTyping={notifyTyping}
          available={available}
        />
      </div>
    </div>
  );

  return (
    <>
      <Launcher
        variant={variant}
        mode={mode}
        label={launcherLabel}
        subtitle={launcherSubtitle}
        onOpen={() => setOpen(true)}
      />
      {open && mounted && typeof document !== "undefined"
        ? createPortal(
            <FocusScope asChild trapped loop>
              {slideOver}
            </FocusScope>,
            document.body,
          )
        : null}
    </>
  );
}
