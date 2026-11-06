import { createSlice, PayloadAction } from "@reduxjs/toolkit";

// Non-filter presentation, category bookkeeping, and block source Redux state
export interface ProductFilterState {
  section_id: any | null;
  grid_view: boolean;
  section_products: any | null;
  search_sizes: any[];
  search_product: any[];
  selectedCategories: any[];
  searchedCategory: string;
  listing_source: string;
  category_slug: string;
  categoryBreadcrumb: any[];
  data_source: string;
  manual_product_ids: string;
  block_source_id: string;
  block_category_ids: string;
  block_brand_ids: string;
  filter_mode: string;
}

export const initialState: ProductFilterState = {
  section_id: null,
  grid_view: true,
  section_products: null,
  search_sizes: [],
  search_product: [],
  selectedCategories: [],
  searchedCategory: "",
  listing_source: "all",
  category_slug: "",
  categoryBreadcrumb: [],
  // Block data source and ID parameters for home layout "See All" flow
  data_source: "",
  manual_product_ids: "",
  block_source_id: "",
  // Scope an automatic row (trending, new_arrivals, …) carries from the builder.
  block_category_ids: "",
  block_brand_ids: "",
  filter_mode: "",
};

export const productFilterReducer = createSlice({
  name: "productFilter",
  initialState,
  reducers: {
    setFilterSection: (state, action: PayloadAction<{ data: any }>) => {
      state.section_id = action.payload.data;
    },
    setFilterView: (state, action: PayloadAction<{ data: boolean }>) => {
      state.grid_view = action.payload.data;
    },
    setFilterProducts: (state, action: PayloadAction<{ data: any }>) => {
      state.section_products = action.payload.data;
    },
    setFilterProductSizes: (state, action: PayloadAction<{ data: any[] }>) => {
      state.search_sizes = action.payload.data;
    },
    setProductBySearch: (state, action: PayloadAction<{ data: any[] }>) => {
      state.search_product = action.payload.data;
    },
    // Reset non-filter Redux state parameters
    clearAllFilter: (state, action: PayloadAction<{ preserveCategory?: boolean } | undefined>) => {
      const { preserveCategory } = action.payload || {};
      state.section_id = null;
      state.search_product = [];
      state.selectedCategories = [];
      state.searchedCategory = "";
      if (!preserveCategory) {
        state.category_slug = "";
        state.categoryBreadcrumb = [];
        state.listing_source = "all";
        state.data_source = "";
        state.manual_product_ids = "";
        state.block_source_id = "";
        state.block_category_ids = "";
        state.block_brand_ids = "";
        state.filter_mode = "";
      }
    },
    setSelectedCategories: (state, action: PayloadAction<{ data: any }>) => {
      state.selectedCategories = [
        ...state.selectedCategories,
        action.payload.data,
      ];
    },
    setSearchedCategory: (state, action: PayloadAction<{ data: string }>) => {
      state.searchedCategory = action.payload.data;
    },
    setListingSource: (state, action: PayloadAction<{ data: string }>) => {
      state.listing_source = action.payload.data;
    },
    setCategorySlug: (state, action: PayloadAction<{ data: string }>) => {
      state.category_slug = action.payload.data;
    },
    setCategoryBreadcrumb: (state, action: PayloadAction<{ data: any[] }>) => {
      state.categoryBreadcrumb = action.payload.data;
    },
    // Set home layout block source parameters
    setBlockSource: (
      state,
      action: PayloadAction<
        | {
            data_source?: string;
            manual_product_ids?: string;
            source_id?: string;
            category_ids?: string;
            brand_ids?: string;
            filter_mode?: string;
          }
        | undefined
      >
    ) => {
      const {
        data_source = "",
        manual_product_ids = "",
        source_id = "",
        category_ids = "",
        brand_ids = "",
        filter_mode = "",
      } = action.payload || {};
      state.data_source = data_source;
      state.manual_product_ids =
        data_source === "manual" ? manual_product_ids : "";
      state.block_source_id = data_source === "manual" ? "" : source_id;
      state.block_category_ids = data_source === "manual" ? "" : category_ids;
      state.block_brand_ids = data_source === "manual" ? "" : brand_ids;
      state.filter_mode = filter_mode;
    },
  },
});

export const {
  setFilterProducts,
  setFilterSection,
  setFilterView,
  setFilterProductSizes,
  clearAllFilter,
  setProductBySearch,
  setSelectedCategories,
  setSearchedCategory,
  setListingSource,
  setCategorySlug,
  setCategoryBreadcrumb,
  setBlockSource,
} = productFilterReducer.actions;

export default productFilterReducer.reducer;
