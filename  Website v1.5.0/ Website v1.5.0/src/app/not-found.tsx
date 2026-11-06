import Custom404 from "@/components/notfound/Custom404";

// Unmatched routes. Rewritten routes render Custom404 inline instead.
export default function NotFound() {
  return <Custom404 />;
}
