import { useSelector } from "react-redux";
import { toast } from "react-toastify";
import { t } from "@/utils/translation";

// Manages soft store-closed UI behavior by blocking order actions and notifying user on click.
interface UseStoreClosedResult {
  storeClosed: boolean;
  notifyClosed: () => void;
  guard: <A extends any[], R>(
    handler?: (...args: A) => R,
  ) => (...args: A) => R | undefined;
  closedProps: Record<string, any>;
  closedDecorClass: string;
}

const useStoreClosed = (): UseStoreClosedResult => {
  const storeClosed =
    useSelector((state: any) => state.ShopMode?.storeClosed) === true;

  const notifyClosed = () => {
    toast.error(t("store_closed_cannot_order"));
  };

  const guard =
    <A extends any[], R>(handler?: (...args: A) => R) =>
    (...args: A): R | undefined => {
      if (storeClosed) {
        (args[0] as any)?.preventDefault?.();
        (args[0] as any)?.stopPropagation?.();
        notifyClosed();
        return undefined;
      }
      return handler?.(...args);
    };

  // Props for buy-path buttons when store is closed.
  const closedProps = storeClosed
    ? {
        "aria-disabled": true,
        title: t("store_closed_cannot_order"),
        className: "grayscale opacity-60",
      }
    : {};

  // Style class for non-interactive elements when store is closed.
  const closedDecorClass = storeClosed ? "grayscale" : "";

  return { storeClosed, notifyClosed, guard, closedProps, closedDecorClass };
};

export default useStoreClosed;
