"use client";

import { useCallback, useEffect, useState } from "react";
import { useSelector } from "react-redux";
import {
  startOrderChat,
  startOrderAdminChat,
  getChatMessages,
  sendChatMessage,
} from "@/api/apiRoutes";
import { subscribeConversation, isChatWsEnabled, log } from "@/lib/chatWs";
import {
  mapConversation,
  mapMessage,
  mapMessages,
  type UiConversation,
  type UiMessage,
} from "@/lib/chatMappers";
import { toast } from "react-toastify";
import { t } from "@/utils/translation";

/** Custom hook managing customer chat with delivery boy or store admin. */
interface DeliveryBoy {
  id?: number | string;
  name?: string;
  phone?: string;
}

interface ChatAgent {
  id: number | string;
  name?: string;
  phone?: string;
  online: boolean;
}

export interface UseDeliveryChatOptions {
  orderId?: number | string;
  orderItemId?: number | string;
  orderStatus?: number | string;
  deliveryBoy?: DeliveryBoy | null;
  mode?: "delivery" | "orderAdmin";
}

export default function useDeliveryChat({
  orderId,
  orderItemId,
  orderStatus,
  deliveryBoy,
  mode = "delivery",
}: UseDeliveryChatOptions = {}) {
  const isOrderAdmin = mode === "orderAdmin";
  const user = useSelector((s: any) => s.User?.user);
  const userId = user?.id;
  // Settings status to trigger realtime connection.
  const settingStatus = useSelector((s: any) => s.Setting?.status);

  const [conversation, setConversation] = useState<UiConversation | null>(null);
  // Seed initial agent details from order props.
  const seededAgent: ChatAgent | null = deliveryBoy?.id
    ? {
        id: deliveryBoy.id,
        name: deliveryBoy.name,
        phone: deliveryBoy.phone,
        online: false,
      }
    : isOrderAdmin
      ? {
          id: `order-admin-${orderId}`,
          name: deliveryBoy?.name || "Store",
          online: false,
        }
      : null;
  const [agent, setAgent] = useState<ChatAgent | null>(seededAgent);
  const [messages, setMessages] = useState<UiMessage[]>([]);
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);

  // Closed status check for delivery chat.
  const closed =
    !isOrderAdmin &&
    ([6, 7, 8].includes(Number(orderStatus)) ||
      (typeof orderStatus === "string" &&
        ["delivered", "completed", "returned", "cancelled"].includes(
          orderStatus.toLowerCase(),
        )));

  const conversationId = conversation?.id || null;
  // Composer stays usable without a conversation; send lazily creates one.
  const available = !closed;

  // Start / fetch the order conversation
  const init = useCallback(async (): Promise<number | string | null> => {
    if (!orderId) return null;
    setLoading(true);
    log(`${mode}: start_order →`, orderId);
    try {
      const res = isOrderAdmin
        ? await startOrderAdminChat({ order_id: orderId })
        : await startOrderChat({
            order_id: orderId,
            order_item_id: orderItemId,
          });
      if (res?.status === 1 && res.data?.id) {
        const conv = mapConversation(res.data);
        setConversation(conv);
        if (isOrderAdmin) {
          setAgent((prev) => ({
            id: res.data.id,
            name: res.data.title || prev?.name || "Store",
            online: false,
          }));
        } else {
          setAgent(
            res.data?.delivery_boy_id
              ? {
                  id: res.data.delivery_boy_id,
                  name: res.data.title,
                  online: false,
                }
              : (prev) => prev ?? seededAgent,
          );
        }
        return conv?.id ?? res.data.id;
      }
      setConversation(null);
      setAgent((prev) => prev ?? seededAgent);
      return null;
    } catch (e) {
      console.error("startOrderChat failed", e);
      setConversation(null);
      setAgent((prev) => prev ?? seededAgent);
      return null;
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [orderId, orderItemId]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- start/fetch conversation on mount/order change
    if (userId && orderId) init();
  }, [userId, orderId, init]);

  // Load message history
  const loadMessages = useCallback(
    async ({ silent }: { silent?: boolean } = {}) => {
      if (!conversationId) return;
      if (!silent) setLoading(true);
      try {
        const res = await getChatMessages({ conversation_id: conversationId });
        if (res?.status === 1) {
          const msgs = mapMessages(res.data?.messages);
          log("delivery: history loaded", msgs.length, "messages");
          setMessages(msgs);
        }
      } catch (e) {
        console.error("loadMessages failed", e);
      } finally {
        if (!silent) setLoading(false);
      }
    },
    [conversationId],
  );

  useEffect(() => {
    if (conversationId) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- load history when conversation becomes available
      loadMessages();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [conversationId]);

  // Send message
  interface SendMessageArgs {
    text?: string;
    images?: any[];
    audios?: any[];
    videos?: any[];
    files?: any[];
  }

  const sendMessage = useCallback(
    async ({ text, images, audios, videos, files }: SendMessageArgs) => {
      if (!available) return;
      const imgs = images || [];
      const auds = audios || [];
      const vids = videos || [];
      const others = files || [];
      if (
        !text?.trim() &&
        !imgs.length &&
        !auds.length &&
        !vids.length &&
        !others.length
      )
        return;
      setSending(true);
      // Conversation may not exist yet (start_order failed or raced) — create now.
      let convId = conversationId;
      if (!convId) convId = await init();
      if (!convId) {
        setSending(false);
        toast.error(t("something_went_wrong") || "Could not start chat");
        return;
      }
      log("delivery: send →", {
        conversationId: convId,
        text,
        images: imgs.length,
        audios: auds.length,
        videos: vids.length,
        files: others.length,
      });
      try {
        const res = await sendChatMessage({
          conversation_id: convId,
          message: text?.trim() || "",
          images: imgs,
          audios: auds,
          videos: vids,
          files: others,
        });
        if (res?.status === 1) {
          const list = Array.isArray(res.data)
            ? res.data
            : res.data?.messages
              ? res.data.messages
              : res.data
                ? [res.data]
                : [];
          const created = mapMessages(list);
          log("delivery: send ✓", created.length, "created");
          // WS echo may already have delivered these — key by id.
          setMessages((prev) => [
            ...prev,
            ...created.filter((m) => !prev.some((p) => p.id === m.id)),
          ]);
        } else if (res?.message) {
          toast.error(res.message);
        }
      } catch (e: any) {
        console.error("sendMessage failed", e);
        const msg = e?.response?.data?.message || e?.message;
        if (msg) toast.error(msg);
      } finally {
        setSending(false);
      }
    },
    [available, conversationId, init],
  );

  // Realtime WebSocket subscription
  useEffect(() => {
    if (!conversationId) return;
    if (!isChatWsEnabled()) {
      const poll = setInterval(() => loadMessages({ silent: true }), 12000);
      return () => clearInterval(poll);
    }
    const unsub = subscribeConversation(conversationId, (payload) => {
      const raw =
        payload?.message && typeof payload.message === "object"
          ? payload.message
          : payload;
      const mapped = mapMessage(raw);
      if (!mapped) return;
      log("delivery: ws message ←", mapped);
      setMessages((prev) =>
        prev.some((m) => m.id === mapped.id) ? prev : [...prev, mapped],
      );
    });
    return unsub;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [conversationId, settingStatus]);

  return {
    conversationId,
    agent,
    agentOnline: !!agent?.online,
    agentTyping: false,
    available,
    closed,
    loading,
    sending,
    messages,
    sendMessage,
    notifyTyping: () => {},
    refresh: loadMessages,
  };
}

