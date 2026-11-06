<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('login_setting') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
                <div class="card">
                    <div class="card-body">
                        <form method="post" enctype="multipart/form-data" @submit.prevent="saveRecordLoginSetting">
                            <h5 class="mb-1">{{ __('customer_login_settings') }}</h5>
                            <small class="text-muted d-block mb-3">{{ __('customer_login_settings_hint') }}</small>
                            <div class="row">
                                <div class="form-group col-md-6 mb-3">
                                    <label for="phone_login">{{ __('phone_login') }}
                                    </label><br>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            name="phone_login" id="phone_login" v-model="login_settings.phone_login">

                                    </div>
                                    <small class="text-muted d-block">{{ __('phone_login_hint')
                                    }}</small>
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="google_login">{{ __('google_login') }}
                                    </label><br>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            name="google_login" id="google_login" v-model="login_settings.google_login">
                                    </div>
                                    <small class="text-muted d-block">{{ __('google_login_hint')
                                    }}</small>
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="apple_login">{{ __('apple_login') }}
                                    </label><br>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            name="apple_login" id="apple_login" v-model="login_settings.apple_login">
                                    </div>
                                    <small class="text-muted d-block">{{ __('apple_login_hint')
                                    }}</small>
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="apple_login">{{ __('email_login') }}
                                    </label><br>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            name="email_login" id="email_login" v-model="login_settings.email_login">
                                    </div>
                                    <small class="text-muted d-block">{{ __('email_login_hint')
                                    }}</small>
                                </div>
                                <div v-if="login_settings.phone_login == '1'" class="form-group col-md-6">

                                    <label for="phone_auth_otp">{{ __('phone_auth_otp') }}
                                    </label><br>
                                    <div class='form-check form-switch'>
                                        <input class='form-check-input' id="phone_auth_otp" type='checkbox'
                                            true-value="1" false-value="0" v-model="login_settings.phone_auth_otp">
                                    </div>
                                    <small class="text-muted d-block">{{ __('phone_auth_otp_hint')
                                    }}</small>

                                </div>
                                <div v-if="login_settings.phone_login == '1'" class="form-group col-md-6">

                                    <label for="phone_auth_password">{{
                                        __('phone_auth_password') }}
                                    </label><br>
                                    <div class='form-check form-switch'>
                                        <input class='form-check-input' id="phone_auth_password" type='checkbox'
                                            true-value="1" false-value="0" v-model="login_settings.phone_auth_password">
                                    </div>
                                    <small class="text-muted d-block">{{
                                        __('phone_auth_password_hint') }}</small>

                                </div>
                                <div v-if="login_settings.phone_auth_otp == '1' || login_settings.phone_auth_password == '1'"
                                    class="form-group col-md-6">


                                    <label for="firebase_authentication">{{
                                        __('firebase_authentication') }}
                                    </label><br>
                                    <div class='form-check form-switch'>
                                        <input class='form-check-input' id="firebase_authentication" type='checkbox'
                                            true-value="1" false-value="0"
                                            v-model="login_settings.firebase_authentication">
                                    </div>
                                    <small class="text-muted d-block">{{
                                        __('firebase_authentication_hint') }}</small>
                                    <router-link :to="'/settings/firebase'"
                                        class="small d-inline-flex align-items-center gap-1 mt-1">
                                        {{ __('open_firebase_settings') }}
                                        <ExternalLink :size="12" />
                                    </router-link>

                                </div>

                                <div v-if="login_settings.phone_auth_otp == '1' || login_settings.phone_auth_password == '1'"
                                    class="form-group col-md-6">


                                    <label for="custom_sms_gateway_otp_based">{{
                                        __('custom_sms_gateway_otp_based') }}
                                    </label><br>
                                    <div class='form-check form-switch'>
                                        <input class='form-check-input' id="custom_sms_gateway_otp_based"
                                            type='checkbox' true-value="1" false-value="0"
                                            v-model="login_settings.custom_sms_gateway_otp_based">
                                    </div>
                                    <small class="text-muted d-block">{{
                                        __('custom_sms_gateway_otp_based_hint') }}</small>
                                    <router-link :to="'/settings/sms'"
                                        class="small d-inline-flex align-items-center gap-1 mt-1">
                                        {{ __('open_sms_settings') }}
                                        <ExternalLink :size="12" />
                                    </router-link>

                                </div>
                            </div>

                            <hr class="my-3">
                            <h5 class="mb-1">{{ __('panel_login_settings') }}</h5>
                            <small class="text-muted d-block mb-3">{{ __('panel_login_settings_hint') }}</small>
                            <!-- Three across from lg up: the switch, its branch-user
                                 qualifier and the expiry read as one setting. -->
                            <div class="row">
                                <div class="form-group col-md-6 col-lg-4 mb-3">
                                    <label for="panel_two_factor">{{ __('panel_two_factor') }}</label><br>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            name="panel_two_factor" id="panel_two_factor"
                                            v-model="login_settings.panel_two_factor">
                                    </div>
                                    <small class="text-muted d-block">{{ __('panel_two_factor_hint') }}</small>
                                    <router-link :to="'/settings/smtp'"
                                        class="small d-inline-flex align-items-center gap-1 mt-1">
                                        {{ __('open_smtp_settings') }}
                                        <ExternalLink :size="12" />
                                    </router-link>
                                </div>
                                <div v-if="login_settings.panel_two_factor == '1'" class="form-group col-md-6 col-lg-4 mb-3">
                                    <label for="panel_two_factor_branch_users">{{ __('panel_two_factor_branch_users') }}</label><br>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            name="panel_two_factor_branch_users" id="panel_two_factor_branch_users"
                                            v-model="login_settings.panel_two_factor_branch_users">
                                    </div>
                                    <small class="text-muted d-block">{{ __('panel_two_factor_branch_users_hint') }}</small>
                                </div>
                                <div v-if="login_settings.panel_two_factor == '1'" class="form-group col-md-6 col-lg-4 mb-3">
                                    <label for="panel_two_factor_expiry">{{ __('panel_two_factor_expiry') }}</label>
                                    <input class="form-control" id="panel_two_factor_expiry" type="number" min="1"
                                        max="60" v-model.number="login_settings.panel_two_factor_expiry">
                                    <small class="text-muted d-block">{{ __('panel_two_factor_expiry_hint') }}</small>
                                </div>
                            </div>

                            <hr class="my-3">
                            <h5 class="mb-1">{{ __('password_policy') }}</h5>
                            <small class="text-muted d-block mb-3">{{ __('password_policy_hint') }}</small>
                            <div class="row">
                                <div class="form-group col-md-3">
                                    <label for="password_min_length">{{ __('minimum_length') }}</label>
                                    <input class="form-control" id="password_min_length" type="number" min="1"
                                        v-model.number="login_settings.password_min_length">
                                    <small class="text-muted d-block">{{ __('minimum_length_hint') }}</small>
                                </div>
                                <div class="form-group col-md-3">
                                    <label for="password_max_length">{{ __('maximum_length') }}</label>
                                    <input class="form-control" id="password_max_length" type="number" min="0"
                                        v-model.number="login_settings.password_max_length">
                                    <small class="text-muted d-block">{{ __('maximum_length_hint') }}</small>
                                </div>
                            </div>
                            <div class="row">
                                <div class="form-group col-md-3">
                                    <label>{{ __('require_uppercase') }}</label><br>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" true-value="1" false-value="0"
                                            v-model="login_settings.password_require_uppercase">
                                    </div>
                                </div>
                                <div class="form-group col-md-3">
                                    <label>{{ __('require_lowercase') }}</label><br>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" true-value="1" false-value="0"
                                            v-model="login_settings.password_require_lowercase">
                                    </div>
                                </div>
                                <div class="form-group col-md-3">
                                    <label>{{ __('require_number') }}</label><br>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" true-value="1" false-value="0"
                                            v-model="login_settings.password_require_number">
                                    </div>
                                </div>
                                <div class="form-group col-md-3">
                                    <label>{{ __('require_special_character') }}</label><br>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" true-value="1" false-value="0"
                                            v-model="login_settings.password_require_special">
                                    </div>
                                </div>
                            </div>

                            <div class="row justify-content-end">
                                <div class="form-group col-auto">
                                    <b-button type="submit" variant="primary" :disabled="isLoading"
                                        v-if="$can('manage_login_settings')">
                                        {{ __('update') }}
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
import { ArrowLeft, ExternalLink } from 'lucide-vue-next';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

