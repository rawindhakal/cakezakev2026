<template>
    <div>
        <div class="page-heading">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3>{{ __('settings') }}</h3>
                <button v-if="isDeliveryBoy" type="button" class="btn btn-danger" @click="deleteAccount"
                    :disabled="isLoading">
                    {{ __('delete_account') }}
                </button>
            </div>
        </div>
        <!-- Delivery boy + branch OWNER: notification prefs + password layout. -->
        <div class="page-content" v-if="isDeliveryBoy || (isBranch && isBranchOwner)">
            <section class="row">
                <div class="col-12 col-lg-12">
                    <div class="row">
                        <div class="col-12 col-lg-6 mb-4">
                            <div class="card">
                                <div class="card-body px-3 py-4-5">
                                    <h3>{{ __('notification_preferences') }}</h3>
                                    <p class="text-muted small mt-2">{{ __('notification_preferences_hint') }}</p>

                                    <div v-if="prefsLoading" class="text-center py-4"><b-spinner></b-spinner></div>

                                    <div v-else-if="!prefGroups.length" class="text-muted small mt-3">
                                        {{ __('no_notifications_available') }}
                                    </div>

                                    <div v-else class="mt-3">
                                        <div v-for="grp in prefGroups" :key="grp.category" class="mb-4">
                                            <div class="row align-items-center g-2 mb-2 border-bottom pb-1">
                                                <div class="col-6"><h6 class="text-uppercase text-muted small fw-bold mb-0">{{ grp.category }}</h6></div>
                                                <div class="col-2 text-center small fw-bold text-muted">{{ __('mail') }}</div>
                                                <div class="col-2 text-center small fw-bold text-muted">{{ __('push') }}</div>
                                                <div class="col-2 text-center small fw-bold text-muted">{{ __('sms') }}</div>
                                            </div>
                                            <div v-for="ev in grp.events" :key="ev.key" class="row align-items-center g-2 mb-2">
                                                <div class="col-6"><label class="mb-0">{{ ev.label || formattedName(ev.key) }}</label></div>
                                                <div class="col-2 text-center">
                                                    <div v-if="'mail' in ev.channels" class="form-check form-switch d-inline-block m-0">
                                                        <input class="form-check-input" type="checkbox" role="switch" v-model="ev.channels.mail">
                                                    </div>
                                                    <span v-else class="text-muted">—</span>
                                                </div>
                                                <div class="col-2 text-center">
                                                    <div v-if="'push' in ev.channels" class="form-check form-switch d-inline-block m-0">
                                                        <input class="form-check-input" type="checkbox" role="switch" v-model="ev.channels.push">
                                                    </div>
                                                    <span v-else class="text-muted">—</span>
                                                </div>
                                                <div class="col-2 text-center">
                                                    <div v-if="'sms' in ev.channels" class="form-check form-switch d-inline-block m-0">
                                                        <input class="form-check-input" type="checkbox" role="switch" v-model="ev.channels.sms">
                                                    </div>
                                                    <span v-else class="text-muted">—</span>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <div class="card-footer d-flex justify-content-end" v-if="prefGroups.length">
                                    <button type="button" class="btn btn-primary me-2" :disabled="prefsSaving" @click="savePreferences">
                                        {{ __('save') }} <b-spinner v-if="prefsSaving" small label="Spinning"></b-spinner>
                                    </button>
                                    <button type="button" class="btn btn-danger" @click="$router.go(-1)">{{ __('back') }}</button>
                                </div>
                            </div>
                        </div>
                        <div class="col-12 col-lg-6 mb-4">
                            <form @submit.prevent="saveRecord">
                                <div class="card">
                                    <div class="card-body px-3 py-4-5">
                                        <div class="row">
                                            <div class="col-md-12">
                                                <h3>{{ __('change_password') }}</h3>
                                                <div class="mt-5">
                                                    <div class="form-group">
                                                        <label for='current_password'>{{ __('current_password') }}</label>
                                                        <div class="input-group">
                                                            <input :type="show.current ? 'text' : 'password'" id='current_password'
                                                                v-model="settings.current_password" class='form-control'
                                                                :placeholder="__('current_password')" required />
                                                            <span class="input-group-text" role="button" @click="show.current = !show.current">
                                                                <Eye v-if="show.current" :size="16" /><EyeOff v-else :size="16" />
                                                            </span>
                                                        </div>
                                                    </div>
                                                    <div class="form-group">
                                                        <label for='password'>{{ __('new_password') }}</label>
                                                        <div class="input-group">
                                                            <input :type="show.new ? 'text' : 'password'" id='password'
                                                                v-model="settings.password" class='form-control'
                                                                :placeholder="__('new_password')" required />
                                                            <span class="input-group-text" role="button" @click="show.new = !show.new">
                                                                <Eye v-if="show.new" :size="16" /><EyeOff v-else :size="16" />
                                                            </span>
                                                        </div>
                                                        <small v-if="passwordError" class="text-danger d-block">{{ passwordError }}</small>
                                                    </div>
                                                    <div class="form-group">
                                                        <label for='confirm_password'>{{ __('confirm_new_password') }}</label>
                                                        <div class="input-group">
                                                            <input :type="show.confirm ? 'text' : 'password'" id='confirm_password'
                                                                v-model="settings.confirm_password" class='form-control'
                                                                :placeholder="__('confirm_new_password')" required />
                                                            <span class="input-group-text" role="button" @click="show.confirm = !show.confirm">
                                                                <Eye v-if="show.confirm" :size="16" /><EyeOff v-else :size="16" />
                                                            </span>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="card-footer d-flex justify-content-end">
                                        <button type="submit" class="btn btn-primary me-2" :disabled="isLoading">
                                            {{ __('save') }} <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                                        </button>
                                        <button type="button" class="btn btn-danger" @click="$router.go(-1)">{{ __('back') }}</button>
                                    </div>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            </section>
        </div>

        <!-- Admin: redesigned account & security. -->
        <div class="page-content acct-page" v-else>
            <form @submit.prevent="saveRecord" class="acct-card">
                <div class="acct-hero">
                    <div class="acct-avatar">{{ initials }}</div>
                    <div class="min-w-0">
                        <div class="acct-hero-name">{{ settings.username || '—' }}</div>
                        <div class="acct-hero-role"><ShieldCheck :size="13" /> {{ roleName }}</div>
                    </div>
                </div>

                <div class="acct-body">
                    <!-- Account (admin only) -->
                    <section class="acct-sec" v-if="!isDeliveryBoy">
                        <div class="acct-sec-head">
                            <span class="acct-sec-ic"><UserCog :size="16" /></span>
                            <div>
                                <div class="acct-sec-title">{{ __('account') }}</div>
                                <div class="acct-sec-sub">{{ __('the_name_you_sign_in_with') }}</div>
                            </div>
                        </div>
                        <div class="acct-field">
                            <label for="acct-username">{{ __('username') }}</label>
                            <input type="text" id="acct-username" v-model="settings.username"
                                class="form-control" :placeholder="__('username')" required autocomplete="username" />
                        </div>
                    </section>

                    <!-- Security -->
                    <section class="acct-sec">
                        <div class="acct-sec-head">
                            <span class="acct-sec-ic"><KeyRound :size="16" /></span>
                            <div>
                                <div class="acct-sec-title">{{ __('change_password') }}</div>
                                <div class="acct-sec-sub">{{ __('leave_password_fields_to_keep_current') }}</div>
                            </div>
                        </div>
                        <div class="row g-3">
                            <div class="col-12">
                                <div class="acct-field">
                                    <label for="acct-current">{{ __('current_password') }}</label>
                                    <div class="input-group">
                                        <input :type="show.current ? 'text' : 'password'" id="acct-current"
                                            v-model="settings.current_password" class="form-control"
                                            :placeholder="__('current_password')" required autocomplete="current-password" />
                                        <span class="input-group-text" role="button" @click="show.current = !show.current">
                                            <Eye v-if="show.current" :size="16" /><EyeOff v-else :size="16" />
                                        </span>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="acct-field">
                                    <label for="acct-new">{{ __('new_password') }}</label>
                                    <div class="input-group">
                                        <input :type="show.new ? 'text' : 'password'" id="acct-new"
                                            v-model="settings.password" class="form-control"
                                            :placeholder="__('new_password')" required autocomplete="new-password" />
                                        <span class="input-group-text" role="button" @click="show.new = !show.new">
                                            <Eye v-if="show.new" :size="16" /><EyeOff v-else :size="16" />
                                        </span>
                                    </div>
                                    <small v-if="passwordError" class="text-danger d-block mt-1">{{ passwordError }}</small>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="acct-field">
                                    <label for="acct-confirm">{{ __('confirm_new_password') }}</label>
                                    <div class="input-group">
                                        <input :type="show.confirm ? 'text' : 'password'" id="acct-confirm"
                                            v-model="settings.confirm_password" class="form-control"
                                            :placeholder="__('confirm_new_password')" required autocomplete="new-password" />
                                        <span class="input-group-text" role="button" @click="show.confirm = !show.confirm">
                                            <Eye v-if="show.confirm" :size="16" /><EyeOff v-else :size="16" />
                                        </span>
                                    </div>
                                    <small v-if="settings.confirm_password && settings.password !== settings.confirm_password"
                                        class="text-danger d-block mt-1">{{ __('password_and_confirm_password_does_not_match') }}</small>
                                </div>
                            </div>
                        </div>
                    </section>
                </div>

                <div class="acct-foot">
                    <button type="button" class="btn btn-outline-secondary" @click="$router.go(-1)">
                        <ArrowLeft :size="16" /> {{ __('back') }}
                    </button>
                    <button type="submit" class="btn btn-primary" :disabled="isLoading">
                        <b-spinner v-if="isLoading" small></b-spinner>
                        <Save v-else :size="16" /> {{ __('save_changes') }}
                    </button>
                </div>
            </form>
        </div>
    </div>
