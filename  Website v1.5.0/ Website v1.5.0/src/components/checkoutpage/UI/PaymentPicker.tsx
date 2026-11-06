"use client";
import { FiCreditCard, FiChevronLeft, FiChevronRight } from "react-icons/fi";
import { CiWallet } from "react-icons/ci";
import { RiCloseFill } from "react-icons/ri";
import {
  Dialog as DialogRaw,
  DialogContent as DialogContentRaw,
} from "@/components/ui/dialog";
import { t } from "@/utils/translation";
import { isRtl } from "@/lib/utils";
import PayPickRow from "./PayPickRow";
import { payMethodIcon } from "./paymentMethods";

// Dialog exports are loosely typed; cast to any.
const Dialog = DialogRaw as any;
const DialogContent = DialogContentRaw as any;

export interface PaymentOption {
  value: string;
  label: string;
}

interface PaymentMethodButtonProps {
  selected?: PaymentOption;
  onClick: () => void;
}

// Summary-card button that opens the picker.
export const PaymentMethodButton = ({ selected, onClick }: PaymentMethodButtonProps) => {
  const rtl = isRtl();
  const Chevron = rtl ? FiChevronLeft : FiChevronRight;
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex w-full items-center gap-3 rounded-xl border p-3 md:p-3.5 text-left transition ${
        selected
          ? "primaryColorBorder primaryLightBack dark:border-white dark:bg-white/5"
          : "border-dashed cardBorder hover:primaryColorBorder"
      }`}
    >
      <span
        key={selected?.value ?? "none"}
        className={`w-9 h-9 rounded-lg bg-white dark:bg-white/10 border cardBorder shadow-sm flex items-center justify-center shrink-0 primaryColor dark:text-white ${selected ? "ckAnimCheckPop" : ""}`}
      >
        {selected ? payMethodIcon(selected.value) : <FiCreditCard size={18} />}
      </span>
      <span className="flex flex-col min-w-0 flex-1">
        <span className="text-[11px] font-medium uppercase tracking-wide SecondaryTextColor leading-tight">
          {t("payment_method")}
        </span>
        <span className="font-semibold text-sm md:text-[15px] textColor capitalize truncate">
          {selected
            ? selected.label
            : t("select_payment_method") || "Select Payment Method"}
        </span>
      </span>
      {selected && (
        <span className="text-xs font-semibold primaryColor dark:text-white shrink-0">
          {t("change") || "Change"}
        </span>
      )}
      <Chevron size={18} className="SecondaryTextColor shrink-0" />
    </button>
  );
};

interface PaymentPickerDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  overlayClassName: string;
  options: PaymentOption[];
  selectedValue?: string;
  onPick: (value: string) => void;
  codHeading: string;
  /** null hides the wallet toggle. */
  walletBalanceText: string | null;
  walletChecked: boolean;
  onWalletToggle: () => void;
}

const groupHeadingClass =
  "px-1.5 text-[10px] font-bold uppercase tracking-[0.08em] SecondaryTextColor";

// Grouped picker: cash, wallet, online gateways.
export const PaymentPickerDialog = ({
  open,
  onOpenChange,
  overlayClassName,
  options,
  selectedValue,
  onPick,
  codHeading,
  walletBalanceText,
  walletChecked,
  onWalletToggle,
}: PaymentPickerDialogProps) => {
  const cod = options.filter((o) => o.value === "COD");
  const online = options.filter((o) => o.value !== "COD");
  const renderRows = (list: PaymentOption[]) =>
    list.map((opt) => (
      <PayPickRow
        key={opt.value}
        opt={opt}
        active={selectedValue === opt.value}
        onPick={() => onPick(opt.value)}
      />
    ));

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        sheetOnMobile
        overlayClassName={overlayClassName}
        className="p-0 overflow-hidden md:max-w-md md:rounded-3xl"
        title={t("select_payment_method")}
      >
        {/* Grab handle — only the mobile sheet shows one. */}
        <span className="mx-auto mt-2 h-1 w-10 shrink-0 rounded-full bg-gray-300 dark:bg-zinc-600 md:hidden" />
        <button
          type="button"
          onClick={() => onOpenChange(false)}
          aria-label={t("close") || "Close"}
          className="absolute top-3 right-3 z-10 md:top-4 md:right-4 flex h-9 w-9 items-center justify-center rounded-full SecondaryTextColor hover:backgroundColor transition"
        >
          <RiCloseFill size={20} />
        </button>

        <div className="flex items-center gap-3 px-4 pt-3 pb-3 pr-14 md:px-5 md:pt-5">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl primaryLightBack primaryColor dark:text-white">
            <FiCreditCard size={19} />
          </span>
          <div className="min-w-0">
            <h2 className="font-bold text-base md:text-lg leading-tight">
              {t("payment_method")}
            </h2>
            <p className="text-xs SecondaryTextColor mt-0.5">
              {t("select_payment_method") || "Choose how to pay"}
            </p>
          </div>
        </div>

        <div className="max-h-[62vh] overflow-y-auto custom-scrollbar px-4 pb-[calc(1rem+env(safe-area-inset-bottom))] pt-1 flex flex-col gap-3 md:pb-4">
          {cod.length > 0 && (
            <div className="flex flex-col gap-2">
              <p className={groupHeadingClass}>{codHeading}</p>
              {renderRows(cod)}
            </div>
          )}

          {walletBalanceText != null && (
            <div className="flex flex-col gap-2">
              <p className={groupHeadingClass}>{t("walletBalance")}</p>
              <div className="flex items-center justify-between gap-3 rounded-2xl border cardBorder p-3.5">
                <div className="flex items-center gap-3.5 min-w-0">
                  <span className="w-11 h-11 rounded-xl iconBackgroundColor primaryColor dark:text-white flex items-center justify-center shrink-0">
                    <CiWallet size={20} />
                  </span>
                  <div className="flex flex-col min-w-0">
                    <p className="font-semibold text-sm md:text-[15px] truncate">
                      {t("use_wallet_balance")}
                    </p>
                    <p className="text-xs SecondaryTextColor">{walletBalanceText}</p>
                  </div>
                </div>
                <button
                  type="button"
                  role="switch"
                  aria-checked={walletChecked}
                  onClick={onWalletToggle}
                  className={`relative w-11 h-6 rounded-lg shrink-0 transition ${
                    walletChecked ? "primaryBackColor" : "iconBackgroundColor"
                  }`}
                >
                  <span
                    className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-lg bg-white dark:bg-zinc-900 transition-transform ${
                      walletChecked ? "translate-x-5" : ""
                    }`}
                  />
                </button>
              </div>
            </div>
          )}

          {online.length > 0 && (
            <div className="flex flex-col gap-2">
              <p className={groupHeadingClass}>{t("pay_online") || "Pay Online"}</p>
              {renderRows(online)}
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
};
