import { useEffect } from "react";
import { useDispatch, useSelector } from "react-redux";
import * as api from "@/api/apiRoutes";
import { setFavoriteProductIds } from "@/redux/slices/FavoriteSlice";

const PAGE_SIZE = 100;
// Maximum pages to fetch for favorites list.
const MAX_PAGES = 20;
// Last synced token and location key.
let syncedKey: string | null = null;

// Seeds the persisted favorite-id list from the user's wishlist API.
export default function useSyncFavoriteIds() {
  const dispatch = useDispatch();
  const jwtToken = useSelector((state: any) => state.User.jwtToken);
  const lat = useSelector((state: any) => state.City.city?.latitude);
  const lng = useSelector((state: any) => state.City.city?.longitude);

  useEffect(() => {
    if (!jwtToken || lat == null || lng == null) return;
    const key = `${jwtToken}|${lat}|${lng}`;
    if (syncedKey === key) return;
    syncedKey = key;
    (async () => {
      try {
        const ids: (number | string)[] = [];
        for (let page = 0; page < MAX_PAGES; page++) {
          const res: any = await api.getFavorite({
            latitude: lat,
            longitude: lng,
            limit: PAGE_SIZE,
            offset: page * PAGE_SIZE,
          });
          // status 0 = empty wishlist, not an error.
          const rows = res?.status == 1 && Array.isArray(res?.data) ? res.data : [];
          for (const row of rows) if (row?.id != null) ids.push(row.id);
          const total = Number(res?.total);
          if (rows.length < PAGE_SIZE || (total && ids.length >= total)) break;
        }
        if (syncedKey !== key) return; // a newer login/location took over
        dispatch(setFavoriteProductIds({ data: ids }));
      } catch (error) {
        if (syncedKey === key) syncedKey = null; // allow a retry
        // Keep the current list — a failed sync must not blank every heart.
        console.log("[favorites] sync failed", error);
      }
    })();
  }, [jwtToken, lat, lng, dispatch]);
}
