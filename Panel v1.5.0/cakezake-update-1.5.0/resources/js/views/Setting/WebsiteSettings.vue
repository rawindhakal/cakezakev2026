<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('website_settings') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>
            <section class="section">
                <form method="post" enctype="multipart/form-data" @submit.prevent="saveRecord" novalidate>

                    <div class="card mb-3">
                        <div class="card-header">
                            <h4 class="card-title">{{ __('header_settings') }}</h4>
                        </div>

                        <div class="card-body">
                            <b-tabs v-model="activeLanguageTab"
                                :nav-class="languages.length <= 1 ? 'd-none' : 'mb-4 border-bottom'"
                                content-class="mt-3" :lazy="false">
                                <b-tab v-for="language in languages" :key="language.id"
                                    :id="'web-lang-tab-' + language.id">
                                    <template #title>
                                        <span :class="{ 'text-primary font-weight-bold': language.is_default }">
                                            {{ language.name }}
                                        </span>
                                    </template>
                                    <div class="card-body ps-0 pt-0">
                                        <div class="row">
                                            <div class="form-group col-md-4 mt-0">
                                                <label for="site_title">{{ __('site_title') }}</label>
                                                <i class="text-danger" v-if="language.is_default">*</i>
                                                <input type="text" name="site_title" id="site_title"
                                                    v-model="webTranslations.site_title[language.code]"
                                                    class="form-control" :placeholder="__('site_title')"
                                                    :required="language.is_default ? true : undefined" />
                                            </div>
                                            <div class="form-group col-sm-6 col-md-6 col-lg-4"
                                                v-if="language.is_default">
                                                <label for="website_url">{{ __('website_url') }}</label>
                                                <i class="text-danger">*</i>
                                                <div class="input-group">
                                                    <input type="text" name="website_url" id="website_url"
                                                        v-model="settings.website_url" class="form-control"
                                                        :placeholder="__('website_url')"
                                                        :required="language.is_default ? true : undefined" />
                                                    <button type="button" class="btn btn-primary mb-0"
                                                        v-if="settings.website_url"
                                                        @click="openUrl(settings.website_url)">
                                                        <i class="fa fa-solid fa-globe fs-5"></i>
                                                    </button>
                                                </div>
                                            </div>
                                            <div class="form-group col-sm-6 col-md-6 col-lg-4">
                                                <label for="common_meta_title">{{ __('common_meta_title') }}</label>
                                                <i class="text-danger" v-if="language.is_default">*</i>
                                                <div class="input-group">
                                                    <input type="text" name="common_meta_title" id="common_meta_title"
                                                        v-model="webTranslations.common_meta_title[language.code]"
                                                        class="form-control" :placeholder="__('common_meta_title')"
                                                        :required="language.is_default ? true : undefined" />
                                                </div>
                                            </div>
                                            <div class="form-group col-sm-6 col-md-6 col-lg-4">
                                                <label for="common_meta_description">{{
                                                    __('common_meta_description') }}</label>
                                                <i class="text-danger" v-if="language.is_default">*</i>
                                                <div class="input-group">
                                                    <textarea type="text" name="common_meta_description"
                                                        id="common_meta_description"
                                                        v-model="webTranslations.common_meta_description[language.code]"
                                                        class="form-control"
                                                        :placeholder="__('common_meta_description')"
                                                        :required="language.is_default ? true : undefined" />
                                                </div>
                                            </div>
                                            <div class="form-group col-sm-6 col-md-6 col-lg-4"
                                                v-if="language.is_default">
                                                <label for="light_mode_color">{{ __('light_mode_color') ?
                                                    __('light_mode_color') : 'Light Mode Color'
                                                    }}</label>
                                                <i class="text-danger">*</i>
                                                <div class="d-flex align-items-center">
                                                    <input type="color" id="light_mode_color" name='light_mode_color'
                                                        v-model="settings.light_mode_color"
                                                        class="form-control form-control-color me-2"
                                                        style="width: 60px; height: 40px;" />
                                                    <input type="text" class="form-control"
                                                        v-model="settings.light_mode_color" placeholder="#FE3C5E"
                                                        maxlength="7" />
                                                </div>
                                            </div>
                                            <div class="form-group col-sm-6 col-md-6 col-lg-4"
                                                v-if="language.is_default">
                                                <label for="dark_mode_color">{{ __('dark_mode_color') ?
                                                    __('dark_mode_color') : 'Dark Mode Color' }}</label>
                                                <i class="text-danger">*</i>
                                                <div class="d-flex align-items-center">
                                                    <input type="color" id="dark_mode_color" name='dark_mode_color'
                                                        v-model="settings.dark_mode_color"
                                                        class="form-control form-control-color me-2"
                                                        style="width: 60px; height: 40px;" />
                                                    <input type="text" class="form-control"
                                                        v-model="settings.dark_mode_color" placeholder="#C8E5D5"
                                                        maxlength="7" />
                                                </div>
                                            </div>
                                            <div class="row mt-3 mb-3 align-items-baseline" v-if="language.is_default">
                                                <div class="col-sm-6 col-md-6 col-lg-4">
                                                    <FileUpload v-model="web_logo_file" :label="__('web_logo')" required
                                                        accept="image/*" recommended-size="512x512px"
                                                        :preview-url="web_logo_url" />
                                                </div>
                                                <div class="col-sm-6 col-md-6 col-lg-4">
                                                    <FileUpload v-model="favicon_file" :label="__('favicon_icon')"
                                                        required accept="image/*" recommended-size="64x64px"
                                                        :preview-url="favicon_url" />
                                                </div>
                                                <div class="col-sm-6 col-md-6 col-lg-4">
                                                    <FileUpload v-model="placeholder_image_file"
                                                        :label="__('placeholder_image')" required accept="image/*"
                                                        recommended-size="512x512px"
                                                        :preview-url="placeholder_image_url" />
                                                </div>
                                                <div class="col-sm-6 col-md-6 col-lg-4">
                                                    <FileUpload v-model="broken_image_file"
                                                        :label="__('broken_image')" accept="image/*"
                                                        recommended-size="512x512px"
                                                        :preview-url="broken_image_url" />
                                                </div>
                                            </div>
                                        </div>
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
                    </div>
                    <div class="card mb-3">

                        <div class="card-header">
                            <h4 class="card-title">
                                {{ __('app_download_section') }}
                            </h4>
                        </div>

                        <div class="card-body" v-if="activeLanguage">

                            <div class="row">

                                <!-- App Title (ALL languages) -->
                                <div class="form-group col-md-6">
                                    <label>{{ __('app_title') }}</label>
                                    <input type="text" v-model="webTranslations.app_title[activeLanguage.code]"
                                        class="form-control" :placeholder="__('enter_app_title')">
                                </div>

                                <!-- Short Description (ALL languages) -->
                                <div class="form-group col-md-6">
                                    <label>{{ __('short_description') }}</label>
                                    <textarea v-model="webTranslations.app_short_description[activeLanguage.code]"
                                        rows="1" class="form-control"
                                        :placeholder="__('enter_app_short_description_here')"></textarea>
                                </div>

                                <!-- Section image (not translatable) -->
                                <div class="col-md-6" v-if="activeLanguage.is_default">
                                    <FileUpload v-model="app_download_image_file" :label="__('app_download_image')"
                                        accept="image/*" recommended-size="800x600px"
                                        :preview-url="app_download_image_url" />
                                </div>

                                <div class="col-md-12" v-if="activeLanguage.is_default">
                                    <div class="row">
                                        <div class="col-12 col-lg-6 mb-3 mb-lg-0">
                                            <div class="border rounded p-3 h-100">
                                                <div class="mb-3">
                                                    <label>{{ __('android_app') }}</label>
                                                    <div class="form-check form-switch">
                                                        <input type="checkbox" true-value="1" false-value="0"
                                                            class="form-check-input" v-model="settings.is_android_app">
                                                    </div>
                                                </div>

                                                <div v-if="settings.is_android_app == 1" class="mb-4">
                                                    <div class="form-group">
                                                        <label>{{ __('android_application_url') }}</label>
                                                        <input type="text" v-model="settings.android_app_url"
                                                            class="form-control"
                                                            :placeholder="__('enter_android_app_url')" />
                                                    </div>

                                                    <FileUpload class="mt-3" v-model="play_store_logo_file"
                                                        :label="__('android_play_store_logo')" required
                                                        accept="image/*" recommended-size="200x60px"
                                                        :preview-url="play_store_logo_url" />
                                                </div>
                                            </div>
                                        </div>

                                        <!-- IOS SECTION: half width on lg+, full width on small screens; separate border -->
                                        <div class="col-12 col-lg-6">
                                            <div class="border rounded p-3 h-100">
                                                <div class="mb-3">
                                                    <label>{{ __('ios_app') }}</label>
                                                    <div class="form-check form-switch">
                                                        <input type="checkbox" true-value="1" false-value="0"
                                                            class="form-check-input" v-model="settings.is_ios_app">
                                                    </div>
                                                </div>

                                                <div v-if="settings.is_ios_app == 1">
                                                    <div class="form-group">
                                                        <label>{{ __('ios_application_url') }}</label>
                                                        <input type="text" v-model="settings.ios_app_url"
                                                            class="form-control"
                                                            :placeholder="__('enter_ios_app_url')" />
                                                    </div>

                                                    <FileUpload class="mt-3" v-model="ios_store_logo_file"
                                                        :label="__('ios_store_logo')" required accept="image/*"
                                                        recommended-size="200x60px"
                                                        :preview-url="ios_store_logo_url" />
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Cookie consent: toggle + per-language title/description (language follows the tabs above). -->
                    <div class="card mb-3">
                        <div class="card-header d-flex justify-content-between align-items-center">
                            <h4 class="card-title mb-0">{{ __('cookie_consent') }}</h4>
                            <div class="form-check form-switch mb-0">
                                <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                    v-model="settings.cookie_consent_enabled">
                            </div>
                        </div>
                        <div class="card-body" v-if="activeLanguage">
                            <div class="row">
                                <div class="form-group col-md-4">
                                    <label>{{ __('cookie_consent_title') }}</label>
                                    <input type="text"
                                        v-model="webTranslations.cookie_consent_title[activeLanguage.code]"
                                        class="form-control" :placeholder="__('cookie_consent_title')" />
                                </div>
                                <div class="form-group col-md-8">
                                    <label>{{ __('cookie_consent_description') }}</label>
                                    <textarea rows="2"
                                        v-model="webTranslations.cookie_consent_description[activeLanguage.code]"
                                        class="form-control" :placeholder="__('cookie_consent_description')"></textarea>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Installable app (PWA). One identity for both surfaces: the panel
                         builds its manifest from these, and the website is handed the same
                         values through the settings API. -->
                    <div class="card mb-3">
                        <div class="card-header">
                            <h4 class="card-title">{{ __('installable_app_pwa') }}</h4>
                            <small class="text-muted d-block">{{ __('installable_app_pwa_hint') }}</small>
                        </div>
                        <div class="card-body">
                            <div class="row">
                                <div class="form-group col-md-4 mt-0">
                                    <label for="pwa_name">{{ __('app_name') }}</label>
                                    <input type="text" id="pwa_name" v-model="settings.pwa_name"
                                        class="form-control" :placeholder="__('app_name')" maxlength="45" />
                                    <small class="text-muted">{{ __('shown_on_the_install_prompt') }}</small>
                                </div>
                                <div class="form-group col-md-4 mt-0">
                                    <label for="pwa_description">{{ __('description') }}</label>
                                    <textarea rows="2" id="pwa_description" v-model="settings.pwa_description"
                                        class="form-control" :placeholder="__('description')"></textarea>
                                </div>
                                <div class="col-md-4 mt-0">
                                    <FileUpload v-model="pwa_icon_file" :label="__('app_icon')"
                                        accept="image/png,image/jpeg,image/webp" recommended-size="512x512px"
                                        :preview-url="pwa_icon_url" />
                                    <small class="text-muted">{{ __('square_png_recommended_no_svg') }}</small>
                                </div>
                            </div>
                        </div>
                        <div class="card-footer d-flex justify-content-end">
                            <b-button type="submit" variant="primary" :disabled="isLoading">{{ __('update') }}
                                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
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
import { ArrowLeft } from 'lucide-vue-next';
import TranslationHelper from '../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

