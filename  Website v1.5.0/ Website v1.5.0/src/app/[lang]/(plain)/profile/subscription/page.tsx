import type { Metadata } from "next";
import Subscription from "@/components/profiledashboard/subscriptions/Subscriptions";
import AuthGate from "@/components/auth/AuthGate";
import { buildPageMetadata } from "@/utils/buildMetadata";

export const metadata: Metadata = buildPageMetadata({
  title: `Subscription - ${process.env.NEXT_PUBLIC_META_TITLE}`,
  pageName: "/profile/subscription",
  robots: "noindex, nofollow",
});

// Route-only subscription gate; profile layout's AuthGate still applies above.
export default function SubscriptionRoute() {
  return (
    <AuthGate requireAuth requireSubscription>
      <Subscription />
    </AuthGate>
  );
}
