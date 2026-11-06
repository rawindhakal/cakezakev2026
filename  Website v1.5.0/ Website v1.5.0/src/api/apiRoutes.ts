"use client";
import api from "./axiosMiddleware";
import * as apiEndPoints from "./apiEndpoints";
import { store } from "@/redux/store";
import { t } from "@/utils/translation";

export const registerUser = async ({
  name,
  email,
  mobile,
  type,
  fcm,
  country_code,
  country_id,
  password,
  phoneAuthType = false,
  friend_code,
}: any): Promise<any> => {
  const formData = new FormData();
  formData.append("name", name);
  formData.append("country_code", country_code);
  if (country_id !== null && country_id !== undefined && country_id !== "") {
    formData.append("country_id", country_id);
  }
  formData.append("type", type);
  formData.append("fcm_token", fcm);
  formData.append("platform", "web");
  if (type == "email" || (type == "phone" && phoneAuthType)) {
    formData.append("password", password);
  }
  if (
    type === "phone" ||
    ((type === "email" || type === "google") && mobile !== null && mobile !== "")
  ) {
    formData.append("mobile", mobile);
  }
  if (type === "email" || type === "google" || (type === "phone" && email)) {
    formData.append("email", email);
  }
  if (friend_code !== null) {
    formData.append("friends_code", friend_code);
  }
  const response = await api.post(apiEndPoints.register, formData);
  return response.data;
};

export const login = async ({
  id,
  fcm,
  type,
  password,
  phoneAuthType,
  country_code,
}: any): Promise<any> => {
  const formData = new FormData();
  formData.append("id", id);
  formData.append("fcm_token", fcm);
  formData.append("type", type);
  formData.append("platform", "web");
  if (type == "phone") {
    formData.append("country_code", country_code || "");
    formData.append(
      "phone_auth_type",
      phoneAuthType ? "phone_auth_password" : "phone_auth_otp"
    );
  }
  if (type == "email" || (type == "phone" && phoneAuthType)) {
    formData.append("password", password);
  }
  const response = await api.post(apiEndPoints.login, formData);
  return response.data;
};

export const sendSms = async ({ mobile }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("phone", mobile);
  const response = await api.post(apiEndPoints.sendSms, formData);
  return response.data;
};

export const verifyOTP = async ({ mobile, otp, country_code }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("phone", mobile);
  formData.append("otp", otp);
  formData.append("country_code", country_code);
  const response = await api.post(apiEndPoints.verifyContact, formData);
  return response.data;
};

export const verifyEmail = async ({ email, code }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("email", email);
  formData.append("code", code);
  const response = await api.post(apiEndPoints.verifyEmail, formData);
  return response.data;
};

export const forgotPasswordOTP = async ({ email }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("email", email);
  const response = await api.post(apiEndPoints.forgotPasswordOtp, formData);
  return response.data;
};

export const forgotPassword = async ({
  phone,
  otp,
  email,
  password,
  confirmPassword,
  type,
  otpMethod,
}: any): Promise<any> => {
  const formData = new FormData();
  if (
    type == "email" ||
    (type == "phone" && (otpMethod == "twilio" || otpMethod == "firebase"))
  ) {
    formData.append("otp", otp ?? "");
  }
  if (type == "email") {
    formData.append("email", email);
  }
  if (type == "phone") {
    formData.append("mobile", phone);
  }
  formData.append("password", password);
  formData.append("password_confirmation", confirmPassword);
  formData.append("type", type);
  if (type == "phone") {
    formData.append("otp_verify_method", otpMethod);
  }
  const response = await api.post(apiEndPoints.forgotPassword, formData);
  return response.data;
};

export const resetPassword = async ({
  password,
  newPassword,
  confirmPassword,
}: any): Promise<any> => {
  const formData = new FormData();
  formData.append("old_password", password);
  formData.append("new_password", newPassword);
  formData.append("new_password_confirmation", confirmPassword);
  const response = await api.post(apiEndPoints.resetPassword, formData);
  return response.data;
};

export const updateProfile = async ({
  image,
  name,
  email,
  mobileNumber,
  countryCode,
  countryId,
  type,
  latitude,
  longitude,
}: any): Promise<any> => {
  const formData = new FormData();
  if (image) formData.append("profile", image);
  formData.append("name", name);
  formData.append("email", email);
  if (countryId !== null && countryId !== undefined && countryId !== "") {
    formData.append("country_id", countryId);
  }
  if (mobileNumber) {
    formData.append("mobile", mobileNumber);
    if (countryCode) formData.append("country_code", countryCode);
  }
  if (latitude) formData.append("latitude", latitude);
  if (longitude) formData.append("longitude", longitude);
  const response = await api.post(apiEndPoints.editProfile, formData);
  return response.data;
};
export const getUser = async ({ latitude, longitude }: any = {}): Promise<any> => {
  const params: Record<string, any> = {};
  if (latitude) params.latitude = latitude;
  if (longitude) params.longitude = longitude;
  const response = await api.get(apiEndPoints.getUser, { params });
  return response.data;
};
export const logout = async ({ fcm }: any = {}): Promise<any> => {
  const formData = new FormData();
  if (fcm) {
    formData.append("fcm_token", fcm);
    formData.append("platform", "web");
  }
  const response = await api.post(`${apiEndPoints.logout}`, formData);
  return response.data;
};
export const deleteUser = async ({ uid = null }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("auth_uid", uid);
  const response = await api.post(apiEndPoints.deleteAccount, formData);
  return response.data;
};

export const getPlaces = async ({ input }: any): Promise<any> => {
  const params = { input: input, source: "web" };

  const response = await api.get(apiEndPoints.getPlaces, { params });
  return response.data;
};