export default {
    mixins: [TranslationHelper, UnsavedChanges],
    components: { ArrowLeft },

    data: function () {
        return {
            languages: [],
            activeLanguageTab: null,
            defaultLanguageId: null,
            // Fields translated by the Translate control (code-keyed via the hooks below).
            translatableFields: ['site_title', 'common_meta_title', 'common_meta_description',
                'app_title', 'app_short_description', 'cookie_consent_title', 'cookie_consent_description'],

            webTranslations: {
                site_title: {},
                common_meta_title: {},
                common_meta_description: {},
                app_title: {},
                app_short_description: {},
                cookie_consent_title: {},
                cookie_consent_description: {},
            },

            colors: "",

            isLoading: false,
            settings: {},
            record: null,

            web_logo_url: "",
            web_logo_file: null,

            favicon_url: "",
            favicon_file: null,
            app_download_image_url: "",
            app_download_image_file: null,
            placeholder_image_url: "",
            placeholder_image_file: null,
            broken_image_url: "",
            broken_image_file: null,

            play_store_logo_url: "",
            play_store_logo_file: null,

            ios_store_logo_url: "",
            ios_store_logo_file: null,

            pwa_icon_url: "",
            pwa_icon_file: null,

        }
    },
    created: function () {
        //this.getSettings()
        this.getLanguages();
    },
    computed: {
        activeLanguage() {
            if (!this.languages.length) return null;
            const idStr = String(this.activeLanguageTab || '');
            const match = idStr.match(/^web-lang-tab-(\d+)$/);
            if (match) {
                const langId = parseInt(match[1], 10);
                return this.languages.find(l => l.id === langId) || null;
            }
            return this.languages.find(l => l.is_default) || this.languages[0] || null;
        }
    },

    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return {
                settings: this.settings,
                webTranslations: this.webTranslations,
                web_logo_file: this.web_logo_file,
                favicon_file: this.favicon_file,
                app_download_image_file: this.app_download_image_file,
                placeholder_image_file: this.placeholder_image_file,
                broken_image_file: this.broken_image_file,
                play_store_logo_file: this.play_store_logo_file,
                ios_store_logo_file: this.ios_store_logo_file,
            };
        },
        getLanguages() {
            axios.get(this.$apiUrl + '/active_languages').then(response => {
                this.languages = response.data.data || [];
                const def = this.languages.find(l => l.is_default);
                this.defaultLanguageId = def ? def.id : null;
                if (def) {
                    this.activeLanguageTab = 'web-lang-tab-' + def.id;
                }
                // after languages load → load settings
                this.getSettings();
            });
        },

        // Code-keyed field model: webTranslations[field][languageCode].
        // The mixin's default translations[langId][field] shape doesn't apply here.
        getTranslateSource() {
            const def = this.languages.find(l => l.is_default);
            if (!def || !def.code) return {};
            const source = {};
            (this.translatableFields || []).forEach((f) => {
                source[f] = (this.webTranslations[f] && this.webTranslations[f][def.code]) || '';
            });
            return source;
        },
        applyTranslated(lang, translated) {
            (this.translatableFields || []).forEach((f) => {
                const val = translated[f];
                if (val == null) return;
                if (!this.webTranslations[f]) this.webTranslations[f] = {};
                this.webTranslations[f][lang.code] = val;
            });
        },

        safeJson(value) {
            try {
                const parsed = JSON.parse(value);
                return (typeof parsed === 'object' && parsed !== null) ? parsed : null;
            } catch (e) {
                return null;
            }
        },
        ValidURL(str) {
            var regex = /(?:https?):\/\/(\w+:?\w*)?(\S+)(:\d+)?(\/|\/([\w#!:.?+=&%!\-\/]))?/;
            if (!regex.test(str)) {
                this.showError("Please enter valid URL.");
                return false;
            } else {
                return true;
            }
        },
        openUrl(url) {
            if (this.ValidURL(url)) {
                window.open(url, '__blank');
            }
        },
        getSettings() {
            axios.get(this.$apiUrl + '/web_settings').then((response) => {

                this.settings = response.data.data.settingsObject;
                this.record = response.data.data.settings;

                // Fill settings
                this.record.forEach((item) => {
                    this.settings[item.variable] = item.value;
                });

                // Now handle translations ONLY ONCE
                const translatableFields = [
                    'site_title',
                    'common_meta_title',
                    'common_meta_description',
                    'app_title',
                    'app_short_description',
                    'cookie_consent_title',
                    'cookie_consent_description'
                ];

                translatableFields.forEach(field => {

                    const raw = this.settings[field] || '';
                    const json = this.safeJson(raw);

                    if (!this.webTranslations[field]) {
                        this.webTranslations[field] = {};
                    }

                    this.languages.forEach(lang => {

                        // If JSON exists
                        if (json && typeof json === 'object') {

                            this.webTranslations[field][lang.code] = json[lang.code] ?? (lang.is_default ? raw : '');

                        } else {

                            // Fallback to plain text
                            this.webTranslations[field][lang.code] = lang.is_default ? raw : '';
                        }

                    });

                });

                // Images
                this.web_logo_url = this.settings.web_logo
                    ? this.$storageUrl + this.settings.web_logo
                    : this.$baseUrl + '/images/logo.png';

                this.favicon_url = this.settings.favicon
                    ? this.$storageUrl + this.settings.favicon
                    : '';

                this.app_download_image_url = this.settings.app_download_image
                    ? this.$storageUrl + this.settings.app_download_image
                    : '';

                this.placeholder_image_url = this.settings.placeholder_image
                    ? this.$storageUrl + this.settings.placeholder_image
                    : '';

                this.broken_image_url = this.settings.broken_image
                    ? this.$storageUrl + this.settings.broken_image
                    : '';

                this.play_store_logo_url = this.settings.play_store_logo
                    ? this.$storageUrl + this.settings.play_store_logo
                    : '';

                this.ios_store_logo_url = this.settings.ios_store_logo
                    ? this.$storageUrl + this.settings.ios_store_logo
                    : '';

                this.pwa_icon_url = this.settings.pwa_icon
                    ? this.$storageUrl + this.settings.pwa_icon
                    : '';

                // Snapshot the loaded settings as the "clean" baseline for the guard.
                this.captureFormBaseline();
            });
        },

        validateDefaultLanguage() {
            if (!this.defaultLanguageId) {
                this.showError(__('default_language_not_found'));
                return false;
            }

            const defaultLang = this.languages.find(l => l.id === this.defaultLanguageId);
            if (!defaultLang || !defaultLang.code) {
                this.showError(__('default_language_not_found'));
                return false;
            }

            // Validate all required default language fields
            const siteTitle = this.webTranslations?.site_title?.[defaultLang.code];
            const commonMetaTitle = this.webTranslations?.common_meta_title?.[defaultLang.code];
            const commonMetaDesc = this.webTranslations?.common_meta_description?.[defaultLang.code];
            const websiteUrl = this.settings?.website_url || '';
            const color = this.settings?.light_mode_color || '';
            const lightColor = this.settings?.dark_mode_color || '';

            const isEmpty = (v) => !v || String(v).trim() === '';

            if (isEmpty(siteTitle)) {
                this.showError(__('please_fill_site_title_in_default_language'));
                this.switchToDefaultLanguageTab();
                return false;
            }
            if (isEmpty(commonMetaTitle)) {
                this.showError(__('please_fill_default_language_required_fields'));
                this.switchToDefaultLanguageTab();
                return false;
            }
            if (isEmpty(commonMetaDesc)) {
                this.showError(__('please_fill_default_language_required_fields'));
                this.switchToDefaultLanguageTab();
                return false;
            }
            if (isEmpty(websiteUrl)) {
                this.showError(__('please_fill_default_language_required_fields'));
                this.switchToDefaultLanguageTab();
                return false;
            }
            if (isEmpty(color) || isEmpty(lightColor)) {
                this.showError(__('please_fill_default_language_required_fields'));
                this.switchToDefaultLanguageTab();
                return false;
            }

            return true;
        },

        switchToDefaultLanguageTab() {
            if (this.defaultLanguageId) {
                this.activeLanguageTab = 'web-lang-tab-' + this.defaultLanguageId;
            }
        },

        saveRecord: function () {
            if (!this.validateDefaultLanguage()) return;
            this.isLoading = true;
            let settingsObject = this.settings;
            let formData = new FormData();
            const fileKeys = ['web_logo', 'favicon', 'placeholder_image', 'broken_image', 'play_store_logo', 'ios_store_logo', 'app_download_image', 'pwa_icon', 'loading'];
            for (let key in settingsObject) {
                const val = settingsObject[key];
                if (val === undefined || val === null) continue;
                if (val instanceof File) {
                    formData.append(key, val, val.name);
                } else if (!fileKeys.includes(key) || typeof val === 'string') {
                    formData.append(key, val);
                }
            }
            // Files picked via <FileUpload> (v-model) override the stored string paths.
            const pickedFiles = {
                web_logo: this.web_logo_file,
                favicon: this.favicon_file,
                placeholder_image: this.placeholder_image_file,
                broken_image: this.broken_image_file,
                app_download_image: this.app_download_image_file,
                play_store_logo: this.play_store_logo_file,
                ios_store_logo: this.ios_store_logo_file,
                pwa_icon: this.pwa_icon_file,
            };
            Object.entries(pickedFiles).forEach(([key, file]) => {
                if (file instanceof File) {
                    formData.set(key, file, file.name);
                }
            });
            const cleanLangObject = (obj = {}) => {
                const cleaned = {};
                Object.keys(obj).forEach(lang => {
                    let value = obj[lang];
                    if (typeof value === 'string') {
                        value = value.replace(/\r?\n|\r/g, ' ')
                            .replace(/\s+/g, ' ')
                            .trim();
                    }
                    cleaned[lang] = value || '';
                });
                return cleaned;
            };

            formData.append('site_title', JSON.stringify(cleanLangObject(this.webTranslations.site_title)));
            formData.append('common_meta_title', JSON.stringify(cleanLangObject(this.webTranslations.common_meta_title)));
            formData.append('common_meta_description', JSON.stringify(cleanLangObject(this.webTranslations.common_meta_description)));
            formData.append('app_title', JSON.stringify(cleanLangObject(this.webTranslations.app_title)));
            formData.append('app_short_description', JSON.stringify(cleanLangObject(this.webTranslations.app_short_description)));
            formData.append('cookie_consent_title', JSON.stringify(cleanLangObject(this.webTranslations.cookie_consent_title)));
            formData.append('cookie_consent_description', JSON.stringify(cleanLangObject(this.webTranslations.cookie_consent_description)));

            let url = this.$apiUrl + '/web_settings/save';
            let vm = this;
            axios.post(url, formData).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    this.showMessage("success", data.message);
                    // getSettings() pulls the saved values back in — no page reload needed.
                    this.getSettings();
                    // Mark clean after a successful save (page stays put).
                    this.captureFormBaseline();
                    vm.$swal.close();
                    vm.isLoading = false;
                } else {
                    vm.showError(data.message);
                    vm.isLoading = false;
                }
            }).catch(error => {
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError("Something went wrong!");
                }
                vm.isLoading = false;
            });
        }
    }
}
</script>
<style scoped>
/* Keep label inline so the * sits beside it, not below */
.form-group label {
    display: inline;
}
</style>