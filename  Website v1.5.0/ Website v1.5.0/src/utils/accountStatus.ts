import { store } from "@/redux/store";
import { t } from "@/utils/translation";
import {
  logoutAuth,
  setJWTToken,
  setCurrentUser,
  setAuthType,
} from "@/redux/slices/userSlice";
import {
  clearCartPromo,
  setCart,
  setCartProducts,
  setCartSubTotal,
  setIsGuest,
} from "@/redux/slices/cartSlice";
import { clearAllFilter } from "@/redux/slices/productFilterSlice";
import {
  isUserDeactivated,
  isDeactivatedUser,
} from "@/utils/isUserDeactivated";

// Store-free module avoids a circular import with axiosMiddleware.
export { isUserDeactivated, isDeactivatedUser };

// Deactivated-account message: translated key, else the server's own text.
export const deactivatedMessage = (res?: { message?: string } | null): string => {
  const translated = t("user_deactivated");
  if (translated && translated !== "user_deactivated") return translated;
  return res?.message || "Your account has been deactivated.";
};

// Clears the session from the store; caller decides where to navigate.
export const clearLocalSession = (): void => {
  store.dispatch(clearAllFilter());
  store.dispatch(logoutAuth());
  store.dispatch(setJWTToken({ data: "" }));
  store.dispatch(setCurrentUser({ data: null }));
  store.dispatch(setAuthType({ data: "" }));
  store.dispatch(setCart({ data: [] }));
  store.dispatch(setCartProducts({ data: [] }));
  store.dispatch(setCartSubTotal({ data: 0 }));
  store.dispatch(clearCartPromo());
  store.dispatch(setIsGuest({ data: true }));
};
