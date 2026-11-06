import ProfileShell from "@/components/profiledashboard/ProfileShell";

// Layout keeps sidebar + user fetch mounted across profile tab switches.
export default function ProfileLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <ProfileShell>{children}</ProfileShell>;
}
