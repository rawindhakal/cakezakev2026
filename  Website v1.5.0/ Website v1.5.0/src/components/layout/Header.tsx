"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger} from "@/components/ui/dropdown-menu";
import * as api from "@/api/apiRoutes";
import {
  IoCartOutline,
  IoLocationOutline,
  IoHomeOutline,
  IoHome,
  IoSearchOutline,
  IoHeartOutline,
  IoBag,
  IoBagOutline,
  IoPersonOutline,
  IoPerson,
  IoArrowBack,
  IoLocationSharp,
  IoChevronDown} from "react-icons/io5";
import useLanguages from "@/hooks/useLanguages";
import { LuUser } from "react-icons/lu";
import { MdDirectionsWalk } from "react-icons/md";
import { BiCategoryAlt, BiSolidCategoryAlt } from "react-icons/bi";

import dynamic from "next/dynamic";
// Dynamic imports for overlays and Lottie
const CartDrawer = dynamic(() => import("../cart/CartDrawer"), { ssr: false });
const Login = dynamic(() => import("../login/Login"), { ssr: false });
import { t } from "@/utils/translation";
import { useDispatch, useSelector } from "react-redux";
import { setShowLocation as setShowLocationAction } from "@/redux/slices/locationModalSlice";
const Lottie = dynamic(() => import('lottie-react'), { ssr: false });
const Location = dynamic(() => import("../locationmodal/Location"), {
  ssr: false,
});
import {
  BiBell,
  BiBookmarkHeart,
  BiCartAlt,
  BiUserCircle,
  BiWallet,
  BiCaretRight} from "react-icons/bi";
import Link from "next/link";
import { usePathname, useParams, useRouter } from "next/navigation";
import { setCity } from "@/redux/slices/citySlice";
import { nextZoneRequestSeq, currentZoneRequestSeq } from "@/utils/zoneRequestSeq";

const LogoutModal = dynamic(() => import("../logoutmodal/LogoutModal"), {
  ssr: false,
});
const ProfileDrawer = dynamic(
  () => import("../profiledashboard/ProfileDrawer"),
  { ssr: false },
);
import { clearCheckout } from "@/redux/slices/checkoutSlice";
import {
  setCategoryBreadcrumb} from "@/redux/slices/productFilterSlice";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import { setShopMode, setDefaultApplied } from "@/redux/slices/shopModeSlice";
import { getPolygonCenter, pickDeviceImage } from "@/utils/helperFunction";
import useGeocode from "@/hooks/useGeocode";
import {
  setCartProducts,
  setCartSubTotal,
  setCartCurrency,
  setGuestChannel} from "@/redux/slices/cartSlice";
import SearchComponent from "../search/SearchComponent";
import useHydratedMediaQuery from "@/hooks/useHydratedMediaQuery";
import useZoneCityPending from "@/hooks/useZoneCityPending";
import { RiLogoutCircleRLine } from "react-icons/ri";
import { setSelectedLanguage } from "@/redux/slices/languageSlice";
import Image from "next/image";
const MobileNavSidebar = dynamic(
  () => import("../mobile-nav-sidebar/MobileNavSidebar"),
  { ssr: false },
);

import useLanguageSwitch from "@/hooks/useLanguageSwitch";
import useZoneHref from "@/hooks/useZoneHref";
import useNavClick from "@/hooks/useNavClick";
import useIsHydrated from "@/hooks/useIsHydrated";
import useCurrency from "@/hooks/useCurrency";
import useDeviceBreakpoint from "@/hooks/useDeviceBreakpoint";
import useMobileHeaderCollapse from "@/hooks/useMobileHeaderCollapse";
import useSearchSuggestions from "@/hooks/useSearchSuggestions";
import AnimatedEta from "@/components/ui/AnimatedEta";
import { getZoneForChannel } from "@/utils/zoneChannel";
import { guestCartItemsParam, guestRowsHaveAddons } from "@/utils/addons";

// Cart icon with animated indicator
const hexToHsl = (hex: string) => {
  const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(String(hex || "").trim());
  if (!m) return null;
  const r = Number.parseInt(m[1], 16) / 255;
  const g = Number.parseInt(m[2], 16) / 255;
  const b = Number.parseInt(m[3], 16) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  let h = 0;
  let s = 0;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
    else if (max === g) h = ((b - r) / d + 2) / 6;
    else h = ((r - g) / d + 4) / 6;
  }
  return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) };
};

// Generate gradient stops from brand color
const colorToGradientStops = (color: string) => {
  const hsl = hexToHsl(color);
  if (!hsl) return null;
  return {
    dark: `hsl(${hsl.h}, ${hsl.s}%, ${Math.max(0, hsl.l - 14)}%)`,
    light: `hsl(${hsl.h}, ${hsl.s}%, ${Math.min(100, hsl.l + 12)}%)`,
  };
};

// Parse CSS color to normalized RGB array
const toLottieRgb = (css?: string | null): [number, number, number] => {
  if (!css) return [1, 1, 1];
  const c = css.trim();
  if (c.startsWith("#")) {
    let h = c.slice(1);
    if (h.length === 3)
      h = h
        .split("")
        .map((x) => x + x)
        .join("");
    const n = Number.parseInt(h, 16);
    return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
  }
  const m = c.match(/(\d+(\.\d+)?)/g);
  if (m && m.length >= 3) return m.slice(0, 3).map((v) => Number(v) / 255) as [number, number, number];
  return [1, 1, 1];
};

// Tint Lottie animation shapes
const tintLottie = (data: any, rgb: [number, number, number]) => {
  const clone = structuredClone(data);
  const walk = (node: any) => {
    if (Array.isArray(node)) return node.forEach(walk);
    if (node && typeof node === "object") {
      if (
        (node.ty === "fl" || node.ty === "st") &&
        node.c &&
        Array.isArray(node.c.k)
      ) {
        node.c.k = [rgb[0], rgb[1], rgb[2], node.c.k[3] ?? 1];
      }
      Object.values(node).forEach(walk);
    }
  };
  walk(clone);
  return clone;
};

interface CartIconAnimationProps {
  count: number;
  badgeClass: string;
  size?: number;
}

