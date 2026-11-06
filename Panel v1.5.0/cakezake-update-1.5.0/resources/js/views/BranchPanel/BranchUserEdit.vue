<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" no-fade static centered>
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">{{ __('save') }}
                <b-spinner v-if="isLoading" small></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord">
            <div class="row">
                <div class="form-group">
                    <label>{{ __('username') }} <span class="text-danger">*</span></label>
                    <input type="text" v-model="user.username" class="form-control" required />
                </div>
                <div class="form-group">
                    <label>{{ __('email') }} <span class="text-danger">*</span></label>
                    <input type="email" v-model="user.email" class="form-control" required />
                </div>
                <div class="form-group">
                    <label>{{ __('role') }} <span class="text-danger">*</span></label>
                    <AppSelect class="form-control form-select" v-model="user.role_id" :options="roles" :placeholder="__('select_user_role')" />
                </div>
                <div class="form-group">
                    <label>{{ __('password') }} <span v-if="!user.id" class="text-danger">*</span></label>
                    <div class="input-group">
                        <input :type="showPassword ? 'text' : 'password'" v-model="user.password" class="form-control" autocomplete="new-password" :required="!user.id" />
                        <button type="button" class="btn btn-outline-primary mb-0" @click="showPassword = !showPassword">
                            <Eye v-if="showPassword" :size="16" /><EyeOff v-else :size="16" />
                        </button>
                    </div>
                    <small v-if="passwordError" class="text-danger d-block mt-1">{{ passwordError }}</small>
                </div>
                <div class="form-group">
                    <label>{{ __('confirm_password') }} <span v-if="!user.id" class="text-danger">*</span></label>
                    <div class="input-group">
                        <input :type="showConfirmPassword ? 'text' : 'password'" v-model="user.confirm_password" class="form-control" autocomplete="new-password" :required="!user.id" />
                        <button type="button" class="btn btn-outline-primary mb-0" @click="showConfirmPassword = !showConfirmPassword">
                            <Eye v-if="showConfirmPassword" :size="16" /><EyeOff v-else :size="16" />
                        </button>
                    </div>
                </div>
                <span class="text-muted small mt-2" v-if="user.id">
                    {{ __('note') }} : {{ __('leave_it_blank_if_you_dont_want_to_update_it') }}
                </span>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>
<script>
import { Eye, EyeOff } from 'lucide-vue-next';
import { fetchPasswordPolicy, passwordPolicyError } from '../../utils/passwordPolicy.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
export default {
    props: ['record', 'roles'],
    mixins: [UnsavedChanges],
    components: { Eye, EyeOff },
    data() {
        return {
            isLoading: false,
            showPassword: false,
            showConfirmPassword: false,
            passwordPolicy: null,
            user: {
                id: this.record ? this.record.id : null,
                username: this.record ? this.record.username : '',
                email: this.record ? this.record.email : '',
                role_id: this.record && this.record.role ? this.record.role.id : '',
                password: '', confirm_password: '',
            },
        };
    },
    computed: {
        modal_title() { return (this.user.id ? __('edit') : __('create')) + ' ' + __('branch_users'); },
        passwordError() {
            if (!this.user.password) return '';
            return passwordPolicyError(this.user.password, this.passwordPolicy);
        },
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return this.user;
        },
        showModal() { this.$refs['my-modal'].show(); },
        hideModal() { this.$refs['my-modal'].hide(); },
        saveRecord() {
            if (this.user.password && this.passwordError) {
                this.showError(this.passwordError);
                return;
            }
            if (this.user.password && this.user.password !== this.user.confirm_password) {
                this.showError(__('password_and_confirm_password_must_match'));
                return;
            }
            this.isLoading = true;
            const url = this.$apiUrl + (this.user.id ? '/branch_users/update' : '/branch_users/save');
            axios.post(url, this.user).then(res => {
                this.isLoading = false;
                if (res.data.status === 1) {
                    // Mark clean so closing the modal doesn't trip the guard.
                    this.captureFormBaseline();
                    this.$eventBus.emit('branchUserSaved', res.data.message);
                    setTimeout(() => this.hideModal(), 100);
                } else {
                    this.showMessage('error', res.data.message);
                }
            }).catch(err => {
                this.isLoading = false;
                this.showError(err?.response?.data?.message || err.message || __('something_went_wrong'));
            });
        },
    },
    mounted() {
        this.showModal();
        fetchPasswordPolicy().then(p => { this.passwordPolicy = p; });
        // Baseline the prop-populated form for the UnsavedChanges guard.
        this.captureFormBaseline();
    },
};
</script>
