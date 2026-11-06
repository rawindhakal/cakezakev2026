import { useEffect, useRef, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { usePathname } from "next/navigation";
import * as api from "@/api/apiRoutes";
import { setProductBySearch } from "@/redux/slices/productFilterSlice";
import { isProductsPath } from "@/utils/zonePrefixable";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";

// Looser retries for a 0-result query: drop the last word, then cut a long word to its stem.
const fallbackTerms = (value: string): string[] => {
  const words = value.trim().split(/\s+/).filter(Boolean);
  const out: string[] = [];
  if (words.length > 1) out.push(words.slice(0, -1).join(" "));
  const first = words[0] || "";
  if (first.length >= 5) out.push(first.slice(0, 4));
  return Array.from(new Set(out)).filter((term) => term.toLowerCase() !== value.trim().toLowerCase());
};

// Debounced product search suggestions for the header's search field.
const useSearchSuggestions = () => {
  const dispatch = useDispatch();
  const pathname = usePathname();
  const { setSearch: setUrlSearch } = useUrlProductFilters();
  const cityLat = useSelector((state: any) => state.City.city?.latitude);
  const cityLng = useSelector((state: any) => state.City.city?.longitude);
  const filter = useSelector((state: any) => state.ProductFilter);

  const [searchText, setSearchText] = useState("");
  const [isSuggLoading, setIsSuggLoading] = useState(false);
  const [isSuggError, setIsSuggError] = useState(false);
  // Looser term actually shown when the typed one found nothing ("Showing results for …").
  const [correctedTerm, setCorrectedTerm] = useState<string | null>(null);
  const requestIdRef = useRef(0);
  const typingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Seed search text from URL parameter
  useEffect(() => {
    if (isProductsPath(pathname)) {
      const q = new URLSearchParams(window.location.search).get("q");
      // eslint-disable-next-line react-hooks/set-state-in-effect -- mirrors the URL into the field
      setSearchText(typeof q === "string" ? q : "");
    }
  }, [pathname]);

  const fetchTerm = async (term: string) => {
    const response = await api.getProductByFilter({
      latitude: cityLat,
      longitude: cityLng,
      filters: {
        search: term,
        category_id: filter?.searchedCategory,
      },
    });
    return Array.isArray(response?.data) ? response.data : [];
  };

  const handleSearchData = async (searchValue: string) => {
    const requestId = ++requestIdRef.current;
    setIsSuggLoading(true);
    setIsSuggError(false);
    try {
      let rows = await fetchTerm(searchValue);
      let used: string | null = null;
      if (rows.length === 0) {
        for (const term of fallbackTerms(searchValue)) {
          if (requestId !== requestIdRef.current) return;
          const retry = await fetchTerm(term);
          if (retry.length > 0) {
            rows = retry;
            used = term;
            break;
          }
        }
      }
      // A newer keystroke owns the results now.
      if (requestId !== requestIdRef.current) return;
      setCorrectedTerm(used);
      dispatch(setProductBySearch({ data: rows }));
      setIsSuggLoading(false);
    } catch (error: any) {
      if (requestId !== requestIdRef.current) return;
      setIsSuggLoading(false);
      setIsSuggError(true);
      console.log("Error", error?.message);
    }
  };

  const handleSearch = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setSearchText(value);
    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }
    if (value.trim() === "") {
      requestIdRef.current++;
      setCorrectedTerm(null);
      setIsSuggLoading(false);
      dispatch(setProductBySearch({ data: [] }));
      if (isProductsPath(pathname)) setUrlSearch(null);
      setIsSuggError(false);
      return;
    }
    setIsSuggLoading(true);
    typingTimeoutRef.current = setTimeout(() => {
      handleSearchData(value);
      if (isProductsPath(pathname)) setUrlSearch(value);
    }, 400);
  };

  const handleSearchRetry = () => {
    if (searchText?.trim()) {
      handleSearchData(searchText);
    }
  };

  return {
    searchText,
    setSearchText,
    isSuggLoading,
    isSuggError,
    correctedTerm,
    handleSearch,
    handleSearchRetry,
  };
};

export default useSearchSuggestions;