export const getPlacesDetails = async ({ placeId }: any): Promise<any> => {
  const params = { place_id: placeId, source: "web" };
  const response = await api.get(apiEndPoints.getPlacecDetails, { params });
  return response.data;
};

export const getGeocoding = async ({ latitude, longitude }: any): Promise<any> => {
  const params = { latitude, longitude, source: "web" };
  const response = await api.get(apiEndPoints.getGeocoding, { params });
  return response.data;
};

export const getZone = async ({ latitude, longitude, channel }: any): Promise<any> => {
  const params = { latitude: latitude, longitude: longitude };
  // channel overrides the store-derived header — used to retry in a zone's own channel.
  const config: any = { params };
  if (channel) config.headers = { channel };
  const response = await api.get(apiEndPoints.getZone, config);
  return response.data;
};

export const getZones = async ({ country_id }: any = {}): Promise<any> => {
  const params = country_id ? { country_id } : {};
  const response = await api.get(apiEndPoints.getZones, { params });
  return response.data;
};

export const getRegions = async ({ country_id }: any = {}): Promise<any> => {
  const params = country_id ? { country_id } : {};
  const response = await api.get(apiEndPoints.getRegions, { params });
  return response.data;
};

export const getCountriesWithDefault = async (): Promise<any> => {
  const response = await api.get(apiEndPoints.getCountries);
  return response.data;
};

export const getShop = async ({ latitude, longitude }: any): Promise<any> => {
  let params = { latitude: latitude, longitude: longitude };
  const response = await api.get(apiEndPoints.getShop, { params });
  return response.data;
};

export const getHomeLayout = async ({
  latitude,
  longitude,
  category_id = null,
  limit,
  offset,
  device,
}: any): Promise<any> => {
  const params: Record<string, any> = {
    latitude,
    longitude,
  };
  if (category_id != null && category_id !== "") {
    params.category_id = category_id;
  }
  if (limit != null) {
    params.limit = limit;
  }
  if (offset != null) {
    params.offset = offset;
  }
  if (device != null && device !== "") {
    params.device = device;
  }
  const response = await api.get(apiEndPoints.homeLayout, { params });
  return response.data;
};

export const getPageBuilder = async ({
  slug,
  id,
  latitude,
  longitude,
  limit,
  offset,
}: any): Promise<any> => {
  const params: Record<string, any> = { latitude, longitude };
  if (slug != null && slug !== "") params.slug = slug;
  else if (id != null && id !== "") params.id = id;
  if (limit != null) params.limit = limit;
  if (offset != null) params.offset = offset;
  const response = await api.get(apiEndPoints.pageBuilder, { params });
  return response.data;
};

export const getCategories = async ({
  slug = "",
  id = "",
  limit,
  offset,
  is_own_data,
  latitude,
  longitude,
}: any = {}): Promise<any> => {
  const params = {
    limit,
    offset,
    ...(slug && { slug }),
    ...(id && { id }),
    ...(is_own_data && { is_own_data }),
    ...(latitude != null && { latitude }),
    ...(longitude != null && { longitude }),
  };

  const response = await api.get(apiEndPoints.getCategory, { params });
  return response.data;
};

export const getProductByFilter = async ({
  latitude,
  longitude,
  filters = undefined,
  tag_names = "",
  slug = "",
  is_similar_product_id = "",
}: any): Promise<any> => {
  // GET since the API moved these reads off POST — POST now answers 405.
  const params: Record<string, any> = { latitude, longitude };
  if (tag_names !== "") params.tag_names = tag_names;
  if (slug !== "") params.tag_slug = slug;
  if (is_similar_product_id !== "" && is_similar_product_id != null) {
    params.is_similar_product_id = is_similar_product_id;
  }
  if (filters !== undefined) {
    for (const filter in filters) {
      if (
        (filters[filter] !== null &&
          filters[filter] !== undefined &&
          filters[filter] !== "") ||
        filters[filter]?.length > 0
      ) {
        params[filter] = filters[filter];
      }
    }
  }
  const response = await api.get(apiEndPoints.getProducts, { params });
  return response.data;
};

export const getProductFilters = async ({
  latitude,
  longitude,
  category_id,
  data_source,
  manual_product_ids,
  source_id,
  block_category_ids,
  block_brand_ids,
  filter_mode,
  min_discount_percent,
  max_discount_percent,
}: any): Promise<any> => {
  const params: Record<string, any> = {};
  if (latitude != null) params.latitude = latitude;
  if (longitude != null) params.longitude = longitude;
  if (category_id != null && category_id !== "") {
    params.category_id = category_id;
  }
  if (data_source != null && data_source !== "") {
    params.data_source = data_source;
    if (
      data_source === "manual" &&
      manual_product_ids != null &&
      manual_product_ids !== ""
    ) {
      params.manual_product_ids = manual_product_ids;
    } else if (source_id != null && source_id !== "") {
      if (data_source === "category") {
        params.category_id = source_id;
      } else if (data_source === "brand") {
        params.brand_ids = source_id;
      }
    }
  }
  // An automatic row can also be scoped by category or brand — ids pass through as received.
  if (!params.category_id && block_category_ids) {
    params.category_id = block_category_ids;
  }
  if (!params.brand_ids && block_brand_ids) {
    params.brand_ids = block_brand_ids;
  }
  if (filter_mode != null && filter_mode !== "") {
    params.filter_mode = filter_mode;
  }
  if (min_discount_percent != null && min_discount_percent !== "") {
    params.min_discount_percent = min_discount_percent;
  }
  if (max_discount_percent != null && max_discount_percent !== "") {
    params.max_discount_percent = max_discount_percent;
  }
  const response = await api.get(apiEndPoints.getProductFilters, { params });
  return response.data;
};

