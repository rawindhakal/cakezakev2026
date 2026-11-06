import BlogSkeleton from "@/components/blogs/BlogsSkeleton";

// Matches Blogs' own skeleton — no layout swap mid-load.
export default function Loading() {
  return <BlogSkeleton />;
}
