"use client";

import { useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import Link from "next/link";
import { useDispatch } from "react-redux";
import { t } from "@/utils/translation";
import { Home, ChevronRight } from "lucide-react";
import useLanguages from "@/hooks/useLanguages";
import useZoneHref from "@/hooks/useZoneHref";
import { parseZonePath } from "@/utils/zoneUrl";
import {
  setListingSource,
  setCategorySlug,
  setBlockSource,
} from "@/redux/slices/productFilterSlice";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useNavClick from "@/hooks/useNavClick";

interface BreadCrumbProps {
  title?: string;
  categoryId?: number | string | null;
  categorySlug?: string;
}

interface Crumb {
  label: string;
  href: string;
}

// categoryId/categorySlug: "Product" crumb opens listing filtered to it.
const BreadCrumb = ({ title, categoryId, categorySlug }: BreadCrumbProps) => {
  const router = useRouter();
  const { run: runNavClick } = useNavClick();
  const pathname = usePathname();
  const dispatch = useDispatch();
  const { parseLangPath } = useLanguages();
  const zoneHref = useZoneHref();
  const { buildQueryPatch } = useUrlProductFilters();
  const [breadcrumbs, setBreadcrumbs] = useState<Crumb[]>([]);
  useEffect(() => {
    if (pathname) {
      // Lang segment isn't a crumb, but stays in hrefs. Zone crumb kept.
      const { rest: pathArray, lang } = parseLangPath(pathname);
      const langPrefix = lang ? `/${lang}` : "";
      const formattedBreadcrumbs = pathArray.map((path, index) => {
        const href = `${langPrefix}/${pathArray.slice(0, index + 1).join("/")}`;
        return { label: decodeURIComponent(path), href };
      });

      if (title && formattedBreadcrumbs.length > 0) {
        formattedBreadcrumbs[formattedBreadcrumbs.length - 1].label = title;
      }

      // eslint-disable-next-line react-hooks/set-state-in-effect
      setBreadcrumbs(formattedBreadcrumbs);
    }
  }, [pathname, title, parseLangPath]);

  const navigateCrumb = (href: string) => {
    // Compare the route part only — strip /{lang}/{zone}.
    const { rest: afterLang } = parseLangPath(href);
    const { rest: routeParts } = parseZonePath("/" + afterLang.join("/"));
    const route = `/${routeParts.join("/")}`;

    if (route === "/product") {
      let query = {};
      if (categoryId != null && categorySlug) {
        dispatch(setListingSource({ data: "category" }));
        dispatch(setCategorySlug({ data: categorySlug }));
        // Clear stale "See All" block source.
        dispatch(setBlockSource());
        query = buildQueryPatch({ category_id: categorySlug });
      }
      const qs = new URLSearchParams(query).toString();
      const dest = zoneHref("/products");
      return router.push(qs ? `${dest}?${qs}` : dest);
    }
    if (route === "/blog") {
      return router.push(zoneHref("/blogs"));
    }
    if (route === "/categories") {
      return router.push(zoneHref("/categories/all"));
    }
    // Not router.back() — that returned to the payment-success page.
    if (route === "/order-detail") {
      return router.push(zoneHref("/profile/activeorders"));
    }
    return router.push(href);
  };

  // Programmatic push — start the progress bar explicitly.
  const handleNotFoundRoutes = (href: string) =>
    runNavClick(() => navigateCrumb(href));

  const formatBreadcrumbLabel = (label: string) => {
    const map: Record<string, string> = {
      activeorders: t("active_orders"),
      orderhistory: t("order_history"),
      wallethistory: t("wallet_history"),
      "about-us": t("about_us"),
      "contact-us": t("contact_us"),
      categories: t("categories"),
      products: t("products"),
      blogs: t("blogs"),
      profile: t("profile"),
      all: t("all"),
      orders: t("orders"),
      wishlist: t("wishlist"),
      address: t("address"),
      subscription: t("subscription"),
      transaction: t("transaction"),
      notifications: t("notifications"),
      "notification-setting": t("notification-setting"),
      faqs: t("faqs"),
      "terms-and-conditions": t("terms-and-conditions"),
      active_orders: t("active_orders"),
      "privacy-policy": t("privacy-policy"),
      "return-and-exchange-policy": t("return-and-exchange-policy"),
      "shipping-policy": t("shipping-policy"),
      "cancellation-policy": t("cancellation-policy"),
      cart: t("cart"),
      checkout: t("checkout"),
      "order-detail": t("order-detail"),
      product: t("product"),
      blog: t("blog"),
      brands: t("brands"),
      countries: t("countries"),
    };

    if (map[label]) return map[label];

    return label
      .replaceAll("-", " ")
      .replace(/\b\w/g, (char) => char.toUpperCase());
  };

  return (
    <section>
      <div className="container pt-4 md:pt-5 pb-1">
        <nav aria-label="breadcrumb">
          {/* min-w-0 lets the last crumb truncate. */}
          <ol className="flex min-w-0 items-center text-sm whitespace-nowrap">
            <li className="flex items-center shrink-0">
              <Link
                href={zoneHref("/")}
                aria-label={t("home")}
                className="flex items-center gap-1.5 capitalize transition-colors hover:primaryColor breadCrumbTrailLink"
              >
                <Home size={15} className="shrink-0" />
                {t("home")}
              </Link>
            </li>

            {breadcrumbs.map((crumb, index) => {
              const isLast = index === breadcrumbs.length - 1;
              return (
                <li
                  key={crumb.href}
                  className={`items-center ${
                    isLast
                      ? "flex min-w-0 flex-1"
                      : // Hidden on phones so long zone names don't crush the title.
                        "hidden shrink-0 sm:flex"
                  }`}
                >
                  <ChevronRight
                    size={15}
                    className="mx-1.5 shrink-0 opacity-40 rtl:rotate-180"
                    aria-hidden="true"
                  />
                  {isLast ? (
                    <span
                      aria-current="page"
                      className="truncate font-semibold capitalize primaryColor"
                      title={crumb.label}
                    >
                      {formatBreadcrumbLabel(crumb.label)}
                    </span>
                  ) : (
                    <button
                      type="button"
                      onClick={() => handleNotFoundRoutes(crumb.href)}
                      className="capitalize transition-colors hover:primaryColor breadCrumbTrailLink"
                      title={crumb.label}
                    >
                      {formatBreadcrumbLabel(crumb.label)}
                    </button>
                  )}
                </li>
              );
            })}
          </ol>
        </nav>
      </div>
    </section>
  );
};

export default BreadCrumb;
