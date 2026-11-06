import { useEffect, useState, type MouseEvent } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogOverlay,
  DialogTitle,
} from "@/components/ui/dialog";
import Image from "next/image";
import Link from "next/link";
import { RiCloseFill } from "react-icons/ri";
import { useDispatch, useSelector } from "react-redux";
import { setIsPopupSeen } from "@/redux/slices/settingSlice";
import { useRouter } from "next/navigation";

import {
  setSelectedCategories,
  setListingSource,
  setCategorySlug,
  setCategoryBreadcrumb,
  setBlockSource,
} from "@/redux/slices/productFilterSlice";
import useZoneHref from "@/hooks/useZoneHref";
import { FILTER_PARAMS } from "@/utils/urlProductFilters";

const HomeOfferModal = () => {
  const zoneHref = useZoneHref();
  const dispatch = useDispatch();
  const setting = useSelector((state: any) => state.Setting);
  const city = useSelector((state: any) => state.City);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const router = useRouter();

  useEffect(() => {
    if (setting?.setting?.popup_enabled === "1" && city?.city !== null) {
      const hasPopupBeenSeen = setting?.isPopupSeen;
      if (!hasPopupBeenSeen) {
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setIsModalOpen(true);
      }
    }
  }, [setting?.setting?.popup_enabled, city?.city, setting?.isPopupSeen]);

  const handleClose = () => {
    setIsModalOpen(false);
    dispatch(setIsPopupSeen({ data: true }));
  };

  const categoryBreadcrumb = useSelector(
    (state: any) => state.ProductFilter.categoryBreadcrumb,
  );

  const slug = setting?.setting?.popup_slug;
  const category_id = setting?.setting?.popup_type_id;
  const brand_id = setting?.setting?.popup_type_id;
  const type = setting?.setting?.popup_type;
  const url = setting?.setting?.popup_url;

  const getHref = () => {
    if (type === "product" && slug) return `/product/${slug}`;
    if (type === "popup_url" && url) return url;
    return "#";
  };

  const handlePopupClick = (e: MouseEvent<HTMLAnchorElement>) => {
    if (type === "category" && slug) {
      e.preventDefault();

      const exists = categoryBreadcrumb.find((c) => c.id === category_id);
      const newBreadcrumb = exists
        ? categoryBreadcrumb
        : [...categoryBreadcrumb, { id: category_id, name: slug, slug: slug }];

      dispatch(setListingSource({ data: "category" }));
      dispatch(setCategorySlug({ data: slug }));
      dispatch(setCategoryBreadcrumb({ data: newBreadcrumb }));
      dispatch(setSelectedCategories({ data: category_id }));
      dispatch(setBlockSource());

      handleClose();
      const qs = new URLSearchParams({
        [FILTER_PARAMS.category_id]: slug,
      }).toString();
      router.push(`${zoneHref("/products")}?${qs}`);
    } else if (type === "brand" && brand_id) {
      e.preventDefault();

      dispatch(setListingSource({ data: "all" }));

      handleClose();
      const qs = new URLSearchParams({
        [FILTER_PARAMS.brand_ids]: String(brand_id),
      }).toString();
      router.push(`${zoneHref("/products")}?${qs}`);
    } else {
      handleClose();
    }
  };

  return (
    <div>
      <Dialog open={isModalOpen}>
        <DialogContent
          className="bg-transparent border-none shadow-none focus-visible:outline-none focus-within:border-none"
          onInteractOutside={(e) => e.preventDefault()}
          aria-describedby={undefined}
        >
          <DialogHeader>
            <DialogTitle>
              <div className="flex justify-end">
                <RiCloseFill
                  className="w-12 h-12 textColor closeButtonBg rounded-full p-[8px]  cursor-pointer"
                  onClick={handleClose}
                />
              </div>
            </DialogTitle>
          </DialogHeader>
          <div className="bg-transparent">
            <div className="h-full w-full">
              <Link
                href={getHref()}
                target={type === "popup_url" ? "_blank" : "_self"}
                onClick={handlePopupClick}
                className="block outline-none"
              >
                <Image
                  src={setting?.setting?.popup_image}
                  alt="Offer image"
                  height={1000}
                  width={1000}
                  className="h-full w-full object-contain focus-visible:outline-none"
                />
              </Link>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default HomeOfferModal;