export const getBrands = async ({ limit, offset, latitude, longitude }: any): Promise<any> => {
  let params = {
    limit: limit,
    offset: offset,
    latitude: latitude,
    longitude: longitude,
  };
  const response = await api.get(apiEndPoints.getBrands, { params });
  return response.data;
};

export const getSetting = async (): Promise<any> => {
  const params = {
    is_web_setting: 1,
  };
  const response = await api.get(apiEndPoints.getSettings, { params });
  return response.data;
};

export const getCountrySetting = async ({ latitude, longitude }: any = {}): Promise<any> => {
  const params: Record<string, any> = {};
  if (latitude) params.latitude = latitude;
  if (longitude) params.longitude = longitude;
  const response = await api.get(apiEndPoints.getCountrySetting, { params });
  return response.data;
};

export const getDialCountries = async (): Promise<any> => {
  const response = await api.get(apiEndPoints.getCountries);
  return response.data;
};

export const getProductById = async ({ latitude, longitude, slug, id }: any): Promise<any> => {
  const params: Record<string, any> = { latitude, longitude };
  if (id !== -1) params.id = id;
  if (slug) params.slug = slug;
  const response = await api.get(apiEndPoints.getProductById, { params });
  return response.data;
};

export const checkServiceability = async ({
  pincode,
  latitude,
  longitude,
  productVariantId,
  quantity,
  storeId,
  cod,
}: any): Promise<any> => {
  const formData = new FormData();
  formData.append("pincode", pincode);
  if (latitude != null) formData.append("latitude", latitude);
  if (longitude != null) formData.append("longitude", longitude);
  if (productVariantId != null)
    formData.append("product_variant_id", productVariantId);
  if (quantity != null) formData.append("quantity", quantity);
  if (storeId != null) formData.append("branch_id", storeId);
  if (cod != null) formData.append("cod", cod ? "1" : "0");
  const response = await api.post(apiEndPoints.checkServiceability, formData);
  return response.data;
};

export const getSpinWheel = async ({ latitude, longitude }: any = {}): Promise<any> => {
  const params: Record<string, any> = {};
  if (latitude != null) params.latitude = latitude;
  if (longitude != null) params.longitude = longitude;
  const response = await api.get(apiEndPoints.spinWheel, { params });
  return response.data;
};

export const spinSpinWheel = async ({
  latitude,
  longitude,
  idempotencyKey,
}: any = {}): Promise<any> => {
  const formData = new FormData();
  if (latitude != null) formData.append("latitude", latitude);
  if (longitude != null) formData.append("longitude", longitude);
  if (idempotencyKey) formData.append("request_token", idempotencyKey);
  const response = await api.post(apiEndPoints.spinWheelSpin, formData);
  return response.data;
};

export const getSpinWheelRewards = async ({
  latitude,
  longitude,
  rewardType,
  limit,
  offset,
}: any = {}): Promise<any> => {
  const params: Record<string, any> = {};
  if (latitude != null) params.latitude = latitude;
  if (longitude != null) params.longitude = longitude;
  if (rewardType) params.reward_type = rewardType;
  if (limit != null) params.limit = limit;
  if (offset != null) params.offset = offset;
  const response = await api.get(apiEndPoints.spinWheelRewards, { params });
  return response.data;
};

export const getProductRatings = async ({ id, limit, offset }: any): Promise<any> => {
  const params = {
    product_id: id,
    limit: limit,
    offset: offset,
  };
  const response = await api.get(
    `${apiEndPoints.getProducts}/${apiEndPoints.getProductRatings}`,
    { params }
  );

  return response.data;
};

export const getProductImages = async ({ id, limit, offset }: any): Promise<any> => {
  const response = await api.get(
    `${apiEndPoints.getProducts}/${apiEndPoints.rating}/${apiEndPoints.imageList}`,
    { params: { product_id: id, limit, offset } }
  );
  return response.data;
};

export const getPaymentSetting = async ({ latitude, longitude }: any = {}): Promise<any> => {
  const response = await api.get(
    `${apiEndPoints.getSettings}/${apiEndPoints.getPaymentMethods}`,
    { params: { latitude, longitude } }
  );
  return response.data;
};

export const getSystemLanguages = async ({ id, isDefault, systemType }: any): Promise<any> => {
  const params = { id: id, is_default: isDefault, system_type: systemType };
  const response = await api.get(apiEndPoints.getSystemLanguage, { params });
  return response.data;
};

export const updateFcmToken = async ({ langaugeId, fcmToken }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("language_id", langaugeId);
  formData.append("fcm_token", fcmToken);
  const response = await api.post(apiEndPoints.updateFcmToken, formData);
  return response.data;
};

// Collapses the mount burst (Header + page + StrictMode re-run) into one /cart call.
// Short window so a post-mutation refresh never joins an older, stale request.
const CART_DEDUPE_MS = 100;
const cartInFlight = new Map<string, { at: number; promise: Promise<any> }>();

export const getCart = async ({
  latitude,
  longitude,
  checkout = 0,
  promocode_id = 0,
  order_type,
  address_id,
  delivery_type,
}: any): Promise<any> => {
  const params: Record<string, any> = {
    latitude: latitude,
    longitude: longitude,
  };
  if (promocode_id !== 0) {
    params.promocode_id = promocode_id;
  }
  if (checkout) {
    params.checkout = checkout;
  }
  if (order_type) {
    params.order_type = order_type;
  }
  if (delivery_type) {
    params.delivery_type = delivery_type;
  }
  if (address_id != null) {
    params.address_id = address_id;
  }
  if (process.env.NODE_ENV !== "production") {
    console.log(
      "[GETCART TRACE]",
      params,
      new Error().stack?.split("\n").slice(2, 7).join("\n"),
    );
  }
  const state = store.getState() as any;
  const key = `${state?.ShopMode?.mode}|${!!state?.User?.jwtToken}|${JSON.stringify(params)}`;
  const now = Date.now();
  const hit = cartInFlight.get(key);
  if (hit && now - hit.at < CART_DEDUPE_MS) return hit.promise;
  const promise = api
    .get(apiEndPoints.getCart, { params })
    .then((response) => response.data)
    .finally(() => {
      if (cartInFlight.get(key)?.promise === promise) cartInFlight.delete(key);
    });
  cartInFlight.set(key, { at: now, promise });
  return promise;
};

