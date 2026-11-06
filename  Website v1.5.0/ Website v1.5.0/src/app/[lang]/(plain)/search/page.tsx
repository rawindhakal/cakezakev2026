import type { Metadata } from "next";
import SearchPage from "@/components/pagecomponents/SearchPage";
import { buildPageMetadata } from "@/utils/buildMetadata";

export const metadata: Metadata = buildPageMetadata({
  title: `Search - ${process.env.NEXT_PUBLIC_META_TITLE}`,
  pageName: "/search",
  robots: "noindex, nofollow",
});

export default function SearchRoute() {
  return <SearchPage />;
}
