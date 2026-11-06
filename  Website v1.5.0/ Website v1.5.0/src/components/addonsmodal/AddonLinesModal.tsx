import {
  Dialog as DialogRaw,
  DialogContent as DialogContentRaw,
} from "@/components/ui/dialog";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";
import { RiCloseFill } from "react-icons/ri";
import { FiMinus, FiPlus } from "react-icons/fi";
import { t } from "@/utils/translation";
import useCurrency from "@/hooks/useCurrency";
import useHydratedMediaQuery from "@/hooks/useHydratedMediaQuery";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import { addonSummary } from "@/utils/addons";

const Dialog = DialogRaw as any;
const DialogContent = DialogContentRaw as any;

interface AddonLinesModalProps {
  open: boolean;
  setOpen: (open: boolean) => void;
  product: any;
  /** Every cart line of this product, each with its own picks. */
  lines: any[];
  onRemoveLine: (line: any) => void;
  onRepeatLine: (line: any) => void;
  onAddNew: () => void;
}

// A dish customised two ways sits in the cart as two lines, so a card stepper
// cannot say which one is meant. This lists them and steps each on its own.
const AddonLinesModal = ({
  open,
  setOpen,
  product,
  lines,
  onRemoveLine,
  onRepeatLine,
  onAddNew,
}: AddonLinesModalProps) => {
  const isMobile = useHydratedMediaQuery("(max-width: 767px)") === true;
  const { currency: liveCurrency } = useCurrency();
  const currency = product?.currency || liveCurrency;

  const name =
    product?.translations?.name ?? product?.product_name ?? product?.name;
  const image =
    product?.image_url ??
    product?.images?.[0]?.image_url ??
    product?.variants?.[0]?.image;

  // What this line's picks add on top of the dish, per unit.
  const addonExtra = (line: any) =>
    (line?.addons ?? []).reduce(
      (total: number, addon: any) => total + (Number(addon?.line_price) || 0),
      0,
    );

  const header = (
    <div className="px-4 pb-3 pt-4 pe-12 md:px-6 md:pe-14">
      <div className="min-w-0">
        <div className="text-base font-bold capitalize textColor">
          {t("addon_choose_line_title")}
        </div>
        <div className="mt-0.5 line-clamp-1 text-xs text-gray-500">{name}</div>
      </div>
    </div>
  );

  const body = (
    <div className="min-h-0 flex-1 overflow-y-auto custom-scrollbar px-4 pb-4 md:px-6">
      <div className="flex flex-col gap-2">
        {lines.map((line, index) => {
          const extra = addonExtra(line);
          return (
            <div
              key={`${line?.product_variant_id}-${index}`}
              className="flex items-center gap-3 rounded-lg border border-gray-100 px-3 py-2.5 dark:border-zinc-800"
            >
              <span className="h-10 w-10 shrink-0 overflow-hidden rounded-md border border-gray-100 bg-white dark:border-zinc-800">
                <ImageWithPlaceholder
                  src={image}
                  alt={name}
                  width={80}
                  height={80}
                  className="h-full w-full object-contain"
                />
              </span>

              <div className="min-w-0 flex-1">
                <p className="line-clamp-2 text-xs leading-snug textColor">
                  {addonSummary(line) || t("addon_no_customisation")}
                </p>
                {extra > 0 && (
                  <p className="mt-0.5 text-xs font-semibold primaryColor">
                    +{currency}
                    {extra}
                  </p>
                )}
              </div>

              <div className="flex shrink-0 items-center gap-2.5 rounded-lg border primaryColorBorder px-2 py-1">
                <button
                  type="button"
                  aria-label={t("decrease")}
                  onClick={() => onRemoveLine(line)}
                >
                  <FiMinus size={13} className="primaryColor" />
                </button>
                <span className="min-w-4 text-center text-sm font-bold primaryColor">
                  {line?.qty}
                </span>
                <button
                  type="button"
                  aria-label={t("increase")}
                  onClick={() => onRepeatLine(line)}
                >
                  <FiPlus size={13} className="primaryColor" />
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );

  const footer = (
    <div className="shrink-0 border-t border-gray-100 bg-white px-4 py-4 dark:border-zinc-800 dark:bg-zinc-900 md:px-6">
      <button
        type="button"
        onClick={() => {
          setOpen(false);
          onAddNew();
        }}
        className="flex h-11 w-full items-center justify-center gap-1.5 rounded-lg border primaryColorBorder bg-white text-sm font-bold uppercase primaryColor transition hover:primaryLightBack dark:bg-zinc-900"
      >
        <FiPlus size={15} />
        {t("addon_add_new")}
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
          <SheetTitle className="sr-only">
            {t("addon_choose_line_title")}
          </SheetTitle>
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
        className="flex max-h-[85vh] max-w-md flex-col gap-0 overflow-hidden p-0"
        title={t("addon_choose_line_title")}
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

export default AddonLinesModal;
