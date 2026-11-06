<template>
    <div class="auth" :style="$panelLoginBackgroundImg ? { backgroundImage: `url(${$panelLoginBackgroundImg})` } : null">
        <div class="login-wrapper">
            <div class="auth-section">
                <div class="auth-card login-card">

                    <div class="lg-brand">
                        <img v-if="$appLogo != ''" :src="$storageUrl + $appLogo" class="lg-brand-logo" alt="" />
                        <img v-else :src="$baseUrl + '/images/logo.png'" class="lg-brand-logo" alt="" />
                    </div>

                    <h1 class="lg-title">{{ twoFactor.active ? __('two_factor_verification') : __('branch_login') }}</h1>
                    <p class="lg-subtitle" v-if="!twoFactor.active">{{ __('sign_in_to_your_branch_panel') }}</p>
                    <p class="lg-subtitle" v-else>
                        {{ __('enter_the_code_we_emailed_you') }} <strong>{{ twoFactor.emailHint }}</strong>
                    </p>

                    <form v-if="twoFactor.active" @submit.prevent="finishTwoFactor()" novalidate>
                        <label class="lg-label">{{ __('verification_code') }}</label>
                        <OtpInput v-model="twoFactor.code" :has-error="!!twoFactor.error"
                            :disabled="twoFactor.verifying" @complete="finishTwoFactor()" />

                        <div class="d-flex justify-content-between align-items-center mb-3 small">
                            <span class="text-danger" v-if="twoFactor.error">{{ twoFactor.error }}</span>
                            <span class="text-muted" v-else-if="twoFactor.expiresIn > 0">
                                {{ __('code_expires_in') }} {{ twoFactorCountdown() }}
                            </span>
                            <button type="button" class="btn btn-link btn-sm p-0 ms-auto"
                                :disabled="twoFactor.resendIn > 0 || twoFactor.resending || twoFactor.sendsLeft <= 0"
                                @click="resendTwoFactorCode()">
                                <span v-if="twoFactor.resendIn > 0">
                                    {{ __('resend_code_in_seconds', { seconds: twoFactor.resendIn }) }}
                                </span>
                                <span v-else>{{ __('resend_code') }}</span>
                            </button>
                        </div>

                        <button type="submit" class="lg-btn lg-btn-primary"
                            :disabled="twoFactor.verifying || twoFactor.code.length < 6">
                            <b-spinner v-if="twoFactor.verifying" small label="Verifying" />
                            <template v-else>
                                {{ __('verify_and_sign_in') }}
                                <component :is="icons.arrowRight" :size="17" />
                            </template>
                        </button>

                        <button type="button" class="lg-btn lg-btn-soft mt-2" @click="cancelTwoFactor()">
                            {{ __('back_to_login') }}
                        </button>
                    </form>

                    <form v-else @submit.prevent="loginCheck()" novalidate>
                        <label class="lg-label" for="branch-email">{{ __('email_address') }}</label>
                        <div class="lg-field">
                            <component :is="icons.mail" :size="18" class="lg-field-icon" />
                            <input id="branch-email" type="email" class="lg-input" placeholder="you@example.com"
                                autocomplete="email" required v-model="user.email">
                        </div>

                        <label class="lg-label" for="branch-password">{{ __('password') }}</label>
                        <div class="lg-field">
                            <component :is="icons.key" :size="18" class="lg-field-icon" />
                            <input id="branch-password" :type="showPassword ? 'text' : 'password'" class="lg-input has-trail"
                                :placeholder="__('enter_password')" autocomplete="current-password" required
                                v-model="user.password">
                            <button type="button" class="lg-eye" @click="showPassword = !showPassword"
                                :aria-label="showPassword ? 'Hide password' : 'Show password'">
                                <component :is="showPassword ? icons.eye : icons.eyeOff" :size="17" />
                            </button>
                        </div>

                        <button type="submit" class="lg-btn lg-btn-primary" :disabled="isLoading">
                            <b-spinner v-if="isLoading" small label="Signing in" />
                            <template v-else>
                                {{ __('login') }}
                                <component :is="icons.arrowRight" :size="17" />
                            </template>
                        </button>

                        <div class="lg-divider"><span>{{ __('or') }}</span></div>

                        <router-link to="/login" class="lg-btn lg-btn-soft">
                            <component :is="icons.layout" :size="17" />
                            {{ __('admin_login') }}
                        </router-link>
                    </form>

                    <div class="lg-copyright" v-html="copyrightDetails"></div>
                </div>
            </div>
        </div>
    </div>
</template>
<script>
import { markRaw } from 'vue';
import axios from 'axios';
import Auth from '../../Auth.js';
import OtpInput from '../../components/OtpInput.vue';
import TwoFactorLogin from '../../mixins/TwoFactorLogin.js';
import { Mail, KeyRound, Eye, EyeOff, ArrowRight, LayoutDashboard } from 'lucide-vue-next';

export default {
    components: { OtpInput },
    mixins: [TwoFactorLogin],
    data: function () {
        return {
            icons: {
                mail: markRaw(Mail),
                key: markRaw(KeyRound),
                eye: markRaw(Eye),
                eyeOff: markRaw(EyeOff),
                arrowRight: markRaw(ArrowRight),
                layout: markRaw(LayoutDashboard),
            },
            isLoading: false,
            user: {
                email: (this.$isDemo === 1 || this.$isDemo === '1') ? 'mumbai@branch.com' : '',
                password: (this.$isDemo === 1 || this.$isDemo === '1') ? 'Mumbai@1' : '',
                type: 'branch',
            },
            showPassword: false,
            copyrightDetails: window.copyrightDetails,
        };
    },
    mounted() {
        if (Auth.user) this.$router.push('/branch/dashboard').catch(() => { });
    },
    methods: {
        onVerified: function (data) {
            if (!data.user) {
                this.showError(this.__('user_is_not_register_with_this_email_address'));
                return;
            }
            Auth.login(data.access_token, data.user);
            // Guard re-prefixes to /branch and resolves the first permitted page.
            this.$router.push('/dashboard');
        },

        loginCheck: function () {
            let vm = this;
            this.isLoading = true;
            let url = this.$apiUrl + '/login';
            let payload = Object.assign({}, this.user, {
                fcm_token: window.panelFcmToken || '',
                language_code: window.localStorage.getItem('lang') || window.appLocale || 'en',
            });
            axios.post(url, payload).then(res => {
                vm.isLoading = false;
                let data = res.data;
                if (data.status === 1) {
                    if (data.data.two_factor_required) {
                        vm.beginTwoFactor(data.data);
                        return;
                    }
                    vm.onVerified(data.data);
                } else {
                    vm.showError(data.message);
                }
            }).catch(error => {
                vm.isLoading = false;
                this.showError(error.response?.data?.message || error.message || 'Something went wrong!');
            });
        }
    }
}
</script>
<style scoped>
/* Shared auth card styling lives in assets/css/custom/common.css (.lg-*). */
</style>
