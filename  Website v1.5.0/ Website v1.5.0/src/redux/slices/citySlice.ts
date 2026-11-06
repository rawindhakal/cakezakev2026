import { createSlice, PayloadAction } from "@reduxjs/toolkit";

interface CityState {
    status: "loading" | "fulfill";
    city: any | null;
}

const initialState: CityState = {
    status: "loading",
    city: null,
};
export const locationReducer = createSlice({
    name: "city",
    initialState,
    reducers: {
        setCity: (state, action: PayloadAction<{ data: any }>) => {
            state.status = "fulfill";
            const next = action.payload.data;
            // Skip state update if city coordinates and slug are unchanged
            if (
                state.city &&
                next &&
                state.city.latitude === next.latitude &&
                state.city.longitude === next.longitude &&
                (state.city.slug ?? null) === (next.slug ?? null)
            ) {
                return;
            }
            state.city = next;
        }
    }
});

export const { setCity } = locationReducer.actions;
export default locationReducer.reducer;