const CartIconAnimation = ({ count, badgeClass, size = 26 }: CartIconAnimationProps) => {
  const isHydrated = useIsHydrated();
  const showBadge = isHydrated && count > 0;
  const lottieRef = useRef(null);
  const prevCount = useRef(count);
  const [anim, setAnim] = useState<any>(null);

  const tinted = useMemo(() => {
    if (!anim || typeof window === "undefined") return anim;
    const css = getComputedStyle(document.documentElement)
      .getPropertyValue("--layout-header-text")
      .trim();
    return tintLottie(anim, toLottieRgb(css));
  }, [anim]);

  useEffect(() => {
    if (count > prevCount.current) {
      import("@/assets/shopping-cart.json").then((mod) => setAnim(mod.default));
    } else if (count < prevCount.current) {
      import("@/assets/empty-cart.json").then((mod) => setAnim(mod.default));
    }
    prevCount.current = count;
  }, [count]);

  return (
    <span data-cart-target className="relative inline-flex flex-shrink-0">
      {anim ? (
        <Lottie
          lottieRef={lottieRef}
          animationData={tinted}
          loop={false}
          autoplay
          onComplete={() => setAnim(null)}
          style={{ width: size, height: size }}
        />
      ) : (
        <IoCartOutline size={size} className="layoutHeaderText" />
      )}
      {showBadge && (
        <span className={badgeClass}>
          <span key={count} className={`inline-block ${anim ? "motion-safe:animate-qtyPop" : ""}`}>
            {count}
          </span>
        </span>
      )}
    </span>
  );
};

