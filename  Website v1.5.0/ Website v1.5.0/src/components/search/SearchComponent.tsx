"use client";
import React, { useEffect, useRef, useState } from "react";
import { t } from "@/utils/translation";
import { toast } from "react-toastify";
import { useSelector } from "react-redux";
import { usePathname, useRouter } from "next/navigation";
import SearchProductCard from "../cards/SearchProductCard";
import { IoSearchOutline, IoTimeOutline, IoTrendingUp, IoMicOutline, IoMic, IoClose } from "react-icons/io5";
import ThemedSvg from "@/components/notfound/ThemedSvg";
import NoSearchImage from "@/assets/empty-state/no-search.svg";
import useZoneHref from "@/hooks/useZoneHref";
import useNavClick from "@/hooks/useNavClick";
import useSearchPlaceholder from "@/hooks/useSearchPlaceholder";
import useIsHydrated from "@/hooks/useIsHydrated";
import { isProductsPath } from "@/utils/zonePrefixable";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useRecentSearches from "@/hooks/useRecentSearches";
import useVoiceSearch from "@/hooks/useVoiceSearch";
import SearchMindProducts from "./SearchMindProducts";
import SearchWishlistProducts from "./SearchWishlistProducts";

interface SearchComponentProps {
  handleSearch: (e: React.ChangeEvent<HTMLInputElement>) => void;
  isSuggLoading?: boolean;
  isSuggError?: boolean;
  onRetrySearch?: () => void;
  searchText?: string;
  isMobile?: boolean;
  mobileSearch?: boolean;
  setMobileSearch?: (open: boolean) => void;
  onResultClick?: () => void;
  // "page" = full-screen search route: inline panels, sticky box, no dismiss.
  variant?: "dropdown" | "page";
  leading?: React.ReactNode;
  // Dropdown only: focusing the box hands off to the search page instead.
  onActivate?: () => void;
  // Looser term the results came from when the typed one found nothing.
  correctedTerm?: string | null;
}

