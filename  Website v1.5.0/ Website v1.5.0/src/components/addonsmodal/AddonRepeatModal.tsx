import {
  Dialog as DialogRaw,
  DialogContent as DialogContentRaw,
} from "@/components/ui/dialog";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";
import { RiCloseFill } from "react-icons/ri";
import { FiPlus } from "react-icons/fi";
import { t } from "@/utils/translation";
import useCurrency from "@/hooks/useCurrency";
import useHydratedMediaQuery from "@/hooks/useHydratedMediaQuery";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import { addonSummary } from "@/utils/addons";

const Dialog = DialogRaw as any;
const DialogContent = DialogContentRaw as any;

interface AddonRepeatModalProps {
  open: boolean;
  setOpen: (open: boolean) => void;
  product: any;
  /** The line whose picks "repeat" would reuse — the last one added. */
  lastLine: any;
  onRepeat: () => void;
  onAddNew: () => void;
}

// Asked before a second helping of a customisable dish: reuse the last picks,
// or answer the questions again. Mirrors the food-app convention.
const AddonRepeatModal = ({
  open,
  setOpen,
  product,
  lastLine,
  onRepeat,
  onAddNew,
}: AddonRepeatModalProps) => {
  const isMobile = useHydratedMediaQuery("(max-width: 767px)") === true;
  const { currency: liveCurrency } = useCurrency();
  const currency = product?.currency || liveCurrency;

  const summary = addonSummary(lastLine);
  const name =
    product?.translations?.name ?? product?.product_name ?? product?.name;
  const image =
    product?.image_url ??
    product?.images?.[0]?.image_url ??
    product?.variants?.[0]?.image;

  // What the remembered picks add on top of the dish, per unit.
  const extra = (lastLine?.addons ?? []).reduce(
    (total: number, addon: any) => total + (Number(addon?.line_price) || 0),
    0,
  );

  const header = (
    <div className="px-4 pb-3 pt-4 pe-12 md:px-6 md:pe-14">
      <div className="min-w-0">
        <div className="text-base font-bold textColor">
          {t("addon_repeat_title")}
        </div>
        <div className="mt-0.5 text-xs text-gray-500">
          {t("addon_repeat_subtitle")}
        </div>
      </div>
    </div>
  );

  const body = (
    <div className="px-4 pb-4 md:px-6">
      <div className="flex items-center gap-3 rounded-lg border border-gray-100 px-3 py-2.5 dark:border-zinc-800">
        <span className="h-11 w-11 shrink-0 overflow-hidden rounded-md border border-gray-100 bg-white dark:border-zinc-800">
          <ImageWithPlaceholder
            src={image}
            alt={name}
            width={88}
            height={88}
            className="h-full w-full object-contain"
          />
        </span>
        <div className="min-w-0 flex-1">
          <p className="line-clamp-1 text-sm font-semibold capitalize textColor">
            {name}
          </p>
          {summary && (
            <p className="mt-0.5 line-clamp-2 text-xs leading-snug text-gray-500">
              {summary}
            </p>
          )}
        </div>
        {extra > 0 && (
          <span className="shrink-0 text-sm font-bold primaryColor">
            +{currency}
            {extra}
          </span>
        )}
      </div>
    </div>
  );

  const footer = (
    <div className="flex shrink-0 items-center gap-3 border-t border-gray-100 bg-white px-4 py-4 dark:border-zinc-800 dark:bg-zinc-900 md:px-6">
      <button
        type="button"
        onClick={() => {
          setOpen(false);
          onAddNew();
        }}
        className="flex h-11 flex-1 items-center justify-center gap-1.5 rounded-lg border primaryColorBorder bg-white text-sm font-bold uppercase primaryColor transition hover:primaryLightBack dark:bg-zinc-900"
      >
        <FiPlus size={15} />
        {t("addon_add_new_short")}
      </button>
      <button
        type="button"
        onClick={() => {
          setOpen(false);
          onRepeat();
        }}
        className="h-11 flex-1 rounded-lg primaryBackColor text-sm font-bold uppercase text-white transition active:scale-95"
      >
        {t("addon_repeat_last")}
      </button>
    </div>
  );

  if (isMobile) {
    return (
      <Sheet open={open} onOpenChange={(next: boolean) => !next && setOpen(false)}>
        <SheetContent
          side="bottom"
          className="flex max-h-[85dvh] flex-col gap-0 overflow-hidden rounded-t-3xl border-0 bg-white p-0 dark:bg-zinc-900"
        >
          <div className="flex justify-center pt-2.5 pb-1">
            <span className="h-1 w-10 rounded-full bg-gray-300 dark:bg-zinc-700" />
          </div>
          <SheetTitle className="sr-only">{t("addon_repeat_title")}</SheetTitle>
          {header}
          {body}
          {footer}
        </SheetContent>
      </Sheet>
    );
  }

  return (
    <Dialog open={open} onOpenChange={(next: boolean) => !next && setOpen(false)}>
      <DialogContent
        className="flex max-w-md flex-col gap-0 overflow-hidden p-0"
        title={t("addon_repeat_title")}
      >
        <button
          type="button"
          aria-label={t("close")}
          onClick={() => setOpen(false)}
          className="absolute end-3 top-3 z-10 flex h-8 w-8 items-center justify-center rounded-full border border-gray-100 bg-white transition hover:primaryLightBack dark:border-zinc-800 dark:bg-zinc-900"
        >
          <RiCloseFill size={18} className="textColor" />
        </button>

        {header}
        {body}
        {footer}
      </DialogContent>
    </Dialog>
  );
};

export default AddonRepeatModal;