const Header = () => {
  const switchLanguageUrl = useLanguageSwitch();
  const zoneHref = useZoneHref();
  const { reverseGeocode } = useGeocode();
  const router = useRouter();
  const { run: runNavClick } = useNavClick();
  const pathname = usePathname();
  const dispatch = useDispatch();
  const routeParams = useParams<{ zone?: string }>();

  const zoneSlugFromUrl = routeParams?.zone ?? null;

  // Check if current route is Home
  const { parseLangPath } = useLanguages();
  const isHomeRoute = (() => {
    const { rest } = parseLangPath(pathname || "/");
    const segments = rest.filter(Boolean);
    if (segments[0] && segments[0] === zoneSlugFromUrl) segments.shift();
    return segments.length === 0;
  })();

  // Hydration state check
  const isHydrated = useIsHydrated();

  const cart = useSelector((state: any) => state.Cart);
  const setting = useSelector((state: any) => state.Setting);
  const defaultCityLat = useSelector(
    (state: any) => state.Setting?.setting?.default_city?.latitude,
  );
  const defaultCityLng = useSelector(
    (state: any) => state.Setting?.setting?.default_city?.longitude,
  );
  const user = useSelector((state: any) => state.User);
  const { currency: cartCurrency } = useCurrency();
  const sumQty = (list: any[]) =>
    Array.isArray(list)
      ? list.reduce((n, p) => n + (Number(p?.qty) || 0), 0)
      : 0;
  const cartItemCount =
    cart?.isGuest === true
      ? sumQty(cart?.guestCart)
      : sumQty(cart?.cartProducts);
  const cartTotal =
    Number(
      cart?.isGuest === true
        ? cart?.guestCartTotal
        : cart?.cartSubTotal || cart?.cart?.data?.sub_total,
    ) || 0;
  // Selected city coordinates and details
  const cityLat = useSelector((state: any) => state.City.city?.latitude);
  const cityLng = useSelector((state: any) => state.City.city?.longitude);
  const cityStatus = useSelector((state: any) => state.City.status);
  const cityAddress = useSelector(
    (state: any) => state.City.city?.formatted_address,
  );
  const cityDistance = useSelector((state: any) => state.City.city?.distance);
  const hasCity = useSelector((state: any) => state.City.city != null);
  const citySlug = useSelector((state: any) => state.City.city?.slug ?? null);
  const selectedZoneName = useSelector(
    (state: any) => state?.LocationModal?.selectedZone?.name,
  );
  const selectedZoneSlug = useSelector(
    (state: any) => state?.LocationModal?.selectedZone?.slug,
  );
  useEffect(() => {
    if (process.env.NODE_ENV !== "production") {
      console.log("[ZONE TRACE] zone/location changed", {
        selectedZoneName,
        selectedZoneSlug,
        cityAddress,
        citySlug,
        paramsZone: zoneSlugFromUrl,
      });
    }
  }, [selectedZoneName, selectedZoneSlug, cityAddress, citySlug, zoneSlugFromUrl]);
  const filter = useSelector((state: any) => state.ProductFilter);
  const { setSearch: setUrlSearch } = useUrlProductFilters();
  const {
    searchText,
    setSearchText,
    isSuggLoading,
    isSuggError,
    correctedTerm,
    handleSearch,
    handleSearchRetry,
  } = useSearchSuggestions();
  const language = useSelector((state: any) => state.Language);
  const fcmToken = useSelector((state: any) => state.User?.fcm_token);
  const shopMode = useSelector((state: any) => state.ShopMode.mode);
  const deliveryTime = useSelector((state: any) => state.ShopMode.deliveryTime);
  const deliveryDistance = useSelector(
    (state: any) => state.ShopMode.deliveryDistance,
  );

  // Fetch cart for selected shop mode
  const cartFetchKeyRef = useRef<string | null>(null);
  const cartFetchSeqRef = useRef(0);
  const fetchCartForMode = async () => {
    if (!user?.jwtToken) return;
    const channel = shopMode === "quick" ? "quick" : "ecommerce";
    const fetchKey = `${channel}|${cityLat}|${cityLng}`;
    if (cartFetchKeyRef.current === fetchKey) return;
    cartFetchKeyRef.current = fetchKey;
    const mySeq = ++cartFetchSeqRef.current;
    try {
      const cartData = await api.getCart({
        latitude: cityLat,
        longitude: cityLng,
      });
      if (mySeq !== cartFetchSeqRef.current) return;
      if (cartData?.data?.currency) {
        dispatch(setCartCurrency({ data: cartData.data.currency, channel }));
      }
      if (cartData?.status == 1) {
        const productsData = cartData?.data?.cart?.map((item: any) => ({
          product_id: item?.id,
          product_variant_id: item?.variant_id,
          addons: item?.addons ?? [],
          qty: item?.variants?.[0]?.quantity ?? item?.quantity,
        }));
        dispatch(setCartProducts({ data: productsData }));
        dispatch(setCartSubTotal({ data: cartData?.data?.sub_total }));
      } else {
        dispatch(setCartProducts({ data: [] }));
        dispatch(setCartSubTotal({ data: 0 }));
      }
    } catch (error) {
      if (cartFetchKeyRef.current === fetchKey) cartFetchKeyRef.current = null;
      console.log("fetchCartForMode error", error);
    }
  };

  // Toggle shop mode and navigate home
  const handleModeToggle = (mode: string) => {
    if (mode === shopMode) return;
    dispatch(setShopMode({ mode }));
    const home = zoneHref("/");
    if (pathname !== home) {
      runNavClick(() => router.push(home));
    }
  };

  const fetchGuestCartCurrency = async () => {
    if (!(cart?.isGuest === true && cart?.guestCart?.length > 0)) return;
    const channel = shopMode === "quick" ? "quick" : "ecommerce";
    try {
      const withAddons = guestRowsHaveAddons(cart.guestCart);
      const response = await api.getGuestCart({
        latitude: cityLat,
        longitude: cityLng,
        variant_ids: withAddons
          ? undefined
          : cart.guestCart.map((p: any) => p.product_variant_id).join(","),
        quantities: withAddons
          ? undefined
          : cart.guestCart.map((p: any) => p.qty).join(","),
        items: withAddons ? guestCartItemsParam(cart.guestCart) : undefined,
      });
      if (response?.status == 1 && response?.data?.currency) {
        dispatch(setCartCurrency({ data: response.data.currency, channel }));
      }
    } catch (error) {
      console.log("guest cart currency error", error);
    }
  };

  useEffect(() => {
    if (!shopMode) return;
    const channel = shopMode === "quick" ? "quick" : "ecommerce";
    dispatch(setGuestChannel({ channel }));
  }, [shopMode, cart?.guestCartByChannel, dispatch]);

  const cartDepTraceRef = useRef<any>(null);
  useEffect(() => {
    if (process.env.NODE_ENV !== "production") {
      const now = {
        shopMode,
        jwt: user?.jwtToken ? "yes" : "no",
        isGuest: cart?.isGuest,
        guestLen: cart?.guestCart?.length,
        cityLat,
        cityLng,
      };
      const prev = cartDepTraceRef.current;
      const changed = prev
        ? Object.keys(now).filter(
            (k) => (now as any)[k] !== (prev as any)[k],
          )
        : ["<first run>"];
      console.log("[CART TRACE] effect fired, changed deps:", changed, now);
      cartDepTraceRef.current = now;
    }
    if (!shopMode) return;
    if (user?.jwtToken) {
      if (cityLat == null) return;
      fetchCartForMode();
    } else {
      fetchGuestCartCurrency();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    shopMode,
    user?.jwtToken,
    cart?.isGuest,
    cart?.guestCart?.length,
    cityLat,
    cityLng,
  ]);

  const layoutMode = useSelector((state: any) => state.ShopMode.layoutMode);
  const requestedMode = useSelector((state: any) => state.ShopMode.requested);
  const defaultApplied = useSelector((state: any) => state.ShopMode.defaultApplied);
  const layoutTheme = useSelector((state: any) => state.ShopMode.layoutTheme);
  const quickLabel = useSelector((state: any) => state.ShopMode.quickLabel) || "";
  const ecommerceLabel =
    useSelector((state: any) => state.ShopMode.ecommerceLabel) || "";
  const availableModes = useSelector((state: any) => state.ShopMode.availableModes);
  const showShopModeToggle = isHydrated && availableModes === "both";

  const device = useDeviceBreakpoint();

  useEffect(() => {
    const root = document.documentElement;
    if (!layoutTheme) return;
    if (
      layoutTheme.background_theme === "image" &&
      layoutTheme.background_image_url
    ) {
      const bgUrl =
        typeof layoutTheme.background_image_url === "object"
          ? pickDeviceImage(layoutTheme.background_image_url, device)
          : layoutTheme.background_image_url;
      if (!bgUrl) return;
      const img = `url(${bgUrl})`;
      root.style.setProperty("--layout-header-gradient", img);
      root.style.setProperty("--layout-header-gradient-continue", img);
      root.style.setProperty("--layout-header-bg-pos", "left top");
      root.style.setProperty(
        "--layout-strip-bg-pos",
        "left calc(-1 * var(--layout-header-h))",
      );
      root.style.setProperty("--layout-header-bg-image", "none");
      root.style.removeProperty("--layout-header-bg");
      root.style.removeProperty("--layout-[#strip-bg]");
      const headerEl = document.getElementById("site-header");
      const combinedHeightPx =
        (headerEl?.getBoundingClientRect().height || 0) +
        (Number.parseFloat(
          getComputedStyle(root).getPropertyValue("--layout-strip-h"),
        ) || 0);
      const applySize = (widthPercent: number) => {
        const total =
          "max(100%, calc(var(--layout-header-h) + var(--layout-strip-h)))";
        const size = `max(100%, ${widthPercent}%) ${total}`;
        root.style.setProperty("--layout-header-bg-size", size);
        root.style.setProperty("--layout-strip-bg-size", size);
      };
      if (typeof window !== "undefined" && combinedHeightPx > 0) {
        const probe = new window.Image();
        probe.onload = () => {
          if (!probe.naturalWidth || !probe.naturalHeight) return;
          const aspect = probe.naturalWidth / probe.naturalHeight;
          const viewportWidth = window.innerWidth || 1;
          const widthPercent =
            ((combinedHeightPx * aspect) / viewportWidth) * 100;
          applySize(widthPercent);
        };
        probe.src = bgUrl;
      }
      applySize(100);
    } else if (layoutTheme.background_color) {
      const base = layoutTheme.background_color;
      const stops = colorToGradientStops(base);
      const gradient = stops
        ? `linear-gradient(to bottom, ${stops.dark}, ${stops.light})`
        : "none";
      const stripEnd = stops ? stops.light : base;
      const total = "max(100%, calc(var(--layout-header-h) + var(--layout-strip-h)))";
      root.style.setProperty("--layout-header-bg", base);
      root.style.setProperty("--layout-strip-bg", stripEnd);
      root.style.setProperty("--layout-header-gradient", gradient);
      root.style.setProperty("--layout-header-gradient-continue", gradient);
      root.style.setProperty("--layout-header-bg-size", `100% ${total}`);
      root.style.setProperty("--layout-header-bg-pos", "left top");
      root.style.setProperty("--layout-strip-bg-size", `100% ${total}`);
      root.style.setProperty(
        "--layout-strip-bg-pos",
        "left calc(-1 * var(--layout-header-h))",
      );
      root.style.setProperty("--layout-header-bg-image", "none");
    }
    if (layoutTheme.text_color) {
      root.style.setProperty("--layout-header-text", layoutTheme.text_color);
    }
  }, [layoutTheme, device]);

  // Sync shop mode with URL zone slug
  const primedZoneModeRef = useRef<string | null>(null);
  useEffect(() => {
    if (!zoneSlugFromUrl) return;
    if (primedZoneModeRef.current === zoneSlugFromUrl) return;
    const urlMode = zoneSlugFromUrl.endsWith("-ecommerce")
      ? "allShop"
      : zoneSlugFromUrl.endsWith("-quick")
        ? "quick"
        : null;
    if (!urlMode) return;
    primedZoneModeRef.current = zoneSlugFromUrl;
    if (urlMode !== shopMode) {
      dispatch(setShopMode({ mode: urlMode }));
    }
    dispatch(setDefaultApplied());
  }, [zoneSlugFromUrl, shopMode, dispatch]);

  useEffect(() => {
    if (!layoutMode && !availableModes) return;
    if (availableModes === "both") {
      if (!defaultApplied) {
        const def =
          layoutMode === "allShop" || requestedMode === "allShop"
            ? "allShop"
            : "quick";
        dispatch(setShopMode({ mode: def }));
        dispatch(setDefaultApplied());
      }
    } else {
      const singleChannelMode = layoutMode === "allShop" ? "allShop" : "quick";
      if (singleChannelMode !== shopMode) {
        dispatch(setShopMode({ mode: singleChannelMode }));
      }
    }
  }, [layoutMode, availableModes, requestedMode, defaultApplied, shopMode, dispatch]);

  const hasLocation = cityStatus === "fulfill";
  const hasInvalidUrlZone = useZoneCityPending();
  const settingsDeliveryTime =
    setting?.setting?.web_settings?.delivery_time ||
    setting?.setting?.delivery_time ||
    10;
  const quickDeliveryTime = deliveryTime || settingsDeliveryTime;
  const quickDeliveryHasUnit = !!deliveryTime;
  const quickDeliveryLabel = `${quickDeliveryTime}${quickDeliveryHasUnit ? "" : ` ${t("minutes")}`}`;
  const showQuickDelivery = shopMode === "quick" && hasLocation;
  const rawDistance = deliveryDistance || cityDistance;
  const distanceKm =
    rawDistance && !/^0(\.0+)?\s*km/i.test(String(rawDistance).trim())
      ? String(rawDistance).trim()
      : null;

  const isMobile = useHydratedMediaQuery("(max-width: 765px)");

  const [showCart, setShowCart] = useState(false);
  const [showLogin, setShowLogin] = useState(false);
  const [showLogout, setShowLogout] = useState(false);
  const [mobileActiveKey, setMobileActiveKey] = useState(1);
  const [selectedTab, setSelectedTab] = useState("profile");
  const [showProfile, setShowProfile] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);

  const showLocation = useSelector(
    (state: any) => state?.LocationModal?.showLocation,
  );
  const setShowLocation = useCallback(
    (value: boolean) => dispatch(setShowLocationAction(!!value)),
    [dispatch],
  );

  const [mobileNav, setMobileNav] = useState(false);

  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMounted(true);
  }, []);

  useEffect(() => {
    if (pathname != "/checkout") {
      dispatch(clearCheckout());
    }
  }, [pathname, dispatch]);


  // Seed city from URL zone slug
  const seedCityFromZoneSlug = async (slug: string, mySeq: number) => {
    const zonesRes = await api.getZones();
    const zones = zonesRes?.data || [];
    const zone = zones.find((z: any) => z?.slug === slug);
    if (!zone) return false;
    const center = getPolygonCenter(zone.polygon_boundary);
    if (!center) return false;
    const response = await getZoneForChannel({
      latitude: center.lat,
      longitude: center.lng,
      dispatch,
    });
    if (response?.status !== 1) return false;
    let resolvedAddress = response.data?.formatted_address;
    if (!resolvedAddress) {
      try {
        const geo = await reverseGeocode(center.lat, center.lng);
        resolvedAddress = geo?.formatted_address || zone.name;
      } catch (err) {
        resolvedAddress = zone.name;
      }
    }
    if (mySeq !== currentZoneRequestSeq()) return true;
    dispatch(
      setCity({
        data: {
          ...response.data,
          formatted_address: resolvedAddress,
          latitude: center.lat,
          longitude: center.lng,
        },
      }),
    );
    return true;
  };

  const fetchingCityRef = useRef(false);
  const fetchCity = async () => {
    // Check if zone from URL matches current city or selected zone
    const urlIsAuthoritative =
      !selectedZoneSlug || zoneSlugFromUrl === selectedZoneSlug;
    const zoneMismatch =
      !!zoneSlugFromUrl && zoneSlugFromUrl !== citySlug && urlIsAuthoritative;
    if ((hasCity && !zoneMismatch) || fetchingCityRef.current) return;
    fetchingCityRef.current = true;
    const mySeq = nextZoneRequestSeq();
    try {
      if (zoneSlugFromUrl) {
        const seeded = await seedCityFromZoneSlug(zoneSlugFromUrl, mySeq);
        if (seeded) return;
        setShowLocation(true);
        return;
      }
      if (setting?.setting?.default_city) {
        const latitude = Number.parseFloat(
          setting.setting.default_city?.latitude,
        );
        const longitude = Number.parseFloat(
          setting.setting.default_city?.longitude,
        );
        const response = await getZoneForChannel({
          latitude: latitude,
          longitude: longitude,
          dispatch,
        });
        if (mySeq !== currentZoneRequestSeq()) return;
        if (response.status === 1) {
          dispatch(
            setCity({ data: { ...response.data, latitude, longitude } }),
          );
        } else {
          setShowLocation(true);
        }
      } else if (setting?.setting && !hasCity) {
        setShowLocation(true);
      }
    } catch (error) {
      console.log("error", error);
    } finally {
      fetchingCityRef.current = false;
    }
  };

  useEffect(() => {
    fetchCity();
    // Depends on the specific fields fetchCity reads, not the whole setting object (which changes reference on every rehydrate/refetch).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [!!setting?.setting, defaultCityLat, defaultCityLng, zoneSlugFromUrl, citySlug, selectedZoneSlug]);
  useEffect(() => {
    // Syncs bottom-nav highlight with the current route.
    const path = pathname || "";
    if (path.includes("/activeorders") || path.includes("/orders")) {
      // intentional: derives the active bottom-nav key from the route on
      // every navigation — an external signal (pathname), not render state.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setMobileActiveKey(3); // Orders
    } else if (path.includes("/profile")) {
      setMobileActiveKey(4); // Profile
    } else if (/\/categories(\/|$)/.test(path)) {
      setMobileActiveKey(2); // Categories
    } else if (isHomeRoute) {
      setMobileActiveKey(1); // Home
    } else {
      setMobileActiveKey(0); // Product, cart, etc. — no tab
    }
  }, [pathname, isHomeRoute]);

  const handleLanguageChange = async (language: any) => {
    try {
      const response = await api.getSystemLanguages({
        id: language?.id,
        isDefault: 0,
        systemType: 3,
      });
      if (response.status == 1) {
        dispatch(setSelectedLanguage({ data: response?.data }));
        document.documentElement.dir = response?.data?.type;
        // Same user action as the URL move, so the language segment and Redux stay in step.
        switchLanguageUrl(response?.data?.code);
        // Auth-gated (401 without a JWT); isolated try so a token failure doesn't break the language switch.
        if (user?.jwtToken && fcmToken) {
          try {
            await api.updateFcmToken({
              langaugeId: response?.data?.admin_lang_id_for_fcm,
              fcmToken,
            });
          } catch (fcmErr: any) {
            console.log("FCM token update failed:", fcmErr?.message);
          }
        }
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  const handleCartOpen = () => {
    if (pathname == "/checkout") {
      runNavClick(() => router.push(zoneHref("/cart")));
    } else {
      setShowCart(true);
    }
  };

  const handleLoginOpen = () => {
    setShowLogin(true);
  };

  const handleOpenLocation = () => {
    setShowLocation(true);
  };

  // Handle navigation to home
  const handleHomeClick = () => {
    setMobileActiveKey(1);
    runNavClick(() => router.push(zoneHref("/")));
  };

  const handleCategoriesClick = () => {
    setMobileActiveKey(2);
    dispatch(setCategoryBreadcrumb({ data: [] }));
    runNavClick(() => router.push(zoneHref("/categories")));
  };

  // Mobile back button handler
  const handleMobileBack = () => {
    if (typeof window !== "undefined" && window.history.length > 1) {
      router.back();
    } else {
      runNavClick(() => router.push(zoneHref("/")));
    }
  };

  const handleFavouritesClick = () => {
    setMobileActiveKey(3);
    if (user?.jwtToken) {
      runNavClick(() => router.push(zoneHref("/profile/wishlist")));
    } else {
      setShowLogin(true);
    }
  };

  const handleOrdersClick = () => {
    setMobileActiveKey(3);
    if (user?.jwtToken) {
      runNavClick(() => router.push(zoneHref("/profile/activeorders")));
    } else {
      setShowLogin(true);
    }
  };

  const handleProfileClick = () => {
    setMobileActiveKey(4);
    if (user?.jwtToken) {
      setShowProfile(true);
    } else {
      setShowLogin(true);
    }
  };

  // Search is its own full-screen route (Blinkit-style) on every screen size.
  const searchHref = zoneHref("/search");
  useEffect(() => {
    router.prefetch(searchHref);
  }, [router, searchHref]);
  const handleMobileSearch = () => {
    runNavClick(() => router.push(searchHref));
  };

  const renderShopModeToggle = () => {
    return (
      <div
        dir="ltr"
        className="relative grid grid-cols-2 items-center rounded-lg p-0 xl:p-1 gap-1.5 select-none flex-shrink-0"
      >
        <button
          type="button"
          onClick={() => handleModeToggle("quick")}
          className={`flex items-center justify-center gap-1.5 px-3 lg:px-4 h-[37px] xl:h-[32px] text-xs font-semibold whitespace-nowrap rounded-lg transition-colors duration-300 outline-none focus:outline-none ${
            shopMode === "quick"
              ? "bg-white text-gray-900 shadow-sm"
              : "bg-black/35 text-white"
          }`}
        >
          <span>{quickLabel}</span>
        </button>
        <button
          type="button"
          onClick={() => handleModeToggle("allShop")}
          className={`flex items-center justify-center gap-1.5 px-3 lg:px-4 h-[37px] xl:h-[32px] text-xs font-semibold whitespace-nowrap rounded-lg transition-colors duration-300 outline-none focus:outline-none ${
            shopMode === "allShop"
              ? "bg-white text-gray-900 shadow-sm"
              : "bg-black/35 text-white"
          }`}
        >
          <span>{ecommerceLabel}</span>
        </button>
      </div>
    );
  };

  // Mobile home header height collapse on scroll
  const collapseHomeTop = isHomeRoute && isMobile === true;
  const { mobileTopRef, mobileTopH, showBackToTop } =
    useMobileHeaderCollapse(collapseHomeTop);

  // View Cart pill: rendered by layout/MobileViewCartPill (all pages).

  const deliveryAddress =
    mounted &&
    !hasInvalidUrlZone &&
    (cityAddress || selectedZoneName || setting?.setting?.default_city?.name)
      ? cityAddress || selectedZoneName || setting?.setting?.default_city?.name
      : null;

  return (
    <>
      <header
        id="site-header"
        style={
          collapseHomeTop && mobileTopH
            ? ({ "--header-sticky-top": `-${mobileTopH}px` } as React.CSSProperties)
            : undefined
        }
        className={`sticky top-0 z-50 w-full layoutHeaderGradient layoutHeaderText ${
          // Mobile product list draws its own "‹ Title" bar (app style).
          /\/search\/?$/.test(pathname || "")
            ? "hidden"
            : /\/products\/?$/.test(pathname || "")
              ? "max-md:hidden"
              : ""
        } ${
          // Mobile, non-home: plain primary header with white text instead of
          // the themed gradient/image (vars scoped to this element only).
          isHomeRoute
            ? ""
            : "max-md:[--layout-header-bg:var(--primary-color)] max-md:[--layout-header-gradient:none] max-md:[--layout-header-text:#ffffff]"
        }`}
      >
        {/* ═══════════ Main Header ═══════════ */}
        <div className="layoutHeaderText">
          <div className="w-full px-4 md:px-4 lg:px-10">
            {/* ── Desktop Main Row (md+) ── */}
            <div className="hidden md:flex flex-col xl:flex-row xl:items-center xl:h-[68px] xl:gap-5">
              {/* Row 1: Logo + Location + ShopMode + Cart + Profile */}
              <div className="flex items-center h-[68px] xl:h-auto xl:flex-1 gap-2 xl:gap-5">
                {/* Logo */}
                <Link
                  href={zoneHref("/")}
                  aria-label="Home" // static label so the link is named pre-mount too; not t() to avoid an SSR/locale mismatch
                  className="relative flex-shrink-0 h-[38px] w-[115px] lg:w-[140px]"
                >
                  {mounted && setting?.setting?.web_settings?.web_logo && (
                    <Image
                      src={setting?.setting?.web_settings?.web_logo}
                      alt="Logo"
                      fill
                      priority={true}
                      fetchPriority="high"
                      loading="eager"
                      className="object-contain"
                    />
                  )}
                </Link>

                {/* Location — md+. Doesn't grow below xl (search is on Row 2
                    there), so the logo+location group stays left and cart+profile
                    pin right via ml-auto instead of a stretched location leaving
                    an awkward gap. */}
                <span className="w-px h-8 shortDescriptionTextBg flex-shrink-0" />
                <button
                  type="button"
                  className="flex items-center gap-1.5 cursor-pointer flex-shrink-0 flex-none hover:opacity-70 transition-opacity min-w-0 text-start"
                  onClick={handleOpenLocation}
                >
                  <IoLocationOutline
                    size={18}
                    className="shortDescriptionText flex-shrink-0"
                  />
                  <div className="flex flex-col min-w-0">
                    {mounted && showQuickDelivery ? (
                      <span className="text-sm font-extrabold leading-tight whitespace-nowrap">
                        {t("delivery_in")} <AnimatedEta value={quickDeliveryLabel} />
                        {distanceKm && (
                          <span className="text-sm font-extrabold leading-tight whitespace-nowra ">
                            {" · "}
                            {distanceKm}
                          </span>
                        )}
                      </span>
                    ) : (
                      <span className="text-[10px] shortDescriptionText leading-none uppercase tracking-wide mb-0.5">
                        {mounted ? t("deliver_to") : "Deliver to"}
                      </span>
                    )}
                    <span
                      className={`flex items-center gap-0.5 leading-tight max-w-full lg:max-w-[180px] xl:max-w-[260px] ${
                        mounted && showQuickDelivery
                          ? "text-[11px] font-normal shortDescriptionText"
                          : "text-sm font-bold"
                      }`}
                    >
                      {mounted &&
                      !hasInvalidUrlZone &&
                      (cityAddress ||
                        selectedZoneName ||
                        setting?.setting?.default_city?.name) ? (
                        <span className="truncate min-w-0">
                          {cityAddress ||
                            selectedZoneName ||
                            setting?.setting?.default_city?.name}
                        </span>
                      ) : (
                        <span className="opacity-50 text-xs font-normal">
                          {mounted ? t("loading") : "Loading"}
                        </span>
                      )}
                      <BiCaretRight
                        size={10}
                        className="rotate-90 flex-shrink-0 opacity-40"
                      />
                    </span>
                  </div>
                </button>
                {/* Search inline — xl+ only (fills the row). Below xl (incl. the
                    1024px lg range) it drops to the full-width Row 2, so Row 1
                    doesn't cram search + toggle + cart + profile into one line. */}
                <span className="hidden xl:block w-px h-8 shortDescriptionTextBg flex-shrink-0" />
                <div className="hidden xl:flex flex-1 min-w-0">
                  <SearchComponent
                    isSuggLoading={isSuggLoading}
                    isSuggError={isSuggError}
                    correctedTerm={correctedTerm}
                    onRetrySearch={handleSearchRetry}
                    isMobile={isMobile}
                    searchText={searchText}
                    onResultClick={() => setSearchText("")}
                    handleSearch={handleSearch}
                    onActivate={handleMobileSearch}
                  />
                </div>
                <span className="hidden xl:block w-px h-8 shortDescriptionTextBg flex-shrink-0" />

                {/* Shop mode toggle — xl+ inline; below xl it moves to the search
                    row below to keep Row 1 from overflowing on tablets/small
                    laptops (the 1024px range was cramped). */}
                {showShopModeToggle && (
                  <>
                    <div className="hidden xl:block flex-shrink-0">
                      {renderShopModeToggle()}
                    </div>
                    <span className="hidden xl:block w-px h-8 shortDescriptionTextBg flex-shrink-0" />
                  </>
                )}

                {/* Cart — pinned to the right below xl (ml-auto) so it and the
                    profile sit at the row's end; at xl the inline search fills the
                    middle, so the auto margin is removed. */}
                <button
                  type="button"
                  className="flex items-center gap-2 cursor-pointer flex-shrink-0 ml-auto xl:ml-0 px-2 py-1.5 rounded-xl transition-colors duration-200"
                  onClick={handleCartOpen}
                >
                  <CartIconAnimation
                    count={cartItemCount}
                    size={28}
                    badgeClass="flex absolute -top-1 -right-1.5 bodyTextColor textBackground rounded-full h-[16px] w-[16px] items-center justify-center font-bold text-[9px]"
                  />
                  {mounted && cartItemCount > 0 && (
                    <div className="hidden lg:flex flex-col text-start">
                      <span className="text-xs shortDescriptionText leading-tight">
                        {t("your_cart")}
                      </span>
                      <span className="text-sm font-bold leading-tight">
                        {cartCurrency}
                        {cartTotal?.toFixed(
                          setting?.setting?.decimal_point || 0,
                        )}
                      </span>
                    </div>
                  )}
                </button>

                {/* Profile / Login — gate on mounted: the JWT comes from
                    redux-persist (localStorage), invisible to the server, so the
                    server always renders the guest button. Without the gate the
                    client's logged-in dropdown mismatches the server's button. */}
                {mounted && user?.jwtToken !== "" ? (
                  <div
                    className="flex-shrink-0"
                    onMouseEnter={() => setProfileOpen(true)}
                    onMouseLeave={() => setProfileOpen(false)}
                  >
                    <DropdownMenu
                      open={profileOpen}
                      onOpenChange={setProfileOpen}
                    >
                      <DropdownMenuTrigger className="flex items-center gap-1.5 border-none outline-none shadow-none px-3 py-2 rounded-xl">
                        <LuUser size={20} className="shortDescriptionText" />
                        <span className="hidden lg:inline text-sm font-semibold max-w-[120px] truncate">
                          {user?.user?.name || t("profile")}
                        </span>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent
                        className="w-[220px] p-1.5"
                        sideOffset={0}
                        onMouseEnter={() => setProfileOpen(true)}
                        onMouseLeave={() => setProfileOpen(false)}
                      >
                        <Link href={zoneHref("/profile")}>
                          <DropdownMenuItem className="flex items-center gap-3 px-3 py-2.5 rounded-lg cursor-pointer">
                            <BiUserCircle size={20} className="opacity-70" />
                            <span className="font-medium">
                              {t("editProfile")}
                            </span>
                          </DropdownMenuItem>
                        </Link>
                        <Link href={zoneHref("/profile/activeorders")}>
                          <DropdownMenuItem className="flex items-center gap-3 px-3 py-2.5 rounded-lg cursor-pointer">
                            <BiCartAlt size={20} className="opacity-70" />
                            <span className="font-medium">{t("orders")}</span>
                          </DropdownMenuItem>
                        </Link>
                        <Link href={zoneHref("/profile/wishlist")}>
                          <DropdownMenuItem className="flex items-center gap-3 px-3 py-2.5 rounded-lg cursor-pointer">
                            <BiBookmarkHeart size={20} className="opacity-70" />
                            <span className="font-medium">{t("wishlist")}</span>
                          </DropdownMenuItem>
                        </Link>
                        <Link href={zoneHref("/profile/notifications")}>
                          <DropdownMenuItem className="flex items-center gap-3 px-3 py-2.5 rounded-lg cursor-pointer">
                            <BiBell size={20} className="opacity-70" />
                            <span className="font-medium">
                              {t("notification")}
                            </span>
                          </DropdownMenuItem>
                        </Link>
                        <Link href={zoneHref("/profile/address")}>
                          <DropdownMenuItem className="flex items-center gap-3 px-3 py-2.5 rounded-lg cursor-pointer">
                            <IoLocationOutline
                              size={20}
                              className="opacity-70"
                            />
                            <span className="font-medium">
                              {t("myAddress")}
                            </span>
                          </DropdownMenuItem>
                        </Link>
                        <Link href={zoneHref("/profile/wallethistory")}>
                          <DropdownMenuItem className="flex items-center gap-3 px-3 py-2.5 rounded-lg cursor-pointer">
                            <BiWallet size={20} className="opacity-70" />
                            <span className="font-medium">
                              {t("walletBalance")}
                            </span>
                          </DropdownMenuItem>
                        </Link>
                        <div className="my-1 h-px shortDescriptionTextBg"></div>
                        <DropdownMenuItem
                          className="flex items-center gap-3 px-3 py-2.5 rounded-lg cursor-pointer text-red-500"
                          onSelect={() => setShowLogout(true)}
                        >
                          <RiLogoutCircleRLine size={18} />
                          <span className="font-medium">{t("logout")}</span>
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                ) : (
                  <button
                    type="button"
                    className="flex items-center gap-1.5 cursor-pointer flex-shrink-0 px-3 py-2 rounded-xl"
                    onClick={handleLoginOpen}
                  >
                    <LuUser size={20} className="shortDescriptionText" />
                    <span className="hidden lg:inline text-sm font-semibold">
                      {mounted ? t("login") : "Login"}
                    </span>
                  </button>
                )}
              </div>
              {/* end Row 1 */}

              {/* Row 2: md + lg (below xl). Row 1 has no inline search/toggle
                  below xl, so both live here on a full-width row. At xl+
                  everything is inline in Row 1, so this row is hidden. */}
              <div className="flex xl:hidden items-center gap-3 pb-3">
                <div className="flex-1 min-w-0">
                  <SearchComponent
                    isSuggLoading={isSuggLoading}
                    isSuggError={isSuggError}
                    correctedTerm={correctedTerm}
                    onRetrySearch={handleSearchRetry}
                    isMobile={isMobile}
                    searchText={searchText}
                    onResultClick={() => setSearchText("")}
                    handleSearch={handleSearch}
                    onActivate={handleMobileSearch}
                  />
                </div>
                {showShopModeToggle && (
                  <div className="flex-shrink-0">{renderShopModeToggle()}</div>
                )}
              </div>
            </div>

            {/* ── Mobile, non-home: compact Myntra-style header ── */}
            {!isHomeRoute && (
              <>
                <div className="flex md:hidden items-center gap-1 h-[52px]">
                  <button
                    type="button"
                    onClick={handleMobileBack}
                    className="p-1.5 -ms-1.5 rounded-full active:bg-black/10 flex-shrink-0"
                    aria-label="Back"
                  >
                    <IoArrowBack size={22} className="rtl:rotate-180" />
                  </button>
                  <Link
                    href={zoneHref("/")}
                    aria-label="Home"
                    className="relative h-[30px] w-[100px] flex-shrink-0"
                  >
                    {mounted && setting?.setting?.web_settings?.web_logo && (
                      <Image
                        src={setting?.setting?.web_settings?.web_logo}
                        alt="Logo"
                        fill
                        sizes="100px"
                        className="object-contain object-left rtl:object-right"
                      />
                    )}
                  </Link>
                  <div className="ms-auto flex items-center">
                    <button
                      type="button"
                      onClick={handleMobileSearch}
                      className="p-2 rounded-full active:bg-black/10"
                      aria-label="Search"
                    >
                      <IoSearchOutline size={22} />
                    </button>
                    <button
                      type="button"
                      onClick={handleFavouritesClick}
                      className="p-2 rounded-full active:bg-black/10"
                      aria-label="Wishlist"
                    >
                      <IoHeartOutline size={22} />
                    </button>
                    <button
                      type="button"
                      onClick={handleCartOpen}
                      className="p-2 rounded-full relative active:bg-black/10"
                      aria-label="Cart"
                    >
                      <CartIconAnimation
                        count={cartItemCount}
                        size={22}
                        badgeClass="flex absolute -top-1.5 -right-1.5 bodyTextColor textBackground rounded-full min-w-[14px] h-[14px] px-1 items-center justify-center text-center font-bold text-[8px] leading-none ring-2 ring-white dark:ring-zinc-900"
                      />
                    </button>
                  </div>
                </div>

                {/* Slim location strip — opens the location picker. */}
                <button
                  type="button"
                  onClick={handleOpenLocation}
                  className="flex md:hidden w-[calc(100%+2rem)] -mx-4 items-center gap-1.5 bg-black/10 px-4 py-2 text-start active:bg-black/15"
                >
                  <IoLocationSharp size={14} className="flex-shrink-0" />
                  <span className="min-w-0 flex-1 truncate text-[12px] leading-tight">
                    <span className="font-bold">
                      {mounted && showQuickDelivery
                        ? `${t("delivery_in")} ${quickDeliveryTime}${
                            quickDeliveryHasUnit ? "" : ` ${t("minutes")}`
                          }`
                        : mounted
                          ? t("deliver_to")
                          : "Deliver to"}
                    </span>
                    <span className="opacity-80">
                      {" - "}
                      {mounted &&
                      !hasInvalidUrlZone &&
                      (cityAddress ||
                        selectedZoneName ||
                        setting?.setting?.default_city?.name)
                        ? cityAddress ||
                          selectedZoneName ||
                          setting?.setting?.default_city?.name
                        : mounted
                          ? t("loading")
                          : "Loading"}
                    </span>
                  </span>
                  <BiCaretRight
                    size={12}
                    className="rotate-90 opacity-60 flex-shrink-0"
                  />
                </button>
              </>
            )}

            {/* ── Mobile home top block (scrolls away): mode toggle + delivery ── */}
            {isHomeRoute && (
              <div ref={mobileTopRef} className="headerTopFade md:hidden">
                {showShopModeToggle && (
                  <div dir="ltr" className="flex items-center gap-2 pt-2 select-none">
                    {(["quick", "allShop"] as const).map((mode) => (
                      <button
                        key={mode}
                        type="button"
                        onClick={() => handleModeToggle(mode)}
                        className={`flex h-10 flex-1 items-center justify-center rounded-xl text-[15px] font-semibold transition-colors duration-300 outline-none ${
                          shopMode === mode
                            ? "bg-white text-gray-900 shadow-[0_1px_3px_rgba(0,0,0,0.08)]"
                            : "bg-black/15 layoutHeaderText"
                        }`}
                      >
                        {mode === "quick" ? quickLabel : ecommerceLabel}
                      </button>
                    ))}
                  </div>
                )}

                <div className="flex items-start gap-2 pt-3 pb-1">
                  <button
                    type="button"
                    onClick={handleOpenLocation}
                    className="min-w-0 flex-1 text-start active:opacity-70 transition-opacity"
                  >
                    <span className="block text-[13px] font-medium leading-tight opacity-80">
                      {mounted && showQuickDelivery
                        ? t("delivery_in")
                        : mounted
                          ? t("deliver_to")
                          : "Deliver to"}
                    </span>
                    {mounted && showQuickDelivery && (
                      <span className="mt-0.5 flex min-w-0 items-center gap-2">
                        {/* Time never truncates; the distance pill gives way. */}
                        <span className="shrink-0 whitespace-nowrap text-[24px] font-extrabold leading-tight tracking-tight">
                          <AnimatedEta value={quickDeliveryLabel} />
                        </span>
                        {distanceKm && (
                          <span className="inline-flex min-w-0 items-center gap-1 rounded-full bg-black/10 px-2.5 py-1 text-[12px] font-semibold">
                            <MdDirectionsWalk size={14} className="shrink-0" />
                            <span className="truncate">{distanceKm}</span>
                          </span>
                        )}
                      </span>
                    )}
                    <span
                      className={`mt-0.5 flex min-w-0 items-center gap-1 leading-tight ${
                        mounted && showQuickDelivery
                          ? "text-[13px] opacity-80"
                          : "text-[16px] font-bold"
                      }`}
                    >
                      <span className="truncate">
                        {deliveryAddress ?? (
                          <span className="opacity-50">
                            {mounted ? t("loading") : "Loading"}
                          </span>
                        )}
                      </span>
                      <IoChevronDown size={14} className="shrink-0" />
                    </span>
                  </button>

                </div>
              </div>
            )}

            {/* ── Mobile Sub Row: Search bar (home) ── */}
            {isHomeRoute && (
            <div className="flex md:hidden flex-col gap-1 pt-1.5 pb-2">
              {/* Full-width search bar — opens the search page on tap */}
              <button
                type="button"
                onClick={handleMobileSearch}
                className="flex items-center gap-2 w-full bg-white dark:bg-zinc-800 rounded-xl px-3 h-[40px] shadow-[0_1px_3px_rgba(0,0,0,0.08)] active:opacity-80 transition-opacity"
                aria-label="Search"
              >
                <IoSearchOutline
                  size={19}
                  className="text-zinc-500 flex-shrink-0"
                />
                <span className="text-[13px] text-zinc-500 truncate">
                  {mounted ? t("search") : "Search"}
                </span>
              </button>
            </div>
            )}
          </div>
        </div>
      </header>


      {/* ═══════════ Modals & Drawers ═══════════ */}
      {/* Render-gated dynamic overlays */}
      {mobileNav && (
        <MobileNavSidebar
          open={mobileNav}
          setOpen={setMobileNav}
          handleLanguageChange={handleLanguageChange}
        />
      )}
      {showCart && (
        <CartDrawer
          showCart={showCart}
          setShowCart={setShowCart}
          setShowLogin={setShowLogin}
          setMobileActiveKey={setMobileActiveKey}
        />
      )}
      {showLogin && (
        <Login
          showLogin={showLogin}
          setShowLogin={setShowLogin}
          setMobileActiveKey={setMobileActiveKey}
        />
      )}
      {showLocation && (
        <Location
          showLocation={showLocation}
          setShowLocation={setShowLocation}
        />
      )}
      {showLogout && (
        <LogoutModal showLogout={showLogout} setShowLogout={setShowLogout} />
      )}

      {/* Mobile Bottom Navigation */}
      <nav
        className={`fixed bottom-0 left-0 w-full z-50 md:hidden ${
          /\/(products|search)\/?$/.test(pathname || "") ? "!hidden" : ""
        }`}
      >
        <div className="bg-white dark:bg-zinc-900 border-t border-gray-200 dark:border-zinc-700/60 shadow-[0_-2px_12px_rgba(0,0,0,0.06)] pb-[env(safe-area-inset-bottom)]">
          <div
            className={`grid ${
              mounted && user?.jwtToken ? "grid-cols-4" : "grid-cols-3"
            } items-stretch px-1 pt-2 pb-1.5`}
          >
            {[
              {
                key: 1,
                label: mounted ? t("home") : "Home",
                onClick: handleHomeClick,
                Active: IoHome,
                Inactive: IoHomeOutline,
                size: 22,
              },
              {
                key: 2,
                label: mounted ? t("categories") : "Categories",
                onClick: handleCategoriesClick,
                Active: BiSolidCategoryAlt,
                Inactive: BiCategoryAlt,
                size: 21,
              },
              // Orders tab for logged-in users

              ...(mounted && user?.jwtToken
                ? [
                    {
                      key: 3,
                      label: t("orders") || "Orders",
                      onClick: handleOrdersClick,
                      Active: IoBag,
                      Inactive: IoBagOutline,
                      size: 21,
                    },
                  ]
                : []),
              {
                key: 4,
                // Fixed label — a long name broke the four-up bottom bar.
                label:
                  mounted && user?.jwtToken
                    ? t("profile") || "Profile"
                    : mounted
                      ? t("login")
                      : "Login",
                onClick: handleProfileClick,
                Active: IoPerson,
                Inactive: IoPersonOutline,
                size: 21,
              },
            ].map((tab) => {
              const isActive = mobileActiveKey === tab.key;
              const Icon = isActive ? tab.Active : tab.Inactive;
              return (
                <button
                  type="button"
                  key={tab.key}
                  className="flex flex-col items-center justify-center gap-1 py-1 min-w-0"
                  onClick={tab.onClick}
                  aria-label={tab.label}
                >
                  <Icon
                    size={tab.size}
                    className={
                      isActive
                        ? "primaryColor"
                        : "text-zinc-500 dark:text-zinc-400"
                    }
                  />
                  <span
                    className={`max-w-full truncate text-[11px] leading-tight transition-colors duration-200 ${
                      isActive
                        ? "primaryColor font-semibold"
                        : "text-zinc-500 dark:text-zinc-400 font-medium"
                    }`}
                  >
                    {tab.label}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </nav>
      {showProfile && (
        <ProfileDrawer
          showProfile={showProfile}
          setShowProfile={setShowProfile}
          setSelectedTab={setSelectedTab}
          selectedTab={selectedTab}
        />
      )}
    </>
  );
};

export default Header;
