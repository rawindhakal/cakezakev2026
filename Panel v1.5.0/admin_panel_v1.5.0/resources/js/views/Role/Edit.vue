<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" size="xl" scrollable no-close-on-backdrop
        no-fade static>
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">{{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>

        <template #modal-header="{ close }">
            <h5 v-if="id" class="modal-title">{{ modal_title }} & {{ __('permission_access') }} : <strong> {{ printName }} </strong>
            </h5>
            <h5 v-else class="modal-title">{{ modal_title }}</h5>
            <button type="button" aria-label="Close" class="close" @click="close()">×</button>
        </template>

        <form ref="my-form" @submit.prevent="saveRecord">
            <div class="row">
                <div class="form-group">
                    <label>{{ __('title') }}</label>
                    <i class="text-danger">*</i>
                    <input type="text" class="form-control" required v-model="name" :placeholder="__('title')">
                </div>

                <div class="d-flex justify-content-end mb-2">
                    <div class="btn-group btn-group-sm">
                        <button type="button" class="btn btn-outline-primary mb-0" @click="setAllPermissions(true)">{{ __('select_all') }}</button>
                        <button type="button" class="btn btn-outline-secondary mb-0" @click="setAllPermissions(false)">{{ __('deselect_all') }}</button>
                    </div>
                </div>

                <div class="table-responsive">

                    <table class="table table-lg table-striped">
                        <tbody>
                            <tr v-for="(category, index) in categories">

                                <th class="table-active"> {{ formattedName(category.name) }} </th>

                                <td>
                                    <div class="row">
                                        <template v-if="id">
                                            <div v-for="permission in category.permissions"
                                                class="col-12 col-md-6 col-lg-4 mb-2">
                                                <div class='form-check form-switch'>
                                                    <input class='form-check-input' type='checkbox'
                                                        :id="'checkbox_' + permission.id" :value="permission.id"
                                                        v-model="user_permissions" @change="onPermToggle(permission)">
                                                    <label class="form-check-label" style="margin-left: 5px"
                                                        :for="'checkbox_' + permission.id"> {{
                                                            formattedName(permission.name) }} </label>
                                                </div>
                                            </div>
                                        </template>
                                        <template v-else>
                                            <div v-for="permission in category.permissions"
                                                class="col-12 col-md-6 col-lg-4 mb-2">
                                                <div class='form-check form-switch'>
                                                    <input class='form-check-input' type='checkbox'
                                                        :id="'checkbox_' + permission.id" :value="permission.id"
                                                        v-model="user_permissions"
                                                        :checked="user_permissions.includes(permission.id)"
                                                        @change="onPermToggle(permission)">
                                                    <label class="form-check-label" style="margin-left: 5px"
                                                        :for="'checkbox_' + permission.id"> {{
                                                            formattedName(permission.name) }} </label>
                                                </div>
                                            </div>
                                        </template>
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
import axios from 'axios';
import { cascadePermission } from '../../utils/permissionCascade.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

export default {
    props: ['record'],
    mixins: [UnsavedChanges],
    data: function () {
        return {
            isLoading: false,
            closeModalTimer: null,

            printName: this.record ? this.record.name : null,

            id: this.record ? this.record.id : null,
            name: this.record ? this.record.name : null,
            categories: [],
            user_permissions: [],
        };
    },
    computed: {
        modal_title: function () {
            let title = this.id ? __('edit') : __('add');
            title += ' ' + __('role');
            return title;
        }
    },
    created: function () {
        this.getRecords();
    },
    beforeUnmount() {
        // Clean up event listeners to prevent accumulation
        this.$eventBus.off('roleSaved');
        if (this.closeModalTimer) {
            clearTimeout(this.closeModalTimer);
            this.closeModalTimer = null;
        }
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return {
                name: this.name,
                user_permissions: this.user_permissions,
            };
        },

        getRecords() {
            this.isLoading = true
            let url = this.$apiUrl + '/role/permissions';
            if (this.id) {
                url = this.$apiUrl + '/role/edit/' + this.record.id;
            }
            axios.get(url)
                .then((response) => {
                    this.isLoading = false
                    let data = response.data;
                    this.categories = data.data.categories
                    if (this.id) {
                        this.user_permissions = data.data.user_permissions
                    }
                    // Baseline the loaded form for the UnsavedChanges guard.
                    this.captureFormBaseline();
                });
        },
        showModal() {
            const modal = this.$refs['my-modal'];
            if (modal && typeof modal.show === 'function') {
                modal.show();
            }
        },
        hideModal() {
            const modal = this.$refs['my-modal'];
            if (modal && typeof modal.hide === 'function') {
                modal.hide();
            }
        },

        saveRecord: function () {
            let vm = this;
            this.isLoading = true;

            let formData = new FormData();
            if (this.id) {
                formData.append('id', this.id);
            }
            formData.append('name', this.name);

            for (var index in this.user_permissions) {
                formData.append('permissions[]', this.user_permissions[index]);
            }

            let url = this.$apiUrl + '/role/save';
            if (this.id) {
                url = this.$apiUrl + '/role/update';
            }

            axios.post(url, formData).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    this.isLoading = false;
                    // Mark clean so closing the modal doesn't trip the guard.
                    this.captureFormBaseline();
                    this.$eventBus.emit('roleSaved', data.message);
                    // Add small delay to ensure toast is shown before modal closes
                    this.closeModalTimer = setTimeout(() => {
                        this.hideModal();
                    }, 100);
                } else {
                    vm.showError(data.message);
                    vm.isLoading = false;
                }
            }).catch(error => {
                vm.isLoading = false;
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError("Something went wrong!");
                }
            });
        },

        onPermToggle: function (permission) {
            this.user_permissions = cascadePermission(this.user_permissions, this.categories, permission);
        },
        allPermissionIds: function () {
            return this.categories.flatMap(c => (c.permissions || []).map(p => p.id));
        },
        setAllPermissions: function (checked) {
            this.user_permissions = checked ? this.allPermissionIds() : [];
        },

        formattedName: function (name) {
            var newName = name.replace(/_/g, ' ');
            newName = newName.toLowerCase().replace(/(?<= )[^\s]|^./g, a => a.toUpperCase())
            return newName;
        }
    },
    mounted() {
        this.showModal();
    }
}
</script>

<style scoped>
.switch {
    display: inline-block;
    height: 34px;
    position: relative;
    width: 60px;
}

.switch input {
    display: none;
}

.slider {
    background-color: #ccc;
    bottom: 0;
    cursor: pointer;
    left: 0;
    position: absolute;
    right: 0;
    top: 0;
    transition: .4s;
}

.slider:before {
    background-color: var(--app-card-bg);
    bottom: 4px;
    content: "";
    height: 26px;
    left: 4px;
    position: absolute;
    transition: .4s;
    width: 26px;
}

input:checked+.slider {
    background-color: #66bb6a;
}

input:checked+.slider:before {
    transform: translateX(26px);
}

.slider.round {
    border-radius: 34px;
}

.slider.round:before {
    border-radius: 50%;
}

.form-check {
    display: flex !important;
    align-items: flex-start;
}

.form-check-input {
    flex-shrink: 0;
    margin-top: 0.25rem;
}

.form-check-label {
    word-break: break-word;
    white-space: normal;
}
</style>
