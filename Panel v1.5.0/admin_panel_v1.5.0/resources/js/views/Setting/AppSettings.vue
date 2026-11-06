<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('app_setting') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
                <form method="post" enctype="multipart/form-data" @submit.prevent="saveAppSetting">
                    <div class="card">
                        <div class="card-header">
                            <h4 class="card-title">{{ __('customer_app') }}</h4>
                        </div>
                        <div class="card-body">
                            <div class="row">
                                <div class="form-group col-md-6">
                                    <label for="playstore_url">{{ __('customer_playstore_url')
                                    }}</label>
                                    <input type="url" class="form-control" name="playstore_url" id="playstore_url"
                                        v-model="store_settings.playstore_url"
                                        :placeholder='__("customer_playstore_url")' />
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="appstore_url">{{ __('customer_appstore_url')
                                    }}</label>
                                    <input type="url" class="form-control" name="appstore_url" id="appstore_url"
                                        v-model="store_settings.appstore_url"
                                        :placeholder='__("customer_appstore_url")' />
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="customer_light_mode_color">{{
                                        __('customer_light_mode_color') }}</label>
                                    <div class="d-flex align-items-center gap-2">
                                        <input type="color" id="customer_light_mode_color"
                                            name="customer_light_mode_color"
                                            v-model="store_settings.customer_light_mode_color"
                                            class="form-control form-control-color"
                                            style="width: 60px; height: 38px;" />
                                        <input type="text" class="form-control"
                                            v-model="store_settings.customer_light_mode_color" placeholder="#FE3C5E"
                                            maxlength="7" />
                                    </div>
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="customer_dark_mode_color">{{
                                        __('customer_dark_mode_color') }}</label>
                                    <div class="d-flex align-items-center gap-2">
                                        <input type="color" id="customer_dark_mode_color"
                                            name="customer_dark_mode_color"
                                            v-model="store_settings.customer_dark_mode_color"
                                            class="form-control form-control-color"
                                            style="width: 60px; height: 38px;" />
                                        <input type="text" class="form-control"
                                            v-model="store_settings.customer_dark_mode_color" placeholder="#1A2A3A"
                                            maxlength="7" />
                                    </div>
                                </div>
                            </div>

                            <div class="list-group-item m-0 mt-2">
                                <h6 class="mb-0">{{ __('version_management') }}</h6>
                                <p class="text text-muted font-size-13 mb-0">
                                    {{ __('version_management_hint') }}
                                </p>
                                <div class="row mt-2">
                                    <div class="form-group col-md-4">
                                        <label class="d-block" for="is_version_system_on_customer">{{
                                            __('android_version_system_status')
                                        }}</label>
                                        <div class="form-check form-switch">
                                            <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                                name="is_version_system_on_customer" id="is_version_system_on_customer"
                                                v-model="store_settings.is_version_system_on_customer">
                                        </div>
                                    </div>
                                    <div class="form-group col-md-4" v-if="store_settings.is_version_system_on_customer == 1">
                                        <label class="d-block" for="required_force_update_customer">{{
                                            __('android_required_force_update')
                                        }}</label>
                                        <div class="form-check form-switch">
                                            <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                                name="required_force_update_customer" id="required_force_update_customer"
                                                v-model="store_settings.required_force_update_customer">
                                        </div>
                                    </div>
                                    <div class="form-group col-md-4" v-if="store_settings.is_version_system_on_customer == 1">
                                        <label for="current_version_customer">{{
                                            __('android_current_version_of_app') }}</label>
                                        <input type="text" class="form-control" required name="current_version_customer"
                                            id="current_version_customer" v-model="store_settings.current_version_customer"
                                            placeholder='Android Current Version' />
                                    </div>
                                    <div class="form-group col-md-4">
                                        <label class="d-block" for="ios_is_version_system_on_customer">{{
                                            __('ios_version_system_status')
                                        }}</label>
                                        <div class="form-check form-switch">
                                            <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                                name="ios_is_version_system_on_customer" id="ios_is_version_system_on_customer"
                                                v-model="store_settings.ios_is_version_system_on_customer">
                                        </div>
                                    </div>
                                    <div class="form-group col-md-4" v-if="store_settings.ios_is_version_system_on_customer == 1">
                                        <label class="d-block" for="ios_required_force_update_customer">{{
                                            __('ios_required_force_update')
                                        }}</label>
                                        <div class="form-check form-switch">
                                            <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                                name="ios_required_force_update_customer" id="ios_required_force_update_customer"
                                                v-model="store_settings.ios_required_force_update_customer">
                                        </div>
                                    </div>
                                    <div class="form-group col-md-4" v-if="store_settings.ios_is_version_system_on_customer == 1">
                                        <label for="ios_current_version_customer">{{
                                            __('ios_current_version_of_app') }}</label>
                                        <input type="text" class="form-control" required name="ios_current_version_customer"
                                            id="ios_current_version_customer" v-model="store_settings.ios_current_version_customer"
                                            placeholder='IOS Current Version' />
                                    </div>
                                    <div class="form-group col-md-4"
                                        v-if="store_settings.is_version_system_on_customer == 1 || store_settings.ios_is_version_system_on_customer == 1">
                                        <label class="d-block" for="notify_version_update_customer">
                                            {{ __('notify_users_on_version_update') }}
                                            <i class="fa fa-circle-info text-muted ms-1" v-b-tooltip.hover
                                                :title="__('notify_users_on_version_update_hint')"></i>
                                        </label>
                                        <div class="form-check form-switch">
                                            <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                                name="notify_version_update_customer" id="notify_version_update_customer"
                                                v-model="store_settings.notify_version_update_customer">
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="card">
                        <div class="card-header">
                            <h4 class="card-title">{{ __('delivery_boy_app') }}</h4>
                        </div>
                        <div class="card-body">
                            <div class="row">
                                <div class="form-group col-md-6">
                                    <label for="delivery_boy_playstore_url">{{
                                        __('delivery_boy_playstore_url') }}</label>
                                    <input type="url" class="form-control" name="delivery_boy_playstore_url"
                                        id="delivery_boy_playstore_url"
                                        v-model="store_settings.delivery_boy_playstore_url"
                                        :placeholder='__("delivery_boy_playstore_url")' />
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="delivery_boy_appstore_url">{{
                                        __('delivery_boy_appstore_url') }}</label>
                                    <input type="url" class="form-control" name="delivery_boy_appstore_url"
                                        id="delivery_boy_appstore_url"
                                        v-model="store_settings.delivery_boy_appstore_url"
                                        :placeholder='__("delivery_boy_appstore_url")' />
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="delivery_boy_light_mode_color">{{
                                        __('delivery_boy_light_mode_color') }}</label>
                                    <div class="d-flex align-items-center gap-2">
                                        <input type="color" id="delivery_boy_light_mode_color"
                                            name="delivery_boy_light_mode_color"
                                            v-model="store_settings.delivery_boy_light_mode_color"
                                            class="form-control form-control-color"
                                            style="width: 60px; height: 38px;" />
                                        <input type="text" class="form-control"
                                            v-model="store_settings.delivery_boy_light_mode_color" placeholder="#FE3C5E"
                                            maxlength="7" />
                                    </div>
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="delivery_boy_dark_mode_color">{{
                                        __('delivery_boy_dark_mode_color') }}</label>
                                    <div class="d-flex align-items-center gap-2">
                                        <input type="color" id="delivery_boy_dark_mode_color"
                                            name="delivery_boy_dark_mode_color"
                                            v-model="store_settings.delivery_boy_dark_mode_color"
                                            class="form-control form-control-color"
                                            style="width: 60px; height: 38px;" />
                                        <input type="text" class="form-control"
                                            v-model="store_settings.delivery_boy_dark_mode_color" placeholder="#1A2A3A"
                                            maxlength="7" />
                                    </div>
                                </div>
                            </div>

                            <div class="list-group-item m-0 mt-2">
                                <h6 class="mb-0">{{ __('version_management') }}</h6>
                                <p class="text text-muted font-size-13 mb-0">
                                    {{ __('version_management_hint') }}
                                </p>
                                <div class="row mt-2">
                                    <div class="form-group col-md-4">
                                        <label class="d-block" for="is_version_system_on_delivery_boy">{{
                                            __('android_version_system_status')
                                        }}</label>
                                        <div class="form-check form-switch">
                                            <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                                name="is_version_system_on_delivery_boy" id="is_version_system_on_delivery_boy"
                                                v-model="store_settings.is_version_system_on_delivery_boy">
                                        </div>
                                    </div>
                                    <div class="form-group col-md-4" v-if="store_settings.is_version_system_on_delivery_boy == 1">
                                        <label class="d-block" for="required_force_update_delivery_boy">{{
                                            __('android_required_force_update')
                                        }}</label>
                                        <div class="form-check form-switch">
                                            <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                                name="required_force_update_delivery_boy" id="required_force_update_delivery_boy"
                                                v-model="store_settings.required_force_update_delivery_boy">
                                        </div>
                                    </div>
                                    <div class="form-group col-md-4" v-if="store_settings.is_version_system_on_delivery_boy == 1">
                                        <label for="current_version_delivery_boy">{{
                                            __('android_current_version_of_app') }}</label>
                                        <input type="text" class="form-control" required name="current_version_delivery_boy"
                                            id="current_version_delivery_boy" v-model="store_settings.current_version_delivery_boy"
                                            placeholder='Android Current Version' />
                                    </div>
                                    <div class="form-group col-md-4">
                                        <label class="d-block" for="ios_is_version_system_on_delivery_boy">{{
                                            __('ios_version_system_status')
                                        }}</label>
                                        <div class="form-check form-switch">
                                            <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                                name="ios_is_version_system_on_delivery_boy" id="ios_is_version_system_on_delivery_boy"
                                                v-model="store_settings.ios_is_version_system_on_delivery_boy">
                                        </div>
                                    </div>
                                    <div class="form-group col-md-4" v-if="store_settings.ios_is_version_system_on_delivery_boy == 1">
                                        <label class="d-block" for="ios_required_force_update_delivery_boy">{{
                                            __('ios_required_force_update')
                                        }}</label>
                                        <div class="form-check form-switch">
                                            <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                                name="ios_required_force_update_delivery_boy" id="ios_required_force_update_delivery_boy"
                                                v-model="store_settings.ios_required_force_update_delivery_boy">
                                        </div>
                                    </div>
                                    <div class="form-group col-md-4" v-if="store_settings.ios_is_version_system_on_delivery_boy == 1">
                                        <label for="ios_current_version_delivery_boy">{{
                                            __('ios_current_version_of_app') }}</label>
                                        <input type="text" class="form-control" required name="ios_current_version_delivery_boy"
                                            id="ios_current_version_delivery_boy" v-model="store_settings.ios_current_version_delivery_boy"
                                            placeholder='IOS Current Version' />
                                    </div>
                                    <div class="form-group col-md-4"
                                        v-if="store_settings.is_version_system_on_delivery_boy == 1 || store_settings.ios_is_version_system_on_delivery_boy == 1">
                                        <label class="d-block" for="notify_version_update_delivery_boy">
                                            {{ __('notify_users_on_version_update') }}
                                            <i class="fa fa-circle-info text-muted ms-1" v-b-tooltip.hover
                                                :title="__('notify_users_on_version_update_hint')"></i>
                                        </label>
                                        <div class="form-check form-switch">
                                            <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                                name="notify_version_update_delivery_boy" id="notify_version_update_delivery_boy"
                                                v-model="store_settings.notify_version_update_delivery_boy">
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <hr class="my-2">
                            <div class="row">

                                <div class="form-group col-12 mt-0">
                                    <label for="delivery_boy_bonus_settings">{{
                                        __('bonus_settings') }}</label><br>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            name="delivery_boy_bonus_settings" id="delivery_boy_bonus_settings"
                                            v-model="store_settings.delivery_boy_bonus_settings">
                                    </div>
                                </div>
                                <div v-if="store_settings.delivery_boy_bonus_settings == 1"
                                    class="form-group col-md-6 col-lg-3">
                                    <label for="delivery_boy_bonus_type">{{ __('bonus_type')
                                    }}</label>
                                    <AppSelect class="form-control form-select" v-model="store_settings.delivery_boy_bonus_type" :options="delivery_boy_bonus_typeOptions" :searchable="false" />
                                </div>
                                <div v-if="store_settings.delivery_boy_bonus_settings == 1 && store_settings.delivery_boy_bonus_type == 1"
                                    class="form-group col-md-6 col-lg-3">
                                    <label for="delivery_boy_bonus_percentage">{{
                                        __('delivery_boy_bonus_percentage') }}(%)</label>
                                    <input type="number" min="0.1" max="100" step="0.1" class="form-control"
                                        name="delivery_boy_bonus_percentage" id="delivery_boy_bonus_percentage"
                                        v-model="store_settings.delivery_boy_bonus_percentage"
                                        placeholder='Delivery Boy Bonus' />
                                </div>

                                <div v-if="store_settings.delivery_boy_bonus_settings == 1 && store_settings.delivery_boy_bonus_type == 1"
                                    class="form-group col-md-6 col-lg-3">
                                    <label for="delivery_boy_bonus_min_amount">{{
                                        __('minimum_bonus_amount') }}</label>
                                    <input type="number" min="0" step="0.1" required class="form-control"
                                        name="delivery_boy_bonus_min_amount" id="delivery_boy_bonus_min_amount"
                                        v-model="store_settings.delivery_boy_bonus_min_amount"
                                        placeholder='Minimum bonus amount' />
                                    <small class="text font-size-13">{{
                                        __('set_0_if_you_want_to_remove_limit')
                                    }}.</small>
                                </div>

                                <div v-if="store_settings.delivery_boy_bonus_settings == 1 && store_settings.delivery_boy_bonus_type == 1"
                                    class="form-group col-md-6 col-lg-3">
                                    <label for="delivery_boy_bonus_max_amount">{{
                                        __('maximum_bonus_amount') }}</label>
                                    <input type="number" min="0" step="0.1" required class="form-control"
                                        name="delivery_boy_bonus_max_amount" id="delivery_boy_bonus_max_amount"
                                        v-model="store_settings.delivery_boy_bonus_max_amount"
                                        placeholder='Maximum bonus amount' />
                                    <small class="text font-size-13">{{
                                        __('set_0_if_you_want_to_remove_limit')
                                    }}.</small>
                                </div>
                            </div>
                            <div class="row">
                                <div class="form-group col-md-6">
                                    <label for="generate_otp">{{ __('Order Delivery OTP System')
                                    }}</label><br>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            name="generate_otp" id="generate_otp" v-model="store_settings.generate_otp">
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="d-flex justify-content-end">
                        <b-button type="submit" variant="primary" :disabled="isLoading"
                            v-if="$can('manage_app_settings')">
                            {{ __('update') }}
                            <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                        </b-button>
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

