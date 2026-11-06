import { configureStore } from '@reduxjs/toolkit';
import { createTransform, persistReducer, persistStore } from "redux-persist"
import storage from "redux-persist/lib/storage"
import { rootReducer } from './rootReducer';
import { thunk } from "redux-thunk";
import { writeSsrLocationCookie } from '@/utils/ssrLocationCookie';

// The active tab belongs to the URL. Persisting it meant a tab picked days ago
// came back on a plain /zone load and overrode ?tab=.
const dropSelectedTab = createTransform(
    (inbound: any) => ({ ...inbound, selectedCategoryId: null }),
    (outbound: any) => ({ ...outbound, selectedCategoryId: null }),
    { whitelist: ['ShopMode'] },
);

const persistConfig = {
    key: 'root',
    storage,
    // Cart/LocationModal have their own nested persist — saving them here too doubled the writes.
    blacklist: ['Cart', 'LocationModal'],
    transforms: [dropSelectedTab],
    // Batch localStorage writes instead of serializing on every dispatch.
    throttle: 500,
};


const persistedReducer = persistReducer(persistConfig, rootReducer);

export const store = configureStore({
    reducer: persistedReducer,
    middleware: (getDefaultMiddleware) => getDefaultMiddleware({
        immutableCheck: false,
        serializableCheck: false,
        applyMiddleware: thunk
    })
});
export const persistor = persistStore(store);

// Mirror the active city's coordinates into a cookie so the next server render
// seeds from the SAME location the client will use after hydration — otherwise
// every coordinate-keyed query refetches on hydration. See ssrLocationCookie.ts.
let lastMirroredLocation: string | null = null;
store.subscribe(() => {
    const city = (store.getState() as any)?.City?.city;
    if (!city?.latitude || !city?.longitude) return;
    const next = `${city.latitude},${city.longitude}`;
    if (next === lastMirroredLocation) return;
    lastMirroredLocation = next;
    writeSsrLocationCookie(city.latitude, city.longitude);
});
