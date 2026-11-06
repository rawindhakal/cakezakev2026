import type { Metadata } from "next";
import ActiveOrders from "@/components/profiledashboard/orders/ActiveOrders";
import { buildPageMetadata } from "@/utils/buildMetadata";

export const metadata: Metadata = buildPageMetadata({
  title: `Active Orders - ${process.env.NEXT_PUBLIC_META_TITLE}`,
  pageName: "/profile/active-orders",
  robots: "noindex, nofollow",
});

export default function ActiveOrdersRoute() {
  return <ActiveOrders />;
}
