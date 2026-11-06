<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('branch_users') }}</h3>
            <button v-if="$can('branch_user_manage')"
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="openCreateModal()">
                <Plus :size="16" />
                <span>{{ __('add_user') }}</span>
            </button>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input id="filter-input" v-model="filter" type="search" class="form-control" :placeholder="__('search')">
                </div>
                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getRecords()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive :items="displayUsers" :fields="fields" :current-page="currentPage"
                :per-page="perPage" :filter="filter" :filter-included-fields="filterOn"
                v-model:sort-by="sortBy" v-model:sort-desc="sortDesc" :sort-direction="sortDirection"
                :busy="isLoading" stacked="md" show-empty small>
                <template #cell(email)="row">{{ $filters.emailMask(row.item.email) }}</template>
                <template #cell(role)="row">{{ roleName(row.item) }}</template>
                <template #cell(actions)="row">
                    <template v-if="!row.item.is_branch_owner">
                        <div class="list-actions">
                            <button v-if="$can('branch_user_manage')" class="list-action-btn is-edit" @click="openEditModal(row.item)" v-b-tooltip.hover :title="__('edit')">
                                <Pencil :size="15" />
                            </button>
                            <button v-if="$can('branch_user_manage')" class="list-action-btn is-delete" @click="deleteRecord(row.index, row.item.id)" v-b-tooltip.hover :title="__('delete')">
                                <Trash2 :size="15" />
                            </button>
                        </div>
                    </template>
                    <template v-else>
                        <span class="text-muted small d-inline-flex align-items-center gap-1">
                            <ShieldCheck :size="15" /> {{ __('owner') }}
                        </span>
                    </template>
                </template>
            </MazerDatatable>

            <div class="list-footer">
                <div class="list-perpage">
                    <span>{{ __('per_page') }}</span>
                    <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions" size="sm" class="form-select"></b-form-select>
                </div>
                <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage" size="sm" class="mb-0 list-pagination"></b-pagination>
            </div>
        </div>

        <app-edit-record v-if="create_new || edit_record" :record="edit_record" :roles="roles" @modalClose="hideModal()"></app-edit-record>
    </div>
</template>
<script>
import EditRecord from './BranchUserEdit.vue';
import { Search, RefreshCw, Plus, Pencil, Trash2, ShieldCheck } from 'lucide-vue-next';
export default {
    components: { 'app-edit-record': EditRecord, Search, RefreshCw, Plus, Pencil, Trash2, ShieldCheck },
    data() {
        return {
            fields: [
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc' },
                { key: 'username', label: __('username'), sortable: false, class: 'text-center' },
                { key: 'email', label: __('email'), sortable: false, class: 'text-center' },
                { key: 'role', label: __('role'), sortable: false, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false },
            ],
            totalRows: 1, currentPage: 1, perPage: this.$perPage, pageOptions: this.$pageOptions,
            sortBy: '', sortDesc: false, sortDirection: 'asc', filter: null,
            filterOn: ['username', 'email'], isLoading: false,
            create_new: null, edit_record: null, system_users: [], roles: [],
        };
    },
    computed: {
        displayUsers() { return this.system_users || []; },
    },
    created() { this.ensureEventListeners(); this.getRecords(); },
    beforeUnmount() { this.$eventBus.off('branchUserSaved'); },
    methods: {
        roleName(item) {
            const raw = item.role ? item.role.name : '';
            // Strip the internal "branch{id}:" prefix; humanize the owner slug.
            const display = String(raw).replace(/^branch\d+:/, '');
            return display === '__owner__' ? __('owner') : display;
        },
        getRecords() {
            this.isLoading = true;
            axios.get(this.$apiUrl + '/branch_users').then(res => {
                this.system_users = res.data.data.records;
                this.roles = res.data.data.roles;
                this.totalRows = this.system_users.length;
                this.isLoading = false;
            });
        },
        deleteRecord(index, id) {
            this.$swal.fire({
                title: __('are_you_sure'), text: __('you_want_be_able_to_revert_this'),
                confirmButtonText: __('yes_sure'), cancelButtonText: __('cancel'), icon: 'warning',
                showCancelButton: true, confirmButtonColor: window.adminThemeColor || '#435ebe', cancelButtonColor: '#d33',
            }).then(result => {
                if (result.value) {
                    this.isLoading = true;
                    axios.post(this.$apiUrl + '/branch_users/delete', { id }).then(res => {
                        this.isLoading = false;
                        this.getRecords();
                        this.showMessage('success', res.data.message);
                    });
                }
            });
        },
        hideModal() { this.create_new = false; this.edit_record = null; },
        openCreateModal() { this.create_new = true; this.edit_record = null; this.ensureEventListeners(); },
        openEditModal(record) { this.edit_record = record; this.create_new = false; this.ensureEventListeners(); },
        ensureEventListeners() {
            this.$eventBus.off('branchUserSaved');
            this.$eventBus.on('branchUserSaved', (message) => {
                this.showMessage('success', message);
                this.getRecords();
                this.hideModal();
            });
        },
    },
};
</script>