export default {
    name: 'LoginSettings',
    mixins: [UnsavedChanges],
    components: { ArrowLeft, ExternalLink },
    data() {
        return {
            isLoading: false,
            // Which SMS gateway (if any) is enabled — gates Custom SMS Gateway OTP login.
            activeSmsGateway: '',
            login_settings: {
                phone_login: 0,
                google_login: 0,
                apple_login: 0,
                email_login: 0,
                phone_auth_otp: 0,
                phone_auth_password: 0,
                firebase_authentication: 0,
                custom_sms_gateway_otp_based: 0,
                // Password policy (applied wherever a password is set/changed).
                password_min_length: 5,
                password_max_length: 0,
                password_require_uppercase: 0,
                password_require_lowercase: 0,
                password_require_number: 0,
                password_require_special: 0,
                panel_two_factor: 0,
                panel_two_factor_branch_users: 1,
                panel_two_factor_expiry: 10,
            },
        };
    },
    watch: {
        // OTP and password login are mutually exclusive.
        'login_settings.phone_auth_otp': function (newValue) {
            if (newValue == 1) {
                this.login_settings.phone_auth_password = 0;
                this.login_settings.phone_auth_otp = 1;
            }
        },
        'login_settings.phone_auth_password': function (newValue) {
            if (newValue == 1) {
                this.login_settings.phone_auth_otp = 0;
                this.login_settings.phone_auth_password = 1;
            }
        },
        // So are the two OTP delivery methods.
        'login_settings.firebase_authentication': function (newValue) {
            if (newValue == 1) {
                this.login_settings.custom_sms_gateway_otp_based = 0;
                this.login_settings.firebase_authentication = 1;
            }
        },
        'login_settings.custom_sms_gateway_otp_based': function (newValue) {
            if (newValue == 1) {
                // Needs an active SMS gateway to send the OTP; block otherwise.
                if (!this.activeSmsGateway) {
                    this.$nextTick(() => { this.login_settings.custom_sms_gateway_otp_based = 0; });
                    this.showError(__('enable_sms_gateway_before_otp_login'));
                    return;
                }
                this.login_settings.firebase_authentication = 0;
                this.login_settings.custom_sms_gateway_otp_based = 1;
            }
        },
    },

    created() {
        this.getLoginSetting();
        this.loadSmsGateway();
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return this.login_settings;
        },
        loadSmsGateway() {
            axios.get(this.$apiUrl + '/sms_settings')
                .then(res => { this.activeSmsGateway = (res.data.data && res.data.data.sms_gateway) || ''; })
                .catch(() => { this.activeSmsGateway = ''; });
        },

        getLoginSetting() {
            return axios.get(this.$apiUrl + '/store_settings')
                .then(res => {
                    const rows = res.data?.data?.login_settings;
                    if (!Array.isArray(rows)) return;
                    rows.forEach(item => {
                        if (item.value === '0' || item.value === '1') {
                            this.login_settings[item.variable] = (item.value === '0') ? 0 : 1;
                        } else {
                            this.login_settings[item.variable] = item.value;
                        }
                    });
                    // Snapshot the loaded settings as the "clean" baseline for the guard.
                    this.captureFormBaseline();
                })
                .catch(() => { });
        },

        saveRecordLoginSetting() {
            this.isLoading = true;
            const formData = new FormData();
            Object.keys(this.login_settings).forEach(key => {
                formData.append(key, this.login_settings[key]);
            });

            axios.post(this.$apiUrl + '/store_settings/save_login_setting', formData)
                .then(res => {
                    if (res.data.status === 1) {
                        this.showMessage('success', res.data.message);
                        this.getLoginSetting();
                        // Mark clean after a successful save (page stays put).
                        this.captureFormBaseline();
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
