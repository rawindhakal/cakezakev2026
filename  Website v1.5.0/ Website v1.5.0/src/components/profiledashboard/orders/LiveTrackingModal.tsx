import React, { useCallback, useEffect, useRef, useState } from "react";
import { Dialog, DialogContent, DialogHeader } from "@/components/ui/dialog";
import { RiCloseFill } from "react-icons/ri";
import { t } from "@/utils/translation";
import { formatCustomDate } from "@/lib/utils";
import * as api from "@/api/apiRoutes";
import { BiPhoneCall } from "react-icons/bi";
import { IoLocationOutline } from "react-icons/io5";
import { LuTruck, LuBike, LuClock } from "react-icons/lu";
import Link from "next/link";
// Asset URL imports for map markers
// @ts-expect-error - `?url`-suffixed asset import has no type declaration
import userIcon from "@/assets/customer_location.svg?url";
// @ts-expect-error - `?url`-suffixed asset import has no type declaration
import deliveryBoyIcon from "@/assets/delivery_boy.png?url";
import MapWrapper from "@/components/maps/MapWrapper";
import useMapProvider from "@/hooks/useMapProvider";
import type { MapMarker } from "@/components/maps/types";
import Loader from "@/components/loader/Loader";
import DeliveryChat from "@/components/chat/delivery/DeliveryChat";
import Image from "next/image";
import useTweenedLatLng from "@/hooks/useTweenedLatLng";
import {
  parseDeliverTimeToMs,
  getRemainingMs,
  formatMsAsMinutes,
} from "@/utils/orderDeliveryTime";

// Rider GPS poll interval while the modal is open.
const LIVE_TRACKING_POLL_MS = 15000;

// The bike artwork points north, so the heading is used as-is.
const bearingDeg = (
  fromLat: number,
  fromLng: number,
  toLat: number,
  toLng: number,
): number => {
  const rad = Math.PI / 180;
  const dLng = (toLng - fromLng) * rad;
  const y = Math.sin(dLng) * Math.cos(toLat * rad);
  const x =
    Math.cos(fromLat * rad) * Math.sin(toLat * rad) -
    Math.sin(fromLat * rad) * Math.cos(toLat * rad) * Math.cos(dLng);
  return (Math.atan2(y, x) * 180) / Math.PI;
};

interface LatLng {
  lat: number | null;
  lng: number | null;
}

interface RoutePoint {
  latitude: number;
  longitude: number;
}

interface LiveTrackingModalProps {
  showLiveTracking: boolean;
  setShowLiveTracking: (open: boolean) => void;
  order: any;
}

