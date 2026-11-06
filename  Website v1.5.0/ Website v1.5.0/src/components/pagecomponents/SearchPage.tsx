"use client";

import { useRouter } from "next/navigation";
import { IoArrowBack } from "react-icons/io5";
import { t } from "@/utils/translation";
import useZoneHref from "@/hooks/useZoneHref";
import useSearchSuggestions from "@/hooks/useSearchSuggestions";
import SearchComponent from "@/components/search/SearchComponent";

// Full-screen search (Blinkit-style): back arrow + focused box, discovery/results below.
const SearchPage = () => {
  const router = useRouter();
  const zoneHref = useZoneHref();
  const {
    searchText,
    setSearchText,
    isSuggLoading,
    isSuggError,
    correctedTerm,
    handleSearch,
    handleSearchRetry,
  } = useSearchSuggestions();

  const goBack = () => {
    if (window.history.length > 1) router.back();
    else router.push(zoneHref("/"));
  };

  return (
    <div className="searchPageIn min-h-[100dvh] w-full bg-white dark:bg-zinc-900">
      <SearchComponent
        variant="page"
        leading={
          <button
            type="button"
            onClick={goBack}
            aria-label={t("back") || "Back"}
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-zinc-700 active:bg-black/10 dark:text-zinc-200"
          >
            <IoArrowBack size={22} className="rtl:rotate-180" />
          </button>
        }
        isSuggLoading={isSuggLoading}
        isSuggError={isSuggError}
        correctedTerm={correctedTerm}
        onRetrySearch={handleSearchRetry}
        searchText={searchText}
        onResultClick={() => setSearchText("")}
        handleSearch={handleSearch}
      />
    </div>
  );
};

export default SearchPage;