export const getCartRecommendations = async ({
  latitude,
  longitude,
  product_id,
  cross_sell_limit = 10,
  cross_sell_offset = 0,
  upsell_limit = 10,
  upsell_offset = 0,
}: any = {}): Promise<any> => {
  const city = store.getState()?.City?.city;
  const params: Record<string, any> = {
    latitude: latitude ?? city?.latitude,
    longitude: longitude ?? city?.longitude,
    cross_sell_limit,
    cross_sell_offset,
    upsell_limit,
    upsell_offset,
  };
  if (product_id != null) params.product_id = product_id;
  const response = await api.get(
    `${apiEndPoints.getCart}/${apiEndPoints.cartRecommendations}`,
    { params }
  );
  return response.data;
};

export const addToBulkCart = async ({
  quick_variant_ids,
  quick_quantities,
  ecommerce_variant_ids,
  ecommerce_quantities,
  quick_items,
  ecommerce_items,
  latitude,
  longitude,
}: any): Promise<any> => {
  const params: Record<string, any> = {};
  // The positional CSV pair has nowhere to put addons, so the items form wins.
  if (quick_items) {
    params.quick_items =
      typeof quick_items === "string" ? quick_items : JSON.stringify(quick_items);
  } else if (quick_variant_ids) {
    params.quick_variant_ids = quick_variant_ids;
    params.quick_quantities = quick_quantities;
  }
  if (ecommerce_items) {
    params.ecommerce_items =
      typeof ecommerce_items === "string"
        ? ecommerce_items
        : JSON.stringify(ecommerce_items);
  } else if (ecommerce_variant_ids) {
    params.ecommerce_variant_ids = ecommerce_variant_ids;
    params.ecommerce_quantities = ecommerce_quantities;
  }
  if (latitude != null) params.latitude = latitude;
  if (longitude != null) params.longitude = longitude;
  const response = await api.post(
    `${apiEndPoints.getCart}/${apiEndPoints.bulkAddToCart}`,
    null,
    { params }
  );
  return response.data;
};

const storeClosedResponse = () => ({
  status: 0,
  message: t("store_closed_cannot_order"),
});

const isStoreClosed = () => store.getState()?.ShopMode?.storeClosed === true;

export const addToCart = async ({
  product_id,
  product_variant_id,
  qty,
  latitude,
  longitude,
  addons,
}: any): Promise<any> => {
  if (isStoreClosed()) return storeClosedResponse();
  const city = store.getState()?.City?.city;
  const lat = latitude ?? city?.latitude;
  const lng = longitude ?? city?.longitude;
  const formData = new FormData();
  formData.append("product_id", product_id);
  formData.append("product_variant_id", product_variant_id);
  formData.append("qty", qty);
  if (lat != null) formData.append("latitude", lat);
  if (lng != null) formData.append("longitude", lng);
  // Option ids only — the server resolves the group each one belongs to.
  if (Array.isArray(addons) && addons.length > 0) {
    formData.append("addons", JSON.stringify(addons));
  }
  const response = await api.post(
    `${apiEndPoints.getCart}/${apiEndPoints.add}`,
    formData
  );
  return response.data;
};

export const removeFromCart = async ({
  product_id,
  product_variant_id,
  qty,
  isRemoveAll,
  addons,
}: any): Promise<any> => {
  const formData = new FormData();
  formData.append("product_id", product_id);
  formData.append("product_variant_id", product_variant_id);
  formData.append("is_remove_all", (isRemoveAll ? 1 : 0) as any);
  if (qty != null) formData.append("qty", qty);
  // Picks out which line of this product to decrement when several exist.
  if (Array.isArray(addons) && addons.length > 0) {
    formData.append("addons", JSON.stringify(addons));
  }
  const response = await api.post(
    `${apiEndPoints.getCart}/${apiEndPoints.remove}`,
    formData
  );
  return response.data;
};

export const deleteCart = async (): Promise<any> => {
  const formData = new FormData();
  formData.append("is_remove_all", 1 as any);
  const response = await api.post(
    `${apiEndPoints.getCart}/${apiEndPoints.remove}`,
    formData
  );
  return response.data;
};

export const getGuestCart = async ({
  latitude,
  longitude,
  variant_ids,
  quantities,
  delivery_type,
  items,
}: any): Promise<any> => {
  const params: Record<string, any> = {
    latitude: latitude,
    longitude: longitude,
  };
  // items carries a per-row addon list; the CSV pair cannot, so it wins.
  if (items) {
    params.items = typeof items === "string" ? items : JSON.stringify(items);
  } else {
    params.variant_ids = variant_ids;
    params.quantities = quantities;
  }
  if (delivery_type) {
    params.delivery_type = delivery_type;
  }
  const response = await api.get(
    `${apiEndPoints.getCart}/${apiEndPoints.getGuestCart}`,
    { params }
  );
  return response.data;
};

export const getAddress = async (): Promise<any> => {
  const response = await api.get(`${apiEndPoints.getAddress}`);
  return response.data;
};

