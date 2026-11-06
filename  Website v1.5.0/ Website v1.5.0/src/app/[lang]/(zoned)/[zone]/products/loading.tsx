import ProductsListSkeleton from "@/components/skeleton/ProductsListSkeleton";

// Same layout ProductsList shows while its own data loads, so the route-level
// placeholder hands off without swapping to a different skeleton mid-load.
export default function Loading() {
  return <ProductsListSkeleton />;
}
