import type { Metadata } from "next";
import WalletHistory from "@/components/profiledashboard/wallet/WalletHistory";
import { buildPageMetadata } from "@/utils/buildMetadata";

export const metadata: Metadata = buildPageMetadata({
  title: `Wallet History - ${process.env.NEXT_PUBLIC_META_TITLE}`,
  pageName: "/profile/wallet-history",
  robots: "noindex, nofollow",
});

export default function WalletHistoryRoute() {
  return <WalletHistory />;
}