export const addAddress = async ({
  name,
  mobile,
  country_code = "",
  alternate_country_code = "",
  type,
  address,
  landmark,
  area,
  pincode,
  city,
  state,
  country,
  region_id,
  latitiude,
  longitude,
  is_default = 1,
  alternate_mobile = "",
}: any): Promise<any> => {
  const formData = new FormData();
  formData.append("name", name);
  formData.append("mobile", mobile);
  formData.append("country_code", country_code);
  // Optional alt contact: omit both fields entirely when no number given.
  if (String(alternate_mobile ?? "").trim())
    formData.append("alternate_country_code", alternate_country_code);
  formData.append("type", type);
  formData.append("address", address);
  formData.append("landmark", landmark);
  formData.append("area", area);
  formData.append("pincode", pincode);
  formData.append("city", city);
  formData.append("state", state);
  formData.append("country", country);
  if (region_id != null) formData.append("region_id", region_id);
  if (String(alternate_mobile ?? "").trim())
    formData.append("alternate_mobile", alternate_mobile);
  formData.append("latitude", latitiude);
  formData.append("longitude", longitude);
  formData.append("is_default", (is_default ? 1 : 0) as any);
  const response = await api.post(
    `${apiEndPoints.getAddress}/${apiEndPoints.add}`,
    formData
  );
  return response.data;
};
export const updateAddress = async ({
  id,
  name,
  mobile,
  country_code = "",
  alternate_country_code = "",
  type,
  address,
  landmark,
  area,
  pincode,
  city,
  state,
  country,
  region_id,
  latitiude,
  longitude,
  is_default = 1,
  alternate_mobile = "",
}: any): Promise<any> => {
  const formData = new FormData();
  formData.append("id", id);
  formData.append("name", name);
  formData.append("mobile", mobile);
  formData.append("country_code", country_code);
  // Alt contact is editable: always send, empty clears a saved number.
  const altMobile = String(alternate_mobile ?? "").trim();
  formData.append("alternate_country_code", altMobile ? alternate_country_code : "");
  formData.append("type", type);
  formData.append("address", address);
  formData.append("landmark", landmark);
  formData.append("area", area);
  formData.append("pincode", pincode);
  formData.append("city", city);
  formData.append("state", state);
  formData.append("country", country);
  if (region_id != null) formData.append("region_id", region_id);
  formData.append("alternate_mobile", altMobile);
  formData.append("latitude", latitiude);
  formData.append("longitude", longitude);
  formData.append("is_default", (is_default ? 1 : 0) as any);
  const response = await api.post(
    `${apiEndPoints.getAddress}/${apiEndPoints.update}`,
    formData
  );
  return response.data;
};
export const deleteAddress = async ({ id }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("id", id);
  const response = await api.post(
    `${apiEndPoints.getAddress}/${apiEndPoints.deleteItem}`,
    formData
  );
  return response.data;
};

export const getFavorite = async ({ latitude, longitude, limit, offset }: any): Promise<any> => {
  const params = {
    latitude: latitude,
    longitude: longitude,
    limit: limit,
    offset: offset,
  };
  const response = await api.get(apiEndPoints.getFavorite, { params });
  return response.data;
};
export const addToFavorite = async ({ product_id }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("product_id", product_id);
  const response = await api.post(
    `${apiEndPoints.getFavorite}/${apiEndPoints.add}`,
    formData
  );
  return response.data;
};
export const removeFromFavorite = async ({ product_id }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("product_id", product_id);
  const response = await api.post(
    `${apiEndPoints.getFavorite}/${apiEndPoints.remove}`,
    formData
  );
  return response.data;
};

export const notifyMe = async ({
  product_variant_id,
  latitude,
  longitude,
}: any): Promise<any> => {
  const formData = new FormData();
  formData.append("product_variant_id", product_variant_id);
  formData.append("latitude", latitude);
  formData.append("longitude", longitude);
  const response = await api.post(
    `${apiEndPoints.getProducts}/${apiEndPoints.notifyMe}`,
    formData,
  );
  return response.data;
};

export const removeNotifyMe = async ({ product_variant_id }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("product_variant_id", product_variant_id);
  const response = await api.post(
    `${apiEndPoints.getProducts}/${apiEndPoints.notifyMe}/${apiEndPoints.remove}`,
    formData,
  );
  return response.data;
};

// Promo APIs scope coupons by delivery mode; fall back to the active checkout mode.
const getDeliveryType = (deliveryType?: "delivery" | "pickup") =>
  deliveryType ?? store.getState()?.Checkout?.deliveryType ?? "delivery";

export const getPromo = async ({ amount = 0, latitude, longitude, deliveryType }: any): Promise<any> => {
  const params: Record<string, any> = { amount: amount, delivery_type: getDeliveryType(deliveryType) };
  if (latitude != null) params.latitude = latitude;
  if (longitude != null) params.longitude = longitude;
  const response = await api.get(`${apiEndPoints.getPromoCode}`, { params });
  return response.data;
};
export const setPromoCode = async ({ promoCodeName, amount = 0, latitude, longitude, deliveryType }: any): Promise<any> => {
  const params: Record<string, any> = {
    promo_code: promoCodeName,
    total: amount,
    delivery_type: getDeliveryType(deliveryType),
  };
  if (latitude != null) params.latitude = latitude;
  if (longitude != null) params.longitude = longitude;
  const response = await api.post(
    `${apiEndPoints.getPromoCode}/${apiEndPoints.setPromoCode}`,
    {},
    { params }
  );
  return response.data;
};

// Gifting lookups: occasions, relationships and delivery types.
export const getGiftingMeta = async (): Promise<any> => {
  const response = await api.get("gifting/meta");
  return response.data;
};

