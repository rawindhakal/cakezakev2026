<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('third_party_api_credentials') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
                <div class="card">
                    <div class="card-body">
                        <form method="post" enctype="multipart/form-data" @submit.prevent="saveThirdPartyApiSetting">
                            <h5 class="mb-1">{{ __('maps') }}</h5>
                            <p class="text-muted small">{{ __('maps_hint') }}</p>
                            <div class="row">
                                <div class="form-group col-md-6">
                                    <label for="map_provider">
                                        {{ __('map_provider') }}
                                        <i class="fa fa-circle-info text-muted ms-1" v-b-tooltip.hover
                                            :title="__('map_provider_tooltip')"></i>
                                    </label>
                                    <AppSelect class="form-select" v-model="store_settings.map_provider" :options="map_providerOptions" :searchable="false" />
                                    <small class="text-muted">{{ __('map_provider_help') }}</small>
                                </div>
                            </div>
                            <div class="row" v-if="store_settings.map_provider === 'google'">
                                <div class="form-group col-md-6 mt-0">
                                    <label for="google_place_api_key">{{ __('place_api_key')
                                    }}</label>
                                    <input type="text" class="form-control" name="google_place_api_key"
                                        id="google_place_api_key"
                                        :value="shouldHideThirdPartyValues ? '' : store_settings.google_place_api_key"
                                        @input="!shouldHideThirdPartyValues && (store_settings.google_place_api_key = $event.target.value)"
                                        :placeholder="shouldHideThirdPartyValues ? __('demo_mode') : 'Google Place Api Key'"
                                        :readonly="shouldHideThirdPartyValues">
                                    <input type="hidden" class="form-control" name="apiKey" id="apiKey"
                                        v-model="store_settings.apiKey" placeholder="apiKey">

                                </div>
                                <div class="form-group col-md-6">
                                    <label for="google_map_api_key">{{ __('map_api_key')
                                    }}</label>
                                    <input type="text" class="form-control" name="google_map_api_key"
                                        id="google_map_api_key"
                                        :value="shouldHideThirdPartyValues ? '' : store_settings.google_map_api_key"
                                        @input="!shouldHideThirdPartyValues && (store_settings.google_map_api_key = $event.target.value)"
                                        :placeholder="shouldHideThirdPartyValues ? __('demo_mode') : 'Google Map Api Key'"
                                        :readonly="shouldHideThirdPartyValues">
                                    <input type="hidden" class="form-control" name="googleMapApiKey"
                                        id="googleMapApiKey" v-model="store_settings.googleMapApiKey"
                                        placeholder="googleMapApiKey">
                                </div>
                            </div>

                            <hr>
                            <h5 class="mb-1">{{ __('ai_content_generation') }}</h5>
                            <p class="text-muted small">{{ __('gemini_key_hint') }}</p>
                            <div class="row">
                                <div class="form-group col-md-6">
                                    <label for="text_gen_key ">{{ __('gemini_key') }}</label>
                                    <input type="text" class="form-control" name="text_gen_key" id="text_gen_key"
                                        :value="shouldHideThirdPartyValues ? '' : store_settings.text_gen_key"
                                        @input="!shouldHideThirdPartyValues && (store_settings.text_gen_key = $event.target.value)"
                                        :placeholder="shouldHideThirdPartyValues ? __('demo_mode') : 'Gemini Key'"
                                        :readonly="shouldHideThirdPartyValues">
                                </div>
                            </div>
                            <hr>
                            <h5 class="mb-1">{{ __('microsoft_clarity') }}</h5>
                            <p class="text-muted small">{{ __('microsoft_clarity_hint') }}</p>

                            <!-- One Clarity project per surface — they are tracked separately. -->
                            <div class="row" v-for="s in claritySurfaces" :key="s.key">
                                <div class="form-group col-md-6">
                                    <label :for="'clarity_project_id_' + s.key">{{ s.label }}</label>
                                    <input type="text" class="form-control" :id="'clarity_project_id_' + s.key"
                                        :value="shouldHideThirdPartyValues ? '' : store_settings['clarity_project_id_' + s.key]"
                                        @input="!shouldHideThirdPartyValues && (store_settings['clarity_project_id_' + s.key] = $event.target.value)"
                                        :placeholder="shouldHideThirdPartyValues ? __('demo_mode') : 'abcd1234xy'"
                                        :readonly="shouldHideThirdPartyValues">
                                </div>
                                <div class="form-group col-md-6">
                                    <label class="d-block">{{ __('status') }}</label>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox"
                                            :id="'clarity_status_' + s.key"
                                            :checked="store_settings['clarity_status_' + s.key] == 1"
                                            @change="store_settings['clarity_status_' + s.key] = $event.target.checked ? 1 : 0"
                                            :disabled="shouldHideThirdPartyValues">
                                        <label class="form-check-label" :for="'clarity_status_' + s.key">
                                            {{ store_settings['clarity_status_' + s.key] == 1 ? __('enabled') : __('disabled') }}
                                        </label>
                                    </div>
                                </div>
                            </div>
                            <small class="text-muted d-block mb-3">{{ __('clarity_project_id_hint') }}</small>

                            <div class="row justify-content-end">
                                <div class="form-group col-auto">
                                    <b-button type="submit" variant="primary"
                                        :disabled="isLoading || shouldHideThirdPartyValues"
                                        v-if="$can('manage_api_credentials') && ($isDemo != 1 || (login_user && login_user.id === 1))">{{
                                            __('update') }}
                                        <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                                    </b-button>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>
            </section>
        </div>
    </div>
