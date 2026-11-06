import axios from "axios";
import TranslateLanguages from "../components/TranslateLanguages.vue";

export default {
    components: { TranslateLanguages },
    data() {
        return {
            translating: false,
            translateProgress: '',
        };
    },
    methods: {
        /** Default-language values to translate from. */
        translateSourceData() {
            if (typeof this.getTranslateSource === 'function') {
                return this.getTranslateSource() || {};
            }
            const id = this.defaultLanguageId;
            if (this.translations && this.translations[id]) return this.translations[id];
            if (this.form && this.form[id]) return this.form[id];
            return {};
        },

        /** Write one language's translated values back into the form. */
        applyTranslatedFields(lang, translated) {
            if (typeof this.applyTranslated === 'function') {
                this.applyTranslated(lang, translated);
                return;
            }
            const target = (this.translations && this.translations[lang.id])
                ? this.translations[lang.id]
                : (this.form ? this.form[lang.id] : null);
            if (!target) return;
            Object.keys(translated).forEach((field) => {
                target[field] = translated[field];
            });
        },

        /**
         * Translate the default-language text into `langIds`.
         * One request: the backend translates every requested language in a single pass,
         * so asking for 4 languages costs one round trip, not four.
         */
        runTranslate(langIds) {
            if (typeof this.validateDefaultLanguageForTranslation === 'function'
                && !this.validateDefaultLanguageForTranslation()) {
                return Promise.resolve();
            }

            const targets = (this.languages || [])
                .filter(l => (langIds || []).some(id => String(id) === String(l.id)));
            if (!targets.length) return Promise.resolve();

            const source = this.translateSourceData();
            const fields = this.translatableFields || [];
            const data = {};
            fields.forEach((f) => {
                const v = source ? source[f] : null;
                // Objects/arrays aren't translatable text; skip rather than send junk.
                if (v !== null && v !== undefined && typeof v !== 'object') data[f] = v;
            });

            const hasText = Object.keys(data).some(k => String(data[k] ?? '').trim() !== '');
            if (!hasText) {
                this.showError(__('translation_error_all_fields_empty'));
                return Promise.resolve();
            }

            this.translating = true;
            this.translateProgress = targets.length > 1
                ? String(__('translating_languages')).replace(':count', targets.length)
                : (targets[0].display_name || targets[0].name || '');

            return axios.post(this.$apiUrl + '/languages/translate', {
                target_languages: targets.map(l => l.code).filter(Boolean),
                data,
            }).then((res) => {
                if (res.data.status === 0) {
                    throw new Error(res.data.message || __('something_went_wrong'));
                }
                const all = res.data.data || {};
                let filled = 0;
                targets.forEach((lang) => {
                    const translated = all[lang.code];
                    if (!translated) return;
                    this.applyTranslatedFields(lang, translated);
                    filled++;
                });
                if (!filled) {
                    this.showError(__('something_went_wrong'));
                    return;
                }
                // Product tags arrive as names but the form branches ids.
                if (typeof this.convertTagNamesToIds === 'function') {
                    this.$nextTick(() => this.convertTagNamesToIds());
                }
                this.showMessage('success', __('translation_completed_successfully'));
            }).catch((error) => {
                this.showError(error.response?.data?.message || error.message || __('something_went_wrong'));
            }).finally(() => {
                this.translating = false;
                this.translateProgress = '';
            });
        },
    },
};
