import { createSlice, PayloadAction } from "@reduxjs/toolkit";
import { logoutAuth } from "./userSlice";

interface FavoriteState {
    status: "loading" | "fulfill";
    favorite: any | null;
    favouritelength: number;
    favouriteProductIds: any[];
}

const initialState: FavoriteState = {
    status: 'loading', //fulfill
    favorite: null,
    favouritelength: 0,
    favouriteProductIds: []
};

export const favoriteReducer = createSlice({
    name: "wishlist",
    initialState,
    reducers: {
        setFavorites: (state, action: PayloadAction<{ data: any }>) => {
            state.status = "fulfill"
            state.favorite = action.payload.data
        },
        setFavoriteLength: (state, action: PayloadAction<{ data: number }>) => {
            state.status = "fulfill"
            state.favouritelength = action.payload.data
        },
        setFavoriteProductIds: (state, action: PayloadAction<{ data: any[] }>) => {
            state.status = "fulfill"
            state.favouriteProductIds = action.payload.data
        },
        // Per-id sync against CURRENT state — many cards reconciling in the
        // same tick must not overwrite each other with stale full lists.
        syncFavoriteId: (
            state,
            action: PayloadAction<{ id: number | string; liked: boolean }>
        ) => {
            const { id, liked } = action.payload
            const rest = state.favouriteProductIds.filter((x: any) => x != id)
            state.favouriteProductIds = liked ? [...rest, id] : rest
        }
    },
    // Every logout path dispatches logoutAuth — clear here so the persisted
    // ids never leak into the next session/account as filled hearts.
    extraReducers: (builder) => {
        builder.addCase(logoutAuth, () => initialState)
    }
})

export const { setFavoriteLength, setFavoriteProductIds, setFavorites, syncFavoriteId } = favoriteReducer.actions
export default favoriteReducer.reducer