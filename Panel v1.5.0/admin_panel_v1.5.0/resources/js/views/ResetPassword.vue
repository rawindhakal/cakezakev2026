<template>
    <div class="auth" :style="$panelLoginBackgroundImg ? { backgroundImage: `url(${$panelLoginBackgroundImg})` } : null">
        <div class="login-wrapper">
            <div class="auth-section">

                <div class="auth-card">
                    <div class="auth-logo">
                        <a href="javascript:void(0)" style="display: flex; align-items: center; justify-content: flex-start;">
                            <img v-if="$appLogo != ''" :src="$storageUrl+$appLogo" style="height: 70px; width: 70px;" alt='Logo'/>
                            <img v-else :src="$baseUrl + '/images/logo.png'" style="height: 70px; width: 70px;" alt='Logo'/>
                            <h2 style="margin: 10px;">{{ $appName }}</h2>
                        </a>
                    </div>

                    <h4>Reset Your</h4>
                    <h4>Password here!</h4>

                    <form @submit.prevent="resetPassword()">
                        <div class="form-group position-relative has-icon-left">
                            <input :type="showPassword ? 'text' : 'password'" class="form-control form-control-xl" placeholder="New Password" v-model="user.password" required>
                            <div class="form-control-icon"><i class="bi bi-shield-lock"></i></div>
                            <button type="button" v-on:click="showPassword = !showPassword"
                                    class="btn btn-sm btn-outline-light font-bold text-primary"
                                    style="margin-top: -45px;position: absolute; right: 10px; cursor: pointer;" >
                                <i :class="showPassword ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
                            </button>
                            <small v-if="passwordError" class="text-danger d-block text-start">{{ passwordError }}</small>
                        </div>
                        <div class="form-group position-relative has-icon-left">
                            <input :type="showPasswordConfirmation ? 'text' : 'password'" class="form-control form-control-xl" placeholder="Confirm New Password" v-model="user.password_confirmation" required>
                            <div class="form-control-icon"><i class="bi bi-shield-lock"></i></div>
                            <button type="button" v-on:click="showPasswordConfirmation = !showPasswordConfirmation"
                                    class="btn btn-sm btn-outline-light font-bold text-primary"
                                    style="margin-top: -45px;position: absolute; right: 10px; cursor: pointer;" >
                                <i :class="showPasswordConfirmation ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
                            </button>
                        </div>
                        <button class="btn btn-primary btn-block btn-lg shadow-lg mt-5 auth-btn">
                            Reset Password
                            <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                        </button>
                    </form>

                    <div class="auth-copyright">
                        <a href="javascript:void(0)" class="font-weight-normal"> @ {{ new Date().getFullYear() }} {{$appName}}. All Right Reserved</a>
                    </div>

                </div>
            </div>
        </div>
    </div>
</template>
<script>
import axios from 'axios';
import Auth from '../Auth.js';
import { fetchPasswordPolicy, passwordPolicyError } from '../utils/passwordPolicy.js';

export default {
    data: function () {
        return {
            isLoading: false,
            showPassword: false,
            showPasswordConfirmation: false,
            user: {
                password: '',
                password_confirmation: '',
                token: '',
            },
            passwordPolicy: null,
            loggedUser: Auth.user
        };
    },
    computed: {
        passwordError() {
            if (!this.user.password) return '';
            return passwordPolicyError(this.user.password, this.passwordPolicy);
        },
    },
    mounted() {
        if (this.loggedUser) {
            this.$router.push('/dashboard');
        }
        fetchPasswordPolicy().then(p => { this.passwordPolicy = p; });
    },
    methods: {

        resetPassword: function () {
            if (this.passwordError) { this.showError(this.passwordError); return; }
            this.user.token = this.$route.query.token;
            let vm = this;
            this.isLoading = true;
            let url = this.$apiUrl + '/reset-password';
            axios.post(url, this.user).then(res => {
                vm.isLoading = false;
                let data = res.data;
                if (data.status === 1) {

                    vm.showSuccess(data.message);
                    setTimeout(()=>{
                        this.$router.push('/login');
                    },1000);

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
                    this.showError(__('something_went_wrong'));
                }
            });
        }
    }
}
</script>
<style scoped>

</style>
