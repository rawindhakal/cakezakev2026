import PageSkeleton from "@/components/skeleton/PageSkeleton";

// Explicit override rather than inheriting the group's loading.tsx: this
// route genuinely IS a card grid, unlike the zone home (a server-driven
// stack of banners/rails, which shows a plain Loader) or product detail.
// Stating it here means a change to either of those can't silently
// retarget this route's placeholder.
export default function Loading() {
  return <PageSkeleton />;
}