</template>
<script>
import axios from "axios";
import Auth from '../Auth.js';
import { Eye, EyeOff, UserCog, ShieldCheck, KeyRound, Save, ArrowLeft, Bell } from 'lucide-vue-next';
import { fetchPasswordPolicy, passwordPolicyError } from '../utils/passwordPolicy.js';
export default {
    components: { Eye, EyeOff, UserCog, ShieldCheck, KeyRound, Save, ArrowLeft, Bell },
    data: function () {
        return {
            isLoading: false,
            prefsLoading: false,
            prefsSaving: false,
            prefGroups: [],
            passwordPolicy: null,
            show: { current: false, new: false, confirm: false },
            settings: {
                // Delivery boys log in via the admin record but Auth.user is the delivery-boy
                // row — fall back to name if username isn't present.
                username: Auth.user.username || Auth.user.name || "",
                current_password: "",
                password: "",
                confirm_password: "",
            }
        };
    },
    computed: {
        isDeliveryBoy: function () {
            return Auth.user.role_id === 3;
        },
        isBranch: function () {
            return typeof this.$isBranchUser === 'function' && this.$isBranchUser();
        },
        isBranchOwner: function () {
            return typeof this.$isBranchOwner === 'function' && this.$isBranchOwner();
        },
        // Delivery boys hit the /delivery_boy prefix (passport-guarded); admins use /api.
        apiBase: function () {
            return this.isDeliveryBoy ? this.$deliveryBoyApiUrl : this.$apiUrl;
        },
        // Notification-preferences endpoint by role.
        prefsUrl: function () {
            return this.isBranch
                ? (this.$apiUrl + '/branch_panel/notification_preferences')
                : (this.$deliveryBoyApiUrl + '/notification_preferences');
        },
        passwordError() {
            if (!this.settings.password) return '';
            return passwordPolicyError(this.settings.password, this.passwordPolicy);
        },
        // Two-letter monogram for the identity hero.
        initials() {
            const n = (this.settings.username || 'A').trim();
            const parts = n.split(/\s+/).filter(Boolean);
            const s = parts.length > 1 ? parts[0][0] + parts[1][0] : n.slice(0, 2);
            return s.toUpperCase();
        },
        roleName() {
            if (this.isDeliveryBoy) return __('delivery_boy') || 'Delivery Boy';
            if (this.isBranch) {
                const raw = (Auth.user.role && Auth.user.role.name) || '';
                if (this.isBranchOwner) {
                    const display = String(raw).replace(/^branch\d+:/, '');
                    return display === '__owner__' ? __('owner') : display;
                }
                return window.BranchName || __('branch');
            }
            const u = Auth.user || {};
            return (u.role && u.role.name) || u.role_name || __('administrator') || 'Administrator';
        },
    },
    mounted() {
        fetchPasswordPolicy().then(p => { this.passwordPolicy = p; });
    },
    created: function () {
        if (this.isDeliveryBoy || (this.isBranch && this.isBranchOwner)) {
            this.loadPreferences();
        }
    },
    methods: {
        // Dynamic notification preferences (delivery boy). Each group carries flags
        // for which channels appear so the header columns line up.
        loadPreferences() {
            this.prefsLoading = true;
            const language = window.localStorage.getItem('lang') || window.appLocale || 'en';
            axios.get(this.prefsUrl, { params: { language } }).then(res => {
                const groups = res.data.data || [];
                groups.forEach(g => {
                    g.hasMail = g.events.some(e => 'mail' in e.channels);
                    g.hasSms = g.events.some(e => 'sms' in e.channels);
                    g.hasPush = g.events.some(e => 'push' in e.channels);
                });
                this.prefGroups = groups;
            }).catch(() => { this.showError(__('something_went_wrong')); })
                .finally(() => { this.prefsLoading = false; });
        },
        savePreferences() {
            this.prefsSaving = true;
            const preferences = [];
            this.prefGroups.forEach(g => {
                g.events.forEach(ev => {
                    preferences.push({ key: ev.key, channels: ev.channels });
                });
            });
            axios.post(this.prefsUrl, { preferences }).then(res => {
                if (res.data.status === 1) {
                    this.showMessage('success', res.data.message);
                } else {
                    this.showError(res.data.message);
                }
            }).catch(err => {
                this.showError(err.response?.data?.message || __('something_went_wrong'));
            }).finally(() => { this.prefsSaving = false; });
        },

        saveRecord: function () {
            if (this.passwordError) { this.showError(this.passwordError); return; }
            let vm = this;
            this.isLoading = true;
            // Both endpoints share the old_/new_/confirm_ param contract.
            let payload = {
                old_password: this.settings.current_password,
                new_password: this.settings.password,
                confirm_password: this.settings.confirm_password,
            };
            let changePasswordUrl;
            if (this.isDeliveryBoy) {
                changePasswordUrl = this.$deliveryBoyApiUrl + '/reset_password';
            } else if (this.isBranch) {
                // Branch user is a system-user under a branch scope; hit the scoped alias.
                changePasswordUrl = this.$apiUrl + '/branch_panel/change_password';
                payload.username = this.settings.username;
            } else {
                changePasswordUrl = this.$apiUrl + '/system_users/change_password';
                payload.username = this.settings.username;
            }
            axios.post(changePasswordUrl, payload).then(res => {
                let data = res.data;
                vm.isLoading = false;
                if (data.status === 1) {
                    vm.showMessage("success", data.message);
                    // Admin changes username here; delivery boy resets password only.
                    if (!vm.isDeliveryBoy) {
                        Auth.user.username = vm.settings.username;
                        window.localStorage.setItem('user', JSON.stringify(Auth.user));
                    }
                    let role_id = Auth.user.role_id;
                    if (role_id === 3) {
                        this.$router.push('/delivery_boy');
                    } else {
                        this.$router.push({ path: '/' });
                    }
                } else {
                    vm.showError(data.message);
                }
            }).catch(error => {
                vm.isLoading = false;
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError(__('something_went_wrong'));
                }
            });
        },

        deleteAccount: function () {
            let vm = this;
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('delete_account_confirmation'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#d33',
                cancelButtonColor: '#3085d6',
                confirmButtonText: __('yes_delete'),
                cancelButtonText: __('cancel')
            }).then((result) => {
                if (result.isConfirmed) {
                    vm.$swal.fire({
                        title: __('final_confirmation'),
                        text: __('delete_account_final_warning'),
                        icon: 'error',
                        showCancelButton: true,
                        confirmButtonColor: '#d33',
                        cancelButtonColor: '#3085d6',
                        confirmButtonText: __('yes_delete_permanently'),
                        cancelButtonText: __('cancel'),
                        dangerMode: true
                    }).then((secondResult) => {
                        if (secondResult.isConfirmed) {
                            vm.isLoading = true;
                            let role_id = Auth.user.role_id;
                            let deleteUrl = '';

                            if (role_id === 3) {
                                deleteUrl = this.$deliveryBoyApiUrl + '/delete_account';
                            }

                            if (deleteUrl) {
                                axios.get(deleteUrl).then((response) => {
                                    vm.isLoading = false;
                                    let data = response.data;
                                    if (data.status === 1) {
                                        vm.showSuccess(data.message);
                                        Auth.logout();
                                        setTimeout(() => {
                                            vm.$router.push('/login');
                                        }, 1500);
                                    } else {
                                        vm.showError(data.message);
                                    }
                                }).catch(error => {
                                    vm.isLoading = false;
                                    if (error.request && error.request.statusText) {
                                        this.showError(error.request.statusText);
                                    } else if (error.message) {
                                        this.showError(error.message);
                                    } else {
                                        this.showError(__('something_went_wrong'));
                                    }
                                });
                            }
                        }
                    });
                }
            });
        }
    },
};
</script>
<style scoped>
.acct-page {
    display: flex;
    justify-content: center;
    padding-top: 0.5rem;
}
.acct-card {
    width: 100%;
    background: var(--app-card-bg);
    border: 1px solid var(--app-card-border);
    border-radius: 16px;
    overflow: hidden;
    box-shadow: 0 8px 30px rgba(16, 24, 40, 0.06);
}
/* Identity hero — gradient strip with monogram avatar. */
.acct-hero {
    display: flex;
    align-items: center;
    gap: 0.9rem;
    padding: 1.4rem 1.6rem;
    background: linear-gradient(135deg, rgba(var(--bs-primary-rgb), 0.14), rgba(var(--bs-primary-rgb), 0.02));
    border-bottom: 1px solid var(--app-card-border);
}
.acct-avatar {
    width: 54px;
    height: 54px;
    flex: none;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 1.2rem;
    color: #fff;
    background: linear-gradient(135deg, var(--bs-primary), color-mix(in srgb, var(--bs-primary) 60%, #000));
    box-shadow: 0 4px 12px rgba(var(--bs-primary-rgb), 0.35);
}
.acct-hero-name {
    font-weight: 700;
    font-size: 1.1rem;
    color: var(--app-ink);
    line-height: 1.2;
}
.acct-hero-role {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    font-size: 0.78rem;
    color: var(--app-muted);
    margin-top: 2px;
}
.acct-body {
    padding: 1.4rem 1.6rem;
    display: flex;
    flex-direction: column;
    gap: 1.6rem;
}
.acct-sec-head {
    display: flex;
    align-items: center;
    gap: 0.65rem;
    margin-bottom: 0.9rem;
}
.acct-sec-ic {
    width: 34px;
    height: 34px;
    flex: none;
    border-radius: 9px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    color: var(--bs-primary);
    background: rgba(var(--bs-primary-rgb), 0.1);
}
.acct-sec-title {
    font-weight: 700;
    font-size: 0.95rem;
    color: var(--app-ink);
    line-height: 1.15;
}
.acct-sec-sub {
    font-size: 0.75rem;
    color: var(--app-muted);
}
.acct-field { margin-bottom: 0; }
.acct-field label {
    display: block;
    font-size: 0.78rem;
    font-weight: 600;
    color: var(--app-muted);
    text-transform: uppercase;
    letter-spacing: 0.02em;
    margin-bottom: 0.35rem;
}
.acct-foot {
    display: flex;
    justify-content: flex-end;
    gap: 0.6rem;
    padding: 1rem 1.6rem;
    border-top: 1px solid var(--app-card-border);
    background: var(--app-thead-bg);
}
.acct-foot .btn {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
}
/* Notification preference rows (delivery boy). */
.acct-pref-group { margin-top: 1.1rem; }
.acct-pref-group:first-child { margin-top: 1.2rem; }
.acct-pref-headrow {
    border-bottom: 1px solid var(--app-card-border);
    padding-bottom: 0.4rem;
    margin-bottom: 0.5rem !important;
}
.acct-pref-row {
    padding: 0.35rem 0;
    border-bottom: 1px solid var(--app-card-border);
}
.acct-pref-row:last-child { border-bottom: 0; }
.acct-pref-row label { color: var(--app-ink); font-size: 0.85rem; }
@media (max-width: 575.98px) {
    .acct-hero, .acct-body, .acct-foot { padding-left: 1rem; padding-right: 1rem; }
}
</style>
