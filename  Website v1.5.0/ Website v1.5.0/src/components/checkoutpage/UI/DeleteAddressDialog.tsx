"use client";
import { LuTriangleAlert } from "react-icons/lu";
import {
  Dialog as DialogRaw,
  DialogContent as DialogContentRaw,
  DialogOverlay as DialogOverlayRaw,
} from "@/components/ui/dialog";
import { t } from "@/utils/translation";

// Dialog exports are loosely typed; cast to any.
const Dialog = DialogRaw as any;
const DialogContent = DialogContentRaw as any;
const DialogOverlay = DialogOverlayRaw as any;

interface DeleteAddressDialogProps {
  /** Formatted address being deleted; null = closed. */
  addressText: string | null;
  overlayClassName: string;
  deleting: boolean;
  onCancel: () => void;
  onConfirm: () => void;
}

const DeleteAddressDialog = ({
  addressText,
  overlayClassName,
  deleting,
  onCancel,
  onConfirm,
}: DeleteAddressDialogProps) => (
  <Dialog open={addressText != null}>
    <DialogOverlay className={overlayClassName} />
    <DialogContent
      className="max-w-sm rounded-2xl p-0 overflow-hidden"
      title={t("delete_address") || t("delete")}
    >
      <div className="flex flex-col items-center px-6 pt-8 pb-6 text-center">
        <div className="flex h-14 w-14 items-center justify-center rounded-full bg-red-100 dark:bg-red-500/15">
          <LuTriangleAlert size={28} className="text-red-600 dark:text-red-400" />
        </div>
        <h2 className="mt-4 text-lg font-bold text-gray-900 dark:text-gray-100">
          {t("delete_address") || t("delete")}
        </h2>
        <p className="mt-2 text-sm text-gray-500 dark:text-gray-400 leading-relaxed">
          {t("delete_address_confirm") ||
            "Are you sure you want to delete this address?"}
        </p>
        {addressText && (
          <p className="mt-3 w-full rounded-lg bg-gray-50 dark:bg-white/5 px-3 py-2 text-xs SecondaryTextColor line-clamp-2">
            {addressText}
          </p>
        )}
        <div className="mt-6 flex w-full gap-3">
          <button
            type="button"
            className="flex-1 rounded-xl border border-gray-200 dark:border-white/15 px-4 py-2.5 text-sm font-semibold text-gray-700 dark:text-gray-200 transition hover:bg-gray-50 dark:hover:bg-white/5 disabled:opacity-50"
            onClick={onCancel}
            disabled={deleting}
          >
            {t("cancel")}
          </button>
          <button
            type="button"
            className="flex-1 rounded-xl bg-red-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-red-700 active:scale-[0.98] disabled:opacity-60 disabled:active:scale-100"
            onClick={onConfirm}
            disabled={deleting}
          >
            {deleting ? `${t("delete")}…` : t("delete")}
          </button>
        </div>
      </div>
    </DialogContent>
  </Dialog>
);

export default DeleteAddressDialog;
