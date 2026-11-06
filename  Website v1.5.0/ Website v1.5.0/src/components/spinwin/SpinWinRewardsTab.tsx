"use client";

import React from "react";
import { useSelector } from "react-redux";
import { t } from "@/utils/translation";
import useIsHydrated from "@/hooks/useIsHydrated";
import SpinWinRewardsContent from "./SpinWinRewardsContent";

/**
 * Profile dashboard tab for viewing rewards history.
 */
const SpinWinRewardsTab = () => {
  const city = useSelector((state: any) => state.City);
  const isHydrated = useIsHydrated();
  const latitude = isHydrated ? city?.city?.latitude : undefined;
  const longitude = isHydrated ? city?.city?.longitude : undefined;

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-bold fontColor">
        {t("my_rewards") || "My Rewards"}
      </h1>
      <div className="overflow-hidden rounded-2xl">
        <SpinWinRewardsContent latitude={latitude} longitude={longitude} />
      </div>
    </div>
  );
};

export default SpinWinRewardsTab;
