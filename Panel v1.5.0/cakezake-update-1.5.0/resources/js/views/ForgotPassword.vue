<template>
    <div class="auth" :style="$panelLoginBackgroundImg ? { backgroundImage: `url(${$panelLoginBackgroundImg})` } : null">
        <div class="login-wrapper">
            <div class="auth-section">
                <router-link to="/login" class="lg-back">
                    <component :is="icons.arrowLeft" :size="16" />
                    Back to login
                </router-link>

                <div class="auth-card login-card">
                    <div class="lg-brand">
                        <img v-if="$appLogo != ''" :src="$storageUrl + $appLogo" class="lg-brand-logo" alt="" />
                        <img v-else :src="$baseUrl + '/images/logo.png'" class="lg-brand-logo" alt="" />
                        <span class="lg-brand-name">{{ $appName }}</span>
                    </div>

                    <h1 class="lg-title">Reset your password</h1>
                    <p class="lg-subtitle">Enter your email and we will send you a reset link</p>

                    <form @submit.prevent="forgetPasswordSendMail()" novalidate>
                        <label class="lg-label" for="forgot-email">Email address</label>
                        <div class="lg-field">
                            <component :is="icons.mail" :size="18" class="lg-field-icon" />
                            <input id="forgot-email" type="email" class="lg-input" placeholder="you@example.com"
                                autocomplete="email" required v-model="user.email" />
                        </div>

                        <button type="submit" class="lg-btn lg-btn-primary" :disabled="isLoading">
                            <b-spinner v-if="isLoading" small label="Sending" />
                            <template v-else>
                                Reset Password
                                <component :is="icons.arrowRight" :size="17" />
                            </template>
                        </button>
                    </form>

                    <div class="lg-copyright">{{ $copyrightDetails }}</div>
                </div>
            </div>
        </div>
    </div>
</template>
<script>
import { markRaw } from "vue";
import axios from "axios";
import Auth from "../Auth.js";
import { Mail, ArrowLeft, ArrowRight } from "lucide-vue-next";

export default {
    data: function () {
        return {
            icons: { mail: markRaw(Mail), arrowLeft: markRaw(ArrowLeft), arrowRight: markRaw(ArrowRight) },
            isLoading: false,
            user: {
                email: "",
            },
            loggedUser: Auth.user,
            setting: "",
        };
    },

    mounted() {
        if (this.loggedUser) {
            this.$router.push("/dashboard");
        }
    },
    methods: {
        forgetPasswordSendMail: function () {
            let vm = this;
            this.isLoading = true;
            let url = this.$apiUrl + "/forgot_password";
            axios
                .post(url, this.user)
                .then((res) => {
                    vm.isLoading = false;
                    let data = res.data;

                    if (data.status === 1) {
                        this.user.email = "";
                        vm.showMessage("success", data.message);
                    } else {
                        vm.showError(data.message);
                    }
                })
                .catch((error) => {
                    vm.isLoading = false;
                    if (error.request.statusText) {
                        this.showError(error.request.statusText);
                    } else {
                        if (error.request.statusText) {
                            this.showError(error.request.statusText);
                        } else if (error.message) {
                            this.showError(error.message);
                        } else {
                            this.showError(__("something_went_wrong"));
                        }
                    }
                });
        },
    },
};
</script>
<style scoped>
/* Shared auth card styling lives in assets/css/custom/common.css (.lg-*). */
</style>
