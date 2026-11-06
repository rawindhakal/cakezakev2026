<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('general_settings') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>
            <section class="section">
                <div class="settings-section">
                    <div class="row">
                        <div class="col-12">
                            <div>
                                <!-- Branch basics: identity, logo, copyright + address. -->
                                <div>
                                    <div class="card">
                                        <div class="card-body">
                                            <form method="post" enctype="multipart/form-data"
                                                @submit.prevent="saveStoreBasicSetting" novalidate>

                                                <b-tabs v-model="activeLanguageTab" content-class="mt-3" :lazy="false"
                                                    :nav-class="languages.length <= 1 ? 'd-none' : null">
                                                    <b-tab v-for="language in languages" :key="language.id"
                                                        :id="'branch-lang-tab-' + language.id">
                                                        <template #title>
                                                            <span
                                                                :class="{ 'text-primary font-weight-bold': language.is_default }">
                                                                {{ language.name }}
                                                            </span>
                                                        </template>

                                                        <div class="row">

                                                            <template v-if="language.is_default">
                                                                <input type="hidden"
                                                                    v-model="store_settings.system_configurations">
                                                                <input type="hidden"
                                                                    v-model="store_settings.system_configurations_id">
                                                            </template>

                                                            <div class="form-group col-12 col-md-4 mb-3 mt-0"
                                                                v-if="language.is_default">
                                                                <label for="app_name">{{ __('app_name') }}:</label>
                                                                <input type="text" class="form-control" required
                                                                    name="app_name" id="app_name"
                                                                    v-model="store_settings.app_name"
                                                                    placeholder="Name of the App - used in whole system" />

                                                            </div>

                                                            <div class="form-group col-12 col-md-4 mb-3"
                                                                v-if="language.is_default">
                                                                <label>{{ __('support_number') }}</label>
                                                                <input type="text" class="form-control"
                                                                    v-model="store_settings.support_number"
                                                                    inputmode="numeric" @input="validateMobileNumber" />
                                                                <span v-if="mobilevalidationError" class="error">
                                                                    {{ mobilevalidationError }}
                                                                </span>
                                                            </div>

                                                            <div class="form-group col-12 col-md-4 mb-3"
                                                                v-if="language.is_default">
                                                                <label>{{ __('support_email') }}</label>
                                                                <input type="email" class="form-control"
                                                                    v-model="store_settings.support_email" />
                                                            </div>

                                                            <div class="form-group col-md-6">
                                                                <label>{{ __('copyright_details') }}</label>
                                                                <input type="text" class="form-control"
                                                                    v-model="branchTranslations.copyright_details[language.code]"
                                                                    :placeholder="__('enter_copyright_details_here')" />
                                                            </div>

                                                            <div class="form-group col-md-6">
                                                                <label for="branch_address">{{ __('address') }}</label>
                                                                <input type="text" class="form-control"
                                                                    name="branch_address" id="branch_address"
                                                                    v-model="addressTranslations.branch_address[language.code]" />
                                                            </div>

                                                            <!-- The text above is only words; this is the Google Maps link to the
                                                                 exact spot (Share → Copy link). Same for every language. -->
                                                            <div class="form-group col-12" v-if="language.is_default">
                                                                <label for="store_map_url">{{ __('map_location_link') }}</label>
                                                                <input type="url" class="form-control" id="store_map_url"
                                                                    v-model="store_settings.store_map_url"
                                                                    placeholder="https://maps.app.goo.gl/..." />
                                                                <small class="text-muted d-block">{{ __('map_location_link_hint') }}</small>
                                                            </div>

                                                            <div class="form-group col-12 col-md-4 mb-3"
                                                                v-if="language.is_default">
                                                                <label>{{ __('order_prefix') }}</label>
                                                                <input type="text" class="form-control"
                                                                    v-model="store_settings.order_prefix"
                                                                    placeholder="ORD-" />
                                                                <small class="text-muted d-block">{{
                                                                    __('order_prefix_help') }}</small>
                                                            </div>

                                                            <div class="form-group col-12 col-md-4 mb-3"
                                                                v-if="language.is_default">
                                                                <label>{{ __('return_request_prefix') }}</label>
                                                                <input type="text" class="form-control"
                                                                    v-model="store_settings.return_request_prefix"
                                                                    placeholder="RET-" />
                                                                <small class="text-muted d-block">{{
                                                                    __('return_request_prefix_help') }}</small>
                                                            </div>

                                                            <div class="form-group col-12 col-md-4 mb-3"
                                                                v-if="language.is_default">
                                                                <label>{{ __('invoice_prefix') }}</label>
                                                                <input type="text" class="form-control"
                                                                    v-model="store_settings.invoice_prefix"
                                                                    placeholder="INV-" />
                                                                <small class="text-muted d-block">{{
                                                                    __('invoice_prefix_help') }}</small>
                                                            </div>
                                                        </div>

                                                    </b-tab>

                                                    <!-- Translate control, inline with the language tabs. -->
                                                    <template #tabs-end>
                                                        <li class="nav-item ms-auto d-flex align-items-center">
                                                            <TranslateLanguages :languages="languages"
                                                                :default-language-id="defaultLanguageId"
                                                                :busy="translating" :progress="translateProgress"
                                                                @translate="ids => translateScoped('branch', ids)" />
                                                        </li>
                                                    </template>
                                                </b-tabs>

                                                <div class="row">
                                                    <div class="form-group col-md-4">
                                                        <label for="max_cart_items_count">{{
                                                            __('maximum_items_allowed_in_cart') }}</label>
                                                        <i class="text-danger">*</i>
                                                        <input type="number" required class="form-control"
                                                            name="max_cart_items_count" id="max_cart_items_count"
                                                            v-model="store_settings.max_cart_items_count"
                                                            :placeholder="__('maximum_items_allowed_in_cart')"
                                                            min="1" />
                                                        <small class="text-muted d-block">{{
                                                            __('maximum_items_user_can_add_to_cart_at_once') }}</small>
                                                    </div>

                                                    <div class="form-group col-md-4">
                                                        <label for="admin_theme_color">{{ __('admin_theme_color')
                                                        }}</label>
                                                        <div class="d-flex align-items-center gap-2">
                                                            <input type="color" id="admin_theme_color"
                                                                name="admin_theme_color"
                                                                v-model="store_settings.admin_theme_color"
                                                                @input="applyAdminThemeColor(store_settings.admin_theme_color)"
                                                                class="form-control form-control-color"
                                                                style="width: 60px; height: 38px;" />
                                                            <input type="text" class="form-control"
                                                                v-model="store_settings.admin_theme_color"
                                                                @input="applyAdminThemeColor(store_settings.admin_theme_color)"
                                                                placeholder="#435ebe" maxlength="7" />
                                                        </div>
                                                        <small class="text-muted d-block">{{
                                                            __('primary_color_used_across_admin_panel') }}</small>
                                                    </div>

                                                    <div class="form-group col-md-4">
                                                        <label class="d-block" for="rating">{{ __('product_rating')
                                                        }}</label>
                                                        <div class="form-check form-switch">
                                                            <input type="checkbox" true-value="1" false-value="0"
                                                                class="form-check-input" name="rating" id="rating"
                                                                v-model="store_settings.product_rating">
                                                        </div>
                                                        <small class="text-muted d-block">{{
                                                            __('enable_and_disable_product_rating_system') }}</small>
                                                    </div>

                                                    <div v-if="courierAvailable" class="form-group col-md-4">
                                                        <label class="d-block" for="pincode_delivery_check">{{
                                                            __('pincode_delivery_check') }}</label>
                                                        <div class="form-check form-switch">
                                                            <input type="checkbox" true-value="1" false-value="0"
                                                                class="form-check-input" name="pincode_delivery_check"
                                                                id="pincode_delivery_check"
                                                                v-model="store_settings.pincode_delivery_check">
                                                        </div>
                                                        <small class="text-muted d-block">{{
                                                            __('pincode_delivery_check_hint') }}</small>
                                                    </div>
                                                </div>

                                                <div class="col-md-12">
                                                    <div class="row">
                                                        <!-- LOGO -->
                                                        <div class="col-12 col-md-4 mb-3 mt-0">
                                                            <FileUpload v-model="logo_file" :label="__('logo')"
                                                                accept="image/*" recommended-size="512x512px"
                                                                :max-size-mb="2" :preview-url="logo_url" />
                                                        </div>

                                                        <!-- FAVICON (admin panel browser tab icon) -->
                                                        <div class="col-12 col-md-4 mb-3">
                                                            <FileUpload v-model="admin_favicon_file"
                                                                :label="__('favicon')" accept="image/*"
                                                                recommended-size="64x64px" :max-size-mb="2"
                                                                :preview-url="admin_favicon_url" />
                                                        </div>

                                                        <!-- PANEL LOGIN BACKGROUND -->
                                                        <div class="col-12 col-md-4 mb-3">
                                                            <FileUpload v-model="panel_login_background_img_file"
                                                                :label="__('panel_login_background_img')"
                                                                accept="image/*" recommended-size="1920x1080px"
                                                                :max-size-mb="2"
                                                                :preview-url="panel_login_background_img_url" />
                                                        </div>

                                                    </div>
                                                </div>

                                                <div class="d-flex justify-content-end">
                                                    <b-button type="submit" variant="primary" :disabled="isLoading"
                                                        v-if="$can('manage_general_settings')">
                                                        {{ __('update') }}
                                                        <b-spinner v-if="isLoading" small></b-spinner>
                                                    </b-button>
                                                </div>
                                            </form>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
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

    components: {
        ArrowLeft,
    },
    data: function () {
        return {
            addressTranslations: {
                branch_address: {}
            },

            branchTranslations: {
                app_name: {},
                copyright_details: {}
            },

            isLoadingLanguages: false,

            languages: [],
            defaultLanguageId: null,
            activeLanguageTab: null,

            isLoading: false,
            store_settings: {},
            // Is a courier plugin installed and configured? Drives the pincode-check switch.
            courierAvailable: false,
            record: null,
            currency_codes: null,
            logo_url: "",
            logo_file: null,
            admin_favicon_url: "",
            admin_favicon_file: null,
            panel_login_background_img_url: "",
            panel_login_background_img_file: null,
            validationCategoryError: null,
            validationBrandError: null,
            validationBranchError: null,
            validationCountryError: null,
            mobilevalidationError: null,
        }
    },

    computed: {

        // Fields the Translate control sends.
        translatableFields() {
            return ['copyright_details'];
        },
    },

    created() {
        this.bootstrap();
    },

    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return {
                store_settings: this.store_settings,
                branchTranslations: this.branchTranslations,
                addressTranslations: this.addressTranslations,
                logo_file: this.logo_file,
                admin_favicon_file: this.admin_favicon_file,
                panel_login_background_img_file: this.panel_login_background_img_file,
            };
        },
        async bootstrap() {
            try {
                this.isLoading = true;
                await this.fetchActiveLanguages();
                await this.getStoreSetting();

            } finally {
                this.isLoading = false;
            }
        },

        safeJson(value) {
            if (!value) return null;

            try {
                const parsed = JSON.parse(value);
                return typeof parsed === 'object' ? parsed : null;
            } catch (e) {
                return null; // not JSON
            }
        },

        validateMobileNumber() {
            const mobileNumber = this.store_settings.support_number;
            if (!/^\d{1,16}$/.test(mobileNumber)) {
                this.mobilevalidationError = "Support Number must be maximum 16 digits numbers.";
                this.store_settings.support_number = null;
            } else {
                this.mobilevalidationError = null;
            }
        },

        getStoreSetting() {
            let url = this.$apiUrl + '/store_settings';
            let vm = this;
            axios.get(url).then((response) => {
                this.store_settings = response.data.data.store_settingsObject;
                this.courierAvailable = !!response.data.data.courier_available;

                this.currency_codes = response.data.data.currency_code.country;

                this.record = response.data.data.store_settings;
                this.record.map((item, index) => {

                    if (item.value === '0' || item.value === '1') {
                        this.store_settings[item.variable] = (item.value === '0') ? 0 : 1;
                    } else {
                        this.store_settings[item.variable] = item.value;
                    }
                });
                if (this.store_settings.logo != "") {
                    this.logo_url = this.$storageUrl + this.store_settings.logo;
                } else {
                    this.logo_url = this.$baseUrl + '/images/logo.png';
                }
                if (this.store_settings.admin_favicon) {
                    this.admin_favicon_url = this.$storageUrl + this.store_settings.admin_favicon;
                } else {
                    this.admin_favicon_url = this.$baseUrl + '/images/favicon.png';
                }
                if (this.store_settings.panel_login_background_img != "") {
                    this.panel_login_background_img_url = this.$storageUrl + this.store_settings.panel_login_background_img;
                } else {
                    this.panel_login_background_img_url = this.$baseUrl + '/images/panel_login_background_img.png';
                }
                // Guard against null/undefined before replace — a crash here aborts the whole callback
                const copyrightRaw = this.store_settings.copyright_details
                    ? this.store_settings.copyright_details.replace(/<br\s*\/?>/g, '\n')
                    : '';

                const copyrightJson = this.safeJson(copyrightRaw);

                if (Array.isArray(this.languages) && this.languages.length) {

                    this.languages.forEach(lang => {

                        if (copyrightJson) {
                            // Apply br-replace per language value (safe — applied to text, not raw JSON)
                            const val = (copyrightJson[lang.code] || '').replace(/<br\s*\/?>/g, '\n');
                            this.branchTranslations.copyright_details[lang.code] = val;
                        } else {
                            this.branchTranslations.copyright_details[lang.code] = lang.is_default ? (copyrightRaw || '') : '';
                        }

                    });
                }

                this.addressTranslations.branch_address = {};

                const branchAddressRaw = this.store_settings.branch_address || '';
                const branchAddressJson = this.safeJson(branchAddressRaw);

                if (Array.isArray(this.languages) && this.languages.length) {

                    this.languages.forEach(lang => {

                        if (branchAddressJson) {
                            this.addressTranslations.branch_address[lang.code] = branchAddressJson[lang.code] || '';
                        } else {
                            this.addressTranslations.branch_address[lang.code] = lang.is_default ? (branchAddressRaw || '') : '';
                        }

                    });

                }

                // Snapshot the loaded settings as the "clean" baseline for the guard.
                this.captureFormBaseline();
            });
        },


