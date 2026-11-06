import CardSkeleton from "@/components/skeleton/CardSkeleton";

// Tab content only (sidebar stays). Must exist — else (plain)'s full-screen loader wins.
export default function Loading() {
  return (
    <div className="flex flex-col gap-2">
      <CardSkeleton height={50} />
      <CardSkeleton height={400} />
    </div>
  );
}
