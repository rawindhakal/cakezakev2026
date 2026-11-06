// import { ActionTypes } from "../action-type";
import { createSlice, PayloadAction } from "@reduxjs/toolkit";
import { logoutAuth } from "./userSlice";

// Per-channel guest cart state and active channel mirror mapping
export const GUEST_CHANNELS = ["quick", "ecommerce"];
const DEFAULT_CHANNEL = "quick";

const normalizeChannel = (channel: string | undefined | null): string =>
  channel != null && GUEST_CHANNELS.includes(channel) ? channel : DEFAULT_CHANNEL;

interface CartState {
  status: "loading" | "fulfill";
  cart: any | null;
  checkout: any | null;
  promo_code: any | null;
  is_wallet_checked: number;
  cartProducts: any[];
  cartSubTotal: number;
  currency: string;
  activeChannel: string;
  guestCartByChannel: Record<string, any[]>;
  guestCartTotalByChannel: Record<string, number>;
  currencyByChannel: Record<string, string>;
  guestCart: any[];
  isGuest: boolean;
  guestCartTotal: number;
  self_pickup_mode: number;
  doorstep_delivery_mode: number;
  decimal_point: number;
  prescriptions: Record<string, any>;
  // Pending promo code waiting to be validated and applied
  pendingPromoCode: string | null;
  // Why the last auto-apply of pendingPromoCode failed — shown inline in the cart.
  promoAutoApplyError: { code: string; reason: string } | null;
}

const initialState: CartState = {
  status: "loading",
  cart: null,
  checkout: null,
  promo_code: null,
  is_wallet_checked: 0,
  cartProducts: [],
  cartSubTotal: 0,
  currency: "",
  // Per-channel guest cart and currency initial state
  activeChannel: DEFAULT_CHANNEL,
  guestCartByChannel: { quick: [], ecommerce: [] },
  guestCartTotalByChannel: { quick: 0, ecommerce: 0 },
  currencyByChannel: { quick: "", ecommerce: "" },
  // Mirror of the active channel's bucket — what existing components read/write against.
  guestCart: [],
  isGuest: true,
  guestCartTotal: 0,
  self_pickup_mode: 0,
  doorstep_delivery_mode: 0,
  // Decimal precision from cart response
  decimal_point: 0,
  // Prescription files map keyed by variant ID (in-memory only)
  prescriptions: {},
  pendingPromoCode: null,
  promoAutoApplyError: null,
};

// Sync flat guest cart mirror with active channel bucket
const syncMirror = (state: CartState) => {
  const ch = normalizeChannel(state.activeChannel);
  state.guestCart = state.guestCartByChannel[ch] ?? [];
  state.guestCartTotal = state.guestCartTotalByChannel[ch] ?? 0;
  if (state.currencyByChannel) {
    state.currency = state.currencyByChannel[ch] ?? "";
  }
};

// Ensure per-channel guest cart buckets exist on state
const ensureBuckets = (state: CartState) => {
  if (!state.guestCartByChannel) {
    state.guestCartByChannel = {
      quick: Array.isArray(state.guestCart) ? state.guestCart : [],
      ecommerce: [],
    };
  }
  if (!state.guestCartTotalByChannel) {
    state.guestCartTotalByChannel = {
      quick: typeof state.guestCartTotal === "number" ? state.guestCartTotal : 0,
      ecommerce: 0,
    };
  }
  if (!state.currencyByChannel) {
    state.currencyByChannel = {
      quick: typeof state.currency === "string" ? state.currency : "",
      ecommerce: "",
    };
  }
  if (!state.activeChannel) state.activeChannel = DEFAULT_CHANNEL;
};

