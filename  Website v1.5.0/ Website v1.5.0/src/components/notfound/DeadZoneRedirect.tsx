"use client";
import { useEffect } from "react";
import { useDispatch } from "react-redux";
import { useRouter } from "next/navigation";
import { setSelectedZone } from "@/redux/slices/locationModalSlice";
import { setCity } from "@/redux/slices/citySlice";

// A visitor's browser remembers the delivery zone they picked. If that zone is later removed or renamed
// in the admin, /<zone> no longer exists and used to show a 404. Forget the stale zone and send them to
// the home page, where they can pick a current delivery area.
export default function DeadZoneRedirect() {
  const dispatch = useDispatch();
  const router = useRouter();
  useEffect(() => {
    dispatch(setSelectedZone(null));
    dispatch(setCity({ data: null }));
    router.replace("/");
  }, [dispatch, router]);
  return (
    <div className="flex min-h-[50vh] items-center justify-center text-sm SecondaryTextColor">
      Updating your delivery area…
    </div>
  );
}
