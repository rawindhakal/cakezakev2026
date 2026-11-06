"use client";

import React, { useState, useEffect, useCallback, useRef } from "react";
import { usePathname } from "next/navigation";
import { useDispatch, useSelector } from "react-redux";
import BreadCrumb from "../breadcrumb/BreadCrumb";
import ProfileSidebar from "./ProfileSidebar";
import AuthGate from "@/components/auth/AuthGate";
import { setCurrentUser } from "@/redux/slices/userSlice";
import * as api from "@/api/apiRoutes";

// Persistent layout shell for profile dashboard routes
const ProfileShellInner = ({ children }: { children: React.ReactNode }) => {
  const dispatch = useDispatch();
  const pathname = usePathname();
  const city = useSelector((state: any) => state.City.city);
  const [selectedTab, setSelectedTab] = useState("profile");

  useEffect(() => {
    const currentTab = (pathname || "").split("/").pop();
    // eslint-disable-next-line react-hooks/set-state-in-effect -- syncs selected tab from route pathname
    setSelectedTab(currentTab || "profile");
  }, [pathname]);

  const getCurrentUser = useCallback(async () => {
    try {
      const response = await api.getUser({
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      dispatch(setCurrentUser({ data: response.data }));
    } catch (error) {
      console.log("error", error);
    }
  }, [city, dispatch]);

  // Prevents duplicate user fetch in StrictMode
  const fetchedUserRef = useRef(false);

  useEffect(() => {
    if (fetchedUserRef.current) return;
    fetchedUserRef.current = true;
    getCurrentUser();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <section>
      <BreadCrumb />
      <div className="container">
        <div className="flex flex-col md:flex-row gap-4 lg:gap-6 mb-5 md:mb-10 mt-2 md:mt-4">
          <div className="hidden md:block w-[230px] lg:w-[300px] xl:w-[340px] shrink-0">
            <ProfileSidebar
              setSelectedTab={setSelectedTab}
              selectedTab={selectedTab}
            />
          </div>

          {/* Profile route content container */}
          <div className="flex-1 min-w-0">{children}</div>
        </div>
      </div>
    </section>
  );
};

const ProfileShell = ({
  children,
}: {
  children: React.ReactNode;
}): React.JSX.Element => (
  <AuthGate requireAuth>
    <ProfileShellInner>{children}</ProfileShellInner>
  </AuthGate>
);

export default ProfileShell;
