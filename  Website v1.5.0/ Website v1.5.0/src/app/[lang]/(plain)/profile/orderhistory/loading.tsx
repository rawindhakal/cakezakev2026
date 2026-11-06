import CardSkeleton from "@/components/skeleton/CardSkeleton";

// Mirrors PrevOrder's own first-load skeleton — see activeorders/loading.tsx.
export default function Loading() {
  return (
    <div className="grid grid-cols-1 items-start gap-3 p-3 lg:grid-cols-2 2xl:grid-cols-3">
      {Array.from({ length: 6 }).map((_, index) => (
        <CardSkeleton variant="order" key={index} />
      ))}
    </div>
  );
}