// Scheduled delivery: booking window and per-date slot availability.
export const getDeliverySchedule = async (): Promise<any> => {
  const response = await api.get("gifting/schedule");
  return response.data;
};
export const getDeliverySlots = async (date: string): Promise<any> => {
  const response = await api.get("gifting/slots", { params: { date } });
  return response.data;
};

export const placeOrder = async ({
  productVariantId,
  quantity,
  total,
  deliveryCharge,
  finalTotal,
  paymentMethod,
  addressId,
  walletBalance,
  walletUsed,
  orderNote,
  promocodeId = 0,
  status,
  delivery_type,
  prescriptions = null,
  billingSameAsShipping = true,
  billingName = "",
  billingMobile = "",
  billingCountryCode = "",
  billingAddress = "",
  billingCity = "",
  billingState = "",
  billingPincode = "",
  billingCountry = "",
  billingRegionId,
  buyerTaxNumber = "",
  buyerBusinessName = "",
  latitude,
  longitude,
}: any): Promise<any> => {
  if (isStoreClosed()) return storeClosedResponse();
  let finalPaymentMethod = paymentMethod;
  if (paymentMethod == "wallet") {
    finalPaymentMethod = "Wallet";
  }
  const formData = new FormData();
  formData.append("product_variant_id", productVariantId);
  formData.append("quantity", quantity);
  // Gift details captured at checkout (recipient, date, card message...).
  const gift: Record<string, any> = (store.getState() as any)?.Checkout?.gift || {};
  Object.entries(gift).forEach(([k, v]) => {
    if (v !== "" && v != null && v !== false) formData.append(k, v === true ? "1" : String(v));
  });
  formData.append("total", total);
  formData.append("delivery_charge", deliveryCharge);
  formData.append("final_total", finalTotal);
  formData.append("payment_method", finalPaymentMethod);
  if (addressId != null) {
    formData.append("address_id", addressId);
  }
  formData.append("status", status);
  if (delivery_type) {
    formData.append("delivery_type", delivery_type);
  }
  if (latitude != null && longitude != null) {
    formData.append("latitude", latitude);
    formData.append("longitude", longitude);
  }
  if (walletUsed) {
    formData.append("wallet_used", 1 as any);
    formData.append("wallet_balance", walletBalance);
  }
  if (orderNote !== "" && orderNote !== null && orderNote !== undefined) {
    formData.append("order_note", orderNote);
  }
  if (promocodeId !== 0) {
    formData.append("promocode_id", promocodeId);
  }
  const isPickupNoAddress = delivery_type === "pickup" && addressId == null;
  if (delivery_type !== "pickup") {
    formData.append("billing_same_as_shipping", (billingSameAsShipping ? 1 : 0) as any);
  }
  if (isPickupNoAddress || (delivery_type !== "pickup" && !billingSameAsShipping)) {
    formData.append("billing_name", billingName);
    formData.append("billing_mobile", billingMobile);
    formData.append("billing_country_code", billingCountryCode);
    formData.append("billing_address", billingAddress);
    formData.append("billing_city", billingCity);
    formData.append("billing_state", billingState);
    formData.append("billing_pincode", billingPincode);
    formData.append("billing_country", billingCountry);
    if (billingRegionId != null) formData.append("billing_region_id", billingRegionId);
  }
  // Order-level, whichever address is billed; empty is a normal consumer order.
  if (String(buyerTaxNumber ?? "").trim())
    formData.append("buyer_tax_number", String(buyerTaxNumber).trim());
  if (String(buyerBusinessName ?? "").trim())
    formData.append("buyer_business_name", String(buyerBusinessName).trim());
  if (prescriptions && typeof prescriptions === "object") {
    Object.entries(prescriptions).forEach(([vid, file]) => {
      if (file instanceof File) {
        formData.append(`prescription[${vid}]`, file);
      }
    });
  }
  const response = await api.post(`${apiEndPoints.placeOrder}`, formData);
  return response.data;
};
export const initiateTrasaction = async ({
  orderId,
  paymentMethod,
  type,
  walletAmount = 0,
  subscriptionPlanId = 0,
  latitude,
  longitude,
}: any): Promise<any> => {
  const formData = new FormData();
  if (orderId) {
    formData.append("order_id", orderId);
  }
  formData.append(
    "payment_method",
    typeof paymentMethod === "string" && paymentMethod.toLowerCase() === "payu"
      ? "payu"
      : paymentMethod
  );
  formData.append("type", type);
  formData.append("request_from", "website");
  const city = store.getState()?.City?.city;
  const lat = latitude ?? city?.latitude;
  const lng = longitude ?? city?.longitude;
  if (lat != null) formData.append("latitude", lat);
  if (lng != null) formData.append("longitude", lng);
  if (type == "wallet" && walletAmount != 0) {
    formData.append("wallet_amount", walletAmount);
  }
  if (type == "subscription") {
    formData.append("subscription_plan_id", subscriptionPlanId);
  }
  const response = await api.post(
    `${apiEndPoints.initiateTrasaction}`,
    formData
  );
  return response.data;
};
export const addTransaction = async ({
  orderId,
  transactionId,
  paymentMethod,
  type,
  subscriptionPlanId = 0,
  walletAmount = 0,
  latitude,
  longitude,
}: any): Promise<any> => {
  const formData = new FormData();
  if (orderId) {
    formData.append("order_id", orderId);
  }
  if (walletAmount != 0 && type == "wallet") {
    formData.append("wallet_amount", walletAmount);
  }
  if (latitude !== undefined && latitude !== null && latitude !== "") {
    formData.append("latitude", latitude);
  }
  if (longitude !== undefined && longitude !== null && longitude !== "") {
    formData.append("longitude", longitude);
  }
  if (type == "subscription") {
    formData.append(
      "subscription_plan_id",
      subscriptionPlanId
    )
  }
  formData.append("transaction_id", transactionId);
  formData.append("type", type);
  formData.append("payment_method", paymentMethod);
  formData.append("request_from", "website");
  formData.append("device_type", "web");
  formData.append("app_version", "1.0");
  const response = await api.post(`${apiEndPoints.addTransaction}`, formData);
  return response.data;
};
export const submitPaymentProof = async ({ orderId, reference, proof }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("order_id", orderId);
  if (reference) formData.append("reference", reference);
  formData.append("proof", proof);
  const response = await api.post(`${apiEndPoints.paymentProof}`, formData);
  return response.data;
};
export const deleteOrder = async ({ orderId }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("order_id", orderId);
  const response = await api.post(`${apiEndPoints.deleteOrder}`, formData);
  return response.data;
};

