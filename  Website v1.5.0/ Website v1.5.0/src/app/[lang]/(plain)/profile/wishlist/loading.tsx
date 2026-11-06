import CardSkeleton from "@/components/skeleton/CardSkeleton";

// Mirrors Wishlist's own first-load skeleton — see activeorders/loading.tsx.
export default function Loading() {
  return (
    <div className="p-3 sm:p-4">
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-2.5 sm:gap-3">
        {Array.from({ length: 8 }).map((_, index) => (
          <CardSkeleton height={104} padding="3px" key={index} />
        ))}
      </div>
    </div>
  );
}
