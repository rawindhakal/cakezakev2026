import { MdOutlineCelebration } from "react-icons/md";
import { RiWallet3Line } from "react-icons/ri";
import { t } from "@/utils/translation";

export const SavingsBanner = ({ amountText }: { amountText: string }) => (
  <div className="relative flex items-center gap-3 overflow-hidden rounded-xl border border-emerald-200 bg-gradient-to-r from-emerald-50 via-green-50 to-teal-50 px-3.5 py-2.5 dark:border-emerald-500/25 dark:from-emerald-500/10 dark:via-green-500/10 dark:to-teal-500/10">
    <span className="savings-shine pointer-events-none absolute inset-y-0 left-0 w-1/4 bg-gradient-to-r from-transparent via-white/60 to-transparent dark:via-white/15" />
    <span className="absolute inset-y-0 left-0 w-1 bg-emerald-500" />
    <span className="relative flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-emerald-500/15 text-emerald-600 dark:text-emerald-400">
      <MdOutlineCelebration size={18} />
    </span>
    <p className="relative min-w-0 flex-grow text-sm font-semibold text-emerald-700 dark:text-emerald-300">
      {t("you_saved")} <span className="font-extrabold">{amountText}</span>{" "}
      <span className="font-normal text-emerald-600/80 dark:text-emerald-400/70">
        {t("you_saved_on_this_order")}
      </span>
    </p>
  </div>
);

// Cashback credited to the wallet after the order.
export const CashbackBanner = ({ amountText }: { amountText: string }) => (
  <div className="flex items-center gap-2.5 rounded-xl bg-amber-500/[0.08] px-3 py-2.5">
    <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-amber-500/15 text-amber-600 dark:text-amber-400">
      <RiWallet3Line size={18} />
    </span>
    <div className="min-w-0 flex-grow">
      <p className="text-sm font-bold text-amber-700 dark:text-amber-400">
        {t("you_will_earn_cashback")} {amountText}
      </p>
      <p className="text-[11px] text-amber-700/80 dark:text-amber-400/80">
        {t("cashback_added_to_wallet")}
      </p>
    </div>
  </div>
);

export const WalletCoversBanner = () => (
  <div className="relative flex items-center gap-3.5 overflow-hidden rounded-2xl border border-emerald-500/30 bg-gradient-to-r from-emerald-500/10 via-teal-500/10 to-emerald-500/15 p-3.5 shadow-sm dark:border-emerald-500/30 dark:from-emerald-500/15 dark:via-teal-500/15 dark:to-emerald-500/20">
    <span className="absolute inset-y-0 left-0 w-1.5 bg-gradient-to-b from-emerald-400 to-teal-600 rounded-l-2xl" />
    <div className="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 text-white shadow-md shadow-emerald-500/20">
      <RiWallet3Line size={20} />
    </div>
    <div className="flex flex-col min-w-0">
      <p className="text-sm font-bold text-emerald-900 dark:text-emerald-200 leading-tight">
        {t("wallet_covers_full_order") || "Your wallet balance covers the full order amount."}
      </p>
      <p className="text-xs font-medium text-emerald-700/80 dark:text-emerald-300/80 leading-snug mt-0.5">
        {t("wallet_covers_full_subtext") || "No additional payment method is required."}
      </p>
    </div>
  </div>
);
