import * as api from "@/api/apiRoutes";
import { setShopMode } from "@/redux/slices/shopModeSlice";

// API channel vocabulary -> shop mode vocabulary.
export const channelToShopMode = (channel?: string | null): string =>
  channel === "ecommerce" ? "allShop" : "quick";

const pickChannel = (channels: any): string | null => {
  if (!Array.isArray(channels)) return null;
  const valid = channels.filter(
    (c: any) => c === "quick" || c === "ecommerce",
  );
  return valid[0] ?? null;
};

/**
 * getZone, retried in the channel the zone actually serves.
 * A zone restricted to one channel answers status 0 with
 * channels_available for the current header channel; switch the header shop
 * mode to that channel and ask again so the zone resolves instead of failing.
 */
export const getZoneForChannel = async ({
  latitude,
  longitude,
  dispatch,
}: {
  latitude: any;
  longitude: any;
  dispatch?: (action: any) => void;
}): Promise<any> => {
  const result = await api.getZone({ latitude, longitude });
  if (result?.status === 1) return result;
  const channel = pickChannel(result?.channels_available);
  if (!channel) return result;
  const retry = await api.getZone({ latitude, longitude, channel });
  if (retry?.status !== 1) return retry;
  dispatch?.(setShopMode({ mode: channelToShopMode(channel) }));
  return retry;
};
