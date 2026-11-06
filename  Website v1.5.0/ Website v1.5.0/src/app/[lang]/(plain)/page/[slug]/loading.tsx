import Loader from "@/components/loader/Loader";

// In-flow, not `screen="full"`: that variant is a fixed white overlay covering
// the header too, so every client navigation flashed the whole viewport even
// when the page's data was already cached.
export default function Loading() {
  return (
    <div className="flex min-h-[60vh] w-full items-center justify-center">
      <Loader />
    </div>
  );
}