export const cartReducer = createSlice({
  name: "cart",
  initialState,
  reducers: {
    setCart: (state, action: PayloadAction<{ data: any }>) => {
      state.status = "fulfill";
      state.cart = action.payload.data;
    },
    setCartCheckout: (state, action: PayloadAction<{ data: any }>) => {
      state.status = "fulfill";
      state.checkout = action.payload.data;
    },
    setCartPromo: (state, action: PayloadAction<{ data: any }>) => {
      state.status = "fulfill";
      state.promo_code = action.payload.data;
      state.promoAutoApplyError = null;
    },
    clearCartPromo: (state) => {
      // state.cart.promo_code = [];
      state.promo_code = null;
    },
    setPendingPromoCode: (state, action: PayloadAction<string | null>) => {
      state.pendingPromoCode = action.payload;
    },
    setPromoAutoApplyError: (
      state,
      action: PayloadAction<{ code: string; reason: string } | null>,
    ) => {
      state.promoAutoApplyError = action.payload;
    },
    setWallet: (state, action: PayloadAction<{ data: number }>) => {
      state.status = "fulfill";
      state.is_wallet_checked = action.payload.data;
    },
    setCartProducts: (state, action: PayloadAction<{ data: any[] }>) => {
      state.cartProducts = action.payload.data;
    },
    setCartSubTotal: (state, action: PayloadAction<{ data: number }>) => {
      state.cartSubTotal = action.payload.data;
    },
    setCartCurrency: (state, action: PayloadAction<{ data: string; channel?: string }>) => {
      ensureBuckets(state);
      // Update currency for specified response channel or active channel
      const ch = normalizeChannel(action.payload?.channel ?? state.activeChannel);
      // Ignore empty/falsy currency so an empty-cart response can't blank a known symbol.
      if (action.payload.data) {
        state.currencyByChannel[ch] = action.payload.data;
      }
      syncMirror(state);
    },
    // Persist decimal precision from cart response
    setCartDecimal: (state, action: PayloadAction<{ data: number | string }>) => {
      if (action.payload?.data != null && action.payload?.data !== "") {
        state.decimal_point = action.payload.data as number;
      }
    },
    setIsGuest: (state, action: PayloadAction<{ data: boolean }>) => {
      state.isGuest = action.payload.data;
    },
    // Set active guest channel and sync mirror
    setGuestChannel: (state, action: PayloadAction<{ channel?: string } | undefined>) => {
      ensureBuckets(state);
      state.activeChannel = normalizeChannel(action.payload?.channel);
      syncMirror(state);
    },
    addtoGuestCart: (state, action: PayloadAction<{ data: any[] }>) => {
      ensureBuckets(state);
      const ch = normalizeChannel(state.activeChannel);
      state.guestCartByChannel[ch] = action.payload.data ?? [];
      syncMirror(state);
    },
    setGuestCartTotal: (state, action: PayloadAction<{ data: number }>) => {
      ensureBuckets(state);
      const ch = normalizeChannel(state.activeChannel);
      state.guestCartTotalByChannel[ch] = action.payload.data ?? 0;
      syncMirror(state);
    },
    addGuestCartTotal: (state, action: PayloadAction<{ data: number }>) => {
      ensureBuckets(state);
      const ch = normalizeChannel(state.activeChannel);
      state.guestCartTotalByChannel[ch] =
        (state.guestCartTotalByChannel[ch] ?? 0) + action.payload.data;
      syncMirror(state);
    },
    subGuestCartTotal: (state, action: PayloadAction<{ data: number }>) => {
      ensureBuckets(state);
      const ch = normalizeChannel(state.activeChannel);
      state.guestCartTotalByChannel[ch] =
        (state.guestCartTotalByChannel[ch] ?? 0) - action.payload.data;
      syncMirror(state);
    },
    // Clear only the active channel's guest cart.
    clearActiveGuestCart: (state) => {
      ensureBuckets(state);
      const ch = normalizeChannel(state.activeChannel);
      state.guestCartByChannel[ch] = [];
      state.guestCartTotalByChannel[ch] = 0;
      syncMirror(state);
    },
    // Clear every channel's guest cart (used after login/register merges all channels).
    clearAllGuestCarts: (state) => {
      ensureBuckets(state);
      GUEST_CHANNELS.forEach((ch) => {
        state.guestCartByChannel[ch] = [];
        state.guestCartTotalByChannel[ch] = 0;
      });
      syncMirror(state);
    },
    setSelfPickupMode: (state, action: PayloadAction<{ data: number }>) => {
      state.self_pickup_mode = action.payload.data;
    },
    setDoorStepDeliveryMode: (state, action: PayloadAction<{ data: number }>) => {
      state.doorstep_delivery_mode = action.payload.data;
    },
    // Store prescription file for variant ID
    setPrescription: (state, action: PayloadAction<{ variantId: string | number; file: any }>) => {
      const { variantId, file } = action.payload;
      // Guard: persisted state predating this field rehydrates without it.
      if (!state.prescriptions) state.prescriptions = {};
      state.prescriptions[String(variantId)] = file;
    },
    removePrescription: (state, action: PayloadAction<{ variantId: string | number }>) => {
      if (!state.prescriptions) return;
      delete state.prescriptions[String(action.payload.variantId)];
    },
    clearPrescriptions: (state) => {
      state.prescriptions = {};
    },
  },
  extraReducers: (builder) => {
    // any logout (manual or 401 interceptor) resets cart back to guest
    builder.addCase(logoutAuth, (state) => {
      state.isGuest = true;
      state.prescriptions = {};
      state.pendingPromoCode = null;
      state.promoAutoApplyError = null;
    });
  },
});

export const {
  setCart,
  setCartCheckout,
  setCartPromo,
  clearCartPromo,
  setPendingPromoCode,
  setPromoAutoApplyError,
  setWallet,
  setCartProducts,
  setCartSubTotal,
  setCartCurrency,
  setCartDecimal,
  setIsGuest,
  setGuestChannel,
  addtoGuestCart,
  setGuestCartTotal,
  addGuestCartTotal,
  subGuestCartTotal,
  clearActiveGuestCart,
  clearAllGuestCarts,
  setSelfPickupMode,
  setDoorStepDeliveryMode,
  setPrescription,
  removePrescription,
  clearPrescriptions,
} = cartReducer.actions;
export default cartReducer.reducer;