export const getNotifications = async ({ limit = 7, offset = 0 }: any): Promise<any> => {
  const params = { limit, offset };
  const response = await api.get(`${apiEndPoints.getNotification}`, { params });
  return response.data;
};

export const getFAQs = async ({ limit = 7, offset = 0 }: any): Promise<any> => {
  const params = { limit, offset };
  const response = await api.get(`${apiEndPoints.getFaq}`, { params });
  return response.data;
};

export const getOrders = async ({
  limit,
  offset,
  orderId,
  type,
  orderType,
  channel,
  startDate,
  endDate,
}: any): Promise<any> => {
  const params: Record<string, any> = { limit: limit, offset: offset, type: type };
  if (orderId) {
    params.order_id = orderId;
  }
  if (orderType != "") {
    params.order_type = orderType;
  }
  if (channel) {
    params.channel = channel;
  }
  if (startDate) {
    params.start_date = startDate;
  }
  if (endDate) {
    params.end_date = endDate;
  }
  const response = await api.get(`${apiEndPoints.getOrders}`, { params });
  return response.data;
};

export const getEcomOrders = async ({
  limit,
  offset,
  type,
  orderType,
  startDate,
  endDate,
}: any): Promise<any> => {
  const params: Record<string, any> = { limit, offset, type };
  if (orderType != null && orderType !== "") {
    params.order_type = orderType;
  }
  if (startDate) {
    params.start_date = startDate;
  }
  if (endDate) {
    params.end_date = endDate;
  }
  const response = await api.get(`${apiEndPoints.ecomOrders}`, { params });
  return response.data;
};

export const getEcomOrderDetail = async ({ orderItemId }: any): Promise<any> => {
  const params = { order_item_id: orderItemId };
  const response = await api.get(`${apiEndPoints.ecomOrders}`, { params });
  return response.data;
};

export const changeOrderStatus = async ({
  orderId,
  orderItemId,
  status,
  reason,
  returnReason,
  addressId,
}: any): Promise<any> => {
  const formData = new FormData();
  formData.append("order_id", orderId);
  formData.append("order_item_id", orderItemId);
  formData.append("status", status);
  if (reason) {
    formData.append("cancellation_reason", reason);
  }
  if (returnReason) {
    formData.append("return_reason", returnReason);
  }
  if (addressId) {
    formData.append("address_id", addressId);
  }
  const response = await api.post(
    `${apiEndPoints.updateOrderStatus}`,
    formData
  );
  return response.data;
};

export const reviewProduct = async ({ productId, rating, review, images }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("product_id", productId);
  formData.append("rate", rating);
  formData.append("review", review);
  for (let i = 0; i < images?.length; i++) {
    formData.append(`image[${i}]`, images[i]);
  }
  const response = await api.post(
    `${apiEndPoints.getProducts}/${apiEndPoints.rating}/${apiEndPoints.add}`,
    formData
  );
  return response.data;
};

export const getProductRating = async ({ ratingId }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("id", ratingId);
  const response = await api.post(
    `${apiEndPoints.getProducts}/${apiEndPoints.rating}/${apiEndPoints.edit}`,
    formData
  );
  return response.data;
};

export const updateReviewProduct = async ({
  ratingId,
  rating,
  review,
  deleteImages,
  images,
}: any): Promise<any> => {
  const formData = new FormData();
  formData.append("id", ratingId);
  formData.append("rate", rating);
  formData.append("review", review);
  formData.append("deleteImageIds", `[${deleteImages}]`);
  for (let i = 0; i < images?.length; i++) {
    formData.append(`image[${i}]`, images[i]);
  }
  const response = await api.post(
    `${apiEndPoints.getProducts}/${apiEndPoints.rating}/${apiEndPoints.update}`,
    formData
  );
  return response.data;
};

export const downloadInvoice = async ({ orderId }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("order_id", orderId);
  const response = await api.post(`${apiEndPoints.getInvoice}`, formData, {
    responseType: "blob",
  });
  return response;
};

export const downloadItemInvoice = async ({ orderItemId }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("order_item_id", orderItemId);
  const response = await api.post(`${apiEndPoints.getItemInvoice}`, formData, {
    responseType: "blob",
  });
  return response;
};

export const getUserTransactions = async ({ limit, offset, type }: any): Promise<any> => {
  const params = { limit: limit, offset: offset, type: type };
  const response = await api.get(`${apiEndPoints.getTransactions}`, { params });
  return response.data;
};

export const liveOrderTracking = async ({ orderId }: any): Promise<any> => {
  const params = {
    order_id: orderId,
  };
  const response = await api.get(`${apiEndPoints.liveTracking}`, { params });
  return response.data;
};

