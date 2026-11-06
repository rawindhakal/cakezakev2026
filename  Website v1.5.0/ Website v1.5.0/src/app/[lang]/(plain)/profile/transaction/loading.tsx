import CardSkeleton from "@/components/skeleton/CardSkeleton";

// Matches TransactionHistory's own skeleton.
export default function Loading() {
  return (
    <div className="grid grid-cols-12 gap-3 p-3">
      {Array.from({ length: 6 }).map((_, index) => (
        <div className="col-span-12 md:col-span-6 lg:col-span-6" key={index}>
          <CardSkeleton height={200} padding="p-4" />
        </div>
      ))}
    </div>
  );
}
