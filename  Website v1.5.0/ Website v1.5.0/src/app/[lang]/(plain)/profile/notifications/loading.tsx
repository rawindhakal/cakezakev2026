import CardSkeleton from "@/components/skeleton/CardSkeleton";

// Mirrors Notifications' own first-load skeleton — see activeorders/loading.tsx.
export default function Loading() {
  return (
    <div className="flex flex-col gap-3 p-4">
      {Array.from({ length: 7 }).map((_, index) => (
        <div key={index} className="w-full">
          <CardSkeleton height={100} padding="p-1" />
        </div>
      ))}
    </div>
  );
}