</template>
<script>
import axios from "axios";
import Auth from '../../Auth.js';
import CryptoJS from "crypto-js";
import { ArrowLeft } from 'lucide-vue-next';
import StoreSettingsPage from '../../mixins/StoreSettingsPage.js';

export default {
    name: 'ApiCredentials',
    mixins: [StoreSettingsPage],
    components: { ArrowLeft },
    data() {
        return {
            login_user: Auth.user,
            store_settings: {
                google_place_api_key: '',
                google_map_api_key: '',
                apiKey: '',
                googleMapApiKey: '',
                text_gen_key: '',
                map_provider: 'osm',
                clarity_project_id_panel: '', clarity_status_panel: 0,
                clarity_project_id_delivery_boy: '', clarity_status_delivery_boy: 0,
                clarity_project_id_web: '', clarity_status_web: 0,
                clarity_project_id_customer: '', clarity_status_customer: 0,
            },
        };
    },
    computed: {
        // Fixed option set — no search box needed.
        map_providerOptions() {
            return [
                { id: 'osm', name: (__('openstreetmap_free')) },
                { id: 'google', name: (__('google_paid')) },
            ];
        },
        claritySurfaces() {
            return [
                // The panel is one SPA for admin + delivery boy, so a single project.
                { key: 'panel', label: __('admin_and_delivery_boy_panel') },
                { key: 'web', label: __('website') },
                { key: 'delivery_boy', label: __('delivery_boy_app') },
                { key: 'customer', label: __('customer_app') },
            ];
        },
        // Hide third party credential values in demo mode, except for auth user id 1
        shouldHideThirdPartyValues() {
            return this.$isDemo == 1 && (!this.login_user || this.login_user.id !== 1);
        },
    },
    watch: {
        // The panel keeps a plain copy of each Google key alongside the encrypted one.
        'store_settings.google_place_api_key'(newValue) {
            this.store_settings.apiKey = newValue;
        },
        'store_settings.google_map_api_key'(newValue) {
            this.store_settings.googleMapApiKey = newValue;
        },
    },

    created() {
        this.loadStoreSettings().then(() => this.decryptGoogleKeys());
    },
    methods: {
        /**
         * The two Google keys are stored AES-encrypted, so decrypt them for display.
         * Wrapped per key — decrypt() throws on a value that was never encrypted.
         */
        decryptGoogleKeys() {
            const secretKey = 'ewgrrtoecaemr';
            ['google_place_api_key', 'google_map_api_key'].forEach(field => {
                const value = this.store_settings[field];
                if (!value) return;
                try {
                    const plain = CryptoJS.AES.decrypt(value, secretKey).toString(CryptoJS.enc.Utf8);
                    if (plain) this.store_settings[field] = plain;
                } catch (e) {
                    console.warn(field + ' decrypt failed:', e);
                }
            });
        },

        saveThirdPartyApiSetting() {
            this.isLoading = true;
            const formData = new FormData();
            const apiFields = ['google_place_api_key', 'google_map_api_key', 'apiKey', 'googleMapApiKey', 'text_gen_key', 'map_provider',
                'clarity_project_id_panel', 'clarity_status_panel',
                'clarity_project_id_delivery_boy', 'clarity_status_delivery_boy',
                'clarity_project_id_web', 'clarity_status_web',
                'clarity_project_id_customer', 'clarity_status_customer'];

            apiFields.forEach(field => {
                if (this.store_settings[field] === undefined) return;
                let value = this.store_settings[field];
                // Only the two Google keys are stored encrypted.
                if ((field === 'google_place_api_key' || field === 'google_map_api_key') && value) {
                    value = CryptoJS.AES.encrypt(value, 'ewgrrtoecaemr').toString();
                }
                formData.append(field, value);
            });

            axios.post(this.$apiUrl + '/store_settings/save_third_party_api_setting', formData)
                .then(res => {
                    if (res.data.status === 1) {
                        this.showMessage('success', res.data.message);
                        return this.loadStoreSettings().then(() => this.decryptGoogleKeys());
                    } else {
                        this.showError(res.data.message);
                    }
                })
                .catch(error => {
                    this.showError(error?.response?.data?.message || error.message || __('something_went_wrong'));
                })
                .finally(() => { this.isLoading = false; });
        },
    },
};
</script>
