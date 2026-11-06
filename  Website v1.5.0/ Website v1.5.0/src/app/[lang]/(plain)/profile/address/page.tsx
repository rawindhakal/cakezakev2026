import type { Metadata } from "next";
import Address from "@/components/profiledashboard/Address";
import { buildPageMetadata } from "@/utils/buildMetadata";

export const metadata: Metadata = buildPageMetadata({
  title: `Address - ${process.env.NEXT_PUBLIC_META_TITLE}`,
  pageName: "/profile/address",
  robots: "noindex, nofollow",
});

export default function AddressRoute() {
  return <Address />;
}