/**
 * Customer + delivery-boy app configuration. Split out of GeneralSettings because it
 * owns its own fields, its own save endpoint and its own translated remarks.
 */
export default {
    name: 'AppSettings',
    mixins: [TranslationHelper, UnsavedChanges],
    components: { ArrowLeft },
    data() {
        return {
            isLoading: false,
            languages: [],
            defaultLanguageId: null,
            // One tab strip per maintenance message — they must not share a model.
            activeCustLangTab: null,
            activeDbLangTab: null,
            store_settings: {
                playstore_url: '',
                appstore_url: '',
                delivery_boy_playstore_url: '',
                delivery_boy_appstore_url: '',
                is_version_system_on_customer: 0,
                required_force_update_customer: 0,
                current_version_customer: '',
                ios_is_version_system_on_customer: 0,
                ios_required_force_update_customer: 0,
                ios_current_version_customer: '',
                is_version_system_on_delivery_boy: 0,
                required_force_update_delivery_boy: 0,
                current_version_delivery_boy: '',
                ios_is_version_system_on_delivery_boy: 0,
                ios_required_force_update_delivery_boy: 0,
                ios_current_version_delivery_boy: '',
                notify_version_update_customer: 0,
                notify_version_update_delivery_boy: 0,
                customer_light_mode_color: '#FE3C5E',
                customer_dark_mode_color: '#1A2A3A',
                delivery_boy_light_mode_color: '#FE3C5E',
                delivery_boy_dark_mode_color: '#1A2A3A',
                delivery_boy_bonus_settings: 0,
                delivery_boy_bonus_type: 0,
                delivery_boy_bonus_percentage: 0,
                delivery_boy_bonus_min_amount: 0,
                delivery_boy_bonus_max_amount: 0,
                generate_otp: 0,
            },
            appTranslations: {
            },
        };
    },
    created() {
        this.bootstrap();
    },
    computed: {
        // Fixed option set — no search box needed.
        delivery_boy_bonus_typeOptions() {
            return [
                { id: '', name: (__('select')) },
                { id: '1', name: (__('commission')) },
                { id: '0', name: (__('fixed')) + ' ' + '/' + ' ' + (__('salaried')) },
            ];
        },
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return {
                store_settings: this.store_settings,
                appTranslations: this.appTranslations,
            };
        },
        async bootstrap() {
            await this.loadLanguages();
            await this.getStoreSetting();
            // Snapshot the loaded settings as the "clean" baseline for the guard.
            this.captureFormBaseline();
        },

        loadLanguages() {
            return axios.get(this.$apiUrl + '/active_languages')
                .then(res => {
                    this.languages = res.data.data || [];
                    const def = this.languages.find(l => l.is_default == 1);
                    this.defaultLanguageId = def ? def.id : null;
                    if (def) {
                        this.activeCustLangTab = 'cust-lang-' + def.id;
                        this.activeDbLangTab = 'db-lang-' + def.id;
                    }
                    this.initTranslationShells();
                })
                .catch(() => { this.languages = []; });
        },

        initTranslationShells() {
            Object.keys(this.appTranslations).forEach(field => {
                this.languages.forEach(lang => {
                    if (!this.appTranslations[field]) this.appTranslations[field] = {};
                    if (this.appTranslations[field][lang.code] === undefined) {
                        this.appTranslations[field][lang.code] = '';
                    }
                });
            });
        },

        getStoreSetting() {
            return axios.get(this.$apiUrl + '/store_settings')
                .then(res => {
                    const rows = res.data?.data?.store_settings || [];
                    // Maintenance remarks moved to the dedicated Maintenance page.
                    const translatable = [];

                    rows.forEach(row => {
                        const key = row.variable;
                        const raw = row.value;

                        if (translatable.includes(key)) {
                            // Stored as a JSON map of languageCode -> text; older rows are plain strings.
                            let parsed = null;
                            try { parsed = JSON.parse(raw); } catch (e) { parsed = null; }
                            if (!this.appTranslations[key]) this.appTranslations[key] = {};
                            this.languages.forEach(lang => {
                                if (parsed && typeof parsed === 'object') {
                                    this.appTranslations[key][lang.code] = parsed[lang.code] || '';
                                } else {
                                    this.appTranslations[key][lang.code] = lang.is_default ? (raw || '') : '';
                                }
                            });
                            return;
                        }

                        if (key in this.store_settings) {
                            this.store_settings[key] = raw;
                        }
                    });
                })
                .catch(() => { /* leave defaults; the form still renders */ });
        },

        saveAppSetting() {
            this.isLoading = true;

            const formData = new FormData();

            // Normal fields
            const normalFields = [
                'playstore_url', 'appstore_url',
                'delivery_boy_playstore_url', 'delivery_boy_appstore_url',
                'is_version_system_on_customer', 'required_force_update_customer', 'current_version_customer',
                'ios_is_version_system_on_customer', 'ios_required_force_update_customer', 'ios_current_version_customer',
                'is_version_system_on_delivery_boy', 'required_force_update_delivery_boy', 'current_version_delivery_boy',
                'ios_is_version_system_on_delivery_boy', 'ios_required_force_update_delivery_boy', 'ios_current_version_delivery_boy',
                'notify_version_update_customer', 'notify_version_update_delivery_boy',
                'customer_light_mode_color', 'customer_dark_mode_color',
                'delivery_boy_light_mode_color', 'delivery_boy_dark_mode_color',
                // Delivery-boy rules moved onto the Delivery Boy App card.
                'delivery_boy_bonus_settings', 'delivery_boy_bonus_type',
                'delivery_boy_bonus_percentage', 'delivery_boy_bonus_min_amount',
                'delivery_boy_bonus_max_amount', 'generate_otp',
            ];

            normalFields.forEach(field => {
                if (this.store_settings[field] !== undefined) {
                    // FormData.append(key, null) sends the literal string "null" — send '' instead.
                    formData.append(field, this.store_settings[field] ?? '');
                }
            });

            // Default language required check
            const defaultLang = this.languages.find(lang => lang.is_default);

            // Remark is only required when its corresponding toggle is ON
            const conditionalRequiredFields = [];

            for (let field of conditionalRequiredFields) {
                // Skip validation if the toggle is off
                if (this.store_settings[field.toggle] != 1) continue;
                const value = this.appTranslations[field.key]?.[defaultLang.code];
                if (!value || !value.trim()) {
                    this.showError(`${field.label} (default language) is required!`);
                    this.isLoading = false;
                    return;
                }
            }

            // Helper to clean multilingual content (default required, others optional)
            const cleanLangObject = (obj = {}) => {
                const cleaned = {};
                Object.keys(obj).forEach(lang => {
                    let value = obj[lang];
                    if (typeof value === 'string') {
                        value = value.replace(/\r?\n|\r/g, ' ').replace(/\s+/g, ' ').trim();
                    }
                    // Default language must exist, others can be empty
                    cleaned[lang] = value || '';
                });
                return cleaned;
            };

            axios.post(this.$apiUrl + '/store_settings/save_app_setting', formData)
                .then(res => {
                    if (res.data.status === 1) {
                        this.showMessage('success', res.data.message);
                        this.getStoreSetting();
                        // Mark clean after a successful save (before the redirect fires).
                        this.captureFormBaseline();

                        setTimeout(() => {
                            this.$swal.close();
                            this.isLoading = false;
                            this.$router.push({ path: '/settings/app' });
                        }, 2000);
                    } else {
                        this.showError(res.data.message);
                        this.isLoading = false;
                    }
                })
                .catch(error => {
                    this.isLoading = false;
                    if (error?.response?.data?.message) {
                        this.showError(error.response.data.message);
                    } else if (error.message) {
                        this.showError(error.message);
                    } else {
                        this.showError(__('something_went_wrong'));
                    }
                });
        },

        // TranslationHelper hooks — this page only translates the two maintenance remarks.
        translateScoped(scope, langIds) {
            this.$nextTick(() => this.runTranslate(langIds));
        },
        getTranslateSource() {
            const def = this.languages.find(l => l.is_default);
            if (!def || !def.code) return {};
            const source = {};
            Object.keys(this.appTranslations).forEach(f => {
                source[f] = (this.appTranslations[f] && this.appTranslations[f][def.code]) || '';
            });
            return source;
        },
        applyTranslated(lang, translated) {
            Object.keys(this.appTranslations).forEach(f => {
                const val = translated[f];
                if (val == null) return;
                if (!this.appTranslations[f]) this.appTranslations[f] = {};
                this.appTranslations[f][lang.code] = val;
            });
        },
    },
};
</script>