const LiveTrackingModal = ({
  showLiveTracking,
  setShowLiveTracking,
  order,
}: LiveTrackingModalProps) => {
  const [riderLocation, setRiderLocation] = useState<LatLng | undefined>();
  const [userLocation, setUserLocation] = useState<LatLng>({
    lat: null,
    lng: null,
  });
  // Flag indicating if delivery boy is assigned
  const isDeliveryBoyAssigned = Boolean(order?.delivery_boy_name);

  // Pre-assignment ETA countdown anchored to order creation time
  const totalDeliverMs = parseDeliverTimeToMs(order?.total_deliver_time);
  const showCountdown =
    !isDeliveryBoyAssigned && !!order?.created_at && totalDeliverMs != null;
  // Timestamp state to trigger countdown re-render
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (!showCountdown) return;
    const interval = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(interval);
  }, [showCountdown]);
  const remainingDeliverMs =
    showCountdown && order?.created_at && totalDeliverMs != null
      ? getRemainingMs(order.created_at, totalDeliverMs, now)
      : 0;

  // Branch coordinates extracted from first order item
  const storeLat = Number.parseFloat(order?.items?.[0]?.branch_latitude);
  const storeLng = Number.parseFloat(order?.items?.[0]?.branch_longitude);
  const hasStoreLocation = Number.isFinite(storeLat) && Number.isFinite(storeLng);
  // Signal for e-commerce orders with estimated delivery date
  const isEcommerceOrder = Boolean(order?.estimated_delivery_date);
  // Rider avatar state fetched from order chat initialization
  const [riderAvatar, setRiderAvatar] = useState<string | null>(null);
  useEffect(() => {
    if (!showLiveTracking || !isDeliveryBoyAssigned || !order?.id) return;
    let active = true;
    api
      .startOrderChat({ order_id: order.id, order_item_id: order?.order_item_id })
      .then((res: any) => {
        if (active && res?.data?.avatar) setRiderAvatar(res.data.avatar);
      })
      .catch((error: any) => console.log("startOrderChat error", error));
    return () => {
      active = false;
    };
  }, [showLiveTracking, isDeliveryBoyAssigned, order?.id, order?.order_item_id]);

  const [showOverlay, setShowOverlay] = useState(false);
  // Tracks whether a valid rider GPS fix was ever received
  const [hasEverHadRiderFix, setHasEverHadRiderFix] = useState(false);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- resets the "ever tracked" flag when a different order's modal opens
    setHasEverHadRiderFix(false);
  }, [order?.id]);
  // Real-time ETA string from live tracking API
  const [liveTimeToDeliver, setLiveTimeToDeliver] = useState<string | null>(
    null,
  );
  const fetchLocation = useCallback(async () => {
    // No delivery boy assigned yet → nothing to poll.
    if (!isDeliveryBoyAssigned) return;
    try {
      const res: any = await api.liveOrderTracking({ orderId: order?.id });
      if (res.status == 0) {
        // Show overlay error only if a previous GPS fix existed
        setShowOverlay(hasEverHadRiderFix);
      } else {
        const latitude = Number.parseFloat(res?.data?.latitude);
        const longitude = Number.parseFloat(res?.data?.longitude);
        setRiderLocation({ lat: latitude, lng: longitude });
        setShowOverlay(false);
        setHasEverHadRiderFix(true);
        if (res?.data?.time_to_deliver) {
          setLiveTimeToDeliver(res.data.time_to_deliver);
        }
      }
    } catch (error) {
      console.log("error", error);
    }
  }, [order, isDeliveryBoyAssigned, hasEverHadRiderFix]);

  useEffect(() => {
    if (showLiveTracking) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-on-open pattern; not derivable from render
      fetchLocation();
    }
  }, [showLiveTracking, fetchLocation]);

  // fetchLocation's identity changes on every poll (hasEverHadRiderFix) and on
  // every parent render (order), which restarted the interval each time.
  const fetchLocationRef = useRef(fetchLocation);

  useEffect(() => {
    fetchLocationRef.current = fetchLocation;
  });

  useEffect(() => {
    if (!showLiveTracking) return;
    const interval = setInterval(() => {
      fetchLocationRef.current();
    }, LIVE_TRACKING_POLL_MS);
    return () => clearInterval(interval);
  }, [showLiveTracking, order?.id]);

  useEffect(() => {
    // Extract user location coordinates from order payload
    const rawAddr = order?.address ?? order?.order_address;
    const lat = order?.latitude ?? rawAddr?.latitude;
    const lng = order?.longitude ?? rawAddr?.longitude;
    if (lat && lng) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- derives user location from order prop
      setUserLocation({
        lat: Number.parseFloat(lat),
        lng: Number.parseFloat(lng),
      });
    }
  }, [order]);

  const handleHideLiveTracking = () => {
    setShowLiveTracking(false);
  };

  // Dynamic map container height based on overlay state
  const mapHeight = showOverlay ? "180px" : "calc(45vh - 100px)";

  // Parse delivery address, mobile, and customer name from order
  const rawAddress = order?.address ?? order?.order_address ?? "";
  const deliveryAddress =
    typeof rawAddress === "object" && rawAddress !== null
      ? rawAddress?.address || ""
      : rawAddress;
  const deliveryMobile =
    (typeof rawAddress === "object" && rawAddress !== null
      ? rawAddress?.mobile
      : null) ||
    order?.mobile ||
    order?.order_mobile ||
    "";
  const customerName =
    (typeof rawAddress === "object" && rawAddress !== null
      ? rawAddress?.name
      : null) ||
    order?.name ||
    order?.user_name ||
    "";

  const hasRider = riderLocation?.lat != null && riderLocation?.lng != null;
  const hasUser = userLocation?.lat != null && userLocation?.lng != null;
  // Flag for rendering store location fallback before rider GPS fix
  const hasStoreRoute = !hasRider && !hasEverHadRiderFix && hasStoreLocation;

  // OSRM road route is OSM-only; Google draws the straight fallback line.
  const { provider } = useMapProvider();
  const useOsrmRoute = provider === "osm";
  const [routePath, setRoutePath] = useState<RoutePoint[] | null>(null);
  // OSRM snaps the origin to the nearest road; the raw GPS fix can sit off it.
  const [snappedOrigin, setSnappedOrigin] = useState<LatLng | null>(null);

  useEffect(() => {
    if (!useOsrmRoute || !hasUser || (!hasRider && !hasStoreRoute)) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- clears stale route when provider or coords change
      setRoutePath(null);
      setSnappedOrigin(null);
      return;
    }
    let active = true;
    const originLat = hasRider ? riderLocation!.lat : storeLat;
    const originLng = hasRider ? riderLocation!.lng : storeLng;
    const coords = `${originLng},${originLat};${userLocation.lng},${userLocation.lat}`;
    fetch(
      `https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson`,
    )
      .then((res) => res.json())
      .then((data: any) => {
        if (!active) return;
        const coordinates = data?.routes?.[0]?.geometry?.coordinates;
        setRoutePath(
          Array.isArray(coordinates) && coordinates.length > 1
            ? coordinates.map(([lng, lat]: [number, number]) => ({
                latitude: lat,
                longitude: lng,
              }))
            : null,
        );
        const snapped = data?.waypoints?.[0]?.location;
        setSnappedOrigin(
          Array.isArray(snapped) && snapped.length === 2
            ? { lat: snapped[1], lng: snapped[0] }
            : null,
        );
      })
      .catch(() => {
        if (active) {
          setRoutePath(null);
          setSnappedOrigin(null);
        }
      });
    return () => {
      active = false;
    };
    // riderLocation object identity changes every poll; only its coords matter.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    useOsrmRoute,
    hasRider,
    hasUser,
    hasStoreRoute,
    riderLocation?.lat,
    riderLocation?.lng,
    userLocation?.lat,
    userLocation?.lng,
    storeLat,
    storeLng,
  ]);

  // Show store marker when rider location is not yet available
  const showStoreMarker = hasStoreRoute;

  // Markers and route path for MapWrapper
  // Place the rider on the snapped point when there is one, so the icon sits on
  // the drawn road instead of beside it, and glide between the 15s polls rather
  // than teleporting. Routing still uses the raw fix.
  const smoothRider = useTweenedLatLng(
    hasRider ? ((snappedOrigin ?? riderLocation) as LatLng) : undefined,
  );
  const riderMarkerLat = smoothRider?.lat as number;
  const riderMarkerLng = smoothRider?.lng as number;

  // Face the bike along the route: the next point that is actually a step away,
  // else straight at the customer.
  const riderHeading = (() => {
    if (!hasRider) return undefined;
    const ahead = routePath?.find(
      (pt) =>
        Math.abs(pt.latitude - riderMarkerLat) > 1e-5 ||
        Math.abs(pt.longitude - riderMarkerLng) > 1e-5,
    );
    const target = ahead
      ? { lat: ahead.latitude, lng: ahead.longitude }
      : hasUser
        ? { lat: userLocation.lat as number, lng: userLocation.lng as number }
        : null;
    if (!target) return undefined;
    return bearingDeg(riderMarkerLat, riderMarkerLng, target.lat, target.lng);
  })();

  const markers: MapMarker[] = [
    hasRider && {
      latitude: riderMarkerLat,
      longitude: riderMarkerLng,
      iconUrl: deliveryBoyIcon?.src,
      rotation: riderHeading,
      title: order?.delivery_boy_name,
    },
    showStoreMarker && {
      latitude: storeLat,
      longitude: storeLng,
      title: order?.items?.[0]?.branch_name || t("store") || "Store",
    },
    hasUser && {
      latitude: userLocation.lat as number,
      longitude: userLocation.lng as number,
      iconUrl: userIcon?.src,
    },
  ].filter(Boolean) as MapMarker[];

  // Road-following path on OSM; straight line while it loads or on Google.
  const polyline: MapMarker[] | undefined =
    routePath ??
    (hasRider && hasUser
      ? [
          { latitude: riderMarkerLat, longitude: riderMarkerLng },
          { latitude: userLocation.lat as number, longitude: userLocation.lng as number },
        ]
      : showStoreMarker && hasUser
        ? [
            { latitude: storeLat, longitude: storeLng },
            { latitude: userLocation.lat as number, longitude: userLocation.lng as number },
          ]
        : undefined);

  // Map center coordinates fallback calculation
  const centerLat = hasRider
    ? riderLocation?.lat
    : showStoreMarker
      ? storeLat
      : userLocation.lat;
  const centerLng = hasRider
    ? riderLocation?.lng
    : showStoreMarker
      ? storeLng
      : userLocation.lng;

  // Self-pickup order check for fallback display
  const isPickupOrder = order?.delivery_type === "pickup";

  return (
    <Dialog open={showLiveTracking} onOpenChange={setShowLiveTracking}>
      <DialogContent
        // Chat drawer portals outside this dialog; keep Radix from dismissing on it.
        onPointerDownOutside={(e) => {
          if ((e.target as HTMLElement)?.closest?.("[data-chat-drawer]"))
            e.preventDefault();
        }}
        onFocusOutside={(e) => {
          if ((e.target as HTMLElement)?.closest?.("[data-chat-drawer]"))
            e.preventDefault();
        }}
        onInteractOutside={(e) => {
          if ((e.target as HTMLElement)?.closest?.("[data-chat-drawer]"))
            e.preventDefault();
        }}
        sheetOnMobile
        className="w-full max-h-[90dvh] flex flex-col overflow-hidden md:max-w-2xl"
        title={isPickupOrder ? (t("pickup_from_branch") || "Pick up from branch") : t("livetracking")}
      >
        {/* Grab handle — mobile sheet only. */}
        <span className="mx-auto h-1 w-10 shrink-0 rounded-full bg-gray-300 dark:bg-zinc-600 md:hidden" />
        {isPickupOrder ? (
          <div className="flex flex-col items-center justify-center gap-4 p-10 text-center">
            <span className="flex h-16 w-16 items-center justify-center rounded-full primaryLightBack primaryColor">
              <LuBike size={32} />
            </span>
            <p className="font-bold text-base">
              {t("live_tracking_not_available_pickup") ||
                "Live tracking is not available for pickup orders"}
            </p>
            <p className="text-sm SecondaryTextColor max-w-xs">
              {t("pickup_from_branch") || "Pick up your order directly from the branch."}
            </p>
          </div>
        ) : (
          <>
            <DialogHeader className="shrink-0 flex flex-row items-start justify-between gap-3 space-y-0 text-start">
          <div className="min-w-0 flex-1">
            <span className="flex items-center gap-2 text-lg md:text-2xl font-bold text-start">
              {t("livetracking")}
              {!isEcommerceOrder && (
                <span className="relative flex h-2.5 w-2.5 shrink-0">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-500 opacity-75" />
                  <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-green-500" />
                </span>
              )}
            </span>
            <p className="mt-0.5 text-sm SecondaryTextColor">
              {t("track_your_order_realtime") || "Track your order in real-time"}
            </p>
            {showCountdown && (
              <div className="mt-2 inline-flex max-w-full items-center gap-1.5 rounded-full primaryLightBack primaryColor px-3 py-1 text-xs font-semibold">
                <LuClock size={13} className="shrink-0" />
                {remainingDeliverMs <= 0
                  ? t("reaching_you_soon") || "Reaching you soon"
                  : `${t("estimated_delivery_time") || "Estimated delivery"}: ${formatMsAsMinutes(remainingDeliverMs)}`}
              </div>
            )}
          </div>
          <button
            type="button"
            aria-label={t("close")}
            onClick={handleHideLiveTracking}
            className="closeButtonBg flex h-9 w-9 shrink-0 self-start items-center justify-center rounded-full transition-opacity hover:opacity-80"
          >
            <RiCloseFill size={22} />
          </button>
        </DialogHeader>
        <div className="flex flex-col gap-4 overflow-y-auto pr-1 -mr-1 pb-[env(safe-area-inset-bottom)] md:pb-0">
          {/* Estimated delivery date display for e-commerce orders */}
          {isEcommerceOrder && (
            <div className="flex flex-col items-center gap-3 rounded-2xl border border-[var(--border-color)] p-8 text-center">
              <span className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full primaryLightBack primaryColor">
                <LuTruck size={26} />
              </span>
              <div>
                <p className="text-sm SecondaryTextColor">
                  {t("estimated_delivery") || "Estimated Delivery"}
                </p>
                <p className="mt-1 text-lg font-bold textColor">
                  {order?.estimated_delivery_date}
                </p>
              </div>
            </div>
          )}

          {/* Live tracking map view for Quick orders */}
          {!isEcommerceOrder && (
          <div className="w-full">
            <div className="relative overflow-hidden rounded-xl border border-[var(--border-color)]">
              {centerLat != null && centerLng != null ? (
                <MapWrapper
                  latitude={centerLat}
                  longitude={centerLng}
                  zoom={15}
                  height={mapHeight}
                  markers={markers}
                  polyline={polyline}
                  showCenterMarker={false}
                  fitToMarkers
                />
              ) : (
                <div
                  className="flex items-center justify-center"
                  style={{ height: mapHeight }}
                >
                  <Loader />
                </div>
              )}

              {/* Order preparation badge */}
              {!isDeliveryBoyAssigned && (
                <div className="absolute right-3 top-3 z-[900] flex items-center gap-2 rounded-full bg-white/95 px-3 py-1.5 shadow-md backdrop-blur dark:bg-zinc-900/95">
                  <span className="relative flex h-2 w-2 shrink-0">
                    <span className="absolute inline-flex h-full w-full animate-ping rounded-full primaryBackColor opacity-75" />
                    <span className="relative inline-flex h-2 w-2 rounded-full primaryBackColor" />
                  </span>
                  <span className="text-xs font-semibold textColor">
                    {t("preparing_your_order") || "Preparing your order"}
                  </span>
                </div>
              )}

              {/* "Rider on the way" live badge over the map */}
              {!showOverlay && hasRider && (
                <div className="absolute right-3 top-3 z-[900] flex items-center gap-2 rounded-full bg-white/95 px-3 py-1.5 shadow-md backdrop-blur dark:bg-zinc-900/95">
                  <span className="relative flex h-2 w-2 shrink-0">
                    <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-500 opacity-75" />
                    <span className="relative inline-flex h-2 w-2 rounded-full bg-green-500" />
                  </span>
                  <span className="text-xs font-semibold textColor">
                    {t("rider_on_the_way") || "Rider on the way"}
                    {liveTimeToDeliver ? ` · ${liveTimeToDeliver}` : ""}
                  </span>
                </div>
              )}

              {/* Tracking error overlay fallback */}
              {showOverlay && !showStoreMarker && (
                <div className="absolute inset-0 z-[1000] flex items-center justify-center bg-white/80 backdrop-blur-sm dark:bg-zinc-900/80">
                  <div className="mx-4 flex max-w-[280px] flex-col items-center gap-2.5 rounded-2xl bg-white px-6 py-6 text-center shadow-xl dark:bg-zinc-900">
                    <span className="flex h-12 w-12 items-center justify-center rounded-full bg-red-50 text-[#dc3545] dark:bg-red-500/15">
                      <IoLocationOutline size={26} />
                    </span>
                    <p className="text-sm font-bold text-[#dc3545]">
                      {t("unable_to_load_tracking_data")}
                    </p>
                    <p className="text-xs SecondaryTextColor">
                      {t("tracking_retry_hint") ||
                        "We'll keep checking automatically."}
                    </p>
                  </div>
                </div>
              )}
            </div>
          </div>
          )}

          {/* Delivery details and partner card grid container */}
          <div className="grid grid-cols-1 items-start gap-4 sm:grid-cols-10">
            {/* Delivery details section */}
            <div className="rounded-2xl border border-[var(--border-color)] p-4 sm:col-span-6">
              <div className="flex flex-col gap-3 border-b border-[var(--border-color)] pb-3">
                <div className="flex min-w-0 items-center gap-3">
                  <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg primaryLightBack primaryColor">
                    <IoLocationOutline size={19} />
                  </span>
                  <div className="min-w-0">
                    <h3 className="text-sm font-bold textColor">
                      {t("delivery_details_title") || "Delivery Details"}
                    </h3>
                    <p className="text-xs SecondaryTextColor">
                      {t("delivery_details_hint") ||
                        "Details of your current order"}
                    </p>
                  </div>
                </div>
              </div>

              <dl className="mt-3 flex flex-col gap-3">
                {deliveryAddress && (
                  <div>
                    <dt className="text-xs SecondaryTextColor">
                      {t("deliveryAddress")}
                    </dt>
                    <dd className="mt-0.5 text-sm font-semibold textColor leading-relaxed">
                      {deliveryAddress}
                    </dd>
                  </div>
                )}
                {customerName && (
                  <div>
                    <dt className="text-xs SecondaryTextColor">{t("name")}</dt>
                    <dd className="mt-0.5 text-sm font-semibold textColor">
                      {customerName}
                    </dd>
                  </div>
                )}
                {deliveryMobile && (
                  <div>
                    <dt className="text-xs SecondaryTextColor">
                      {t("mobileNumber") || t("phone")}
                    </dt>
                    <dd className="mt-0.5 text-sm font-semibold textColor">
                      {deliveryMobile}
                    </dd>
                  </div>
                )}
                {order?.payment_method && (
                  <div>
                    <dt className="text-xs SecondaryTextColor">
                      {t("payment_method")}
                    </dt>
                    <dd className="mt-0.5 text-sm font-semibold textColor capitalize">
                      {order?.payment_method}
                    </dd>
                  </div>
                )}
              </dl>
            </div>

            {/* Delivery partner information section */}
            {order?.delivery_boy_name ? (
              <div className="flex min-w-0 flex-col items-center rounded-2xl border border-[var(--border-color)] p-4 text-center sm:col-span-4">
                <h3 className="w-full truncate text-start text-sm font-bold textColor">
                  {t("delivery_partner_title") || "Delivery Partner"}
                </h3> 
                {riderAvatar ? (
                  <span className="relative mt-3 h-14 w-14 shrink-0 overflow-hidden rounded-full primaryLightBack">
                    <Image
                      src={riderAvatar}
                      alt={order?.delivery_boy_name}
                      fill
                      className="object-cover"
                    />
                  </span>
                ) : (
                  <span className="mt-3 flex h-14 w-14 shrink-0 items-center justify-center rounded-full primaryLightBack primaryColor text-lg font-bold uppercase">
                    {order?.delivery_boy_name?.charAt(0) || "?"}
                  </span>
                )}
                <p className="mt-2 w-full truncate text-sm font-bold textColor leading-snug">
                  {order?.delivery_boy_name}
                </p>
                <div className="mt-3 flex w-full min-w-0 items-stretch gap-2">
                  {order?.delivery_boy_mobile && (
                    <Link
                      href={`tel:${order?.delivery_boy_mobile}`}
                      className="flex h-10 min-w-0 flex-1 items-center justify-center gap-1.5 rounded-lg border primaryColorBorder primaryColor px-2 text-sm font-semibold transition hover:primaryBackColor hover:text-white active:scale-95"
                    >
                      <BiPhoneCall size={15} className="shrink-0" />
                      {t("call") || "Call"}
                    </Link>
                  )}
                  {order?.is_delivery_boy_chat_visible === true && (
                    <div className="min-w-0 flex-1 [&>button]:h-10 [&>button]:w-full [&>button]:rounded-lg [&>button]:px-2">
                      <DeliveryChat
                        orderId={order?.order_id ?? order?.id}
                        orderItemId={order?.id}
                        orderStatus={order?.active_status}
                        deliveryBoy={{
                          id: order?.delivery_boy_id,
                          name: order?.delivery_boy_name,
                          phone: order?.delivery_boy_mobile,
                        }}
                        variant="solid"
                        label={t("chat") || "Chat"}
                      />
                    </div>
                  )}
                </div>
              </div>
            ) : (
              <div className="rounded-2xl border border-[var(--border-color)] p-4 sm:col-span-4">
                <div className="flex items-center gap-3 border-b border-[var(--border-color)] pb-3">
                  <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg primaryLightBack primaryColor">
                    <LuBike size={18} />
                  </span>
                  <div className="min-w-0 flex-grow">
                    <h3 className="text-sm font-bold textColor">
                      {t("delivery_partner_title") || "Delivery Partner"}
                    </h3>
                    <p className="text-xs SecondaryTextColor">
                      {t("preparing_your_order") || "Preparing your order"}
                    </p>
                  </div>
                </div>
                <p className="mt-3 text-sm SecondaryTextColor">
                  {t("delivery_partner_assign_hint") ||
                    "A delivery partner will be assigned soon."}
                </p>
              </div>
            )}
          </div>
        </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
};

export default LiveTrackingModal;
