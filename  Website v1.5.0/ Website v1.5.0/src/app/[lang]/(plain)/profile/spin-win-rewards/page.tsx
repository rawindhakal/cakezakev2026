import type { Metadata } from "next";
import SpinWinRewardsTab from "@/components/spinwin/SpinWinRewardsTab";
import { buildPageMetadata } from "@/utils/buildMetadata";

export const metadata: Metadata = buildPageMetadata({
  title: `My Rewards - ${process.env.NEXT_PUBLIC_META_TITLE}`,
  pageName: "/profile/spin-win-rewards",
  robots: "noindex, nofollow",
});

export default function SpinWinRewardsRoute() {
  return <SpinWinRewardsTab />;
}
