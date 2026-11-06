import { useEffect } from "react";
import { useDispatch, useSelector } from "react-redux";
import { setIsGuest } from "@/redux/slices/cartSlice";

// Cart.isGuest and User.jwtToken live in two separate persisted keys
// (persist:Cart and persist:root), so they can rehydrate out of step — a
// cleared or stale root key leaves isGuest=false with no token. The cards then
// take the logged-in branch and every add 401s, and the 401 handler can't
// recover it because it bails when there is no token. Re-derive the flag from
// the token once the store has rehydrated.
const useGuestFlagReconcile = () => {
  const dispatch = useDispatch();
  const jwtToken = useSelector((state: any) => state?.User?.jwtToken);
  const isGuest = useSelector((state: any) => state?.Cart?.isGuest);

  useEffect(() => {
    const shouldBeGuest = !jwtToken;
    if (isGuest === shouldBeGuest) return;
    dispatch(setIsGuest({ data: shouldBeGuest }));
  }, [jwtToken, isGuest, dispatch]);
};

export default useGuestFlagReconcile;