export const getSellers = async ({ limit, offset, latitude, longitude }: any): Promise<any> => {
  const params = {
    limit,
    offset,
    latitude,
    longitude,
  };
  const response = await api.get(`${apiEndPoints.getShopBySellers}`, {
    params,
  });
  return response.data;
};

export const getCountries = async ({ limit, offset, latitude, longitude }: any): Promise<any> => {
  const params = {
    limit,
    offset,
    latitude,
    longitude,
  };
  const response = await api.get(`${apiEndPoints.getShopByCountries}`, {
    params,
  });
  return response.data;
};

export const verifyUserByPhoneNum = async ({ mobile, countryCode, type }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("mobile", mobile);
  formData.append("country_code", countryCode);
  formData.append("type", type);
  const response = await api.post(
    `${apiEndPoints.verifyUserByPhoneNum}`,
    formData
  );
  return response.data;
};

export const getOrderStatusPhonepe = async ({ token, transaction_id }: any): Promise<any> => {
  const params = {
    token: token,
    transaction_id: transaction_id,
  };

  const response = await api.get(apiEndPoints.orderStatusPhonepe, { params });
  return response.data;
};

export const getBlogsCategories = async ({
  offset = 0,
  limit = 10,
  search = "",
}: any): Promise<any> => {
  const params = {
    limit,
    offset,
    ...(search != "" ? { search } : {}),
  };

  const response = await api.get(apiEndPoints.blogCategories, { params });
  return response.data;
};

export const getBlogs = async ({
  offset,
  limit,
  slug,
  categoryId = null,
  tag_id = null,
}: any): Promise<any> => {
  const params = {
    limit,
    offset,
    slug,
    ...(categoryId !== null ? { category_id: categoryId } : null),
    ...(tag_id !== null ? { tag_id: tag_id } : null),
  };
  const response = await api.get(apiEndPoints.blogs, { params });
  return response.data;
};

export const setBlogCount = async ({ blogId }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("blog_id", blogId);
  const response = await api.post(apiEndPoints.blogViewCount, formData);
  return response.data;
};

export const getMostViewedBlogs = async ({ limit = 5 }: any): Promise<any> => {
  const response = await api.get(
    `${apiEndPoints.blogs}/${apiEndPoints.mostViewedBlogs}`
  );
  return response.data;
};

export const getTags = async (): Promise<any> => {
  const response = await api.get(`${apiEndPoints.blogTags}`);
  return response.data;
};

export const addRecentlyViewedProduct = async ({ productId, latitude, longitude }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("product_id", productId);
  if (latitude != null) formData.append("latitude", latitude);
  if (longitude != null) formData.append("longitude", longitude);
  const response = await api.post(
    `${apiEndPoints.getProducts}/${apiEndPoints.addRecentlyViewedProduct}`,
    formData
  );
  return response.data;
};

export const getRecentlyViewedProducts = async ({ productId, latitude, longitude }: any): Promise<any> => {
  const params = {
    product_id: productId,
    ...(latitude != null && { latitude }),
    ...(longitude != null && { longitude }),
  };
  const response = await api.get(
    `${apiEndPoints.getProducts}/${apiEndPoints.recentlyVisited}`,
    { params }
  );
  return response.data;
};

export const getSubscriptionPlans = async (): Promise<any> => {
  const response = await api.get(`${apiEndPoints.subscriptionPlans}`);
  return response.data;
};

export const getUserActivePlan = async (): Promise<any> => {
  const response = await api.get(`${apiEndPoints.userActivePlan}`);
  return response.data;
};

export const getSubscriptionFaqs = async ({ offset, limit }: any): Promise<any> => {
  const params = {
    offset,
    limit,
  };
  const response = await api.get(`${apiEndPoints.subscriptionFaqs}`, { params });
  return response.data;
};

export const getNotificationPreferences = async (): Promise<any> => {
  const response = await api.get(apiEndPoints.notificationPreferences);
  return response.data;
};

export const updateNotificationPreferences = async ({ preferences }: any): Promise<any> => {
  const response = await api.post(
    apiEndPoints.notificationPreferences,
    { preferences },
    { headers: { "Content-Type": "application/json" } }
  );
  return response.data;
};

export const startAdminChat = async (): Promise<any> => {
  const response = await api.post(apiEndPoints.chatStartAdmin);
  return response.data;
};

export const startOrderChat = async ({ order_id, order_item_id }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("order_id", order_id);
  if (order_item_id != null && order_item_id !== "") {
    formData.append("order_item_id", order_item_id);
  }
  const response = await api.post(apiEndPoints.chatStartOrder, formData);
  return response.data;
};

export const startOrderAdminChat = async ({ order_id }: any): Promise<any> => {
  const formData = new FormData();
  formData.append("order_id", order_id);
  const response = await api.post(apiEndPoints.chatStartOrderAdmin, formData);
  return response.data;
};

export const getChatMessages = async ({ conversation_id }: any): Promise<any> => {
  const response = await api.get(apiEndPoints.chatMessages, {
    params: { conversation_id },
  });
  return response.data;
};

export const sendChatMessage = async ({
  conversation_id,
  message,
  images,
  audios,
  videos,
  files,
  latitude,
  longitude,
}: any): Promise<any> => {
  const formData = new FormData();
  formData.append("conversation_id", conversation_id);
  if (message) formData.append("message", message);
  if (latitude != null) formData.append("latitude", latitude);
  if (longitude != null) formData.append("longitude", longitude);
  const appendAll = (field, list) =>
    (list || []).forEach((file) => file && formData.append(field, file));
  appendAll("images[]", images);
  appendAll("audios[]", audios);
  appendAll("videos[]", videos);
  appendAll("files[]", files);
  const response = await api.post(apiEndPoints.chatSend, formData);
  return response.data;
};