import enTranslation from "./en.json"
import { store } from "@/redux/store";

// Hydration gate flag ensuring initial render matches English server fallback.
let hydrated = false;
export const markTranslationsHydrated = (): void => {
    hydrated = true;
};

const enTranslationMap: Record<string, string> = enTranslation;

export const t = (label: string): string => {
    if (!hydrated) return enTranslationMap[label];
    const state = store.getState() as any;
    const langData = state.Language?.selectedLanguage?.json_data && state.Language?.selectedLanguage?.json_data[label];
    if (langData) {
        return langData;
    } else {
        return enTranslationMap[label];
    }
};

