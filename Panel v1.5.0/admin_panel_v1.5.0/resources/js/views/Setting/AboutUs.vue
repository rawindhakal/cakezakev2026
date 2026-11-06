<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('about_us') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
                <form @submit.prevent="saveRecord">
                    <div class="card">
                        <div class="card-body">

                            <!-- Language Tabs -->
                            <div v-if="languages.length && isDataReady">
                                <b-tabs v-model="activeLanguageTab" content-class="mt-3" :nav-class="languages.length <= 1 ? 'd-none' : null">
                                    <b-tab
                                        v-for="language in languages"
                                        :key="language.id"
                                        lazy
                                    >
                                        <template #title>
                                            <span :class="{ 'text-primary font-weight-bold': language.is_default }">
                                                {{ language.name }}
                                            </span>
                                        </template>

                                        <div class="form-group">
                                            <div class="d-flex w-100 align-items-center mb-2">
                                                <label class="mb-0">
                                                    {{ __('about_us') }}
                                                    <i v-if="language.is_default" class="text-danger">*</i>
                                                </label>
                                                <a :href="viewUrl(language.code)" target="_blank"
                                                    class="btn btn-sm btn-primary ms-auto d-inline-flex align-items-center gap-1">
                                                    <Eye :size="14" /> {{ __('view') }}
                                                </a>
                                            </div>

                                            <editor
                                                :key="'editor_about_us_' + language.id"
                                                v-model="translations[language.id].about_us"
                                                :init="tinymceInit"
                                                tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922"
                                                license-key="gpl"
                                            />
                                        </div>
                                    </b-tab>

                                    <!-- Translate control, inline with the language tabs. -->
                                    <template #tabs-end>
                                        <li class="nav-item ms-auto d-flex align-items-center">
                                            <TranslateLanguages :languages="languages"
                                                :default-language-id="defaultLanguageId" :busy="translating"
                                                :progress="translateProgress" @translate="runTranslate" />
                                        </li>
                                    </template>
                                </b-tabs>
                            </div>

                            <div v-else-if="isLoadingLanguages" class="text-center p-3">
                                <b-spinner />
                            </div>

                        </div>

                        <div class="card-footer d-flex justify-content-end">
                            <b-button type="submit" variant="primary" :disabled="isLoading">
                                {{ __('update') }}
                                <b-spinner v-if="isLoading" small />
                            </b-button>
                        </div>

                    </div>
                </form>
            </section>
        </div>
    </div>
</template>

<script>
import axios from "axios";
import { ArrowLeft, Eye } from 'lucide-vue-next';
import Editor from "@tinymce/tinymce-vue";
import TranslationHelper from '../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
import { tinymceInit as buildTinymceInit } from '../../utils/tinymce.js';

export default {
    mixins: [TranslationHelper, UnsavedChanges],
    components: { editor: Editor, ArrowLeft, Eye },

    data() {
        return {
            isLoading: false,
            isLoadingLanguages: false,
            isDataReady: false,
            languages: [],
            translations: {},
            defaultLanguageId: null,
            activeLanguageTab: 0,
            record: null,

            translatableFields: ['about_us'],
            tinymceInit: buildTinymceInit(),
        };
    },

    created() {
        this.fetchActiveLanguages().then(() => {
            this.getAboutUs();
        });
    },

    methods: {
        // Tracked state for the UnsavedChanges guard (per-language editor content).
        formState() {
            return this.translations;
        },
        // Opens the saved content exactly as the storefront renders it.
        viewUrl(langCode = '') {
            return `${this.$baseUrl}/about-us?lang=${langCode}`;
        },
        fetchActiveLanguages() {
            this.isLoadingLanguages = true;
            return axios.get(this.$apiUrl + "/active_languages")
                .then(res => {
                    this.languages = res.data.data || [];
                    const def = this.languages.find(l => l.is_default === 1);
                    this.defaultLanguageId = def ? def.id : null;

                    this.initTranslations();
                    this.isLoadingLanguages = false;
                });
        },

        initTranslations() {
            const t = {};
            this.languages.forEach(lang => {
                t[lang.id] = { about_us: "" };
            });
            this.translations = t;
        },

        getAboutUs() {
            axios.get(this.$apiUrl + "/about_us").then(res => {
                this.record = res.data.data;
                if (this.record) {
                    try {
                        const parsed = JSON.parse(this.record.value);
                        this.languages.forEach(lang => {
                            if (parsed[lang.code]) {
                                this.translations[lang.id].about_us = parsed[lang.code];
                            }
                        });
                    } catch {
                        if (this.defaultLanguageId) {
                            this.translations[this.defaultLanguageId].about_us = this.record.value;
                        }
                    }
                }
                this.isDataReady = true;
                // Snapshot the loaded content as the "clean" baseline.
                this.captureFormBaseline();
            });
        },

        validateDefaultLanguage() {
            const def = this.translations[this.defaultLanguageId];
            if (!def || !def.about_us.trim()) {
                this.showError(__('please_fill_default_language_required_fields'));
                this.switchToDefaultTab();
                return false;
            }
            return true;
        },

        switchToDefaultTab() {
            const index = this.languages.findIndex(l => l.id === this.defaultLanguageId);
            if (index !== -1) this.activeLanguageTab = index;
        },

        saveRecord() {
            if (!this.validateDefaultLanguage()) return;

            this.isLoading = true;

            const dataByLang = {};
            this.languages.forEach(lang => {
                dataByLang[lang.code] = this.translations[lang.id].about_us || "";
            });

            axios.post(this.$apiUrl + "/about_us/save", {
                about_us: JSON.stringify(dataByLang),
            })
            .then(res => {
                res.data.status === 1
                    ? this.showMessage("success", res.data.message)
                    : this.showError(res.data.message);
                // Mark clean after a successful save.
                if (res.data.status === 1) this.captureFormBaseline();
                this.isLoading = false;
            })
            .catch(() => {
                this.showError(__('something_went_wrong'));
                this.isLoading = false;
            });
        },
    },
};
</script>
