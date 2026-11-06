import { useState } from "react";
import { useSelector } from "react-redux";
import * as api from "@/api/apiRoutes";
import { toast } from "react-toastify";
import { t } from "@/utils/translation";

// Back-in-stock notification toggle hook for product variants.
export default function useNotifyMe({
  variantId,
  latitude,
  longitude,
}: {
  variantId?: number | string | null;
  latitude?: number | string;
  longitude?: number | string;
}) {
  const jwtToken = useSelector((state: any) => state?.User?.jwtToken);
  const [isNotifyRequested, setIsNotifyRequested] = useState(false);
  const [loading, setLoading] = useState(false);

  const toggle = async (currentlyRequested: boolean) => {
    if (loading || !variantId) return;
    // notify_me is an authenticated endpoint: without this a guest tap just
    // 401s and the raw backend "Unauthenticated." string lands in a toast.
    if (!jwtToken) {
      toast.error(t("required_login_message_for_notification"), {
        toastId: "required_login_message_for_notify",
      });
      return;
    }
    setLoading(true);
    try {
      const response = currentlyRequested
        ? await api.removeNotifyMe({ product_variant_id: variantId })
        : await api.notifyMe({ product_variant_id: variantId, latitude, longitude });
      // Display backend notification status message.
      if (response?.status === 1) {
        setIsNotifyRequested(!!response?.data?.is_notify_requested);
        if (response?.message) toast.success(response.message);
      } else {
        toast.error(response?.message || t("something_went_wrong") || "Something went wrong");
      }
    } catch (error: any) {
      console.log("notify me error", error);
      // A session that expired mid-use still reaches here; never surface the
      // backend's raw auth string to the user.
      if (error?.response?.status === 401) {
        toast.error(t("required_login_message_for_notification"), {
          toastId: "required_login_message_for_notify",
        });
      } else {
        toast.error(
          error?.response?.data?.message ||
            t("something_went_wrong") ||
            "Something went wrong",
        );
      }
    } finally {
      setLoading(false);
    }
  };

  return { isNotifyRequested, setIsNotifyRequested, loading, toggle };
}

