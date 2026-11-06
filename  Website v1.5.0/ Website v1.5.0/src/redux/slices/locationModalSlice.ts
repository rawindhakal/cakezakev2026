import { createSlice, PayloadAction } from "@reduxjs/toolkit";

interface LocationModalState {
  // Modal visibility flag (transient)
  showLocation: boolean;
  // Selected country object driving zone selection
  selectedCountry: any | null;
  // Selected zone object from API ({ id, name, slug })
  selectedZone: any | null;
}

const initialState: LocationModalState = {
  showLocation: false,
  selectedCountry: null,
  selectedZone: null,
};

export const locationModalReducer = createSlice({
  name: "locationModal",
  initialState,
  reducers: {
    openLocationModal: (state) => {
      state.showLocation = true;
    },
    closeLocationModal: (state) => {
      state.showLocation = false;
    },
    setShowLocation: (state, action: PayloadAction<boolean>) => {
      state.showLocation = action.payload;
    },
    // Set country and open location modal
    setSelectedCountry: (state, action: PayloadAction<any>) => {
      state.selectedCountry = action.payload;
      state.showLocation = true;
    },
    // Set default country on initial resolution
    setDefaultCountry: (state, action: PayloadAction<any>) => {
      state.selectedCountry = action.payload;
    },
    // Store the zone object verbatim from the API.
    setSelectedZone: (state, action: PayloadAction<any>) => {
      state.selectedZone = action.payload;
    },
  },
});

export const {
  openLocationModal,
  closeLocationModal,
  setShowLocation,
  setSelectedCountry,
  setDefaultCountry,
  setSelectedZone,
} = locationModalReducer.actions;
export default locationModalReducer.reducer;
