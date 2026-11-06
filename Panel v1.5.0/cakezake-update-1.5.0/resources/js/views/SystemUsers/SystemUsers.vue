<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('system_users') }}</h3>

            <button
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="openCreateModal()"
                v-if="$role('Super Admin')">
                <Plus :size="16" />
                <span>{{ __('add_user') }}</span>
            </button>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input
                        id="filter-input"
                        v-model="filter"
                        type="search"
                        class="form-control"
                        :placeholder="__('search')">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getRecords()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive
                :items="displayUsers"
                :fields="fields"
                :current-page="currentPage"
                :per-page="perPage"
                :filter="filter"
                :filter-included-fields="filterOn"
                v-model:sort-by="sortBy"
                v-model:sort-desc="sortDesc"
                :sort-direction="sortDirection"

                :busy="isLoading"
                stacked="md"
                show-empty
                small>

                <template #cell(email)="row">
                    {{ $filters.emailMask(row.item.email) }}
                </template>

                <template #cell(role)="row">
                    {{ row.item.role.name }}
                </template>

                <template #cell(actions)="row">
                    <template v-if="row.item.role.name !== 'Super Admin'">
                        <div class="list-actions">
                            <button class="list-action-btn is-edit" @click="openEditModal(row.item)" v-b-tooltip.hover :title="__('edit')">
                                <Pencil :size="15" />
                            </button>
                            <button class="list-action-btn is-delete" @click="deleteSystemUser(row.index,row.item.id)" v-b-tooltip.hover :title="__('delete')">
                                <Trash2 :size="15" />
                            </button>
                        </div>
                    </template>
                    <template v-else>
                        <span class="text-muted small d-inline-flex align-items-center gap-1">
                            <ShieldCheck :size="15" /> {{ __('protected') }}
                        </span>
                    </template>
                </template>

            </MazerDatatable>

            <div class="list-footer">
                <div class="list-perpage">
                    <span>{{ __('per_page') }}</span>
                    <b-form-select
                        id="per-page-select"
                        v-model="perPage"
                        :options="pageOptions"
                        size="sm"
                        class="form-select"
                    ></b-form-select>
                </div>

                <b-pagination
                    v-model="currentPage"
                    :total-rows="totalRows"
                    :per-page="perPage"
                    size="sm"
                    class="mb-0 list-pagination"
                ></b-pagination>
            </div>
        </div>

        <!-- Add / Edit -->
        <app-edit-record
            v-if="create_new || edit_record"
            :record="edit_record"
            :roles="roles"
            :products="products"
            @modalClose="hideModal()"
        ></app-edit-record>
    </div>
</template>
<script>
import EditRecord from './Edit.vue';
import { Search, RefreshCw, Plus, Pencil, Trash2, ShieldCheck } from 'lucide-vue-next';
export default {
    components: {
        'app-edit-record' : EditRecord,
        Search, RefreshCw, Plus, Pencil, Trash2, ShieldCheck,
    },
    data: function() {
        return {
            fields: [
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc' },
                { key: 'username', label: __('username'), sortable: false, class: 'text-center' },
                { key: 'email', label: __('email'), sortable: false, class: 'text-center' },
                { key: 'role', label: __('role'), sortable: false,  class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false, }
            ],
            totalRows: 1,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            sortBy: '',
            sortDesc: false,
            sortDirection: 'asc',
            filter: null,
            filterOn: ['name', 'email', 'role_name'],
            page: 1,

            isLoading: false,

            create_new : null,
            edit_record : null,
            system_users : [],
            roles : [],
        }
    },
    computed: {
        displayUsers() {
            return (this.system_users || []).map(u => ({
                ...u,
                role_name: u.role ? u.role.name : '',
            }));
        },
        sortOptions() {
            // Create an options list from our fields
            return this.fields
                .filter(f => f.sortable)
                .map(f => {
                    return { text: f.label, value: f.key }
                })
        }
    },
    mounted() {
        // Set the initial number of items
        this.totalRows = this.system_users.length
    },
    created: function() {
        this.ensureEventListeners();
        this.getRecords();
    },
    beforeUnmount() {
        // Clean up event listeners to prevent accumulation
        this.$eventBus.off('systemUserSaved');
    },
    methods: {
        getRecords(){
            this.isLoading = true
            axios.get(this.$apiUrl + '/system_users')
                .then((response) => {
                    this.system_users = response.data.data.records;
                    this.roles = response.data.data.roles;
                    this.totalRows = this.system_users.length;
                    this.isLoading = false;
                });
        },
        deleteSystemUser(index, id){
            this.$swal.fire({
                title: __('are_you_sure'),  
                text: __('you_want_be_able_to_revert_this'),
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (result.value) {
                    this.isLoading = true
                    let postData = {
                        id : id
                    }
                    axios.post(this.$apiUrl + '/system_users/delete',postData)
                        .then((response) => {
                            this.isLoading = false;
                            this.system_users.splice(index, 1);
                            this.showMessage("success", response.data.message);
                        });
                }
            });
        },
        hideModal() {
            this.create_new = false
            this.edit_record = null
        },
        openCreateModal() {
            this.create_new = true
            this.edit_record = null
            this.ensureEventListeners();
        },
        openEditModal(record) {
            this.edit_record = record
            this.create_new = false
            this.ensureEventListeners();
        },
        ensureEventListeners() {
            this.$eventBus.off('systemUserSaved');
            this.$eventBus.on('systemUserSaved', (message) => {
                this.showMessage("success", message);
                this.getRecords();
                this.hideModal();
            });
        },
    }
};
</script>
