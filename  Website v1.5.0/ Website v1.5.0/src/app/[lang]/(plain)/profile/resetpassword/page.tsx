import type { Metadata } from "next";
import ResetPassword from "@/components/profiledashboard/ResetPassword";
import { buildPageMetadata } from "@/utils/buildMetadata";

export const metadata: Metadata = buildPageMetadata({
  title: "Reset Password",
  pageName: "/profile/reset-password",
  robots: "noindex, nofollow",
});

export default function ResetPasswordRoute() {
  return <ResetPassword />;
}