const SearchComponent = ({ handleSearch, isSuggLoading, isSuggError, onRetrySearch, searchText = "", onResultClick, variant = "dropdown", leading, onActivate, correctedTerm }: SearchComponentProps) => {
  const isPage = variant === "page";
  const zoneHref = useZoneHref();
  const router = useRouter();
  const { run: runNavClick } = useNavClick();
  const pathname = usePathname();
  const { buildQueryPatch } = useUrlProductFilters();
  // Search suggestions data from redux
  const searchProduct = useSelector((state: any) => state.ProductFilter.search_product);
  // Search placeholder rotation hook
  const { suggestion, index: suggestionIndex, hasSuggestions } =
    useSearchPlaceholder({ active: !searchText });
  // Hydration check to prevent placeholder SSR mismatch
  const hydrated = useIsHydrated();
  // Show animated hint only when input is empty
  const showAnimatedHint = hydrated && hasSuggestions && !searchText;

  // Dropdown visibility state
  const [dismissed, setDismissed] = useState(false);
  // Discovery panel (recent + trending) opens on focus of an empty box.
  const [opened, setOpened] = useState(false);
  const { recent, add: addRecent, remove: removeRecent, clear: clearRecent } =
    useRecentSearches();
  const rawTrending = useSelector((state: any) => state?.ShopMode?.searchSuggestions);
  const trending: string[] = Array.isArray(rawTrending) ? rawTrending.slice(0, 8) : [];
  const rootRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (isPage) return;
    const handlePointerDown = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) {
        setDismissed(true);
      }
    };
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setDismissed(true);
    };
    // Dismiss dropdown on window scroll
    const handleScroll = () => setDismissed(true);
    document.addEventListener("mousedown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => {
      document.removeEventListener("mousedown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
      window.removeEventListener("scroll", handleScroll);
    };
  }, [isPage]);

  const goToResults = (term: string) => {
    const qs = new URLSearchParams(
      buildQueryPatch({ search: term || null }),
    ).toString();
    const dest = zoneHref("/products");
    runNavClick(() => router.push(qs ? `${dest}?${qs}` : dest));
  };

  const handleSearchItemClick = async () => {
    addRecent(searchText);
    goToResults(searchText);
  };

  // Chip / voice pick: fill the box like typing, remember it, open results.
  const runSearch = (term: string) => {
    const value = term.trim();
    if (!value) return;
    handleSearch({ target: { value } } as React.ChangeEvent<HTMLInputElement>);
    addRecent(value);
    setDismissed(true);
    goToResults(value);
  };

  const handleVoiceError = (code: string) => {
    const messages: Record<string, string> = {
      "not-allowed": t("mic_permission_denied") || "Microphone permission denied. Allow mic access in browser settings.",
      "service-not-allowed": t("mic_permission_denied") || "Microphone permission denied. Allow mic access in browser settings.",
      "insecure-context": t("voice_needs_https") || "Voice search needs a secure (https) connection.",
      "no-speech": t("voice_no_speech") || "Didn't catch that. Please try again.",
      "audio-capture": t("voice_no_mic") || "No microphone found.",
      network: t("voice_network_error") || "Voice search is unavailable in this browser.",
    };
    toast.error(messages[code] || t("voice_search_failed") || "Voice search failed. Please try again.", {
      toastId: "voice-search-error",
    });
  };

  const voice = useVoiceSearch(runSearch, handleVoiceError);

  const handleResultClick = () => {
    addRecent(searchText);
    onResultClick?.();
  };

  // Picking a product in the panel navigates away; close it on the new page.
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- reset panel on route change
    setOpened(false);
  }, [pathname]);

  const showDiscovery = hydrated && !searchText && (isPage || (opened && !dismissed));
  const showResults = !!searchText && (isPage || (!isProductsPath(pathname) && !dismissed));

  // Skeleton loader for search suggestions
  const SkeletonRow = () => (
    <div className="flex items-center gap-3 px-4 py-2.5 border-b border-gray-100 dark:border-zinc-800/80 last:border-b-0">
      <div className="w-10 h-10 flex-shrink-0 rounded-md bg-zinc-200 dark:bg-zinc-800 animate-pulse" />
      <div className="flex flex-col flex-grow gap-2 min-w-0">
        <div className="h-3 w-3/4 rounded bg-zinc-200 dark:bg-zinc-800 animate-pulse" />
        <div className="h-3 w-1/4 rounded bg-zinc-200 dark:bg-zinc-800 animate-pulse" />
      </div>
    </div>
  );

  const inputBox = (
      <div className={`flex w-full ${isPage ? "h-[44px]" : "h-[44px] md:h-[37px] xl:h-[48px]"} md:h-[37px] xl:h-[48px] items-center bg-gray-100 dark:bg-zinc-800 rounded-lg px-4 gap-2.5`}>
        <IoSearchOutline size={17} className="flex-shrink-0 text-zinc-400 dark:text-zinc-500" />
        {/* Animated search hint overlay */}
        <div className="relative flex-1 min-w-0 h-full">
          <input
            type="text"
            aria-label={hydrated ? t("search") : "search"}
            placeholder={
              showAnimatedHint ? "" : hydrated ? t("iAmLookingFor") : ""
            }
            className="w-full h-full text-sm focus:outline-none bg-transparent text-zinc-800 dark:text-zinc-100 placeholder-zinc-400 dark:placeholder-zinc-500 border-none shadow-none min-w-0"
            value={searchText}
            autoFocus={isPage}
            enterKeyHint="search"
            onChange={(e) => {
              setDismissed(false);
              handleSearch(e);
            }}
            onFocus={(e) => {
              if (onActivate && !isPage) {
                e.currentTarget.blur();
                onActivate();
                return;
              }
              setDismissed(false);
              setOpened(true);
            }}
            onKeyDown={(e) => e.key === "Enter" && handleSearchItemClick()}
          />
          {showAnimatedHint && (
            <div
              aria-hidden="true"
              className="pointer-events-none absolute inset-0 flex items-center gap-1.5 text-sm text-zinc-400 dark:text-zinc-500"
            >
              <span className="flex-shrink-0">{t("iAmLookingFor")}</span>
              {/* Animated text container */}
              <span className="relative flex-1 min-w-0 h-5 overflow-hidden">
                {/* Animated suggestion text */}
                <span
                  key={suggestionIndex}
                  className="search-hint-slide absolute inset-0 flex items-center font-medium text-zinc-500 dark:text-zinc-400 whitespace-nowrap overflow-hidden text-ellipsis"
                >
                  {suggestion}
                </span>
              </span>
            </div>
          )}
        </div>
        {voice.supported && (
          <button
            type="button"
            onClick={voice.listening ? voice.stop : voice.start}
            aria-label={t("voice_search") || "Voice search"}
            aria-pressed={voice.listening}
            className={`relative flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full transition-colors ${
              voice.listening
                ? "bg-red-500 text-white"
                : "text-zinc-500 hover:bg-black/5 dark:text-zinc-400 dark:hover:bg-white/10"
            }`}
          >
            {voice.listening && (
              <span className="absolute inset-0 animate-ping rounded-full bg-red-500/40" />
            )}
            {voice.listening ? <IoMic size={17} className="relative" /> : <IoMicOutline size={18} />}
          </button>
        )}
      </div>
  );

  const listeningContent = (
    <>
          <p>{t("listening") || "Listening…"}</p>
          {voice.interim && (
            <p className="mt-1 truncate text-base font-semibold text-zinc-800 dark:text-zinc-100">
              {voice.interim}
            </p>
          )}
    </>
  );

  const discoveryContent = (
    <>
          {recent.length > 0 && (
            <div>
              <div className="mb-2 flex items-center justify-between">
                <span className="text-[11px] font-bold uppercase tracking-wide text-zinc-500 dark:text-zinc-400 sm:text-xs">
                  {t("recent_searches") || "Recent searches"}
                </span>
                <button
                  type="button"
                  onClick={clearRecent}
                  className="text-xs font-semibold primaryColor hover:underline"
                >
                  {t("clearAll") || "Clear All"}
                </button>
              </div>
              <div className="flex flex-wrap gap-1.5 sm:gap-2">
                {recent.map((term) => (
                  <span
                    key={term}
                    className="group inline-flex max-w-full items-center gap-1 rounded-full border border-gray-200 bg-white py-0.5 pl-2 pr-0.5 text-xs sm:gap-1.5 sm:py-1 sm:pl-2.5 sm:pr-1 sm:text-[13px] text-zinc-700 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-200"
                  >
                    <IoTimeOutline size={13} className="shrink-0 text-zinc-400" />
                    <button
                      type="button"
                      onClick={() => runSearch(term)}
                      className="min-w-0 truncate text-start"
                    >
                      {term}
                    </button>
                    <button
                      type="button"
                      onClick={() => removeRecent(term)}
                      aria-label={t("remove") || "Remove"}
                      className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-zinc-400 hover:bg-black/5 hover:text-zinc-600 dark:hover:bg-white/10"
                    >
                      <IoClose size={12} />
                    </button>
                  </span>
                ))}
              </div>
            </div>
          )}
          {trending.length > 0 && (
            <div>
              <span className="mb-2 block text-[11px] font-bold uppercase tracking-wide text-zinc-500 dark:text-zinc-400 sm:text-xs">
                {t("trending_products") || "Trending products"}
              </span>
              <div className="flex flex-wrap gap-1.5 sm:gap-2">
                {trending.map((term) => (
                  <button
                    key={term}
                    type="button"
                    onClick={() => runSearch(term)}
                    className="inline-flex max-w-full items-center gap-1 rounded-full primaryLightBack px-2.5 py-[3px] text-xs font-medium primaryColor sm:gap-1.5 sm:px-3 sm:py-1 sm:text-[13px] transition-opacity hover:opacity-80"
                  >
                    <IoTrendingUp size={13} className="shrink-0" />
                    <span className="truncate">{term}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
          <SearchWishlistProducts enabled={showDiscovery} />
          <SearchMindProducts enabled={showDiscovery} />
    </>
  );

  const resultsContent = (
    <>
          {!isSuggLoading && isSuggError ? (
            <div className="flex flex-col items-center justify-center gap-2.5 py-6 text-center">
              <span className="text-sm font-semibold text-zinc-500 dark:text-zinc-400">
                {t("something_went_wrong") || "Something went wrong"}
              </span>
              <button
                type="button"
                onClick={onRetrySearch}
                className="rounded-lg primaryBackColor py-1.5 px-4 text-white text-xs font-medium"
              >
                {t("retry") || t("try_again") || "Retry"}
              </button>
            </div>
          ) : isSuggLoading && searchProduct?.length === 0 ? (
            Array.from({ length: 4 }).map((_, idx) => <SkeletonRow key={idx} />)
          ) : (
            <>
              {correctedTerm && searchProduct?.length > 0 && (
                <p className="px-4 pb-1.5 pt-2 text-xs text-zinc-500 dark:text-zinc-400">
                  {t("no_results_for") || "No results for"} &ldquo;{searchText}&rdquo;.{" "}
                  {t("showing_results_for") || "Showing results for"}{" "}
                  <span className="font-semibold primaryColor">&ldquo;{correctedTerm}&rdquo;</span>
                </p>
              )}
              {searchProduct?.map((product: any, idx: number) => (
                <SearchProductCard key={idx} product={product} onResultClick={handleResultClick} highlight={correctedTerm || searchText} />
              ))}
              {!isSuggLoading && searchProduct?.length === 0 && (
                <div className="flex flex-col items-center justify-center gap-2 py-6 text-center">
                  <ThemedSvg
                    src={NoSearchImage}
                    alt={t("no_product_found")}
                    className="w-32 max-w-[140px]"
                  />
                  <span className="text-sm font-semibold text-zinc-400 dark:text-zinc-500">
                    {t("no_product_found")}
                  </span>
                </div>
              )}
            </>
          )}
      {isPage && !isSuggLoading && searchProduct?.length > 0 && (
        <button
          type="button"
          onClick={() => {
            addRecent(searchText);
            goToResults(correctedTerm || searchText);
          }}
          className="mt-1 w-full rounded-xl primaryLightBack py-2.5 text-sm font-semibold primaryColor"
        >
          {t("see_all_results") || "See all results for"} &ldquo;{correctedTerm || searchText}&rdquo;
        </button>
      )}
    </>
  );

  if (isPage) {
    return (
      <div className="w-full" ref={rootRef}>
        <div className="sticky top-0 z-40 border-b border-gray-100 bg-white dark:border-zinc-800 dark:bg-zinc-900">
          <div className="container flex items-center gap-1.5 py-2 max-md:ps-2 md:py-3">
            {leading}
            <div className="min-w-0 flex-1">{inputBox}</div>
          </div>
        </div>
        <div className="container flex flex-col gap-4 pb-28 pt-3 text-start md:gap-5 md:pt-4">
          {voice.listening ? (
            <div className="rounded-2xl primaryLightBack px-4 py-6 text-center text-sm font-medium text-zinc-600 dark:text-zinc-300">
              {listeningContent}
            </div>
          ) : showResults ? (
            <div className="flex flex-col">{resultsContent}</div>
          ) : (
            showDiscovery && discoveryContent
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="relative w-full" ref={rootRef}>
      {inputBox}

      {voice.listening && (
        <div className="absolute left-0 right-0 top-full z-[60] mt-2 rounded-2xl border border-gray-100 bg-white px-4 py-3 text-center text-sm font-medium text-zinc-600 shadow-xl dark:border-zinc-800/80 dark:bg-zinc-900 dark:text-zinc-300">
          {listeningContent}
        </div>
      )}

      {showDiscovery && !voice.listening && (
        // Outer clips to the rounded shape; inner scrolls, so the scrollbar can't square the corners.
        <div className="absolute left-0 right-0 top-full z-[60] mt-2 overflow-hidden rounded-2xl border border-gray-100 bg-white shadow-xl shadow-zinc-200/40 dark:border-zinc-800/80 dark:bg-zinc-900 dark:shadow-none">
          <div className="custom-scrollbar flex max-h-[min(75vh,680px)] flex-col gap-4 overflow-y-auto overscroll-contain p-3 text-start sm:gap-5 sm:p-4">
            {discoveryContent}
          </div>
        </div>
      )}

      {showResults && (
        <div className="w-full mt-2 flex flex-col bg-white dark:bg-zinc-900 border border-gray-100 dark:border-zinc-800/80 rounded-2xl shadow-xl shadow-zinc-200/40 dark:shadow-none absolute z-[60] top-full left-0 right-0 max-h-[360px] overflow-y-auto p-1.5">
          {resultsContent}
        </div>
      )}
    </div>
  );
};

export default SearchComponent;