// Apply primary color live to the panel + persist on window
        applyAdminThemeColor(color) {
            if (typeof window.applyAdminThemeColor === 'function') {
                window.applyAdminThemeColor(color);
            }
        },

        // Save app settings
        saveStoreBasicSetting() {
            this.isLoading = true;

            const formData = new FormData();

            // Normal fields (default only). The last three came from the old
            // "Other settings" area — they are general branch preferences.
            const normalFields = [
                'app_name',
                'system_configurations', 'system_configurations_id',
                'support_number', 'support_email', 'store_map_url',
                'max_cart_items_count', 'product_rating', 'pincode_delivery_check', 'admin_theme_color',
                'order_prefix', 'return_request_prefix', 'invoice_prefix'
            ];

            normalFields.forEach(field => {
                if (this.store_settings[field] !== undefined) {
                    formData.append(field, this.store_settings[field]);
                }
            });

            // Default language required check
            const defaultLang = this.languages.find(lang => lang.is_default);

            if (!this.branchTranslations.copyright_details[defaultLang.code]) {
                this.showError('Copyright Details (default language) are required!');
                this.isLoading = false;
                return;
            }

            // Multilingual fields
            const cleanLangObject = (obj = {}) => {
                const cleaned = {};
                Object.keys(obj).forEach(lang => {
                    let value = obj[lang];
                    if (typeof value === 'string') {
                        value = value.replace(/\r?\n|\r/g, ' ').replace(/\s+/g, ' ').trim();
                    }
                    cleaned[lang] = value || '';
                });
                return cleaned;
            };

            //   formData.append('app_name', JSON.stringify(cleanLangObject(this.branchTranslations.app_name)));
            formData.append('copyright_details', JSON.stringify(cleanLangObject(this.branchTranslations.copyright_details)));
            // Branch address is part of the branch basics now (sits beside copyright).
            formData.append('branch_address', JSON.stringify(cleanLangObject(this.addressTranslations.branch_address)));

            // Files (default language only)
            if (this.logo_file) formData.append('logo', this.logo_file);
            if (this.admin_favicon_file) formData.append('admin_favicon', this.admin_favicon_file);
            if (this.panel_login_background_img_file) formData.append('panel_login_background_img', this.panel_login_background_img_file);

            axios.post(this.$apiUrl + '/store_settings/save_store_basic_setting', formData)
                .then(res => {
                    if (res.data.status === 1) {
                        this.showMessage('success', res.data.message);
                        this.getStoreSetting();
                        // Mark clean after a successful save (page stays put).
                        this.captureFormBaseline();
                    } else {
                        this.showError(res.data.message);
                    }
                    this.isLoading = false;
                })
                .catch(err => {
                    this.isLoading = false;
                    this.showError(err?.response?.data?.message || err.message || __('something_went_wrong'));
                });
        },

        fetchActiveLanguages() {
            if (this.languages.length) {
                return Promise.resolve(this.languages);
            }

            this.isLoadingLanguages = true;

            return axios.get(this.$apiUrl + '/active_languages')
                .then(res => {
                    this.languages = res.data.data || [];

                    const def = this.languages.find(l => l.is_default == 1);
                    this.defaultLanguageId = def ? def.id : null;
                    if (def) {
                        this.activeLanguageTab = 'branch-lang-tab-' + def.id;
                    }

                    // init empty translation shells ONCE
                    this.initTranslationShells();

                    return this.languages;
                })
                .finally(() => {
                    this.isLoadingLanguages = false;
                });
        },
        initTranslationShells() {
            this.languages.forEach(lang => {
                this.branchTranslations.app_name[lang.code] = '';
                this.branchTranslations.copyright_details[lang.code] = '';
            });
        },

        // TranslationHelper hooks. Copyright is the only translated field on this page.
        translateScoped(scope, langIds) {
            this.$nextTick(() => this.runTranslate(langIds));
        },
        getTranslateSource() {
            const def = this.languages.find(l => l.is_default);
            if (!def || !def.code) return {};
            return {
                copyright_details: (this.branchTranslations.copyright_details || {})[def.code] || '',
            };
        },
        applyTranslated(lang, translated) {
            const val = translated.copyright_details;
            if (val == null) return;
            if (!this.branchTranslations.copyright_details) this.branchTranslations.copyright_details = {};
            this.branchTranslations.copyright_details[lang.code] = val;
        },

    },

};
</script>
<style scoped>
</style>
