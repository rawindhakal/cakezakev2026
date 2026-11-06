<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" no-fade static centered>
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">{{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord">
            <div class="row">
                <div class="form-group">
                    <label for='username'>{{ __('username') }} <span class="text-danger text-xs">*</span></label>
                    <input type='text' id='username' v-model="system_user.username" class='form-control' :placeholder="__('username')" required />
                </div>
                <div class="form-group">
                    <label for='email'>{{ __('email') }} <span class="text-danger text-xs">*</span></label>
                    <input type='email' id='email' v-model="system_user.email" class='form-control' :placeholder="__('email')" required />
                </div>

                <div class="form-group">
                    <label for='role'>{{ __('role') }} <span class="text-danger text-xs">*</span></label>
                    <AppSelect class="form-control form-select" v-model="system_user.role_id"
                        :options="roleOptions" :placeholder="__('select_user_role')" />
                </div>

                <div class="form-group">
                    <label for='password'>{{ __('password') }} <span class="text-danger text-xs">*</span></label>
                    <div class="input-group">
                        <input :type="showPassword ? 'text' : 'password'" id='password' v-model="system_user.password" class='form-control' :placeholder="__('password')" :required="!system_user.id ? true : false" />
                        <button type="button" v-on:click="showPassword = !showPassword" class="btn btn-outline-primary mb-0">
                            <Eye v-if="showPassword" :size="16" />
                            <EyeOff v-else :size="16" />
                        </button>
                    </div>
                    <small v-if="passwordError" class="text-danger d-block mt-1">{{ passwordError }}</small>
                </div>
                <div class="form-group">
                    <label for='confirm_password'>{{ __('confirm_password') }} <span class="text-danger text-xs">*</span></label>
                    <div class="input-group">
                        <input :type="showConfirmPassword ? 'text' : 'password'" id='confirm_password' v-model="system_user.confirm_password" class='form-control' :placeholder="__('confirm_password')" :required="!system_user.id ? true : false" />
                        <button type="button" v-on:click="showConfirmPassword = !showConfirmPassword" class="btn btn-outline-primary mb-0">
                            <Eye v-if="showConfirmPassword" :size="16" />
                            <EyeOff v-else :size="16" />
                        </button>
                    </div>
                </div>

                <span class='text_hint' v-if="system_user.id">
                    {{ __('note') }} : {{ __('leave_it_blank_if_you_dont_want_to_update_it') }}
                </span>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import Multiselect from 'vue-multiselect'
import { fetchPasswordPolicy, passwordPolicyError } from '../../utils/passwordPolicy.js';
import { Eye, EyeOff } from 'lucide-vue-next';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
export default {
    props: ['record','roles'],
    mixins: [UnsavedChanges],
    components: {
        Multiselect, Eye, EyeOff
    },
    created: function() {
    },
    beforeUnmount() {
        // Clean up event listeners to prevent accumulation
        this.$eventBus.off('systemUserSaved');
    },
    data : function(){
        return {
            isLoading: false,
            showPassword: false,
            showConfirmPassword:false,
            passwordPolicy: null,
            system_user : {
                id: this.record ? this.record.id : null,
                username: this.record ? this.record.username : "",
                email: this.record ? this.record.email : "",
                role_id: this.record ? this.record.role.id : "",
                password: "",
                confirm_password: "",
            }

        };
    },
    computed: {
        // Super Admin is not assignable here, so it never reaches the list.
        roleOptions() {
            return (this.roles || []).filter(r => r.name !== 'Super Admin');
        },
        modal_title: function(){
            let title = this.system_user.id ? __('edit') : __('create') ;
            title += ' ' + __('system_users');
            return title;
        },
        // Inline password policy error (empty when valid or password left blank).
        passwordError() {
            if (!this.system_user.password) return '';
            return passwordPolicyError(this.system_user.password, this.passwordPolicy);
        },
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return this.system_user;
        },
        showModal() {
            this.$refs['my-modal'].show()
        },
        hideModal() {
            this.$refs['my-modal'].hide()
        },
        saveRecord: function(){
            let vm = this;

            // Password must satisfy the configured policy (create, or edit when set).
            if (this.system_user.password && this.passwordError) {
                this.showError(this.passwordError);
                return;
            }
            if (this.system_user.password
                && this.system_user.password !== this.system_user.confirm_password) {
                this.showError(__('password_and_confirm_password_must_match'));
                return;
            }

            this.isLoading = true;

            let url = this.$apiUrl + '/system_users/save';
            if(this.system_user.id){
                url = this.$apiUrl + '/system_users/update';
            }
            axios.post(url, this.system_user).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    vm.isLoading = false;
                    // Mark clean so closing the modal doesn't trip the guard.
                    vm.captureFormBaseline();
                    vm.$eventBus.emit('systemUserSaved', data.message);
                    // Add small delay to ensure toast is shown before modal closes
                    setTimeout(() => {
                        vm.hideModal();
                    }, 100);
                }else{
                    vm.showMessage('error', data.message);
                    vm.isLoading = false;
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
    },
    mounted(){
        this.showModal();
        fetchPasswordPolicy().then(p => { this.passwordPolicy = p; });
        // Baseline the prop-populated form for the UnsavedChanges guard.
        this.captureFormBaseline();
    }
}
</script>

<style scoped>
.text_hint{
    margin-top: 10px;
    margin-bottom: 10px;
    color: gray;
}
</style>
