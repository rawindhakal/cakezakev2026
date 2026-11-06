<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" size="xl" scrollable no-close-on-backdrop no-fade static>
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">{{ __('save') }}
                <b-spinner v-if="isLoading" small></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord">
            <div class="row">
                <div class="form-group">
                    <label>{{ __('title') }} <i class="text-danger">*</i></label>
                    <input type="text" class="form-control" required v-model="name" :placeholder="__('title')">
                </div>
                <div class="table-responsive">
                    <table class="table table-lg table-striped">
                        <tbody>
                            <tr v-for="category in categories" :key="category.id">
                                <th class="table-active">{{ formattedName(category.name) }}</th>
                                <td>
                                    <div class="row">
                                        <div v-for="permission in category.permissions" :key="permission.id" class="col-12 col-md-6 col-lg-4 mb-2">
                                            <div class="form-check form-switch">
                                                <input class="form-check-input" type="checkbox" :id="'sp_' + permission.id" :value="permission.id" v-model="user_permissions" @change="onPermToggle(permission)">
                                                <label class="form-check-label" style="margin-left:5px" :for="'sp_' + permission.id">{{ formattedName(permission.name) }}</label>
                                            </div>
                                        </div>
                                    </div>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>
<script>
import { cascadePermission } from '../../utils/permissionCascade.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
export default {
    props: ['record'],
    mixins: [UnsavedChanges],
    data() {
        return {
            isLoading: false, closeModalTimer: null,
            id: this.record ? this.record.id : null,
            name: this.record ? this.record.name : null,
            categories: [], user_permissions: [],
        };
    },
    computed: {
        modal_title() { return (this.id ? __('edit') : __('add')) + ' ' + __('role'); },
    },
    created() { this.getRecords(); },
    beforeUnmount() {
        this.$eventBus.off('branchRoleSaved');
        if (this.closeModalTimer) { clearTimeout(this.closeModalTimer); }
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return {
                name: this.name,
                user_permissions: this.user_permissions,
            };
        },
        onPermToggle(permission) {
            this.user_permissions = cascadePermission(this.user_permissions, this.categories, permission);
        },
        getRecords() {
            this.isLoading = true;
            const url = this.id ? this.$apiUrl + '/branch_roles/edit/' + this.id : this.$apiUrl + '/branch_roles/permissions';
            axios.get(url).then(res => {
                this.isLoading = false;
                const data = res.data.data;
                this.categories = data.categories || [];
                if (this.id) {
                    this.name = data.name;
                    this.user_permissions = data.user_permissions || [];
                }
                // Baseline the loaded form for the UnsavedChanges guard.
                this.captureFormBaseline();
            });
        },
        showModal() { this.$refs['my-modal']?.show(); },
        hideModal() { this.$refs['my-modal']?.hide(); },
        saveRecord() {
            this.isLoading = true;
            const fd = new FormData();
            if (this.id) fd.append('id', this.id);
            fd.append('name', this.name);
            this.user_permissions.forEach(p => fd.append('permissions[]', p));
            const url = this.$apiUrl + (this.id ? '/branch_roles/update' : '/branch_roles/save');
            axios.post(url, fd).then(res => {
                this.isLoading = false;
                if (res.data.status === 1) {
                    // Mark clean so closing the modal doesn't trip the guard.
                    this.captureFormBaseline();
                    this.$eventBus.emit('branchRoleSaved', res.data.message);
                    this.closeModalTimer = setTimeout(() => this.hideModal(), 100);
                } else {
                    this.showError(res.data.message);
                }
            }).catch(err => {
                this.isLoading = false;
                this.showError(err?.response?.data?.message || err.message || __('something_went_wrong'));
            });
        },
        formattedName(name) {
            let n = String(name).replace(/_/g, ' ').toLowerCase();
            return n.replace(/(?<= )[^\s]|^./g, a => a.toUpperCase());
        },
    },
    mounted() { this.showModal(); },
};
</script>
