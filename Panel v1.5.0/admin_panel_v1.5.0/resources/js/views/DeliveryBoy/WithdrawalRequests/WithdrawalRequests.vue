<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('withdrawal_request') }}</h3>

            <button
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="create_new=true">
                <Plus :size="16" />
                <span>{{ __('create_withdraw_request') }}</span>
            </button>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-toolbar-start">
                    <AppSelect class="form-control form-select" v-model="status" :options="statusOptions" :searchable="false" @update:model-value="getWthdrawalRequests()" />
                </div>

                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input
                        id="filter-input"
                        v-model="filter"
                        type="search"
                        class="form-control"
                        :placeholder="__('search')">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getWthdrawalRequests()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive
                :items="withdrawalRequests"
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
                <template #cell(amount)="row">
                    <strong>{{ (row.item.currency || $currency) + row.item.amount }}</strong>
                </template>
                <template #cell(status)="row">
                    <span v-if="row.item.status === 0" class="badge bg-warning">{{ __('pending') }}</span>
                    <span v-else-if="row.item.status === 1" class="status-pill is-active">{{ __('approved') }}</span>
                    <span v-else-if="row.item.status === 2" class="status-pill is-inactive">{{ __('rejected') }}</span>
                    <span v-else class="status-pill is-inactive">{{ __('undefine') }}</span>
                </template>
                <template #cell(receipt_image)="row">
                    <img v-if="row.item.receipt_image_url" :src="row.item.receipt_image_url" class="list-thumb" />
                    <span v-else class="text-muted">-</span>
                </template>
                <template #cell(created_at)="row">
                    {{ $filters.formatDateTime(row.item.created_at) }}
                </template>
                <template #cell(message)="row">
                    <small :id="'bonus'+row.item.id" class="d-inline-flex mb-3 px-2 py-1 text-muted bg-secondary bg-opacity-10 border border-secondary border-opacity-10 rounded-2">
                        <Info :size="14" />
                    </small>
                    <b-popover :target="'bonus'+row.item.id" triggers="hover" placement="left">
                        {{ row.item.message }}
                    </b-popover>

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
            :customers="customers"
            :balance="balance"
            :currency="currency"
            @modalClose="hideModal()"
        ></app-edit-record>
    </div>
</template>
<script>
import EditRecord from './Edit.vue';
import { Search, RefreshCw, Plus, Info } from 'lucide-vue-next';

export default {
    components: {
        'app-edit-record': EditRecord,
        Search, RefreshCw, Plus, Info,
    },
    data: function () {
        return {
            fields: [
               { key: 'id', label:  __('id') , sortable: true, sortDirection: 'desc'  , class: 'text-center' },
                { key: 'type', label: __('type'), sortable: false, class: 'text-center' },
                { key: 'name', label: __('name'), sortable: false, class: 'text-center' },
                { key: 'amount', label: __('amount'), sortable: false, class: 'text-center' },            
                { key: 'message', label: __('message'), sortable: false,  class: 'text-center' },
                { key: 'status', label: __('status'), sortable: true, class: 'text-center' },
                { key: 'remark', label: __('remark'), sortable: false, class: 'text-center' },
                { key: 'receipt_image', label: __('receipt_image'), sortable: false, class: 'text-center' },
                { key: 'created_at', label:__('date'), sortable: true, class: 'text-center' },
               
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

            isLoading: false,
            sectionStyle: 'style_1',
            max_visible_units: 12,
            max_col_in_single_row: 3,
            create_new: null,
            edit_record: null,

            customers: null,
            withdrawalRequests: [
                
            ],
            balance: 0,
            currency: '',
            status : ""
        }
    },
    computed: {
        // Fixed option set — no search box needed.
        statusOptions() {
            return [
                { id: '', name: (__('select_status')) },
                { id: '0', name: (__('pending')) },
                { id: '1', name: (__('approved')) },
                { id: '2', name: (__('rejected')) },
            ];
        },
        sortOptions() {
            // Create an options list from our fields
            return this.fields
                .filter(f => f.sortable)
                .map(f => {
                    return {text: f.label, value: f.key}
                })
        }
    },
    mounted() {
        // Set the initial number of items
        this.totalRows = this.withdrawalRequests.length
    },
   
    created: function () {
        this.$eventBus.on('withdrawalRequestsSaved', (message) => {
            //this.showSuccess(message);
            this.showMessage("success", message);
            this.getWthdrawalRequests();
            this.create_new = null;
        });
        this.getWthdrawalRequests();
    },
    methods: {
        getWthdrawalRequests() {
            this.isLoading = true
            let param = {
                "status": this.status
            }
            axios.get(this.$deliveryBoyApiUrl + '/withdrawal_requests',{
                params: param
            })
                .then((response) => {
                    this.isLoading = false
                    this.withdrawalRequests = response.data.data.withdraw_requests;
                    this.totalRows = this.withdrawalRequests.length;
                    this.balance = response.data.data.balance
                    this.currency = response.data.data.currency || this.$currency || ''
                });
        },
        hideModal() {
            this.create_new = false
            this.edit_record = false
        },
    }
};
</script>
