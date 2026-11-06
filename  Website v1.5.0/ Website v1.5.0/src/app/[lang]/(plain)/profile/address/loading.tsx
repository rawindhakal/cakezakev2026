import CardSkeleton from "@/components/skeleton/CardSkeleton";

// Mirrors Address' own first-load skeleton — see activeorders/loading.tsx.
export default function Loading() {
  return (
    <div className="grid grid-cols-1 gap-3 p-3 lg:grid-cols-2">
      {Array.from({ length: 4 }).map((_, index) => (
        <CardSkeleton key={index} height={200} padding="2px" />
      ))}
    </div>
  );
}
