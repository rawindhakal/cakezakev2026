import type { Metadata } from "next";
import SupportChat from "@/components/chat/support/SupportChat";
import { buildPageMetadata } from "@/utils/buildMetadata";

export const metadata: Metadata = buildPageMetadata({
  title: `Support Chat - ${process.env.NEXT_PUBLIC_META_TITLE}`,
  pageName: "/profile/support-chat",
  robots: "noindex, nofollow",
});

export default function SupportChatRoute() {
  return <SupportChat />;
}
