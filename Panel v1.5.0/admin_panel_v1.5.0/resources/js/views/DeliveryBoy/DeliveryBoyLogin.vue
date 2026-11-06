<template>
    <div class="auth" :style="$panelLoginBackgroundImg ? { backgroundImage: `url(${$panelLoginBackgroundImg})` } : null">
        <div class="login-wrapper">
            <div class="auth-section">
                <div class="auth-card login-card">

                    <div class="lg-brand">
                        <img v-if="$appLogo != ''" :src="$storageUrl + $appLogo" class="lg-brand-logo" alt="" />
                        <img v-else :src="$baseUrl + '/images/logo.png'" class="lg-brand-logo" alt="" />
                    </div>

                    <h1 class="lg-title">{{ __('welcome_back') }}</h1>
                    <p class="lg-subtitle">{{ __('please_login_to_your_delivery_boy_account') }}</p>

                    <form @submit.prevent="loginCheck()" novalidate>
                        <label class="lg-label" for="db-email">{{ __('email') }}</label>
                        <div class="lg-field">
                            <component :is="icons.mail" :size="18" class="lg-field-icon" />
                            <input id="db-email" type="email" class="lg-input" placeholder="you@example.com"
                                autocomplete="email" required v-model="user.email">
                        </div>

                        <label class="lg-label" for="db-password">{{ __('password') }}</label>
                        <div class="lg-field">
                            <component :is="icons.key" :size="18" class="lg-field-icon" />
                            <input id="db-password" :type="showPassword ? 'text' : 'password'"
                                class="lg-input has-trail" :placeholder="__('password')"
                                autocomplete="current-password" required v-model="user.password">
                            <button type="button" class="lg-eye" @click="showPassword = !showPassword"
                                :aria-label="showPassword ? 'Hide password' : 'Show password'">
                                <component :is="showPassword ? icons.eye : icons.eyeOff" :size="17" />
                            </button>
                        </div>

                        <div class="lg-forgot">
                            <router-link to="/forgot-password">{{ __('forgot_password') }}</router-link>
                        </div>

                        <button type="submit" class="lg-btn lg-btn-primary" :disabled="isLoading">
                            <b-spinner v-if="isLoading" small label="Signing in" />
                            <template v-else>
                                {{ __('login') }}
                                <component :is="icons.arrowRight" :size="17" />
                            </template>
                        </button>

                        <div class="lg-divider"><span>{{ __('or') }}</span></div>

                        <router-link to="/delivery_boy/register" class="lg-btn lg-btn-soft">
                            <component :is="icons.userPlus" :size="17" />
                            {{ __('register') }}
                        </router-link>
                        <router-link to="/login" class="lg-btn lg-btn-soft">
                            <component :is="icons.layout" :size="17" />
                            {{ __('admin_panel') }}
                        </router-link>
                    </form>

                    <div class="lg-copyright">{{ $copyrightDetails }}</div>
                </div>
            </div>
        </div>
    </div>
</template>
<script>
import { markRaw } from 'vue';
import axios from 'axios';
import Auth from '../../Auth.js';
import { Mail, KeyRound, Eye, EyeOff, ArrowRight, UserPlus, LayoutDashboard } from 'lucide-vue-next';

export default {
    data: function () {
        return {
            icons: {
                mail: markRaw(Mail),
                key: markRaw(KeyRound),
                eye: markRaw(Eye),
                eyeOff: markRaw(EyeOff),
                arrowRight: markRaw(ArrowRight),
                userPlus: markRaw(UserPlus),
                layout: markRaw(LayoutDashboard),
            },
            isLoading: false,
            user: {
                email: (this.$isDemo === 1 || this.$isDemo === '1') ? 'alex@gmail.com' : '',
                password: (this.$isDemo === 1 || this.$isDemo === '1') ? 'Alex@1234' : '',
                type: 3
            },
            showPassword: false,
            loggedUser: Auth.user,
            setting:""
        };
    },
    mounted() {
        if (this.loggedUser) {
            this.$router.push('/delivery_boy');
        }
    },
    methods: {

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
                    const db = data.data;
                    const perms = (db.user && db.user.allPermissions) || db.allPermissions || [];
                    const user = {
                        ...db,
                        role_id: 3,
                        delivery_boy_status: db.status ?? 1,
                        role: { name: 'Delivery Boy' },
                        allPermissions: perms,
                        delivery_boy: { id: db.id, status: db.status ?? 1 },
                    };
                    Auth.login(db.access_token, user);
                    this.$router.push('/delivery_boy');
                } else {
                    vm.showError(data.message);
                }
            }).catch(error => {
                vm.isLoading = false;
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                }else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError("Something went wrong!");
                }

            });
        }
    }
}
</script>
<style scoped>
/* Shared auth card styling lives in assets/css/custom/common.css (.lg-*). */
</style>
