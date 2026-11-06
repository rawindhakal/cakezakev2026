<template>

    <div class="list-page">

        <div class="page-head">
            <h3 class="page-head-title">{{ __('role') }}</h3>

            <button
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="openCreateModal()">
                <Plus :size="16" />
                <span>{{ __('add_new') }}</span>
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
                :items="roles"
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

                <template #cell(actions)="row">
                    <div class="list-actions">
                        <button v-if="!nonDeleteAbleRoles.includes(row.item.name)" class="list-action-btn is-edit" @click="openEditModal(row.item)" v-b-tooltip.hover :title="__('edit')">
                            <Pencil :size="15" />
                        </button>
                        <button v-if="!nonDeleteAbleRoles.includes(row.item.name) && row.item.name !== $roleNameBranch" class="list-action-btn is-delete" @click="deleteRecord(row.index,row.item.id)" v-b-tooltip.hover :title="__('delete')">
                            <Trash2 :size="15" />
                        </button>
                    </div>
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
                    <span class="list-range">{{__('total_records')}} - {{ totalRows }}</span>
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
            @modalClose="hideModal()"
        ></app-edit-record>
    </div>

</template>
<script>
import EditRecord from './Edit.vue';
import { Search, RefreshCw, Plus, Pencil, Trash2 } from 'lucide-vue-next';


export default {
    components: {
            'app-edit-record' : EditRecord,
            Search, RefreshCw, Plus, Pencil, Trash2,
    },
    data: function() {
        return {
            roles: [],
            nonDeleteAbleRoles : [this.$roleSuperAdmin,this.$roleDeliveryBoy],
            isLoading: false,
            edit_record : null,
            create_new : null,
            fields: [
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc', class: 'text-center' },
                { key: 'name', label: __('name'), sortable: false, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false, class: 'text-center' }
            ],
            totalRows: 1,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            sortBy: '',
            sortDesc: false,
            sortDirection: 'asc',
            filter: null,
            filterOn: [],
            page: 1,
        }
    },
    created: function() {
        this.category_id = this.$route.params.id;

        this.ensureEventListeners();
        
        this.getRecords();
    },
    beforeUnmount() {
        this.$eventBus.off('roleSaved');
    },
    methods: {

        getRecords(){
            this.isLoading = true
            axios.get(this.$apiUrl + '/role')
                .then((response) => {
                    this.isLoading = false
                    let data = response.data;
                    this.roles = data.data
                    this.totalRows = this.roles.length;
                });
        },
        deleteRecord(index, id){
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
                    axios.post(this.$apiUrl + '/role/delete',postData)
                        .then((response) => {
                            let data = response.data;
                            this.isLoading = false

                            if (data.status === 1) {
                                this.roles.splice(index, 1)
                                this.showMessage("success", data.message)
                            }else{
                                this.showMessage("error", data.message)
                            }
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
            this.$eventBus.off('roleSaved');
            this.$eventBus.on('roleSaved', (message) => {
                this.showMessage("success", message);
                this.getRecords();
                this.hideModal();
            });
        },
    }
};
</script>
