"use client";

import React, { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { m, AnimatePresence } from "framer-motion";
import { useSelector } from "react-redux";
import { t } from "@/utils/translation";
import useIsHydrated from "@/hooks/useIsHydrated";
import useZoneHref from "@/hooks/useZoneHref";
import useCountdown from "@/hooks/useCountdown";
import useSpinSound from "@/hooks/useSpinSound";
import { useSpinWheel } from "@/hooks/useSpinWheel";
import { useSpinWheelRewards } from "@/hooks/useSpinWheelRewards";
import SpinWheel from "./SpinWheel";
import SpinWinStand from "./SpinWinStand";
import SpinWinBackPanel from "./SpinWinBackPanel";
import SpinCountdown from "./SpinCountdown";
import { FiClock } from "react-icons/fi";
import {
  RiCheckboxCircleFill,
  RiEmotionSadLine,
  RiFileCopyLine,
  RiRefreshLine,
  RiShoppingBag3Line,
  RiWallet3Line,
} from "react-icons/ri";
import { useRouter } from "next/navigation";
import { toast } from "react-toastify";
import useCurrency from "@/hooks/useCurrency";
import { formatCurrency } from "@/utils/helperFunction";
import type { SpinWheelSegment, SpinWheelSpinResult } from "@/types/spinWin";
import Image from "next/image";
import rewardGift from "@/assets/reward-gift.png";
import useLazyLottie from "@/hooks/useLazyLottie";

const Lottie = dynamic(() => import("lottie-react"), { ssr: false });
const Login = dynamic(() => import("../login/Login"), { ssr: false });

const SOFT_EASE = [0.22, 0.61, 0.36, 1] as const;
const softIn = (delay: number) => ({
  initial: { y: 12, opacity: 0 },
  animate: { y: 0, opacity: 1 },
  transition: { duration: 0.55, delay, ease: SOFT_EASE },
});

// Hexagon polygon clip-path for action buttons.
const HEX = "polygon(9% 0%, 91% 0%, 100% 50%, 91% 100%, 9% 100%, 0% 50%)";

interface SpinWinPanelProps {
  /** Callback fired before navigating to My Rewards page. */
  onNavigateAway?: () => void;
}

/**
 * Spin & Win interactive campaign panel.
 */
const SpinWinPanel = ({ onNavigateAway }: SpinWinPanelProps = {}) => {
  // 240KB of Lottie JSON — its own chunk, fetched after mount.
  const confettiFall = useLazyLottie(() => import("@/assets/confetti.json"));
  const user = useSelector((state: any) => state.User?.user);
  const city = useSelector((state: any) => state.City);
  const isHydrated = useIsHydrated();
  const latitude = isHydrated ? city?.city?.latitude : undefined;
  const longitude = isHydrated ? city?.city?.longitude : undefined;

  const { data, isLoading, isError, spin, spinning, refetch } = useSpinWheel({
    latitude,
    longitude,
    enabled: isHydrated,
  });

  // Rewards summary for user balance badge.
  const { summary: rewardsSummary } = useSpinWheelRewards({
    latitude,
    longitude,
    enabled: isHydrated && Boolean(user?.id),
  });

  const [showLogin, setShowLogin] = useState(false);
  const [spinToken, setSpinToken] = useState(0);
  const [selectedSegment, setSelectedSegment] = useState<SpinWheelSegment | null>(
    null,
  );
  const [spinJitter, setSpinJitter] = useState(0);
  const [spinResult, setSpinResult] = useState<SpinWheelSpinResult | null>(
    null,
  );
  const [showResult, setShowResult] = useState(false);
  const [wheelSpinning, setWheelSpinning] = useState(false);
  const [confettiToken, setConfettiToken] = useState(0);
  const [copied, setCopied] = useState(false);
  const zoneHref = useZoneHref();
  const router = useRouter();

  const { currency, decimals } = useCurrency();
  const isWin = spinResult?.result === "win";
  const promo = spinResult?.promo_code;
  const wallet = spinResult?.wallet;

  const norm = (s?: string) => s?.trim().toLowerCase().replace(/[.!]+$/, "");
  const resultMessage =
    norm(spinResult?.message) === norm(spinResult?.title)
      ? undefined
      : spinResult?.message;

  const handleCopyCode = () => {
    if (!promo?.promo_code) return;
    navigator.clipboard
      .writeText(promo.promo_code)
      .then(() => {
        setCopied(true);
        setTimeout(() => setCopied(false), 2200);
      })
      .catch(() => toast.error(t("something_went_wrong")));
  };

  const campaignTitle =
    data?.campaign?.name || t("spin_and_win") || "Spin & Win!";
  const titleSplitAt = campaignTitle.indexOf(" ");
  const titleLead =
    titleSplitAt === -1 ? campaignTitle : campaignTitle.slice(0, titleSplitAt);
  const titleRest =
    titleSplitAt === -1 ? "" : campaignTitle.slice(titleSplitAt + 1);

  const requiresLogin = data?.requires_login === 1 && !user?.id;
  const canSpin = Boolean(data?.spins?.can_spin) && !wheelSpinning && !spinning;
  const { playTick, playWin, playSpinSound, stopSpinSound } = useSpinSound();
  const outOfSpins = !requiresLogin && data?.spins?.can_spin === false;
  const nextSpinSeconds = data?.spins?.next_spin_in_seconds;

  // Absolute deadline latched per response so the countdown does not drift
  const [nextSpinDeadline, setNextSpinDeadline] = useState<string | null>(null);
  useEffect(() => {
    if (nextSpinSeconds == null) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- reads the wall clock, not derivable from render
      setNextSpinDeadline(data?.spins?.next_spin_at ?? null);
      return;
    }
    setNextSpinDeadline(
      new Date(Date.now() + nextSpinSeconds * 1000).toISOString(),
    );
  }, [nextSpinSeconds, data?.spins?.next_spin_at]);

  const nextSpinCountdown = useCountdown(
    outOfSpins ? nextSpinDeadline : null,
  );

  const handleSpin = async () => {
    if (requiresLogin) {
      setShowLogin(true);
      return;
    }
    if (!canSpin) {
      if (!data?.spins?.can_spin) {
        const reasonKey = data?.spins?.reason_key;
        toast.error(
          reasonKey === "spin_wheel_daily_limit_reached"
            ? t("daily_spin_limit_reached") ||
                "You've used today's spins — come back tomorrow"
            : reasonKey === "spin_wheel_no_spins_left"
              ? t("no_spins_left") || "No spins left"
              : reasonKey === "spin_wheel_order_required"
                ? t("spin_wheel_order_required") ||
                  "Place an order to unlock a spin"
                : data?.spins?.reason ||
                    t("spin_not_available_now") ||
                    "Spin isn't available right now",
          { toastId: "spin-win-blocked" }
        );
      }
      return;
    }
    try {
      const { segment, result } = await spin();
      setSelectedSegment(segment);
      setSpinResult(result);
      setSpinJitter(Math.random() - 0.5);
      setWheelSpinning(true);
      setSpinToken((tkn) => tkn + 1);
      playSpinSound();
    } catch {
      // API error handled globally.
    }
  };

  const handleSpinAnimationComplete = () => {
    setWheelSpinning(false);
    stopSpinSound();
    if (spinResult?.result === "win") {
      setConfettiToken((tkn) => tkn + 1);
      playWin();
      setTimeout(() => setShowResult(true), 250);
    } else {
      setShowResult(true);
    }
  };

  const handleSpinAgain = () => {
    setShowResult(false);
  };

  if (!isHydrated || isLoading) {
    return (
      <div className="flex items-center justify-center p-10">
        <span className="h-8 w-8 animate-spin rounded-full border-[3px] border-white/30 border-t-white" />
      </div>
    );
  }

  if (isError || !data) {
    return (
      <div className="flex flex-col items-center gap-3 p-10 text-center">
        <p className="text-sm font-medium text-white/80">
          {t("something_went_wrong") || "Something went wrong"}
        </p>
        <button
          type="button"
          onClick={() => refetch()}
          className="rounded-full primaryBackColor px-4 py-2 text-xs font-bold text-white"
        >
          {t("retry") || "Retry"}
        </button>
      </div>
    );
  }

  if (data.is_available !== 1) {
    return (
      <div className="flex flex-col items-center gap-2 p-10 text-center">
        <p className="text-sm font-medium text-white/80">
          {data.message || t("spin_win_unavailable") || "Spin & Win isn't available right now"}
        </p>
      </div>
    );
  }

  return (
    <div className="relative flex flex-col gap-4 lg:gap-6">
      {/* Confetti overlay */}
      {confettiToken > 0 && confettiFall && (
        <m.div
          key={confettiToken}
          className="pointer-events-none fixed inset-0 z-50 overflow-hidden"
          initial={{ opacity: 0 }}
          animate={{ opacity: [0, 1, 1, 0] }}
          transition={{
            duration: 4,
            times: [0, 0.04, 0.75, 1],
            ease: "easeInOut",
          }}
        >
          <Lottie
            className="h-full w-full"
            animationData={confettiFall}
            loop={false}
            rendererSettings={{ preserveAspectRatio: "xMidYMid slice" }}
          />
        </m.div>
      )}

      <div className="relative z-10 flex justify-center">
        <div
          className="relative mx-auto flex w-full flex-col items-center justify-center gap-3.5 rounded-[32px] p-5"
          style={{
            maxWidth: "min(560px, 92vw)",
            ...(data.campaign?.theme?.bg_color
              ? ({
                  "--primary-color": data.campaign.theme.bg_color,
                } as React.CSSProperties)
              : {}),
          }}
        >
          <AnimatePresence mode="wait">
          {!showResult && (
            <m.div
              key="wheel"
              className="relative z-10 flex w-full flex-col items-center gap-7"
              initial={{ opacity: 0, scale: 0.96 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.96 }}
              transition={{ duration: 0.4, ease: SOFT_EASE }}
            >
              {/* Header title */}
              <div className="flex flex-col items-center gap-1.5 px-5 text-center">
                <h2 className="spinTitle">
                  <span
                    className="spinTitle__lead block"
                    style={
                      data.campaign?.theme?.title_color
                        ? ({
                            color: `color-mix(in srgb, ${data.campaign.theme.title_color} 35%, #fff)`,
                            "--spinTitle-border-color":
                              data.campaign.theme.title_color,
                          } as React.CSSProperties)
                        : undefined
                    }
                  >
                    {titleLead}
                  </span>
                  {titleRest && (
                    <span
                      className="spinTitle__rest block"
                      style={(() => {
                        const c =
                          data.campaign?.theme?.title_color_2 ||
                          data.campaign?.theme?.title_color;
                        return c
                          ? ({
                              color: `color-mix(in srgb, ${c} 35%, #fff)`,
                              "--spinTitle-border-color": c,
                            } as React.CSSProperties)
                          : undefined;
                      })()}
                    >
                      {titleRest}
                    </span>
                  )}
                </h2>
                {outOfSpins &&
                  (nextSpinCountdown?.finished ||
                    (!nextSpinCountdown && data.spins?.next_spin_at_label)) && (
                    <p className="mt-1 inline-flex items-center gap-1.5 rounded-full bg-black/25 px-2.5 py-1 text-[11px] font-bold text-white tabular-nums [text-shadow:0_1px_2px_rgba(0,0,0,0.5)]">
                      <FiClock size={12} />
                      {nextSpinCountdown?.finished
                        ? t("spin_available_now") || "Spin available — refresh"
                        : `${t("next_spin_at") || "Next spin"}: ${data.spins?.next_spin_at_label}`}
                    </p>
                  )}
              </div>

              {/* Wheel & Stand assembly */}
              <div className="relative flex w-full flex-col items-center">
                <SpinWinBackPanel roundedAll={false} width="72%" />

                <div className="relative z-10 w-[80%]">
                  <SpinWheel
                    segments={data.segments}
                    selectedSegment={selectedSegment}
                    jitter={spinJitter}
                    spinning={wheelSpinning}
                    spinToken={spinToken}
                    onSpinComplete={handleSpinAnimationComplete}
                    canSpin={requiresLogin || canSpin}
                    theme={data.campaign?.theme}
                    onTick={playTick}
                  />
                </div>

                <div className="relative w-[80%]">
                  <SpinWinStand
                    onSpin={handleSpin}
                    canSpin={requiresLogin || canSpin}
                    disabled={wheelSpinning || spinning}
                    spinning={wheelSpinning}
                    label={
                      data.campaign?.theme?.button_text?.slice(0, 12) ||
                      t("spin") ||
                      "Spin"
                    }
                    buttonColor={data.campaign?.theme?.button_color}
                    buttonTextColor={data.campaign?.theme?.button_text_color}
                    lightColor={data.campaign?.theme?.light_color}
                    countdown={
                      outOfSpins &&
                      nextSpinCountdown &&
                      !nextSpinCountdown.finished ? (
                        <SpinCountdown countdown={nextSpinCountdown} compact />
                      ) : null
                    }
                  />
                </div>
              </div>

              {/* User rewards balance button */}
              {user?.id && (
                <button
                  type="button"
                  onClick={() => {
                    onNavigateAway?.();
                    router.push("/profile/spin-win-rewards");
                  }}
                  className="group relative z-10 mt-2 flex flex-col items-center transition active:scale-[0.97]"
                >
                  <span
                    className="relative z-[1] -mb-[11px] flex h-[34px] w-[34px] items-center justify-center rounded-full p-[3px] transition group-hover:brightness-110"
                    style={{
                      background:
                        "linear-gradient(180deg, color-mix(in srgb, var(--primary-color) 55%, #fff) 0%, var(--primary-color) 55%, color-mix(in srgb, var(--primary-color) 70%, #0A0A0A) 100%)",
                      boxShadow:
                        "0 3px 8px rgba(0,0,0,0.6), inset 0 1px 0 rgba(255,255,255,0.7)",
                    }}
                  >
                    <span
                      className="flex h-full w-full items-center justify-center rounded-full text-[15px] font-black leading-none"
                      style={{
                        background:
                          "radial-gradient(circle at 34% 28%, color-mix(in srgb, var(--primary-color) 12%, #fff) 0%, color-mix(in srgb, var(--primary-color) 38%, #fff) 42%, color-mix(in srgb, var(--primary-color) 82%, #fff) 78%, var(--primary-color) 100%)",
                        boxShadow:
                          "inset 0 -2px 4px rgba(0,0,0,0.35), inset 0 2px 3px rgba(255,255,255,0.55)",
                        color:
                          "color-mix(in srgb, var(--primary-color) 55%, #0A0A0A)",
                      }}
                    >
                      {currency}
                    </span>
                  </span>
                  <span
                    className="relative z-0 rounded-full px-4 pb-1 pt-[13px] text-[15px] font-extrabold tabular-nums leading-none text-white"
                    style={{
                      background:
                        "linear-gradient(180deg, color-mix(in srgb, var(--primary-color) 14%, #0A0A0A) 0%, color-mix(in srgb, var(--primary-color) 8%, #060606) 100%)",
                      boxShadow:
                        "0 0 0 2px var(--primary-color), 0 0 20px -2px color-mix(in srgb, var(--primary-color) 70%, transparent), 0 6px 14px rgba(0,0,0,0.55)",
                    }}
                  >
                    {formatCurrency(
                      Number(rewardsSummary?.wallet_won || 0),
                      currency,
                      decimals,
                    )}
                  </span>
                  <span className="mt-1.5 text-[10px] font-bold uppercase tracking-[0.12em] text-white/70">
                    {t("my_rewards") || "My Rewards"}
                  </span>
                </button>
              )}
            </m.div>
          )}

          {/* Spin result view */}
            {showResult && (
              <m.div
                key="result"
                className="relative z-10 w-full max-w-[340px] rounded-[30px] p-[3px] text-center"
                style={{
                  background:
                    "linear-gradient(#0a0909, #0a0909) padding-box, linear-gradient(180deg, color-mix(in srgb, var(--primary-color) 95%, #fff) 0%, var(--primary-color) 45%, color-mix(in srgb, var(--primary-color) 80%, #000) 100%) border-box",
                  border: "4px solid transparent",
                  boxShadow: "0 30px 60px rgba(0,0,0,0.55)",
                  transformStyle: "preserve-3d",
                  transformPerspective: 900,
                }}
                initial={{ scale: 0.9, y: 40, opacity: 0, rotateX: 12 }}
                animate={{ scale: 1, y: 0, opacity: 1, rotateX: 0 }}
                exit={{ scale: 0.96, y: 12, opacity: 0 }}
                transition={{ duration: 0.62, ease: SOFT_EASE }}
              >
                {/* Extruded card depth */}
                <span
                  aria-hidden
                  className="pointer-events-none absolute inset-x-1 -bottom-[14px] top-3 rounded-[30px]"
                  style={{
                    background:
                      "linear-gradient(180deg, color-mix(in srgb, var(--primary-color) 45%, #141414), color-mix(in srgb, var(--primary-color) 60%, #181818) 88%, color-mix(in srgb, var(--primary-color) 70%, #1C1C1C))",
                    transform: "translateZ(-26px)",
                  }}
                />

                {/* Card face */}
                <div
                  className="relative rounded-[26px] p-2"
                  style={{
                    background:
                      "linear-gradient(180deg, color-mix(in srgb, var(--primary-color) 38%, #0E0E0E) 0%, color-mix(in srgb, var(--primary-color) 52%, #121212) 40%, color-mix(in srgb, var(--primary-color) 70%, #191919) 72%, color-mix(in srgb, var(--primary-color) 88%, #191919) 100%)",
                    boxShadow:
                      "inset 0 0 0 2px color-mix(in srgb, var(--primary-color) 30%, transparent), inset 0 -8px 0 color-mix(in srgb, var(--primary-color) 18%, transparent)",
                  }}
                >
                {/* Inner panel */}
                <div
                  className="relative rounded-[22px] px-1 pb-1"
                  style={{
                    background:
                      "linear-gradient(180deg, color-mix(in srgb, var(--primary-color) 34%, #151515), color-mix(in srgb, var(--primary-color) 52%, #1A1A1A))",
                    boxShadow: [
                      "inset 0 8px 14px -6px rgba(0,0,0,0.75)",
                      "inset 0 1px 0 rgba(0,0,0,0.6)",
                      "inset 0 -2px 0 color-mix(in srgb, var(--primary-color) 85%, #fff)",
                      "inset 0 -16px 22px -14px color-mix(in srgb, var(--primary-color) 75%, #000)",
                    ].join(", "),
                  }}
                >
                {/* Win background glow */}
                {isWin && (
                  <span
                    aria-hidden
                    className="pointer-events-none absolute inset-0 overflow-hidden rounded-[26px]"
                  >
                    <span
                      className="absolute inset-x-0 top-0 h-56"
                      style={{
                        background:
                          "linear-gradient(180deg, color-mix(in srgb, var(--primary-color) 26%, transparent), transparent)",
                      }}
                    />
                    <span
                      className="absolute -left-10 -top-8 h-36 w-36 rounded-full blur-2xl"
                      style={{
                        background:
                          "color-mix(in srgb, var(--primary-color) 38%, transparent)",
                      }}
                    />
                    <span
                      className="absolute -right-12 top-10 h-40 w-40 rounded-full blur-2xl"
                      style={{
                        background:
                          "color-mix(in srgb, var(--primary-color) 28%, transparent)",
                      }}
                    />
                  </span>
                )}

                {/* Hero icon illustration */}
                <div
                  className={
                    isWin
                      ? "relative z-10 flex h-[150px] items-center justify-center overflow-hidden"
                      : "relative z-10 flex h-[104px] items-end justify-center overflow-hidden"
                  }
                >
                  <m.div
                    className="flex h-full w-full items-center justify-center"
                    initial={{ scale: 0.82, opacity: 0 }}
                    animate={{ scale: 1, opacity: 1 }}
                    transition={{ duration: 0.7, delay: 0.08, ease: SOFT_EASE }}
                  >
                    {isWin ? (
                      selectedSegment?.icon_url ? (
                        <Image
                          src={selectedSegment.icon_url}
                          alt=""
                          width={230}
                          height={150}
                          priority
                          unoptimized
                          className="h-auto max-h-[130px] w-auto max-w-[180px] object-contain"
                        />
                      ) : (
                        <Image
                          src={rewardGift}
                          alt=""
                          priority
                          className="h-auto w-[230px] object-contain"
                        />
                      )
                    ) : selectedSegment?.icon_url ? (
                      <Image
                        src={selectedSegment.icon_url}
                        alt=""
                        width={230}
                        height={150}
                        priority
                        unoptimized
                        className="h-auto max-h-[130px] w-auto max-w-[180px] object-contain"
                      />
                    ) : (
                      <span className="flex h-[72px] w-[72px] items-center justify-center rounded-full bg-white/[0.08]">
                        <RiEmotionSadLine size={34} className="text-white/55" />
                      </span>
                    )}
                  </m.div>
                </div>

                <div className="relative z-10 px-6 pb-6">
                  {/* Header text */}
                  <m.div
                    className="flex items-center justify-center gap-2.5"
                    {...softIn(0.22)}
                  >
                    <span className="h-px w-5 bg-white/25" />
                    <span className="text-[11px] font-bold uppercase tracking-[0.16em] text-white/60">
                      {isWin ? t("you_won") || "YOU WON" : t("oh_no") || "OH NO"}
                    </span>
                    <span className="h-px w-5 bg-white/25" />
                  </m.div>

                  <m.h2
                    className="mt-2 text-[27px] font-extrabold leading-tight tracking-[-0.02em] text-white"
                    {...softIn(0.3)}
                  >
                    {spinResult?.title ||
                      (isWin
                        ? t("congratulations") || "Congratulations!"
                        : t("better_luck_next_time") || "Better luck next time")}
                  </m.h2>

                  <m.p
                    className="mx-auto mt-1.5 max-w-[250px] text-[13px] leading-snug text-white/65"
                    {...softIn(0.36)}
                  >
                    {resultMessage ||
                      (isWin
                        ? t("reward_added_automatically") ||
                          "Added to your account automatically."
                        : t("better_luck_next_time_detail") ||
                          "No reward this time — come back and try again soon.")}
                  </m.p>

                  {/* Wallet prize display */}
                  {isWin && wallet && wallet.amount > 0 && (
                    <m.div
                      className="relative mt-4 overflow-hidden rounded-[14px] px-4 py-4"
                      style={{
                        background:
                          "linear-gradient(180deg, rgba(255,255,255,0.92), rgba(255,255,255,0.82))",
                        backdropFilter: "blur(18px)",
                        WebkitBackdropFilter: "blur(18px)",
                        boxShadow: [
                          "inset 0 1px 0 rgba(255,255,255,0.9)",
                          "inset 0 0 0 1px rgba(255,255,255,0.5)",
                          "0 10px 24px -8px rgba(0,0,0,0.45)",
                          "0 2px 6px rgba(0,0,0,0.25)",
                        ].join(", "),
                      }}
                      {...softIn(0.42)}
                    >
                      <span
                        aria-hidden
                        className="absolute -left-[13px] top-1/2 h-[26px] w-[26px] -translate-y-1/2 rounded-full"
                        style={{
                          background:
                            "color-mix(in srgb, var(--primary-color) 30%, #1A1A1A)",
                          backdropFilter: "blur(6px)",
                          WebkitBackdropFilter: "blur(6px)",
                        }}
                      />
                      <span
                        aria-hidden
                        className="absolute -right-[13px] top-1/2 h-[26px] w-[26px] -translate-y-1/2 rounded-full"
                        style={{
                          background:
                            "color-mix(in srgb, var(--primary-color) 30%, #1A1A1A)",
                          backdropFilter: "blur(6px)",
                          WebkitBackdropFilter: "blur(6px)",
                        }}
                      />
                      <p
                        className="text-[32px] font-black leading-none"
                        style={{ color: "var(--primary-color)" }}
                      >
                        +{formatCurrency(wallet.amount, currency, decimals)}
                      </p>
                      <p className="mt-2 flex items-center justify-center gap-1.5 text-[11.5px] font-semibold text-[#3C3C3C]">
                        <RiWallet3Line size={13} />
                        {t("cashback_added_to_wallet_instant") ||
                          "Added to your wallet instantly"}
                      </p>
                    </m.div>
                  )}

                  {/* Promo code prize card */}
                  {isWin && promo && (
                    <m.div className="mt-4" {...softIn(0.42)}>
                      <button
                        type="button"
                        onClick={handleCopyCode}
                        className="group relative block w-full rounded-[18px] px-5 py-3 text-center transition active:translate-y-[1px]"
                        style={{
                          background:
                            "color-mix(in srgb, var(--primary-color) 22%, rgba(0,0,0,0.55))",
                          backdropFilter: "blur(12px)",
                          WebkitBackdropFilter: "blur(12px)",
                          boxShadow: [
                            "inset 0 0 0 1px rgba(255,255,255,0.18)",
                            "inset 0 1px 0 rgba(255,255,255,0.14)",
                            "0 8px 20px -10px rgba(0,0,0,0.5)",
                          ].join(", "),
                        }}
                      >
                        <span className="block transition-opacity group-hover:opacity-0 group-focus-visible:opacity-0">
                          <span className="block text-[10px] font-bold uppercase tracking-[0.2em] text-white/55">
                            {t("couponCode") || t("coupon_code") || "Coupon Code"}
                          </span>
                          <span className="mt-1 block break-all text-[21px] font-black uppercase leading-[1.15] tracking-[0.06em] text-white">
                            {promo.promo_code}
                          </span>
                        </span>

                        <span className="pointer-events-none absolute inset-0 flex items-center justify-center gap-2 text-[13px] font-bold uppercase tracking-[0.12em] text-white opacity-0 transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100">
                          <RiFileCopyLine size={16} />
                          {t("copy_code") || t("copy") || "Copy"}
                        </span>
                      </button>

                      <AnimatePresence>
                        {copied && (
                          <m.div
                            className="flex justify-center overflow-hidden"
                            initial={{ height: 0, opacity: 0 }}
                            animate={{ height: "auto", opacity: 1 }}
                            exit={{ height: 0, opacity: 0 }}
                            transition={{ duration: 0.28, ease: SOFT_EASE }}
                          >
                            <span
                              className="mt-2 inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-[11.5px] font-bold text-white"
                              style={{
                                background: "rgba(0,0,0,0.3)",
                                boxShadow:
                                  "inset 0 0 0 1px color-mix(in srgb, var(--primary-color) 45%, #fff)",
                              }}
                            >
                              <RiCheckboxCircleFill size={13} />
                              {t("copied_to_clipboard") || "Copied to clipboard!"}
                            </span>
                          </m.div>
                        )}
                      </AnimatePresence>
                    </m.div>
                  )}

                  {/* Remaining spins notice */}
                  {!isWin && data.spins?.spins_per_day > 0 && (
                    <m.div className="mt-3" {...softIn(0.5)}>
                      {!data.spins.can_spin &&
                      nextSpinCountdown &&
                      !nextSpinCountdown.finished ? (
                        <SpinCountdown countdown={nextSpinCountdown} compact />
                      ) : (
                        <p
                          className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-[11.5px] font-bold text-white"
                          style={{
                            background: "rgba(0,0,0,0.3)",
                            boxShadow:
                              "inset 0 0 0 1px color-mix(in srgb, var(--primary-color) 45%, #fff)",
                          }}
                        >
                          <FiClock size={12} />
                          {data.spins.can_spin
                            ? `${data.spins.remaining_today} ${t("spins_left") || "spins left"}`
                            : nextSpinCountdown?.finished
                              ? t("spin_available_now") ||
                                "Spin available — refresh"
                              : t("no_spins_left") || "No spins left today"}
                        </p>
                      )}
                    </m.div>
                  )}

                  {/* Action buttons */}
                  <m.div
                    className="relative z-20 mx-auto -mb-[50px] mt-5 flex w-full gap-2"
                    {...softIn(0.54)}
                  >
                    {(() => {
                      const canSpinAgain = Boolean(data.spins?.can_spin);
                      return (
                      <button
                        type="button"
                        onClick={
                          canSpinAgain
                            ? handleSpinAgain
                            : () => {
                                onNavigateAway?.();
                                router.push(zoneHref("/products"));
                              }
                        }
                        className="group relative flex flex-1 transition active:scale-[0.985] [filter:drop-shadow(0_5px_5px_rgba(0,0,0,0.5))]"
                        style={{
                          clipPath: HEX,
                          background:
                            "linear-gradient(180deg, color-mix(in srgb, var(--primary-color) 45%, #fff), var(--primary-color))",
                        }}
                      >
                        <span
                          className="flex flex-1 items-center justify-center gap-2 py-3 whitespace-nowrap text-[13px] font-bold text-white transition group-hover:brightness-125"
                          style={{
                            clipPath: HEX,
                            margin: "3px 8px",
                            background:
                              "color-mix(in srgb, var(--primary-color) 18%, #0B0B0B)",
                          }}
                        >
                          {canSpinAgain ? (
                            <>
                              <RiRefreshLine size={16} />
                              {t("spin_again") || "Spin Again"}
                            </>
                          ) : (
                            <>
                              <RiShoppingBag3Line size={16} />
                              {t("shop_now") || "Shop Now"}
                            </>
                          )}
                        </span>
                      </button>
                      );
                    })()}
                  </m.div>
                </div>
                </div>
                </div>
              </m.div>
            )}
          </AnimatePresence>
        </div>
      </div>

      <Login
        showLogin={showLogin}
        setShowLogin={setShowLogin}
        setMobileActiveKey={() => {}}
      />
    </div>
  );
};

export default SpinWinPanel;
