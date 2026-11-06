import { createSlice, PayloadAction } from "@reduxjs/toolkit";

interface LayoutTheme {
    background_color: any;
    background_theme: any;
    background_image_url: any;
    text_color: any;
    header_icon_url: any;
}

interface ShopModeState {
    mode: string;
    layoutMode: string | null;
    availableModes: string | null;
    requested: string;
    zoneId: any | null;
    zoneSlug: any | null;
    quickLabel: any | null;
    ecommerceLabel: any | null;
    defaultApplied: boolean;
    layoutTheme: LayoutTheme | null;
    searchSuggestions: any[];
    deliveryTime: any | null;
    deliveryDistance: any | null;
    storeClosed: boolean;
    selectedCategoryId: any | null;
}

const initialState: ShopModeState = {
    mode: "quick", // "quick" | "allShop" — current active channel
    layoutMode: null, // "both" | "quick" | "allShop" — from home_layout `channel.layout_mode` (picks/forces default channel)
    availableModes: null, // "both" | "quick" | "allShop" — from home_layout `available_modes` (gates toggle visibility)
    requested: "quick", // default channel requested by backend
    zoneId: null,
    zoneSlug: null, // Zone URL slug from home_layout
    quickLabel: null, // toggle label for quick channel — from home_layout `channel_label_quick`
    ecommerceLabel: null, // toggle label for ecommerce channel — from home_layout `channel_label_ecommerce`
    defaultApplied: false, // true once the backend-requested default has been set; persists across remounts
    layoutTheme: null, // background_color/theme/image/text_color/header_icon_url from home_layout API
    // Search placeholder suggestions array
    searchSuggestions: [],
    deliveryTime: null, // ready-made label from home_layout `time_to_deliver` (e.g. "22 mins")
    deliveryDistance: null, // ready-made label from home_layout `distance` (e.g. "5.99 km")
    // Store closed flag from home_layout (blocks purchasing)
    storeClosed: false,
    // Selected home page category tab ID
    selectedCategoryId: null,
};

export const shopModeReducer = createSlice({
    name: "shopMode",
    initialState,
    reducers: {
        setShopMode: (state, action: PayloadAction<{ mode: string }>) => {
            const next = action.payload.mode;
            // Clear selected category ID when channel changes
            if (next !== state.mode) {
                state.selectedCategoryId = null;
            }
            state.mode = next;
        },
        setSelectedCategoryId: (state, action: PayloadAction<any>) => {
            state.selectedCategoryId = action.payload ?? null;
        },
        // Store channel config returned by the home_layout API
        setChannel: (state, action: PayloadAction<{
            layout_mode?: string;
            available_modes?: string;
            requested?: string;
            zone_id?: any;
            zone_slug?: any;
            search_suggestions?: any[];
            channel_label_quick?: any;
            channel_label_ecommerce?: any;
        } | undefined>) => {
            const { layout_mode, available_modes, requested, zone_id, zone_slug, search_suggestions, channel_label_quick, channel_label_ecommerce } = action.payload || {};
            // Normalize channel vocabulary (ecommerce -> allShop)
            const norm = (v?: string | null) => (v === "ecommerce" ? "allShop" : v);
            const nextLayoutMode = norm(layout_mode) ?? null;
            // Reset defaultApplied on layout mode change
            if (nextLayoutMode !== state.layoutMode) {
                state.defaultApplied = false;
            }
            state.layoutMode = nextLayoutMode;
            state.availableModes = norm(available_modes) ?? null;
            state.requested = norm(requested) ?? "quick";
            state.zoneId = zone_id ?? null;
            state.zoneSlug = zone_slug ?? null;
            state.searchSuggestions = Array.isArray(search_suggestions)
              ? search_suggestions.filter(Boolean)
              : [];
            state.quickLabel = channel_label_quick ?? null;
            state.ecommerceLabel = channel_label_ecommerce ?? null;
        },
        setDefaultApplied: (state) => {
            state.defaultApplied = true;
        },
        setLayoutTheme: (state, action: PayloadAction<Partial<LayoutTheme> | undefined>) => {
            const { background_color, background_theme, background_image_url, text_color, header_icon_url } = action.payload || {};
            state.layoutTheme = { background_color, background_theme, background_image_url, text_color, header_icon_url };
        },
        setDeliveryTime: (state, action: PayloadAction<any>) => {
            state.deliveryTime = action.payload ?? null;
        },
        setDeliveryDistance: (state, action: PayloadAction<any>) => {
            state.deliveryDistance = action.payload ?? null;
        },
        setStoreClosed: (state, action: PayloadAction<any>) => {
            state.storeClosed = Number(action.payload) === 1;
        },
    },
});

export const { setShopMode, setChannel, setDefaultApplied, setLayoutTheme, setDeliveryTime, setDeliveryDistance, setStoreClosed, setSelectedCategoryId } = shopModeReducer.actions;
export default shopModeReducer.reducer;
